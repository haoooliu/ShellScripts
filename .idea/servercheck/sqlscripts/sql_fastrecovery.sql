SET LINESIZE 100
SET PAGESIZE 50
column name heading "name" format a30
column value heading "value" format a15

select name, value
from v$parameter
where name = 'db_recovery_file_dest'
   or name = 'db_recovery_file_dest_size';
SPOOL OFF
EXIT;

