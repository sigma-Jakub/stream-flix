-- 01_schema.sql - first StreamFlix schema for MariaDB 10.11 or newer.
-- This script follows the reviewed ERD: 30 tables and 46 foreign keys.
-- Run it once in an empty database using a setup/admin account.
-- It does not drop tables or change an existing schema.
--
-- PRIMARY KEY: identifies a row. AUTO_INCREMENT creates the next id.
-- FOREIGN KEY: links a row to a row that must exist in another table.
-- NOT NULL: a value is required. NULL: a value may be left empty.
-- UNIQUE: the value, or combination of values, cannot be repeated.
-- CHECK: the row must follow the stated rule.
--
-- Foreign keys use RESTRICT (the default). Referenced history is not
-- silently deleted. Use is_available to remove content from the catalogue.
-- DATETIME values are stored in UTC by convention.
-- Token hashes are SHA-256 hexadecimal strings; passwords use a proper
-- password-hashing algorithm in the API, not a plain SHA-256 password hash.

CREATE DATABASE IF NOT EXISTS streamflix
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE streamflix;
SET time_zone = '+00:00';


-- 1. Lookup tables

-- age_classification: One fixed classification per minimum age.
CREATE TABLE age_classification (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    minimum_age INT NOT NULL,
    CONSTRAINT uq_age_classification_1 UNIQUE (minimum_age),
    CONSTRAINT ck_age_classification_minimum_age CHECK (
        minimum_age >= 0
    )
) ENGINE=InnoDB;

-- genre: Each genre definition is stored once.
CREATE TABLE genre (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT uq_genre_1 UNIQUE (name),
    CONSTRAINT ck_genre_name CHECK (
        CHAR_LENGTH(TRIM(name)) > 0
    )
) ENGINE=InnoDB;

-- viewing_guide: Each guide definition is stored once, such as violence or fear.
CREATE TABLE viewing_guide (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    CONSTRAINT uq_viewing_guide_1 UNIQUE (name),
    CONSTRAINT ck_viewing_guide_name CHECK (
        CHAR_LENGTH(TRIM(name)) > 0
    )
) ENGINE=InnoDB;

-- quality: SD, HD and UHD each have a unique name and ordering rank.
CREATE TABLE quality (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    quality_rank INT NOT NULL,
    CONSTRAINT uq_quality_1 UNIQUE (name),
    CONSTRAINT uq_quality_2 UNIQUE (quality_rank),
    CONSTRAINT ck_quality_name CHECK (
        name IN ('SD', 'HD', 'UHD')
    ),
    -- The rank puts SD, HD and UHD in order.
    CONSTRAINT ck_quality_rank CHECK (
        (name = 'SD' AND quality_rank = 1)
        OR (name = 'HD' AND quality_rank = 2)
        OR (name = 'UHD' AND quality_rank = 3)
    )
) ENGINE=InnoDB;


-- 2. Accounts, profiles and preferences

-- account: Account and authentication facts only.
CREATE TABLE account (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    application_role VARCHAR(20) NOT NULL DEFAULT 'user',
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    failed_login_count INT NOT NULL DEFAULT 0,
    blocked_until DATETIME NULL,
    trial_ends_at DATETIME NULL,
    CONSTRAINT uq_account_1 UNIQUE (email),
    CONSTRAINT ck_account_email CHECK (
        CHAR_LENGTH(TRIM(email)) > 0
    ),
    CONSTRAINT ck_account_password_hash CHECK (
        CHAR_LENGTH(password_hash) > 0
    ),
    CONSTRAINT ck_account_status CHECK (
        status IN ('pending', 'active', 'payment_blocked', 'deactivated')
    ),
    CONSTRAINT ck_account_role CHECK (
        application_role IN ('user', 'content_manager')
    ),
    CONSTRAINT ck_account_verified CHECK (
        is_verified IN (0, 1)
    ),
    CONSTRAINT ck_account_failed_logins CHECK (
        failed_login_count >= 0
    ),
    -- An account must be verified before it becomes active.
    CONSTRAINT ck_account_active_verified CHECK (
        status <> 'active' OR is_verified = TRUE
    )
) ENGINE=InnoDB;

-- verification_token: Each activation or password-reset token belongs to one account; no copied email or password.
CREATE TABLE verification_token (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    token_hash CHAR(64) NOT NULL,
    purpose VARCHAR(20) NOT NULL,
    expires_at DATETIME NOT NULL,
    used_at DATETIME NULL,
    CONSTRAINT uq_verification_token_1 UNIQUE (token_hash),
    CONSTRAINT fk_verification_token_account_id
        FOREIGN KEY (account_id) REFERENCES account(id),
    -- token_hash contains a SHA-256 hash written as 64 hexadecimal characters.
    CONSTRAINT ck_verification_token_hash CHECK (
        CHAR_LENGTH(TRIM(token_hash)) = 64
    ),
    CONSTRAINT ck_verification_token_purpose CHECK (
        purpose IN ('activation', 'password_reset')
    ),
    CONSTRAINT ck_verification_token_used_at CHECK (
        used_at IS NULL OR used_at <= expires_at
    )
) ENGINE=InnoDB;

-- access_token: One login token belongs to one account.
-- The API saves only the token hash. Logging out sets revoked_at.
CREATE TABLE access_token (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    token_hash CHAR(64) NOT NULL,
    issued_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME NOT NULL,
    revoked_at DATETIME NULL,
    CONSTRAINT uq_access_token_1 UNIQUE (token_hash),
    CONSTRAINT fk_access_token_account_id
        FOREIGN KEY (account_id) REFERENCES account(id),
    CONSTRAINT ck_access_token_hash CHECK (
        CHAR_LENGTH(TRIM(token_hash)) = 64
    ),
    -- A login token is valid for 8 hours from when it was issued.
    CONSTRAINT ck_access_token_expiry CHECK (
        expires_at = issued_at + INTERVAL 8 HOUR
    ),
    CONSTRAINT ck_access_token_revoked_at CHECK (
        revoked_at IS NULL OR revoked_at >= issued_at
    )
) ENGINE=InnoDB;

-- profile: Profile identity and age category only.
CREATE TABLE profile (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    age_classification_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    image_url VARCHAR(2048) NULL,
    CONSTRAINT uq_profile_1 UNIQUE (account_id, name),
    CONSTRAINT fk_profile_account_id
        FOREIGN KEY (account_id) REFERENCES account(id),
    CONSTRAINT fk_profile_age_classification_id
        FOREIGN KEY (age_classification_id) REFERENCES age_classification(id),
    CONSTRAINT ck_profile_name CHECK (
        CHAR_LENGTH(TRIM(name)) > 0
    )
) ENGINE=InnoDB;

-- preference: At most one preference record per profile.
CREATE TABLE preference (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    profile_id INT NOT NULL,
    preferred_title_type VARCHAR(10) NOT NULL DEFAULT 'all',
    minimum_age_classification_id INT NULL,
    maximum_age_classification_id INT NULL,
    CONSTRAINT uq_preference_1 UNIQUE (profile_id),
    CONSTRAINT fk_preference_profile_id
        FOREIGN KEY (profile_id) REFERENCES profile(id),
    CONSTRAINT fk_preference_minimum_age_classification_id
        FOREIGN KEY (minimum_age_classification_id) REFERENCES age_classification(id),
    CONSTRAINT fk_preference_maximum_age_classification_id
        FOREIGN KEY (maximum_age_classification_id) REFERENCES age_classification(id),
    CONSTRAINT ck_preference_title_type CHECK (
        preferred_title_type IN ('all', 'film', 'series')
    )
    -- Age filters may be empty. The procedure must compare the minimum_age
    -- values in age_classification, not the IDs, and respect the profile age.
) ENGINE=InnoDB;

-- preference_genre: One selection per preference and genre.
CREATE TABLE preference_genre (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    preference_id INT NOT NULL,
    genre_id INT NOT NULL,
    CONSTRAINT uq_preference_genre_1 UNIQUE (preference_id, genre_id),
    CONSTRAINT fk_preference_genre_preference_id
        FOREIGN KEY (preference_id) REFERENCES preference(id),
    CONSTRAINT fk_preference_genre_genre_id
        FOREIGN KEY (genre_id) REFERENCES genre(id)
) ENGINE=InnoDB;

-- preference_viewing_guide: One selection per preference and viewing_guide.
CREATE TABLE preference_viewing_guide (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    preference_id INT NOT NULL,
    viewing_guide_id INT NOT NULL,
    CONSTRAINT uq_preference_viewing_guide_1 UNIQUE (preference_id, viewing_guide_id),
    CONSTRAINT fk_preference_viewing_guide_preference_id
        FOREIGN KEY (preference_id) REFERENCES preference(id),
    CONSTRAINT fk_preference_viewing_guide_viewing_guide_id
        FOREIGN KEY (viewing_guide_id) REFERENCES viewing_guide(id)
) ENGINE=InnoDB;


-- 3. Films, series, seasons and episodes

-- title: Common catalogue name, description, classification and availability only.
CREATE TABLE title (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    age_classification_id INT NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_title_age_classification_id
        FOREIGN KEY (age_classification_id) REFERENCES age_classification(id),
    CONSTRAINT ck_title_name CHECK (
        CHAR_LENGTH(TRIM(name)) > 0
    ),
    CONSTRAINT ck_title_available CHECK (
        is_available IN (0, 1)
    )
) ENGINE=InnoDB;

-- film: Film-specific runtime.
CREATE TABLE film (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title_id INT NOT NULL,
    duration_seconds INT NOT NULL,
    CONSTRAINT uq_film_1 UNIQUE (title_id),
    CONSTRAINT fk_film_title_id
        FOREIGN KEY (title_id) REFERENCES title(id),
    CONSTRAINT ck_film_duration CHECK (
        duration_seconds > 0
    )
) ENGINE=InnoDB;

-- series: Series subtype, with id and title_id as candidate keys.
CREATE TABLE series (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title_id INT NOT NULL,
    CONSTRAINT uq_series_1 UNIQUE (title_id),
    CONSTRAINT fk_series_title_id
        FOREIGN KEY (title_id) REFERENCES title(id)
) ENGINE=InnoDB;

-- season: One season belongs to one series.
CREATE TABLE season (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    series_id INT NOT NULL,
    age_classification_id INT NOT NULL,
    season_number INT NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_season_1 UNIQUE (series_id, season_number),
    CONSTRAINT fk_season_series_id
        FOREIGN KEY (series_id) REFERENCES series(id),
    CONSTRAINT fk_season_age_classification_id
        FOREIGN KEY (age_classification_id) REFERENCES age_classification(id),
    CONSTRAINT ck_season_available CHECK (
        is_available IN (0, 1)
    ),
    CONSTRAINT ck_season_number CHECK (
        season_number > 0
    )
) ENGINE=InnoDB;

-- episode: Episode information is stored individually.
CREATE TABLE episode (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    season_id INT NOT NULL,
    age_classification_id INT NOT NULL,
    episode_number INT NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    duration_seconds INT NOT NULL,
    is_available BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_episode_1 UNIQUE (season_id, episode_number),
    CONSTRAINT fk_episode_season_id
        FOREIGN KEY (season_id) REFERENCES season(id),
    CONSTRAINT fk_episode_age_classification_id
        FOREIGN KEY (age_classification_id) REFERENCES age_classification(id),
    CONSTRAINT ck_episode_name CHECK (
        CHAR_LENGTH(TRIM(name)) > 0
    ),
    CONSTRAINT ck_episode_available CHECK (
        is_available IN (0, 1)
    ),
    CONSTRAINT ck_episode_duration CHECK (
        duration_seconds > 0
    ),
    CONSTRAINT ck_episode_number CHECK (
        episode_number > 0
    )
) ENGINE=InnoDB;


-- 4. Catalogue linking tables

-- title_genre: One title/genre association; the pair is unique.
CREATE TABLE title_genre (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title_id INT NOT NULL,
    genre_id INT NOT NULL,
    CONSTRAINT uq_title_genre_1 UNIQUE (title_id, genre_id),
    CONSTRAINT fk_title_genre_title_id
        FOREIGN KEY (title_id) REFERENCES title(id),
    CONSTRAINT fk_title_genre_genre_id
        FOREIGN KEY (genre_id) REFERENCES genre(id)
) ENGINE=InnoDB;

-- title_viewing_guide: One title/guide association.
CREATE TABLE title_viewing_guide (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title_id INT NOT NULL,
    viewing_guide_id INT NOT NULL,
    CONSTRAINT uq_title_viewing_guide_1 UNIQUE (title_id, viewing_guide_id),
    CONSTRAINT fk_title_viewing_guide_title_id
        FOREIGN KEY (title_id) REFERENCES title(id),
    CONSTRAINT fk_title_viewing_guide_viewing_guide_id
        FOREIGN KEY (viewing_guide_id) REFERENCES viewing_guide(id)
) ENGINE=InnoDB;

-- season_viewing_guide: One season association per row.
CREATE TABLE season_viewing_guide (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    season_id INT NOT NULL,
    viewing_guide_id INT NOT NULL,
    CONSTRAINT uq_season_viewing_guide_1 UNIQUE (season_id, viewing_guide_id),
    CONSTRAINT fk_season_viewing_guide_season_id
        FOREIGN KEY (season_id) REFERENCES season(id),
    CONSTRAINT fk_season_viewing_guide_viewing_guide_id
        FOREIGN KEY (viewing_guide_id) REFERENCES viewing_guide(id)
) ENGINE=InnoDB;

-- episode_viewing_guide: Episodes may have additional indicators.
CREATE TABLE episode_viewing_guide (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    episode_id INT NOT NULL,
    viewing_guide_id INT NOT NULL,
    CONSTRAINT uq_episode_viewing_guide_1 UNIQUE (episode_id, viewing_guide_id),
    CONSTRAINT fk_episode_viewing_guide_episode_id
        FOREIGN KEY (episode_id) REFERENCES episode(id),
    CONSTRAINT fk_episode_viewing_guide_viewing_guide_id
        FOREIGN KEY (viewing_guide_id) REFERENCES viewing_guide(id)
) ENGINE=InnoDB;

-- title_quality: Stores available qualities for a film or the allowed quality set for a series.
CREATE TABLE title_quality (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title_id INT NOT NULL,
    quality_id INT NOT NULL,
    CONSTRAINT uq_title_quality_1 UNIQUE (title_id, quality_id),
    CONSTRAINT fk_title_quality_title_id
        FOREIGN KEY (title_id) REFERENCES title(id),
    CONSTRAINT fk_title_quality_quality_id
        FOREIGN KEY (quality_id) REFERENCES quality(id)
) ENGINE=InnoDB;

-- season_quality: One season association per row.
CREATE TABLE season_quality (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    season_id INT NOT NULL,
    quality_id INT NOT NULL,
    CONSTRAINT uq_season_quality_1 UNIQUE (season_id, quality_id),
    CONSTRAINT fk_season_quality_season_id
        FOREIGN KEY (season_id) REFERENCES season(id),
    CONSTRAINT fk_season_quality_quality_id
        FOREIGN KEY (quality_id) REFERENCES quality(id)
) ENGINE=InnoDB;

-- episode_quality: Stores which qualities an individual episode supports.
CREATE TABLE episode_quality (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    episode_id INT NOT NULL,
    quality_id INT NOT NULL,
    CONSTRAINT uq_episode_quality_1 UNIQUE (episode_id, quality_id),
    CONSTRAINT fk_episode_quality_episode_id
        FOREIGN KEY (episode_id) REFERENCES episode(id),
    CONSTRAINT fk_episode_quality_quality_id
        FOREIGN KEY (quality_id) REFERENCES quality(id)
) ENGINE=InnoDB;


-- 5. Viewing and watch lists

-- viewing_session: One playback event belongs to one profile and targets exactly one film_id OR episode_id.
CREATE TABLE viewing_session (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    profile_id INT NOT NULL,
    film_id INT NULL,
    episode_id INT NULL,
    quality_id INT NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    watched_seconds INT NOT NULL DEFAULT 0,
    last_position_seconds INT NOT NULL DEFAULT 0,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    auto_continued BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_viewing_session_profile_id
        FOREIGN KEY (profile_id) REFERENCES profile(id),
    CONSTRAINT fk_viewing_session_film_id
        FOREIGN KEY (film_id) REFERENCES film(id),
    CONSTRAINT fk_viewing_session_episode_id
        FOREIGN KEY (episode_id) REFERENCES episode(id),
    CONSTRAINT fk_viewing_session_quality_id
        FOREIGN KEY (quality_id) REFERENCES quality(id),
    -- A session is for one film OR one episode, never both.
    CONSTRAINT ck_viewing_session_target CHECK (
        (film_id IS NOT NULL AND episode_id IS NULL)
        OR (film_id IS NULL AND episode_id IS NOT NULL)
    ),
    CONSTRAINT ck_viewing_session_watched CHECK (
        watched_seconds >= 0
    ),
    CONSTRAINT ck_viewing_session_position CHECK (
        last_position_seconds >= 0
    ),
    CONSTRAINT ck_viewing_session_completed CHECK (
        is_completed IN (0, 1)
    ),
    CONSTRAINT ck_viewing_session_continued CHECK (
        auto_continued IN (0, 1)
    ),
    -- Automatic continuation only applies to episodes.
    CONSTRAINT ck_viewing_session_episode_continue CHECK (
        film_id IS NULL OR auto_continued = FALSE
    )
) ENGINE=InnoDB;

-- watch_list: One saved film or series per profile per row; the pair is unique.
CREATE TABLE watch_list (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    profile_id INT NOT NULL,
    title_id INT NOT NULL,
    added_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_watch_list_1 UNIQUE (profile_id, title_id),
    CONSTRAINT fk_watch_list_profile_id
        FOREIGN KEY (profile_id) REFERENCES profile(id),
    CONSTRAINT fk_watch_list_title_id
        FOREIGN KEY (title_id) REFERENCES title(id)
) ENGINE=InnoDB;


-- 6. Subscriptions, payments and invitations

-- subscription_type: Plan definition and current monthly price are stored once, separate from account subscription periods.
CREATE TABLE subscription_type (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    maximum_quality_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    monthly_price DECIMAL(10,2) NOT NULL,
    CONSTRAINT uq_subscription_type_1 UNIQUE (name),
    CONSTRAINT fk_subscription_type_maximum_quality_id
        FOREIGN KEY (maximum_quality_id) REFERENCES quality(id),
    CONSTRAINT ck_subscription_type_name CHECK (
        CHAR_LENGTH(TRIM(name)) > 0
    ),
    CONSTRAINT ck_subscription_type_name_values CHECK (
        name IN ('SD', 'HD', 'UHD')
    ),
    CONSTRAINT ck_subscription_type_price CHECK (
        monthly_price >= 0
    )
) ENGINE=InnoDB;

-- subscription: One paid plan period belongs to one account.
CREATE TABLE subscription (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    subscription_type_id INT NOT NULL,
    started_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at DATETIME NULL,
    -- This helper is filled in by MariaDB, not by the API.
    -- An open subscription gets its account_id; a closed one gets NULL.
    -- UNIQUE then allows only one open subscription for each account.
    -- Many closed subscriptions are allowed because UNIQUE allows many NULLs.
    -- VIRTUAL means the value is calculated, not stored as another fact.
    open_account_id INT GENERATED ALWAYS AS (
        CASE WHEN ended_at IS NULL THEN account_id ELSE NULL END
    ) VIRTUAL,
    CONSTRAINT uq_subscription_open_account UNIQUE (open_account_id),
    CONSTRAINT fk_subscription_account_id
        FOREIGN KEY (account_id) REFERENCES account(id),
    CONSTRAINT fk_subscription_subscription_type_id
        FOREIGN KEY (subscription_type_id) REFERENCES subscription_type(id),
    CONSTRAINT ck_subscription_period CHECK (
        ended_at IS NULL OR ended_at >= started_at
    )
) ENGINE=InnoDB;

-- payment: One monthly bill/payment record.
CREATE TABLE payment (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    subscription_id INT NOT NULL,
    billing_period_start DATE NOT NULL,
    payment_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'open',
    failed_at DATETIME NULL,
    CONSTRAINT uq_payment_1 UNIQUE (subscription_id, billing_period_start),
    CONSTRAINT fk_payment_subscription_id
        FOREIGN KEY (subscription_id) REFERENCES subscription(id),
    -- Use the first day of the billed month, so the UNIQUE key allows one bill per month.
    CONSTRAINT ck_payment_month CHECK (
        DAY(billing_period_start) = 1
    ),
    CONSTRAINT ck_payment_amount CHECK (
        amount >= 0
    ),
    CONSTRAINT ck_payment_discount CHECK (
        discount_amount >= 0 AND discount_amount <= amount
    ),
    CONSTRAINT ck_payment_status CHECK (
        status IN ('open', 'paid', 'failed')
    ),
    CONSTRAINT ck_payment_failure_date CHECK (
        status <> 'failed' OR failed_at IS NOT NULL
    )
) ENGINE=InnoDB;

-- invitation: Links the account that invited someone to the account that accepted.
CREATE TABLE invitation (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    inviter_account_id INT NOT NULL,
    invitee_account_id INT NULL,
    token_hash CHAR(64) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    CONSTRAINT uq_invitation_1 UNIQUE (token_hash),
    CONSTRAINT uq_invitation_2 UNIQUE (invitee_account_id),
    CONSTRAINT fk_invitation_inviter_account_id
        FOREIGN KEY (inviter_account_id) REFERENCES account(id),
    CONSTRAINT fk_invitation_invitee_account_id
        FOREIGN KEY (invitee_account_id) REFERENCES account(id),
    CONSTRAINT ck_invitation_hash CHECK (
        CHAR_LENGTH(TRIM(token_hash)) = 64
    ),
    CONSTRAINT ck_invitation_status CHECK (
        status IN ('pending', 'accepted', 'rewarded', 'expired', 'revoked')
    ),
    CONSTRAINT ck_invitation_different_accounts CHECK (
        invitee_account_id IS NULL OR invitee_account_id <> inviter_account_id
    ),
    CONSTRAINT ck_invitation_recipient CHECK (
        status NOT IN ('accepted', 'rewarded') OR invitee_account_id IS NOT NULL
    ),
    CONSTRAINT ck_invitation_pending CHECK (
        status <> 'pending' OR invitee_account_id IS NULL
    )
) ENGINE=InnoDB;

-- invitation_discount: One discount record belongs to one account.
-- The procedure adds one row for each account in the same transaction.
-- Both receive EUR 2.00 per month for 3 months.
CREATE TABLE invitation_discount (
    id INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    invitation_id INT NOT NULL,
    account_id INT NOT NULL,
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    monthly_amount DECIMAL(10,2) NOT NULL,
    -- Each account can receive an invitation discount only once.
    CONSTRAINT uq_invitation_discount_1 UNIQUE (account_id),
    CONSTRAINT fk_invitation_discount_invitation_id
        FOREIGN KEY (invitation_id) REFERENCES invitation(id),
    CONSTRAINT fk_invitation_discount_account_id
        FOREIGN KEY (account_id) REFERENCES account(id),
    CONSTRAINT ck_invitation_discount_period CHECK (
        ends_at > starts_at
    ),
    CONSTRAINT ck_invitation_discount_amount CHECK (
        monthly_amount > 0
    )
) ENGINE=InnoDB;


-- Rules for the later procedures/triggers (not implemented in this file):
-- 1. Each title must have exactly one film OR series subtype.
--    Separate UNIQUE(title_id) keys do not enforce that across two tables.
-- 2. Paid subscription periods for one account must not overlap.
--    UNIQUE(open_account_id) already prevents two open periods, but it
--    does not prevent overlapping periods that have an end date.
-- 3. Age restrictions, quality limits and resume positions need checks
--    against other rows. They cannot be enforced by these row CHECKs alone.
--    Compare preference age_classification.minimum_age values, not their IDs.
-- 4. Remove completed titles from watch_list using the required trigger.
-- 5. Activate both invitation discounts in one transaction. Check that
--    each recipient is one of the invitation's two accounts, set the same
--    3-month period and EUR 2.00 amount for both, and mark it rewarded.
--    UNIQUE(account_id) prevents an account receiving another discount.
--    Revoke an invitation only while it is pending.
-- 6. Activate the seven-day trial and apply login/payment blocking policies.
-- 7. Create employee/API views, roles and controlled write procedures.
--    api_user_account must not receive direct access to these tables.
