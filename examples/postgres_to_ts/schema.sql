--
-- PostgreSQL database dump
--

-- Dumped from database version 14.16
-- Dumped by pg_dump version 14.14 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: metric_helpers; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA metric_helpers;


ALTER SCHEMA metric_helpers OWNER TO postgres;

--
-- Name: user_management; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA user_management;


ALTER SCHEMA user_management OWNER TO postgres;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pg_stat_statements IS 'track planning and execution statistics of all SQL statements executed';


--
-- Name: pgaudit; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgaudit WITH SCHEMA public;


--
-- Name: EXTENSION pgaudit; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgaudit IS 'provides auditing functionality';


--
-- Name: pgauditlogtofile; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgauditlogtofile WITH SCHEMA public;


--
-- Name: EXTENSION pgauditlogtofile; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgauditlogtofile IS 'pgAudit addon to redirect audit entries to an independent file';


--
-- Name: get_btree_bloat_approx(); Type: FUNCTION; Schema: metric_helpers; Owner: postgres
--

CREATE FUNCTION metric_helpers.get_btree_bloat_approx(OUT i_database name, OUT i_schema_name name, OUT i_table_name name, OUT i_index_name name, OUT i_real_size numeric, OUT i_extra_size numeric, OUT i_extra_ratio double precision, OUT i_fill_factor integer, OUT i_bloat_size double precision, OUT i_bloat_ratio double precision, OUT i_is_na boolean) RETURNS SETOF record
    LANGUAGE sql IMMUTABLE STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
SELECT current_database(), nspname AS schemaname, tblname, idxname, bs*(relpages)::bigint AS real_size,
  bs*(relpages-est_pages)::bigint AS extra_size,
  100 * (relpages-est_pages)::float / relpages AS extra_ratio,
  fillfactor,
  CASE WHEN relpages > est_pages_ff
    THEN bs*(relpages-est_pages_ff)
    ELSE 0
  END AS bloat_size,
  100 * (relpages-est_pages_ff)::float / relpages AS bloat_ratio,
  is_na
  -- , 100-(pst).avg_leaf_density AS pst_avg_bloat, est_pages, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, reltuples, relpages -- (DEBUG INFO)
FROM (
  SELECT coalesce(1 +
         ceil(reltuples/floor((bs-pageopqdata-pagehdr)/(4+nulldatahdrwidth)::float)), 0 -- ItemIdData size + computed avg size of a tuple (nulldatahdrwidth)
      ) AS est_pages,
      coalesce(1 +
         ceil(reltuples/floor((bs-pageopqdata-pagehdr)*fillfactor/(100*(4+nulldatahdrwidth)::float))), 0
      ) AS est_pages_ff,
      bs, nspname, tblname, idxname, relpages, fillfactor, is_na
      -- , pgstatindex(idxoid) AS pst, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, reltuples -- (DEBUG INFO)
  FROM (
      SELECT maxalign, bs, nspname, tblname, idxname, reltuples, relpages, idxoid, fillfactor,
            ( index_tuple_hdr_bm +
                maxalign - CASE -- Add padding to the index tuple header to align on MAXALIGN
                  WHEN index_tuple_hdr_bm%maxalign = 0 THEN maxalign
                  ELSE index_tuple_hdr_bm%maxalign
                END
              + nulldatawidth + maxalign - CASE -- Add padding to the data to align on MAXALIGN
                  WHEN nulldatawidth = 0 THEN 0
                  WHEN nulldatawidth::integer%maxalign = 0 THEN maxalign
                  ELSE nulldatawidth::integer%maxalign
                END
            )::numeric AS nulldatahdrwidth, pagehdr, pageopqdata, is_na
            -- , index_tuple_hdr_bm, nulldatawidth -- (DEBUG INFO)
      FROM (
          SELECT n.nspname, ct.relname AS tblname, i.idxname, i.reltuples, i.relpages,
              i.idxoid, i.fillfactor, current_setting('block_size')::numeric AS bs,
              CASE -- MAXALIGN: 4 on 32bits, 8 on 64bits (and mingw32 ?)
                WHEN version() ~ 'mingw32' OR version() ~ '64-bit|x86_64|ppc64|ia64|amd64' THEN 8
                ELSE 4
              END AS maxalign,
              /* per page header, fixed size: 20 for 7.X, 24 for others */
              24 AS pagehdr,
              /* per page btree opaque data */
              16 AS pageopqdata,
              /* per tuple header: add IndexAttributeBitMapData if some cols are null-able */
              CASE WHEN max(coalesce(s.stanullfrac,0)) = 0
                  THEN 2 -- IndexTupleData size
                  ELSE 2 + (( 32 + 8 - 1 ) / 8) -- IndexTupleData size + IndexAttributeBitMapData size ( max num filed per index + 8 - 1 /8)
              END AS index_tuple_hdr_bm,
              /* data len: we remove null values save space using it fractionnal part from stats */
              sum( (1-coalesce(s.stanullfrac, 0)) * coalesce(s.stawidth, 1024)) AS nulldatawidth,
              max( CASE WHEN a.atttypid = 'pg_catalog.name'::regtype THEN 1 ELSE 0 END ) > 0 AS is_na
          FROM (
              SELECT idxname, reltuples, relpages, tbloid, idxoid, fillfactor,
                  CASE WHEN indkey[i]=0 THEN idxoid ELSE tbloid END AS att_rel,
                  CASE WHEN indkey[i]=0 THEN i ELSE indkey[i] END AS att_pos
              FROM (
                  SELECT idxname, reltuples, relpages, tbloid, idxoid, fillfactor, indkey, generate_series(1,indnatts) AS i
                  FROM (
                      SELECT ci.relname AS idxname, ci.reltuples, ci.relpages, i.indrelid AS tbloid,
                          i.indexrelid AS idxoid,
                          coalesce(substring(
                              array_to_string(ci.reloptions, ' ')
                              from 'fillfactor=([0-9]+)')::smallint, 90) AS fillfactor,
                          i.indnatts,
                          string_to_array(textin(int2vectorout(i.indkey)),' ')::int[] AS indkey
                      FROM pg_index i
                      JOIN pg_class ci ON ci.oid=i.indexrelid
                      WHERE ci.relam=(SELECT oid FROM pg_am WHERE amname = 'btree')
                        AND ci.relpages > 0
                  ) AS idx_data
              ) AS idx_data_cross
          ) i
          JOIN pg_attribute a ON a.attrelid = i.att_rel
                             AND a.attnum = i.att_pos
          JOIN pg_statistic s ON s.starelid = i.att_rel
                             AND s.staattnum = i.att_pos
          JOIN pg_class ct ON ct.oid = i.tbloid
          JOIN pg_namespace n ON ct.relnamespace = n.oid
          GROUP BY 1,2,3,4,5,6,7,8,9,10
      ) AS rows_data_stats
  ) AS rows_hdr_pdg_stats
) AS relation_stats;
$$;


ALTER FUNCTION metric_helpers.get_btree_bloat_approx(OUT i_database name, OUT i_schema_name name, OUT i_table_name name, OUT i_index_name name, OUT i_real_size numeric, OUT i_extra_size numeric, OUT i_extra_ratio double precision, OUT i_fill_factor integer, OUT i_bloat_size double precision, OUT i_bloat_ratio double precision, OUT i_is_na boolean) OWNER TO postgres;

--
-- Name: get_table_bloat_approx(); Type: FUNCTION; Schema: metric_helpers; Owner: postgres
--

CREATE FUNCTION metric_helpers.get_table_bloat_approx(OUT t_database name, OUT t_schema_name name, OUT t_table_name name, OUT t_real_size numeric, OUT t_extra_size double precision, OUT t_extra_ratio double precision, OUT t_fill_factor integer, OUT t_bloat_size double precision, OUT t_bloat_ratio double precision, OUT t_is_na boolean) RETURNS SETOF record
    LANGUAGE sql IMMUTABLE STRICT SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
SELECT
  current_database(),
  schemaname,
  tblname,
  (bs*tblpages) AS real_size,
  ((tblpages-est_tblpages)*bs) AS extra_size,
  CASE WHEN tblpages - est_tblpages > 0
    THEN 100 * (tblpages - est_tblpages)/tblpages::float
    ELSE 0
  END AS extra_ratio,
  fillfactor,
  CASE WHEN tblpages - est_tblpages_ff > 0
    THEN (tblpages-est_tblpages_ff)*bs
    ELSE 0
  END AS bloat_size,
  CASE WHEN tblpages - est_tblpages_ff > 0
    THEN 100 * (tblpages - est_tblpages_ff)/tblpages::float
    ELSE 0
  END AS bloat_ratio,
  is_na
FROM (
  SELECT ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil( toasttuples / 4 ) AS est_tblpages,
    ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
    tblpages, fillfactor, bs, tblid, schemaname, tblname, heappages, toastpages, is_na
    -- , tpl_hdr_size, tpl_data_size, pgstattuple(tblid) AS pst -- (DEBUG INFO)
  FROM (
    SELECT
      ( 4 + tpl_hdr_size + tpl_data_size + (2*ma)
        - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
        - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
      ) AS tpl_size, bs - page_hdr AS size_per_block, (heappages + toastpages) AS tblpages, heappages,
      toastpages, reltuples, toasttuples, bs, page_hdr, tblid, schemaname, tblname, fillfactor, is_na
      -- , tpl_hdr_size, tpl_data_size
    FROM (
      SELECT
        tbl.oid AS tblid, ns.nspname AS schemaname, tbl.relname AS tblname, tbl.reltuples,
        tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
        coalesce(toast.reltuples, 0) AS toasttuples,
        coalesce(substring(
          array_to_string(tbl.reloptions, ' ')
          FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor,
        current_setting('block_size')::numeric AS bs,
        CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
        24 AS page_hdr,
        23 + CASE WHEN MAX(coalesce(s.null_frac,0)) > 0 THEN ( 7 + count(s.attname) ) / 8 ELSE 0::int END
           + CASE WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4 ELSE 0 END AS tpl_hdr_size,
        sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0) ) AS tpl_data_size,
        bool_or(att.atttypid = 'pg_catalog.name'::regtype)
          OR sum(CASE WHEN att.attnum > 0 THEN 1 ELSE 0 END) <> count(s.attname) AS is_na
      FROM pg_attribute AS att
        JOIN pg_class AS tbl ON att.attrelid = tbl.oid
        JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
        LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname
          AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
        LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
      WHERE NOT att.attisdropped
        AND tbl.relkind = 'r'
      GROUP BY 1,2,3,4,5,6,7,8,9,10
      ORDER BY 2,3
    ) AS s
  ) AS s2
) AS s3 WHERE schemaname NOT LIKE 'information_schema';
$$;


ALTER FUNCTION metric_helpers.get_table_bloat_approx(OUT t_database name, OUT t_schema_name name, OUT t_table_name name, OUT t_real_size numeric, OUT t_extra_size double precision, OUT t_extra_ratio double precision, OUT t_fill_factor integer, OUT t_bloat_size double precision, OUT t_bloat_ratio double precision, OUT t_is_na boolean) OWNER TO postgres;

--
-- Name: pg_stat_statements(boolean); Type: FUNCTION; Schema: metric_helpers; Owner: postgres
--

CREATE FUNCTION metric_helpers.pg_stat_statements(showtext boolean) RETURNS SETOF public.pg_stat_statements
    LANGUAGE sql IMMUTABLE STRICT SECURITY DEFINER
    AS $$
  SELECT * FROM public.pg_stat_statements(showtext);
$$;


ALTER FUNCTION metric_helpers.pg_stat_statements(showtext boolean) OWNER TO postgres;

--
-- Name: add(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.add(integer, integer) RETURNS integer
    LANGUAGE sql IMMUTABLE STRICT
    AS $_$select $1 + $2;$_$;


ALTER FUNCTION public.add(integer, integer) OWNER TO postgres;

--
-- Name: filtertests(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.filtertests(text) RETURNS text
    LANGUAGE plpgsql
    AS $_$
    DECLARE
        filtered text;
	BEGIN

    	SELECT regexp_replace($1, '"PATIENT_CODE",', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, '"USER_CODE",', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, '"REGISTRATION",', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, '"SPEECH_TEST",', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, '"INTRO",', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, '"REMOTE_INTRO",', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, '"INPUT_DEVICE_SELECT",', '', 'g') INTO filtered;

        SELECT regexp_replace(filtered, '"RAVLT_REC"', '"RAVLT_RECOGNITION"') INTO filtered;
        SELECT regexp_replace(filtered, '"TMT_ONLY_A"', '"TMT_A"') INTO filtered;
        SELECT regexp_replace(filtered, '"CORSI_FORWARD_ONLY"', '"CORSI_FORWARD"') INTO filtered;
        SELECT regexp_replace(filtered, '"TOKEN_TEST"', '"TOKEN"') INTO filtered;
        SELECT regexp_replace(filtered, '"CERAD_FIRST"', '"CERAD_LEARNING"') INTO filtered;
        SELECT regexp_replace(filtered, '"CERAD_SECOND"', '"CERAD_DELAYED"') INTO filtered;
        SELECT regexp_replace(filtered, '"CERAD_REC"', '"CERAD_RECOGNITION"') INTO filtered;
        SELECT regexp_replace(filtered, '"CORSI_FORWARD_ONLY"', '"CORSI_FORWARD"') INTO filtered;
        SELECT regexp_replace(filtered, '"BNT2"', '"BNT"') INTO filtered;
        SELECT regexp_replace(filtered, '"RAVLT2_FIRST"', '"RAVLT_FIRST"') INTO filtered;
        SELECT regexp_replace(filtered, '"RAVLT2_SECOND"', '"RAVLT_SECOND"') INTO filtered;
        SELECT regexp_replace(filtered, '"RAVLT2_REC"', '"RAVLT_RECOGNITION"') INTO filtered;

        SELECT regexp_replace(filtered, ',"FEEDBACK_PATIENT"', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, ',"FEEDBACK_CLINICIAN"', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, ',"REMOTE_FEEDBACK"', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, ',"RETURN_TABLET"', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, ',"OFFLINE_SYNC"', '', 'g') INTO filtered;
        SELECT regexp_replace(filtered, ',"REMOTE_END"', '', 'g') INTO filtered;
        return filtered;
	END;
$_$;


ALTER FUNCTION public.filtertests(text) OWNER TO postgres;

--
-- Name: identify_date_format(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.identify_date_format(date_text text) RETURNS text
    LANGUAGE plpgsql
    AS $$
    BEGIN
      IF LENGTH(date_text) = 24 THEN
        RETURN 'ISO';
      ELSIF LENGTH(date_text) = 29 THEN
        RETURN 'GMT';
      ELSE
        RETURN 'UNKNOWN';
      END IF;
    END;
    $$;


ALTER FUNCTION public.identify_date_format(date_text text) OWNER TO postgres;

--
-- Name: create_application_user(text); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.create_application_user(username text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $_$
DECLARE
    pw text;
BEGIN
    SELECT user_management.random_password(20) INTO pw;
    EXECUTE format($$ CREATE USER %I WITH PASSWORD %L $$, username, pw);
    RETURN pw;
END
$_$;


ALTER FUNCTION user_management.create_application_user(username text) OWNER TO postgres;

--
-- Name: FUNCTION create_application_user(username text); Type: COMMENT; Schema: user_management; Owner: postgres
--

COMMENT ON FUNCTION user_management.create_application_user(username text) IS 'Creates a user that can login, sets the password to a strong random one,
which is then returned';


--
-- Name: create_application_user_or_change_password(text, text); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.create_application_user_or_change_password(username text, password text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $_$
BEGIN
    PERFORM 1 FROM pg_roles WHERE rolname = username;

    IF FOUND
    THEN
        EXECUTE format($$ ALTER ROLE %I WITH PASSWORD %L $$, username, password);
    ELSE
        EXECUTE format($$ CREATE USER %I WITH PASSWORD %L $$, username, password);
    END IF;
END
$_$;


ALTER FUNCTION user_management.create_application_user_or_change_password(username text, password text) OWNER TO postgres;

--
-- Name: FUNCTION create_application_user_or_change_password(username text, password text); Type: COMMENT; Schema: user_management; Owner: postgres
--

COMMENT ON FUNCTION user_management.create_application_user_or_change_password(username text, password text) IS 'USE THIS ONLY IN EMERGENCY!  The password will appear in the DB logs.
Creates a user that can login, sets the password to the one provided.
If the user already exists, sets its password.';


--
-- Name: create_role(text); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.create_role(rolename text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $_$
BEGIN
    -- set ADMIN to the admin user, so every member of admin can GRANT these roles to each other
    EXECUTE format($$ CREATE ROLE %I WITH ADMIN admin $$, rolename);
END;
$_$;


ALTER FUNCTION user_management.create_role(rolename text) OWNER TO postgres;

--
-- Name: FUNCTION create_role(rolename text); Type: COMMENT; Schema: user_management; Owner: postgres
--

COMMENT ON FUNCTION user_management.create_role(rolename text) IS 'Creates a role that cannot log in, but can be used to set up fine-grained privileges';


--
-- Name: create_user(text); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.create_user(username text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $_$
BEGIN
    EXECUTE format($$ CREATE USER %I IN ROLE zalandos, admin $$, username);
    EXECUTE format($$ ALTER ROLE %I SET log_statement TO 'all' $$, username);
END;
$_$;


ALTER FUNCTION user_management.create_user(username text) OWNER TO postgres;

--
-- Name: FUNCTION create_user(username text); Type: COMMENT; Schema: user_management; Owner: postgres
--

COMMENT ON FUNCTION user_management.create_user(username text) IS 'Creates a user that is supposed to be a human, to be authenticated without a password';


--
-- Name: drop_role(text); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.drop_role(username text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
SELECT user_management.drop_user(username);
$$;


ALTER FUNCTION user_management.drop_role(username text) OWNER TO postgres;

--
-- Name: FUNCTION drop_role(username text); Type: COMMENT; Schema: user_management; Owner: postgres
--

COMMENT ON FUNCTION user_management.drop_role(username text) IS 'Drop a human or application user.  Intended for cleanup (either after team changes or mistakes in role setup).
Roles (= users) that own database objects cannot be dropped.';


--
-- Name: drop_user(text); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.drop_user(username text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $_$
BEGIN
    EXECUTE format($$ DROP ROLE %I $$, username);
END
$_$;


ALTER FUNCTION user_management.drop_user(username text) OWNER TO postgres;

--
-- Name: FUNCTION drop_user(username text); Type: COMMENT; Schema: user_management; Owner: postgres
--

COMMENT ON FUNCTION user_management.drop_user(username text) IS 'Drop a human or application user.  Intended for cleanup (either after team changes or mistakes in role setup).
Roles (= users) that own database objects cannot be dropped.';


--
-- Name: random_password(integer); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.random_password(length integer) RETURNS text
    LANGUAGE sql
    SET search_path TO 'pg_catalog'
    AS $$
WITH chars (c) AS (
    SELECT chr(33)
    UNION ALL
    SELECT chr(i) FROM generate_series (35, 38) AS t (i)
    UNION ALL
    SELECT chr(i) FROM generate_series (42, 90) AS t (i)
    UNION ALL
    SELECT chr(i) FROM generate_series (97, 122) AS t (i)
),
bricks (b) AS (
    -- build a pool of chars (the size will be the number of chars above times length)
    -- and shuffle it
    SELECT c FROM chars, generate_series(1, length) ORDER BY random()
)
SELECT substr(string_agg(b, ''), 1, length) FROM bricks;
$$;


ALTER FUNCTION user_management.random_password(length integer) OWNER TO postgres;

--
-- Name: revoke_admin(text); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.revoke_admin(username text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $_$
BEGIN
    EXECUTE format($$ REVOKE admin FROM %I $$, username);
END
$_$;


ALTER FUNCTION user_management.revoke_admin(username text) OWNER TO postgres;

--
-- Name: FUNCTION revoke_admin(username text); Type: COMMENT; Schema: user_management; Owner: postgres
--

COMMENT ON FUNCTION user_management.revoke_admin(username text) IS 'Use this function to make a human user less privileged,
ie. when you want to grant someone read privileges only';


--
-- Name: terminate_backend(integer); Type: FUNCTION; Schema: user_management; Owner: postgres
--

CREATE FUNCTION user_management.terminate_backend(pid integer) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
SELECT pg_terminate_backend(pid);
$$;


ALTER FUNCTION user_management.terminate_backend(pid integer) OWNER TO postgres;

--
-- Name: FUNCTION terminate_backend(pid integer); Type: COMMENT; Schema: user_management; Owner: postgres
--

COMMENT ON FUNCTION user_management.terminate_backend(pid integer) IS 'When there is a process causing harm, you can kill it using this function.  Get the pid from pg_stat_activity
(be careful to match the user name (usename) and the query, in order not to kill innocent kittens) and pass it to terminate_backend()';


--
-- Name: index_bloat; Type: VIEW; Schema: metric_helpers; Owner: postgres
--

CREATE VIEW metric_helpers.index_bloat AS
 SELECT get_btree_bloat_approx.i_database,
    get_btree_bloat_approx.i_schema_name,
    get_btree_bloat_approx.i_table_name,
    get_btree_bloat_approx.i_index_name,
    get_btree_bloat_approx.i_real_size,
    get_btree_bloat_approx.i_extra_size,
    get_btree_bloat_approx.i_extra_ratio,
    get_btree_bloat_approx.i_fill_factor,
    get_btree_bloat_approx.i_bloat_size,
    get_btree_bloat_approx.i_bloat_ratio,
    get_btree_bloat_approx.i_is_na
   FROM metric_helpers.get_btree_bloat_approx() get_btree_bloat_approx(i_database, i_schema_name, i_table_name, i_index_name, i_real_size, i_extra_size, i_extra_ratio, i_fill_factor, i_bloat_size, i_bloat_ratio, i_is_na);


ALTER TABLE metric_helpers.index_bloat OWNER TO postgres;

--
-- Name: table_bloat; Type: VIEW; Schema: metric_helpers; Owner: postgres
--

CREATE VIEW metric_helpers.table_bloat AS
 SELECT get_table_bloat_approx.t_database,
    get_table_bloat_approx.t_schema_name,
    get_table_bloat_approx.t_table_name,
    get_table_bloat_approx.t_real_size,
    get_table_bloat_approx.t_extra_size,
    get_table_bloat_approx.t_extra_ratio,
    get_table_bloat_approx.t_fill_factor,
    get_table_bloat_approx.t_bloat_size,
    get_table_bloat_approx.t_bloat_ratio,
    get_table_bloat_approx.t_is_na
   FROM metric_helpers.get_table_bloat_approx() get_table_bloat_approx(t_database, t_schema_name, t_table_name, t_real_size, t_extra_size, t_extra_ratio, t_fill_factor, t_bloat_size, t_bloat_ratio, t_is_na);


ALTER TABLE metric_helpers.table_bloat OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: collectibletoyrarity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.collectibletoyrarity (
    id integer NOT NULL,
    title text NOT NULL,
    description text,
    type text NOT NULL,
    internal boolean DEFAULT false,
    "testPathEnums" json NOT NULL,
    deleted timestamp without time zone,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "internalNotes" text,
    locale text DEFAULT 'sv-se'::text NOT NULL,
    country text DEFAULT 'se'::text NOT NULL,
    "recommendations" json DEFAULT '[]'::json,
    inquiry character varying,
    "isDefault" boolean DEFAULT false,
    tags json DEFAULT '[]'::json
);


ALTER TABLE public.collectibletoyrarity OWNER TO postgres;

--
-- Name: collectibletoyrarity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.collectibletoyrarity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.collectibletoyrarity_id_seq OWNER TO postgres;

--
-- Name: collectibletoyrarity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.collectibletoyrarity_id_seq OWNED BY public.collectibletoyrarity.id;


--
-- Name: productmemoryretention; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productmemoryretention (
    id integer NOT NULL,
    products json,
    associations json,
    memory_list json,
    duration integer,
    test_occasion integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    sound text,
    "reviewedAt" timestamp without time zone,
    alternatives json,
    transcript text,
    status text,
);


ALTER TABLE public.productmemoryretention OWNER TO postgres;

--
-- Name: productmemoryretention_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productmemoryretention_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productmemoryretention_id_seq OWNER TO postgres;

--
-- Name: productmemoryretention_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.productmemoryretention_id_seq OWNED BY public.productmemoryretention.id;


--
-- Name: buildingblockassemblydata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.buildingblockassemblydata (
    id integer NOT NULL,
    blueprint json,
    instructions json,
    num_correct integer,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.buildingblockassemblydata OWNER TO postgres;

--
-- Name: buildingblockassemblydata_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.buildingblockassemblydata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.buildingblockassemblydata_id_seq OWNER TO postgres;

--
-- Name: buildingblockassemblydata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.buildingblockassemblydata_id_seq OWNED BY public.buildingblockassemblydata.id;


--
-- Name: userinteractionevents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.userinteractionevents (
    id integer NOT NULL,
    version integer,
    "toyId" integer,
    round text,
    "timestamp" timestamp without time zone,
    "order" integer,
    type text,
    data text,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.userinteractionevents OWNER TO postgres;

--
-- Name: userinteractionevents_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.userinteractionevents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.userinteractionevents_id_seq OWNER TO postgres;

--
-- Name: userinteractionevents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.userinteractionevents_id_seq OWNED BY public.userinteractionevents.id;


--
-- Name: mechanicalfeatureduraion; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mechanicalfeatureduration (
    id integer NOT NULL,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.mechanicalfeatureduraion OWNER TO postgres;

--
-- Name: mechanicalfeatureduraion_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mechanicalfeatureduraion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mechanicalfeatureduraion_id_seq OWNER TO postgres;

--
-- Name: mechanicalfeatureduraion_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mechanicalfeatureduraion_id_seq OWNED BY public.mechanicalfeatureduraion.id;


--
-- Name: soundpatternsequence; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.soundpatternsequence (
    id integer NOT NULL,
    backwards boolean,
    correct boolean,
    level text,
    name text,
    seq json,
    user_seq json,
    max_time boolean,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.soundpatternsequence OWNER TO postgres;

--
-- Name: soundpatternsequence_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.soundpatternsequence_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.soundpatternsequence_id_seq OWNER TO postgres;

--
-- Name: soundpatternsequence_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.soundpatternsequence_id_seq OWNED BY public.soundpatternsequence.id;


--
-- Name: productspecification; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productspecification (
    id integer NOT NULL,
    "deviceInfoJson" json,
    "toyId" integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.productspecification OWNER TO postgres;

--
-- Name: productspecification_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productspecification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productspecification_id_seq OWNER TO postgres;

--
-- Name: productspecification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.productspecification_id_seq OWNED BY public.productspecification.id;


--
-- Name: customercommunication; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.customercommunication (
    id integer NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    facility integer NOT NULL,
    "thankYouMessage" text,
    "apologyMessage" text,
    name text
);


ALTER TABLE public.customercommunication OWNER TO postgres;

--
-- Name: customercommunication_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.customercommunication_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.customercommunication_id_seq OWNER TO postgres;

--
-- Name: customercommunication_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.customercommunication_id_seq OWNED BY public.customercommunication.id;


--
-- Name: voicefeatureresponse; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.voicefeatureresponse (
    id integer NOT NULL,
    answers json,
    letter character varying,
    number_of_words integer,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    repeated_words text[],
    number_of_repeats integer,
    erroneous_words text[],
    number_of_erroneous_words integer,
    "completedAt" timestamp without time zone,
    sound text,
    "reviewedAt" timestamp without time zone,
    manual_transcript text,
    transcript text,
    transcript_server text,
);


ALTER TABLE public.voicefeatureresponse OWNER TO postgres;

--
-- Name: voicefeatureresponse_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.voicefeatureresponse_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.voicefeatureresponse_id_seq OWNER TO postgres;

--
-- Name: voicefeatureresponse_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.voicefeatureresponse_id_seq OWNED BY public.voicefeatureresponse.id;


--
-- Name: handlerobservations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.handlerobservations (
    id integer NOT NULL,
    was_interrupted boolean,
    charactervoiceactor_complained boolean,
    charactervoiceactor_complaint text,
    app_rating integer,
    comment text,
    toy_id integer NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone
);


ALTER TABLE public.handlerobservations OWNER TO postgres;

--
-- Name: handlerobservations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.handlerobservations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.handlerobservations_id_seq OWNER TO postgres;

--
-- Name: handlerobservations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.handlerobservations_id_seq OWNED BY public.handlerobservations.id;


--
-- Name: consumerresponsedata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.consumerresponsedata (
    id integer NOT NULL,
    clear_instructions boolean,
    what_unclear json DEFAULT '[]'::json,
    problems json DEFAULT '[]'::json,
    discount_level integer,
    toy_id integer NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    has_difficulties boolean,
    difficulty_cause text,
    rating integer,
    rating_comment text
);


ALTER TABLE public.consumerresponsedata OWNER TO postgres;

--
-- Name: consumerresponsedata_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.consumerresponsedata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.consumerresponsedata_id_seq OWNER TO postgres;

--
-- Name: consumerresponsedata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.consumerresponsedata_id_seq OWNED BY public.consumerresponsedata.id;


--
-- Name: engagementstrategy; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.engagementstrategy (
    id integer NOT NULL,
    name text NOT NULL,
    "readableName" text NOT NULL,
    enabled boolean NOT NULL,
    template json NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "isDefault" boolean DEFAULT false
);


ALTER TABLE public.engagementstrategy OWNER TO postgres;

--
-- Name: engagementstrategy_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.engagementstrategy_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.engagementstrategy_id_seq OWNER TO postgres;

--
-- Name: engagementstrategy_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.engagementstrategy_id_seq OWNED BY public.engagementstrategy.id;


--
-- Name: repeatplaystatistics; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.repeatplaystatistics (
    id integer NOT NULL,
    toy_id integer,
    round integer,
    "time" integer,
    movements integer,
    errors_type1 integer,
    errors_type2 integer,
    success boolean,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.repeatplaystatistics OWNER TO postgres;

--
-- Name: repeatplaystatistics_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.repeatplaystatistics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.repeatplaystatistics_id_seq OWNER TO postgres;

--
-- Name: repeatplaystatistics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.repeatplaystatistics_id_seq OWNED BY public.repeatplaystatistics.id;


--
-- Name: visualfeatureengagement; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.visualfeatureengagement (
    id integer NOT NULL,
    test text NOT NULL,
    grade text NOT NULL,
    "toyId" integer,
    "evaluatedBy" integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.visualfeatureengagement OWNER TO postgres;

--
-- Name: visualfeatureengagement_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.visualfeatureengagement_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.visualfeatureengagement_id_seq OWNER TO postgres;

--
-- Name: visualfeatureengagement_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.visualfeatureengagement_id_seq OWNED BY public.visualfeatureengagement.id;


--
-- Name: characterassociation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.characterassociation (
    id integer NOT NULL,
    "user" integer,
    "toyId" integer,
    "referenceId" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "timeoutMinutes" integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
);


ALTER TABLE public.characterassociation OWNER TO postgres;

--
-- Name: characterassociation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.characterassociation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.characterassociation_id_seq OWNER TO postgres;

--
-- Name: characterassociation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.characterassociation_id_seq OWNED BY public.characterassociation.id;


--
-- Name: productinteractionsessionterminationdata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productinteractionsessionterminationdata (
    id integer NOT NULL,
    start timestamp without time zone NOT NULL,
    "end" timestamp without time zone NOT NULL,
    "toyId" integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.productinteractionsessionterminationdata OWNER TO postgres;

--
-- Name: productinteractionsessionterminationdata_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productinteractionsessionterminationdata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productinteractionsessionterminationdata_id_seq OWNER TO postgres;

--
-- Name: productinteractionsessionterminationdata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.productinteractionsessionterminationdata_id_seq OWNED BY public.productinteractionsessionterminationdata.id;


--
-- Name: productpreference; Type: TABLE; Schema: public; Owner: minnemera_user
--

CREATE TABLE public.productpreference (
    id integer NOT NULL,
    facility integer NOT NULL,
    toy_ids integer[] NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.productpreference OWNER TO minnemera_user;

--
-- Name: productpreference_id_seq; Type: SEQUENCE; Schema: public; Owner: minnemera_user
--

CREATE SEQUENCE public.productpreference_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productpreference_id_seq OWNER TO minnemera_user;

--
-- Name: productpreference_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: minnemera_user
--

ALTER SEQUENCE public.productpreference_id_seq OWNED BY public.productpreference.id;


--
-- Name: productpreferenceevent; Type: TABLE; Schema: public; Owner: minnemera_user
--

CREATE TABLE public.productpreferenceevent (
    id integer NOT NULL,
    productpreference integer NOT NULL,
    event jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.productpreferenceevent OWNER TO minnemera_user;

--
-- Name: productpreferenceevent_id_seq; Type: SEQUENCE; Schema: public; Owner: minnemera_user
--

CREATE SEQUENCE public.productpreferenceevent_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productpreferenceevent_id_seq OWNER TO minnemera_user;

--
-- Name: productpreferenceevent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: minnemera_user
--

ALTER SEQUENCE public.productpreferenceevent_id_seq OWNED BY public.productpreferenceevent.id;


--
-- Name: behaviorclassificationtag; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.behaviorclassificationtag (
    id integer NOT NULL,
    facility integer NOT NULL,
    text text NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    type character varying DEFAULT 'behaviorclassificationtag'::character varying NOT NULL
);


ALTER TABLE public.behaviorclassificationtag OWNER TO postgres;

--
-- Name: behaviorclassificationtag_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.behaviorclassificationtag_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.behaviorclassificationtag_id_seq OWNER TO postgres;

--
-- Name: behaviorclassificationtag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.behaviorclassificationtag_id_seq OWNED BY public.behaviorclassificationtag.id;


--
-- Name: legacyproductcode; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.legacyproductcode (
    id integer NOT NULL,
    sequence_id UUID NOT NULL,
    "toyId" integer NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.legacyproductcode OWNER TO postgres;

--
-- Name: legacyproductcode_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.legacyproductcode_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.legacyproductcode_id_seq OWNER TO postgres;

--
-- Name: legacyproductcode_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.legacyproductcode_id_seq OWNED BY public.legacyproductcode.id;


--
-- Name: historicalresponsedata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.historicalresponsedata (
    id integer NOT NULL,
    "toyId" integer NOT NULL,
    result json NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.historicalresponsedata OWNER TO postgres;

--
-- Name: historicalresponsedata_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.historicalresponsedata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.historicalresponsedata_id_seq OWNER TO postgres;

--
-- Name: historicalresponsedata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.historicalresponsedata_id_seq OWNED BY public.historicalresponsedata.id;


--
-- Name: productimagecorrection; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productimagecorrection (
    id integer NOT NULL,
    toy_id integer,
    test text NOT NULL,
    corrections text NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.productimagecorrection OWNER TO postgres;

--
-- Name: productimagecorrection_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productimagecorrection_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productimagecorrection_id_seq OWNER TO postgres;

--
-- Name: productimagecorrection_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.productimagecorrection_id_seq OWNED BY public.productimagecorrection.id;


--
-- Name: partnumber; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.partnumber (
    id integer NOT NULL,
    version integer NOT NULL,
    data json NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.partnumber OWNER TO postgres;

--
-- Name: partnumber_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.partnumber_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.partnumber_id_seq OWNER TO postgres;

--
-- Name: partnumber_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.partnumber_id_seq OWNED BY public.partnumber.id;


--
-- Name: mobilenotificationsystem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.mobilenotificationsystem (
    id integer NOT NULL,
    code character varying NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "user" integer NOT NULL,
    "expiresAt" character varying
);


ALTER TABLE public.mobilenotificationsystem OWNER TO postgres;

--
-- Name: mobilenotificationsystem_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.mobilenotificationsystem_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.mobilenotificationsystem_id_seq OWNER TO postgres;

--
-- Name: mobilenotificationsystem_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.mobilenotificationsystem_id_seq OWNED BY public.mobilenotificationsystem.id;


--
-- Name: productrecalltesting; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productrecalltesting (
    id integer NOT NULL,
    correct boolean,
    incorrect json,
    accepted json,
    toy_id integer,
    transcript text,
    alternatives json,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    version character varying,
    "reviewedAt" timestamp without time zone,
    sound text,
    variant text NOT NULL,
    status text NOT NULL,
    "s2tLogs" json
);


ALTER TABLE public.productrecalltesting OWNER TO postgres;

--
-- Name: productrecalltesting_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productrecalltesting_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productrecalltesting_id_seq OWNER TO postgres;

--
-- Name: productrecalltesting_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.productrecalltesting_id_seq OWNED BY public.productrecalltesting.id;


--
-- Name: marketingcontentdistribution; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marketingcontentdistribution (
    id integer NOT NULL,
    title text NOT NULL,
    body json NOT NULL,
    published boolean DEFAULT false,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    critical boolean DEFAULT false
);


ALTER TABLE public.marketingcontentdistribution OWNER TO postgres;

--
-- Name: marketingcontentdistribution_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.marketingcontentdistribution_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.marketingcontentdistribution_id_seq OWNER TO postgres;

--
-- Name: marketingcontentdistribution_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.marketingcontentdistribution_id_seq OWNED BY public.marketingcontentdistribution.id;


--
-- Name: facility; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.facility (
    id integer NOT NULL,
    name text NOT NULL,
    country text DEFAULT 'SE'::text,
    locale text DEFAULT 'sv-SE'::text,
    "RND" boolean DEFAULT true,
    "allowTracking" boolean DEFAULT true,
    "useFeatureInquiries" boolean DEFAULT false,
    "excludeFromManualWorkflow" boolean DEFAULT false,
    tags json DEFAULT '[]'::json,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.facility OWNER TO postgres;

--
-- Name: facility_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.facility_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.facility_id_seq OWNER TO postgres;

--
-- Name: facility_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.facility_id_seq OWNED BY public.facility.id;


--
-- Name: engagementdurationmetrics; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.engagementdurationmetrics (
    id integer NOT NULL,
    numbers BIGINT NOT NULL,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.engagementdurationmetrics OWNER TO postgres;

--
-- Name: engagementdurationmetrics_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.engagementdurationmetrics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.engagementdurationmetrics_id_seq OWNER TO postgres;

--
-- Name: engagementdurationmetrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.engagementdurationmetrics_id_seq OWNED BY public.engagementdurationmetrics.id;


--
-- Name: operantassessment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.operantassessment (
    id integer NOT NULL,
    answer text,
    should_be text,
    is_correct boolean,
    conditioning text,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.operantassessment OWNER TO postgres;

--
-- Name: operantassessment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.operantassessment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.operantassessment_id_seq OWNER TO postgres;

--
-- Name: operantassessment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.operantassessment_id_seq OWNED BY public.operantassessment.id;


--
-- Name: lightsequence; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lightsequence (
    id integer NOT NULL,
    email character varying NOT NULL,
    "userId" integer NOT NULL,
    "privateKey" character varying NOT NULL,
    "validUntil" timestamp without time zone NOT NULL,
    "createdAt" timestamp without time zone NOT NULL,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.lightsequence OWNER TO postgres;

--
-- Name: lightsequence_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lightsequence_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lightsequence_id_seq OWNER TO postgres;

--
-- Name: lightsequence_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lightsequence_id_seq OWNED BY public.lightsequence.id;


--
-- Name: charactervoiceactor; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.charactervoiceactor (
    id integer NOT NULL,
    pseudonym public.citext NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "ownedByUser" integer NOT NULL,
    "isDemo" boolean DEFAULT false,
    "isGlobalDemo" boolean DEFAULT false
);


ALTER TABLE public.charactervoiceactor OWNER TO postgres;

--
-- Name: charactervoiceactoralias; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.charactervoiceactoralias (
    id integer NOT NULL,
    charactervoiceactor integer NOT NULL,
    behaviorclassificationtag integer NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.charactervoiceactoralias OWNER TO postgres;

--
-- Name: charactervoiceactoralias_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.charactervoiceactoralias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.charactervoiceactoralias_id_seq OWNER TO postgres;

--
-- Name: charactervoiceactoralias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.charactervoiceactoralias_id_seq OWNED BY public.charactervoiceactoralias.id;


--
-- Name: charactervoiceactorbehaviorclassificationtag; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.charactervoiceactorbehaviorclassificationtag (
    id integer NOT NULL,
    charactervoiceactor integer NOT NULL,
    behaviorclassificationtag integer NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.charactervoiceactorbehaviorclassificationtag OWNER TO postgres;

--
-- Name: charactervoiceactorbehaviorclassificationtag_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.charactervoiceactorbehaviorclassificationtag_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.charactervoiceactorbehaviorclassificationtag_id_seq OWNER TO postgres;

--
-- Name: charactervoiceactorbehaviorclassificationtag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.charactervoiceactorbehaviorclassificationtag_id_seq OWNED BY public.charactervoiceactorbehaviorclassificationtag.id;


--
-- Name: productinteractionsessioninterruptionlog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productinteractionsessioninterruptionlog (
    id integer NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    type text NOT NULL,
    path text NOT NULL,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.productinteractionsessioninterruptionlog OWNER TO postgres;

--
-- Name: productinteractionsessioninterruptionlog_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productinteractionsessioninterruptionlog_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productinteractionsessioninterruptionlog_id_seq OWNER TO postgres;

--
-- Name: productinteractionsessioninterruptionlog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.productinteractionsessioninterruptionlog_id_seq OWNED BY public.productinteractionsessioninterruptionlog.id;


--
-- Name: audiocueidentifier; Type: TABLE; Schema: public; Owner: minnemera_user
--

CREATE TABLE public.audiocueidentifier (
    id integer NOT NULL,
    "contextId" character varying(255) NOT NULL,
    "systemPrompt" text NOT NULL,
    "userPrompt" text NOT NULL,
    response jsonb NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.audiocueidentifier OWNER TO minnemera_user;

--
-- Name: audiocueidentifier_id_seq; Type: SEQUENCE; Schema: public; Owner: minnemera_user
--

CREATE SEQUENCE public.audiocueidentifier_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.audiocueidentifier_id_seq OWNER TO minnemera_user;

--
-- Name: audiocueidentifier_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: minnemera_user
--

ALTER SEQUENCE public.audiocueidentifier_id_seq OWNED BY public.audiocueidentifier.id;


--
-- Name: productidentificationdata; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productidentificationdata (
    id integer NOT NULL,
    answers json,
    correct_answers json,
    num_correct integer,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    version text,
    variant text,
    status text
);


ALTER TABLE public.productidentificationdata OWNER TO postgres;

--
-- Name: productidentificationdata_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productidentificationdata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productidentificationdata_id_seq OWNER TO postgres;

--
-- Name: productidentificationdata_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.productidentificationdata_id_seq OWNED BY public.productidentificationdata.id;


--
-- Name: initialresponselatency; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.initialresponselatency (
    id integer NOT NULL,
    initialresponselatency integer NOT NULL,
    "correctColor" boolean NOT NULL,
    "correctPreviousColor" boolean NOT NULL,
    "noReaction" boolean NOT NULL,
    reaction_time_result integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    index integer NOT NULL,
    "buttonReleased" integer
);


ALTER TABLE public.initialresponselatency OWNER TO postgres;

--
-- Name: initialresponselatency_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.initialresponselatency_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.initialresponselatency_id_seq OWNER TO postgres;

--
-- Name: initialresponselatency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.initialresponselatency_id_seq OWNED BY public.initialresponselatency.id;


--
-- Name: initialresponselatencyresult; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.initialresponselatencyresult (
    id integer NOT NULL,
    test_round text NOT NULL,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.initialresponselatencyresult OWNER TO postgres;

--
-- Name: initialresponselatencyresult_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.initialresponselatencyresult_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.initialresponselatencyresult_id_seq OWNER TO postgres;

--
-- Name: initialresponselatencyresult_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.initialresponselatencyresult_id_seq OWNED BY public.initialresponselatencyresult.id;


--
-- Name: userbehaviorquery; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.userbehaviorquery (
    id integer NOT NULL,
    name text NOT NULL,
    description text,
    details text,
    query text,
    author text DEFAULT ''::text,
    enabled boolean DEFAULT false,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.userbehaviorquery OWNER TO postgres;

--
-- Name: userbehaviorquery_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.userbehaviorquery_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.userbehaviorquery_id_seq OWNER TO postgres;

--
-- Name: userbehaviorquery_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.userbehaviorquery_id_seq OWNED BY public.userbehaviorquery.id;


--
-- Name: productiterationtracking; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productiterationtracking (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    run_on timestamp without time zone NOT NULL
);


ALTER TABLE public.productiterationtracking OWNER TO postgres;

--
-- Name: productiterationtracking_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.productiterationtracking_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.productiterationtracking_id_seq OWNER TO postgres;

--
-- Name: productiterationtracking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.productiterationtracking_id_seq OWNED BY public.productiterationtracking.id;


--
-- Name: iconrecognitioncapacity; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.iconrecognitioncapacity (
    id integer NOT NULL,
    correct integer,
    incorrect integer,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.iconrecognitioncapacity OWNER TO postgres;

--
-- Name: iconrecognitioncapacity_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.iconrecognitioncapacity_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.iconrecognitioncapacity_id_seq OWNER TO postgres;

--
-- Name: iconrecognitioncapacity_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.iconrecognitioncapacity_id_seq OWNED BY public.iconrecognitioncapacity.id;


--
-- Name: behavioralpatternmetrics; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.behavioralpatternmetrics (
    id integer NOT NULL,
    answered_symbol text,
    correct_symbol text,
    is_correct boolean,
    sequence_index integer,
    sdmt_result integer,
    "answeredAt" timestamp without time zone,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.behavioralpatternmetrics OWNER TO postgres;

--
-- Name: behavioralpatternmetrics_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.behavioralpatternmetrics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.behavioralpatternmetrics_id_seq OWNER TO postgres;

--
-- Name: behavioralpatternmetrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.behavioralpatternmetrics_id_seq OWNED BY public.behavioralpatternmetrics.id;


--
-- Name: selfreportedpreferences; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.selfreportedpreferences (
    id integer NOT NULL,
    education integer,
    handedness text,
    hearing integer,
    vision integer,
    calmness integer,
    rest integer,
    "toyId" integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.selfreportedpreferences OWNER TO postgres;

--
-- Name: selfreportedpreferences_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.selfreportedpreferences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.selfreportedpreferences_id_seq OWNER TO postgres;

--
-- Name: selfreportedpreferences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.selfreportedpreferences_id_seq OWNED BY public.selfreportedpreferences.id;


--
-- Name: playpatternrecognition; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.playpatternrecognition (
    id integer NOT NULL,
    toy_id integer,
    "questionIndex" integer NOT NULL,
    "questionText" text NOT NULL,
    "answerIndex" integer,
    "answerText" text,
    "answerScore" integer,
    "templateId" character varying NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "formName" text DEFAULT 'FAQ'::text NOT NULL,
    "suicideAlert" boolean DEFAULT false NOT NULL
);


ALTER TABLE public.playpatternrecognition OWNER TO postgres;

--
-- Name: playpatternrecognition_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.playpatternrecognition_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.playpatternrecognition_id_seq OWNER TO postgres;

--
-- Name: playpatternrecognition_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.playpatternrecognition_id_seq OWNED BY public.playpatternrecognition.id;


--
-- Name: productinteractionsession; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.productinteractionsession (
    sid character varying NOT NULL,
    sess json NOT NULL,
    expire timestamp(6) without time zone NOT NULL
);


ALTER TABLE public.productinteractionsession OWNER TO postgres;

--
-- Name: setcharactervoiceactorlog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.setcharactervoiceactorlog (
    id integer NOT NULL,
    "user" integer NOT NULL,
    "toyId" integer NOT NULL,
    "oldPatient" integer NOT NULL,
    "newPatient" integer NOT NULL,
    status text,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.setcharactervoiceactorlog OWNER TO postgres;

--
-- Name: setcharactervoiceactorlog_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.setcharactervoiceactorlog_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.setcharactervoiceactorlog_id_seq OWNER TO postgres;

--
-- Name: setcharactervoiceactorlog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.setcharactervoiceactorlog_id_seq OWNED BY public.setcharactervoiceactorlog.id;


--
-- Name: internalcommunicationlog; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.internalcommunicationlog (
    id integer NOT NULL,
    message text,
    "user" integer NOT NULL,
    facility integer NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.internalcommunicationlog OWNER TO postgres;

--
-- Name: internalcommunicationlog_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.internalcommunicationlog_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.internalcommunicationlog_id_seq OWNER TO postgres;

--
-- Name: internalcommunicationlog_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.internalcommunicationlog_id_seq OWNED BY public.internalcommunicationlog.id;


--
-- Name: remotecommandack; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.remotecommandack (
    id integer NOT NULL,
    answers json,
    reaction_time json,
    correct_answers json,
    num_correct integer,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.remotecommandack OWNER TO postgres;

--
-- Name: remotecommandack_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.remotecommandack_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.remotecommandack_id_seq OWNER TO postgres;

--
-- Name: remotecommandack_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.remotecommandack_id_seq OWNED BY public.remotecommandack.id;


--
-- Name: usermonitoringconsent; Type: TABLE; Schema: public; Owner: minnemera_user
--

CREATE TABLE public.usermonitoringconsent (
    id integer NOT NULL,
    "sourceTable" character varying(255) NOT NULL,
    "sourceId" integer NOT NULL,
    "destinationTable" character varying(255) NOT NULL,
    "destinationId" integer NOT NULL,
    "createdAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.usermonitoringconsent OWNER TO minnemera_user;

--
-- Name: usermonitoringconsent_id_seq; Type: SEQUENCE; Schema: public; Owner: minnemera_user
--

CREATE SEQUENCE public.usermonitoringconsent_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.usermonitoringconsent_id_seq OWNER TO minnemera_user;

--
-- Name: usermonitoringconsent_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: minnemera_user
--

ALTER SEQUENCE public.usermonitoringconsent_id_seq OWNED BY public.usermonitoringconsent.id;


--
-- Name: seasonalcollection; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.seasonalcollection (
    id integer NOT NULL,
    correct_words json,
    incorrect_words json,
    word_list json,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    alternatives json,
    transcript text,
    duration integer,
    round text,
    "completedAt" timestamp without time zone,
    sound text,
    "reviewedAt" timestamp without time zone,
    manual_transcript text,
    transcript_server text,
    alternatives_server json,
    correct_words_server json,
    incorrect_words_server json,
    version text,
    variant text,
    status text,
    "s2tLogs" json
);


ALTER TABLE public.seasonalcollection OWNER TO postgres;

--
-- Name: seasonalcollection_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.seasonalcollection_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.seasonalcollection_id_seq OWNER TO postgres;

--
-- Name: seasonalcollection_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.seasonalcollection_id_seq OWNED BY public.seasonalcollection.id;


--
-- Name: packagingdesign; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.packagingdesign (
    id integer NOT NULL,
    drawing_key text NOT NULL,
    test_round text NOT NULL,
    max_time boolean DEFAULT false,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    duration integer,
    "completedAt" timestamp without time zone,
    correct integer,
    status text
);


ALTER TABLE public.packagingdesign OWNER TO postgres;

--
-- Name: packagingdesign_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.packagingdesign_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.packagingdesign_id_seq OWNER TO postgres;

--
-- Name: packagingdesign_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.packagingdesign_id_seq OWNED BY public.packagingdesign.id;


--
-- Name: musicaltoysequence; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.musicaltoysequence (
    id integer NOT NULL,
    uuid text NOT NULL,
    version integer NOT NULL,
    "toyId" integer,
    test text,
    round text,
    "timestamp" timestamp without time zone NOT NULL,
    "order" integer NOT NULL,
    type text NOT NULL,
    data json,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    amendment boolean DEFAULT false
);


ALTER TABLE public.musicaltoysequence OWNER TO postgres;

--
-- Name: musicaltoysequence_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.musicaltoysequence_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.musicaltoysequence_id_seq OWNER TO postgres;

--
-- Name: musicaltoysequence_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.musicaltoysequence_id_seq OWNED BY public.musicaltoysequence.id;


--
-- Name: planneduserinteraction; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.planneduserinteraction (
    id integer NOT NULL,
    charactervoiceactor integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    charactervoiceactor_info text,
    "ownedByUser" integer,
    "startedAt" timestamp without time zone,
    "formTemplateNames" json,
    "completedAt" timestamp without time zone,
    collectibletoyrarity integer,
    "apiVersion" integer DEFAULT 0,
    uri text
);


ALTER TABLE public.planneduserinteraction OWNER TO postgres;

--
-- Name: planneduserinteraction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.planneduserinteraction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.planneduserinteraction_id_seq OWNER TO postgres;

--
-- Name: planneduserinteraction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.planneduserinteraction_id_seq OWNED BY public.planneduserinteraction.id;


--
-- Name: constructiveplaymetrics; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.constructiveplaymetrics (
    id integer NOT NULL,
    drawing_key text NOT NULL,
    toy_id integer,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.constructiveplaymetrics OWNER TO postgres;

--
-- Name: constructiveplaymetrics_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.constructiveplaymetrics_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.constructiveplaymetrics_id_seq OWNER TO postgres;

--
-- Name: constructiveplaymetrics_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.constructiveplaymetrics_id_seq OWNED BY public.constructiveplaymetrics.id;


--
-- Name: completionrateanalysis; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.completionrateanalysis (
    id integer NOT NULL,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    correct integer,
    connections json,
    missed json,
    errors text,
    info text,
    algorithm text,
    tmt_result integer
);


ALTER TABLE public.completionrateanalysis OWNER TO postgres;

--
-- Name: completionrateanalysis_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.completionrateanalysis_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.completionrateanalysis_id_seq OWNER TO postgres;

--
-- Name: completionrateanalysis_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.completionrateanalysis_id_seq OWNED BY public.completionrateanalysis.id;


--
-- Name: audioresponseparameters; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audioresponseparameters (
    id integer NOT NULL,
    global json DEFAULT '{}'::json,
    orgs json DEFAULT '{}'::json,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone
);


ALTER TABLE public.audioresponseparameters OWNER TO postgres;

--
-- Name: incentiveallocation; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.incentiveallocation (
    id integer NOT NULL,
    toy_id integer,
    sequence_1 real,
    sequence_2 real,
    sequence_3 real,
    sequence_4 real,
    sequence_5 real,
    sequence_6 real,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    "completedAt" timestamp without time zone,
    status text
);


ALTER TABLE public.incentiveallocation OWNER TO postgres;

--
-- Name: incentiveallocation_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.incentiveallocation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.incentiveallocation_id_seq OWNER TO postgres;

--
-- Name: incentiveallocation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.incentiveallocation_id_seq OWNED BY public.incentiveallocation.id;


--
-- Name: user; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public."user" (
    id integer NOT NULL,
    email public.citext NOT NULL,
    password text,
    "firstName" text DEFAULT ''::text,
    "lastName" text DEFAULT ''::text,
    roles json DEFAULT '[]'::json,
    "group" text,
    "createdAt" timestamp without time zone,
    "updatedAt" timestamp without time zone,
    mobilephone character varying,
    facility integer NOT NULL,
    "seenTour" boolean DEFAULT true,
    "lastLoginAt" timestamp without time zone,
    old_roles json DEFAULT '[]'::json
);


--
-- Name: usermonitoringconsent usermonitoringconsent_pkey; Type: CONSTRAINT; Schema: public; Owner: minnemera_user
--

ALTER TABLE ONLY public.usermonitoringconsent
    ADD CONSTRAINT usermonitoringconsent_pkey PRIMARY KEY (id);


--
-- Name: seasonalcollection seasonalcollection_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.seasonalcollection
    ADD CONSTRAINT seasonalcollection_pkey PRIMARY KEY (id);


--
-- Name: packagingdesign packagingdesign_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.packagingdesign
    ADD CONSTRAINT packagingdesign_pkey PRIMARY KEY (id);


--
-- Name: musicaltoysequence musicaltoysequence_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.musicaltoysequence
    ADD CONSTRAINT musicaltoysequence_pkey PRIMARY KEY (id);


--
-- Name: musicaltoysequence musicaltoysequence_uuid_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.musicaltoysequence
    ADD CONSTRAINT musicaltoysequence_uuid_key UNIQUE (uuid);


--
-- Name: planneduserinteraction planneduserinteraction_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planneduserinteraction
    ADD CONSTRAINT planneduserinteraction_pkey PRIMARY KEY (id);


--
-- Name: planneduserinteraction planneduserinteraction_uri_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.planneduserinteraction
    ADD CONSTRAINT planneduserinteraction_uri_key UNIQUE (uri);


--
-- Name: constructiveplaymetrics constructiveplaymetrics_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.constructiveplaymetrics
    ADD CONSTRAINT constructiveplaymetrics_pkey PRIMARY KEY (id);


--
-- Name: completionrateanalysis completionrateanalysis_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.completionrateanalysis
    ADD CONSTRAINT completionrateanalysis_pkey PRIMARY KEY (id);


--
-- Name: audioresponseparameters audioresponseparameters_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audioresponseparameters
    ADD CONSTRAINT audioresponseparameters_pkey PRIMARY KEY (id);


--
-- Name: incentiveallocation incentiveallocation_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.incentiveallocation
    ADD CONSTRAINT incentiveallocation_pkey PRIMARY KEY (id);


--
-- Name: user user_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_email_key UNIQUE (email);


--
-- Name: charactervoiceactor user_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.charactervoiceactor
    ADD CONSTRAINT user_pkey PRIMARY KEY (id);


--
-- Name: user user_pkey1; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public."user"
    ADD CONSTRAINT user_pkey1 PRIMARY KEY (id);


--
-- Name: charactervoiceactor user_ssn_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.charactervoiceactor
    ADD CONSTRAINT user_ssn_key UNIQUE (pseudonym);


--
-- Name: IDX_productinteractionsession_expire; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX "IDX_productinteractionsession_expire" ON public.productinteractionsession USING btree (expire);


--
-- Name: legacyproductcode_by_planneduserinteraction; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX legacyproductcode_by_planneduserinteraction ON public.legacyproductcode USING btree ("toyId");


--
-- Name: planneduserinteraction_index; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX planneduserinteraction_index ON public.musicaltoysequence USING btree ("toyId");


--
-- PostgreSQL database dump complete
--

