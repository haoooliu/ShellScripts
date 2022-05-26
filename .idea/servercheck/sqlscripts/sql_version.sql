SET LINESIZE 100
SET PAGESIZE 50
column banner heading "banner" format a15

select banner as ORACLE_DATABASE_VERSION from v$version where banner like 'Oracle Database%';
SPOOL OFF
EXIT;

