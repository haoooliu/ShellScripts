SET LINESIZE 100
SET PAGESIZE 50
column directory_name heading "directory_name" format a20
column directory_path heading "directory_path" format a35

select directory_name,directory_path from dba_directories where directory_name = 'EXPDIR';
SPOOL OFF
EXIT;