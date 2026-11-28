-- employee views for streamflix
-- run this after the updated 01_schema.sql, using the setup/admin account
-- a view is a saved SELECT query, it does not store another copy of the data
-- CREATE OR REPLACE means we can run the file again to update the views
-- JOIN connects rows from related tables
-- LEFT JOIN keeps the row even if there is no matching row in the other table
-- AS gives a table or column another name in this query
--
-- permissions to add later in 05_security.sql:
-- junior can read the v_junior_ views
-- mid-level can also read the v_mid_ views
-- senior can read all these employee views
-- none of these views show password or token hashes
-- this file only creates the views, it does not give users access yet
-- we still need to give each role access to its views, not the tables
-- permissions to change accounts and profiles will be added separately
-- API views will be added later with names starting with v_api_

USE streamflix;


-- 1. junior employees

-- shows the account ID and status
CREATE OR REPLACE VIEW v_junior_account AS
SELECT
    id,
    status
FROM account;

-- shows the profile details and the age linked to the profile
CREATE OR REPLACE VIEW v_junior_profile AS
SELECT
    profile.id,
    profile.account_id,
    profile.name,
    profile.image_url,
    profile.age_classification_id,
    age_classification.minimum_age
FROM profile
JOIN age_classification
    ON profile.age_classification_id = age_classification.id;


-- 2. mid-level employees

-- shows account details, without prices, payments, discounts or hashes
-- blocked_until shows when the temporary login block ends
CREATE OR REPLACE VIEW v_mid_account AS
SELECT
    id,
    email,
    status,
    application_role,
    is_verified,
    blocked_until
FROM account;

-- shows the saved preferences and their minimum and maximum ages
-- both ages use age_classification, so we give it a different name for each one
-- LEFT JOIN keeps the preference even when an age filter is not set
-- profiles without saved preferences still appear in v_junior_profile
CREATE OR REPLACE VIEW v_mid_preference AS
SELECT
    preference.id,
    preference.profile_id,
    preference.preferred_title_type,
    preference.minimum_age_classification_id,
    minimum_age.minimum_age AS minimum_title_age,
    preference.maximum_age_classification_id,
    maximum_age.minimum_age AS maximum_title_age
FROM preference
LEFT JOIN age_classification AS minimum_age
    ON preference.minimum_age_classification_id = minimum_age.id
LEFT JOIN age_classification AS maximum_age
    ON preference.maximum_age_classification_id = maximum_age.id;

-- shows each selected genre and the profile it belongs to
CREATE OR REPLACE VIEW v_mid_preference_genre AS
SELECT
    preference_genre.id,
    preference_genre.preference_id,
    preference.profile_id,
    preference_genre.genre_id,
    genre.name AS genre_name
FROM preference_genre
JOIN preference
    ON preference_genre.preference_id = preference.id
JOIN genre
    ON preference_genre.genre_id = genre.id;

-- shows the viewing warnings a profile wants to avoid, such as violence or fear
CREATE OR REPLACE VIEW v_mid_preference_viewing_guide AS
SELECT
    preference_viewing_guide.id,
    preference_viewing_guide.preference_id,
    preference.profile_id,
    preference_viewing_guide.viewing_guide_id,
    viewing_guide.name AS viewing_guide_name
FROM preference_viewing_guide
JOIN preference
    ON preference_viewing_guide.preference_id = preference.id
JOIN viewing_guide
    ON preference_viewing_guide.viewing_guide_id = viewing_guide.id;


-- 3. senior employees

-- shows subscriptions and the current price of each plan
-- the amount billed in the past is shown in the payment view below
CREATE OR REPLACE VIEW v_senior_subscription AS
SELECT
    subscription.id,
    subscription.account_id,
    account.email,
    subscription.subscription_type_id,
    subscription_type.name AS subscription_type_name,
    subscription_type.monthly_price AS current_monthly_price,
    subscription_type.maximum_quality_id,
    quality.name AS maximum_quality_name,
    subscription.started_at,
    subscription.ended_at
FROM subscription
JOIN account
    ON subscription.account_id = account.id
JOIN subscription_type
    ON subscription.subscription_type_id = subscription_type.id
JOIN quality
    ON subscription_type.maximum_quality_id = quality.id;

-- shows payments and which account they belong to
-- net_amount is the amount minus the discount, calculated when we read the view
CREATE OR REPLACE VIEW v_senior_payment AS
SELECT
    payment.id,
    payment.subscription_id,
    subscription.account_id,
    account.email,
    payment.billing_period_start,
    payment.payment_date,
    payment.amount,
    payment.discount_amount,
    payment.amount - payment.discount_amount AS net_amount,
    payment.status,
    payment.failed_at
FROM payment
JOIN subscription
    ON payment.subscription_id = subscription.id
JOIN account
    ON subscription.account_id = account.id;

-- shows viewing history, including sessions that are not completed
-- each session is for a film or an episode, so we use LEFT JOIN for both
-- titles stay in the history even if they are no longer available
CREATE OR REPLACE VIEW v_senior_viewing_session AS
SELECT
    viewing_session.id,
    viewing_session.profile_id,
    profile.name AS profile_name,
    profile.account_id,
    account.email,
    viewing_session.film_id,
    title.name AS film_name,
    viewing_session.episode_id,
    episode.name AS episode_name,
    viewing_session.quality_id,
    quality.name AS quality_name,
    viewing_session.started_at,
    viewing_session.watched_seconds,
    viewing_session.last_position_seconds,
    viewing_session.is_completed,
    viewing_session.auto_continued
FROM viewing_session
JOIN profile
    ON viewing_session.profile_id = profile.id
JOIN account
    ON profile.account_id = account.id
JOIN quality
    ON viewing_session.quality_id = quality.id
LEFT JOIN film
    ON viewing_session.film_id = film.id
LEFT JOIN title
    ON film.title_id = title.id
LEFT JOIN episode
    ON viewing_session.episode_id = episode.id;

-- shows who sent and accepted an invitation, without the token hash
-- LEFT JOIN keeps pending invitations that have not been accepted yet
CREATE OR REPLACE VIEW v_senior_invitation AS
SELECT
    invitation.id,
    invitation.inviter_account_id,
    inviter.email AS inviter_email,
    invitation.invitee_account_id,
    invitee.email AS invitee_email,
    invitation.status
FROM invitation
JOIN account AS inviter
    ON invitation.inviter_account_id = inviter.id
LEFT JOIN account AS invitee
    ON invitation.invitee_account_id = invitee.id;

-- shows each account's invitation discount, only for senior employees
CREATE OR REPLACE VIEW v_senior_invitation_discount AS
SELECT
    invitation_discount.id,
    invitation_discount.invitation_id,
    invitation_discount.account_id,
    account.email,
    invitation_discount.starts_at,
    invitation_discount.ends_at,
    invitation_discount.monthly_amount
FROM invitation_discount
JOIN account
    ON invitation_discount.account_id = account.id;


-- examples to try after running this file:
-- SELECT * FROM v_junior_account;
-- SELECT * FROM v_junior_profile;
-- SELECT * FROM v_mid_preference;
-- SELECT * FROM v_senior_payment;
-- SELECT * FROM v_senior_viewing_session;
-- SELECT * FROM v_senior_invitation_discount;
-- if there is no test data yet, these queries will return no rows
