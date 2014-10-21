--
-- This is a Media Cloud PostgreSQL schema difference file (a "diff") between schema
-- versions 4473 and 4474.
--
-- If you are running Media Cloud with a database that was set up with a schema version
-- 4473, and you would like to upgrade both the Media Cloud and the
-- database to be at version 4474, import this SQL file:
--
--     psql mediacloud < mediawords-4473-4474.sql
--
-- You might need to import some additional schema diff files to reach the desired version.
--

--
-- 1 of 2. Import the output of 'apgdiff':
--

SET search_path = public, pg_catalog;


DROP FUNCTION upsert_bitly_story_statistics(INT, INT, INT);
DROP FUNCTION num_controversy_stories_without_bitly_statistics(INT);
DROP TABLE bitly_story_statistics;


-- Bit.ly click statistics for stories, broken down into days (sparse table --
-- only days for which there are records are stored)
CREATE TABLE bitly_story_clicks (
    bitly_story_statistics_id   SERIAL      PRIMARY KEY,
    stories_id                  INT         NOT NULL REFERENCES stories ON DELETE CASCADE,

    -- Day for which the click count is being saved
    click_date                  DATE        NOT NULL,

    -- Click count
    click_count                 INT         NOT NULL
);
CREATE UNIQUE INDEX bitly_story_clicks_stories_id_date
    ON bitly_story_clicks ( stories_id, click_date );

-- Helper to INSERT / UPDATE story's Bit.ly statistics
CREATE FUNCTION upsert_bitly_story_clicks (
    param_stories_id INT,
    param_click_date DATE,
    param_click_count INT
) RETURNS VOID AS
$$
BEGIN

    LOOP
        -- Try UPDATing
        UPDATE bitly_story_clicks
            SET click_count = param_click_count
            WHERE stories_id = param_stories_id
              AND click_date = param_click_date;
        IF FOUND THEN RETURN; END IF;

        -- Nothing to UPDATE, try to INSERT a new record
        BEGIN
            INSERT INTO bitly_story_clicks (stories_id, click_date, click_count)
            VALUES (param_stories_id, param_click_date, param_click_count);
            RETURN;
        EXCEPTION WHEN UNIQUE_VIOLATION THEN
            -- If someone else INSERTs the same key concurrently,
            -- we will get a unique-key failure. In that case, do
            -- nothing and loop to try the UPDATE again.
        END;
    END LOOP;
END;
$$
LANGUAGE plpgsql;


-- Bit.ly referrer statistics for stories
CREATE TABLE bitly_story_referrers (
    bitly_story_statistics_id   SERIAL      PRIMARY KEY,
    stories_id                  INT         NOT NULL REFERENCES stories ON DELETE CASCADE,

    -- Day range for which the referrer count is being saved
    referrer_start_date         DATE        NOT NULL,
    referrer_end_date           DATE        NOT NULL,

    -- Referrer count
    referrer_count              INT         NOT NULL
);
CREATE UNIQUE INDEX bitly_story_referrers_stories_id_start_date_end_date
    ON bitly_story_referrers ( stories_id, referrer_start_date, referrer_end_date );

-- Helper to INSERT / UPDATE story's Bit.ly statistics
CREATE FUNCTION upsert_bitly_story_referrers (
    param_stories_id INT,
    param_referrer_start_date DATE,
    param_referrer_end_date DATE,
    param_referrer_count INT
) RETURNS VOID AS
$$
BEGIN

    LOOP
        -- Try UPDATing
        UPDATE bitly_story_referrers
            SET referrer_count = param_referrer_count
            WHERE stories_id = param_stories_id
              AND referrer_start_date = param_referrer_start_date
              AND referrer_end_date = param_referrer_end_date;
        IF FOUND THEN RETURN; END IF;

        -- Nothing to UPDATE, try to INSERT a new record
        BEGIN
            INSERT INTO bitly_story_referrers (stories_id, referrer_start_date, referrer_end_date, referrer_count)
            VALUES (param_stories_id, param_referrer_start_date, param_referrer_end_date, param_referrer_count);
            RETURN;
        EXCEPTION WHEN UNIQUE_VIOLATION THEN
            -- If someone else INSERTs the same key concurrently,
            -- we will get a unique-key failure. In that case, do
            -- nothing and loop to try the UPDATE again.
        END;
    END LOOP;
END;
$$
LANGUAGE plpgsql;


CREATE FUNCTION num_controversy_stories_without_bitly_statistics (param_controversies_id INT) RETURNS INT AS
$$
DECLARE
    controversy_exists BOOL;
    num_stories_without_bitly_statistics INT;
BEGIN

    SELECT 1 INTO controversy_exists
    FROM controversies
    WHERE controversies_id = param_controversies_id
      AND process_with_bitly = 't';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Controversy % does not exist or is not set up for Bit.ly processing.', param_controversies_id;
        RETURN FALSE;
    END IF;

    SELECT COUNT(stories_id) INTO num_stories_without_bitly_statistics
    FROM controversy_stories
    WHERE controversies_id = param_controversies_id
      AND stories_id NOT IN (
        SELECT stories_id
        FROM bitly_story_clicks
      )
      AND stories_id NOT IN (
        SELECT stories_id
        FROM bitly_story_referrers
      )
    GROUP BY controversies_id;
    IF NOT FOUND THEN
        num_stories_without_bitly_statistics := 0;
    END IF;

    RETURN num_stories_without_bitly_statistics;
END;
$$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION set_database_schema_version() RETURNS boolean AS $$
DECLARE
    
    -- Database schema version number (same as a SVN revision number)
    -- Increase it by 1 if you make major database schema changes.
    MEDIACLOUD_DATABASE_SCHEMA_VERSION CONSTANT INT := 4474;
    
BEGIN

    -- Update / set database schema version
    DELETE FROM database_variables WHERE name = 'database-schema-version';
    INSERT INTO database_variables (name, value) VALUES ('database-schema-version', MEDIACLOUD_DATABASE_SCHEMA_VERSION::int);

    return true;
    
END;
$$
LANGUAGE 'plpgsql';

--
-- 2 of 2. Reset the database version.
--
SELECT set_database_schema_version();

