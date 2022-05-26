SET LINESIZE 100
SET PAGESIZE 50
column name heading "name" format a25
column value heading "value" format a15

select name, value
from v$parameter
where name = 'open_cursors'
   or name = 'processes'
   or name = 'sessions'
   or name = 'memory_target'
   or name = 'sga_max_size'
   or name = 'sga_target'
   or name = 'pga_aggregate_target'
   or name = 'undo_tablespace'
   or name = 'undo_retention';
SPOOL OFF
EXIT;
