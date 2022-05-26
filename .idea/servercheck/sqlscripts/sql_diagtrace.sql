SET LINESIZE 100
SET PAGESIZE 50
column name heading "name" format a15
column value heading "value" format a50

select name, value from v$diag_info where name = 'Diag Trace';
SPOOL OFF
EXIT;