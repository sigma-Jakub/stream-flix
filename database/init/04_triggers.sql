-- watch list triggers for streamflix
-- run this after the updated 01_schema.sql with the setup/admin account
-- a series is fully watched when this profile has completed every available
-- episode in its available seasons
-- INSERT checks a new viewing session, UPDATE checks an existing one
-- NEW means the values in the session we just saved
-- FOR EACH ROW runs the check for each session that was added or changed
-- SELECT ... INTO saves a query result in a variable for the next check
-- changing catalogue availability or adding to the watch list does not run these
-- triggers, those actions need their own checks later
--
-- we use $$ to mark the end of each trigger
-- this lets us use normal semicolons inside BEGIN and END

USE streamflix;

DELIMITER $$

-- removes a completed film or fully watched series after a new session
CREATE OR REPLACE TRIGGER trg_viewing_session_watch_list_after_insert
AFTER INSERT ON viewing_session
FOR EACH ROW
BEGIN
    -- these variables hold the series IDs and episode counts while we check
    DECLARE series_to_check INT;
    DECLARE series_title_id INT;
    DECLARE episode_count INT;
    DECLARE completed_count INT;
    IF NEW.is_completed = TRUE AND NEW.film_id IS NOT NULL THEN
        -- find the film's title_id because the watch list uses title IDs
        -- only remove it from the profile that watched the film
        DELETE FROM watch_list
        WHERE profile_id = NEW.profile_id
          AND title_id = (
              SELECT title_id
              FROM film
              WHERE id = NEW.film_id
          );
    ELSEIF NEW.is_completed = TRUE AND NEW.episode_id IS NOT NULL THEN
        -- find the series and its title through the episode's season
        SELECT season.series_id, series.title_id
        INTO series_to_check, series_title_id
        FROM episode
        JOIN season ON episode.season_id = season.id
        JOIN series ON season.series_id = series.id
        WHERE episode.id = NEW.episode_id;

        -- count all available episodes across the available seasons
        SELECT COUNT(*)
        INTO episode_count
        FROM episode
        JOIN season ON episode.season_id = season.id
        WHERE season.series_id = series_to_check
          AND season.is_available = TRUE
          AND episode.is_available = TRUE;

        -- count the available episodes completed by this profile
        -- DISTINCT counts an episode once, even if it was watched many times
        SELECT COUNT(DISTINCT episode.id)
        INTO completed_count
        FROM episode
        JOIN season ON episode.season_id = season.id
        JOIN viewing_session ON viewing_session.episode_id = episode.id
        WHERE season.series_id = series_to_check
          AND season.is_available = TRUE
          AND episode.is_available = TRUE
          AND viewing_session.profile_id = NEW.profile_id
          AND viewing_session.is_completed = TRUE;

        -- only remove the series when all its available episodes are completed
        -- a series with no available episodes is not counted as watched
        IF episode_count > 0 AND completed_count = episode_count THEN
            DELETE FROM watch_list
            WHERE profile_id = NEW.profile_id
              AND title_id = series_title_id;
        END IF;
    END IF;
END$$

-- does the same checks when a viewing session is updated
CREATE OR REPLACE TRIGGER trg_viewing_session_watch_list_after_update
AFTER UPDATE ON viewing_session
FOR EACH ROW
BEGIN
    -- these variables hold the series IDs and episode counts while we check
    DECLARE series_to_check INT;
    DECLARE series_title_id INT;
    DECLARE episode_count INT;
    DECLARE completed_count INT;
    IF NEW.is_completed = TRUE AND NEW.film_id IS NOT NULL THEN
        DELETE FROM watch_list
        WHERE profile_id = NEW.profile_id
          AND title_id = (
              SELECT title_id
              FROM film
              WHERE id = NEW.film_id
          );
    ELSEIF NEW.is_completed = TRUE AND NEW.episode_id IS NOT NULL THEN
        -- find the series and its title through the episode's season
        SELECT season.series_id, series.title_id
        INTO series_to_check, series_title_id
        FROM episode
        JOIN season ON episode.season_id = season.id
        JOIN series ON season.series_id = series.id
        WHERE episode.id = NEW.episode_id;

        -- count all available episodes across the available seasons
        SELECT COUNT(*)
        INTO episode_count
        FROM episode
        JOIN season ON episode.season_id = season.id
        WHERE season.series_id = series_to_check
          AND season.is_available = TRUE
          AND episode.is_available = TRUE;

        -- count the available episodes completed by this profile
        -- DISTINCT counts an episode once, even if it was watched many times
        SELECT COUNT(DISTINCT episode.id)
        INTO completed_count
        FROM episode
        JOIN season ON episode.season_id = season.id
        JOIN viewing_session ON viewing_session.episode_id = episode.id
        WHERE season.series_id = series_to_check
          AND season.is_available = TRUE
          AND episode.is_available = TRUE
          AND viewing_session.profile_id = NEW.profile_id
          AND viewing_session.is_completed = TRUE;

        -- only remove the series when all its available episodes are completed
        -- a series with no available episodes is not counted as watched
        IF episode_count > 0 AND completed_count = episode_count THEN
            DELETE FROM watch_list
            WHERE profile_id = NEW.profile_id
              AND title_id = series_title_id;
        END IF;
    END IF;
END$$

-- use normal semicolons again
DELIMITER ;
