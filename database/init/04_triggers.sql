-- watch list triggers for streamflix
-- run this after the updated 01_schema.sql with the setup/admin account
-- INSERT checks a new viewing session, UPDATE checks an existing one
-- NEW means the values in the session we just saved
-- FOR EACH ROW runs the check for each session that was added or changed
--
-- we use $$ to mark the end of each trigger
-- this lets us use normal semicolons inside BEGIN and END

USE streamflix;

DELIMITER $$

-- removes the film if a new session is saved as completed
CREATE OR REPLACE TRIGGER trg_viewing_session_watch_list_after_insert
AFTER INSERT ON viewing_session
FOR EACH ROW
BEGIN
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
    END IF;
END$$

-- does the same check when a viewing session is updated
CREATE OR REPLACE TRIGGER trg_viewing_session_watch_list_after_update
AFTER UPDATE ON viewing_session
FOR EACH ROW
BEGIN
    IF NEW.is_completed = TRUE AND NEW.film_id IS NOT NULL THEN
        DELETE FROM watch_list
        WHERE profile_id = NEW.profile_id
          AND title_id = (
              SELECT title_id
              FROM film
              WHERE id = NEW.film_id
          );
    END IF;
END$$

-- use normal semicolons again
DELIMITER ;
