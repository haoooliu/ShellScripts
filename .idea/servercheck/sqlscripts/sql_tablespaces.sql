SET LINESIZE 100
column tablespace_name heading "tablespace_name" format a15
column Used_Pct heading "Used_Pct" format a15

SELECT total.tablespace_name,
       Round(total.MB, 2) AS Total_MB,
       Round(total.MB - free.MB, 2) AS Used_MB,
       Round((1 - free.MB / total.MB) * 100, 2) || '%' AS Used_Pct
FROM (SELECT tablespace_name, Sum(bytes) / 1024 / 1024 AS MB
      FROM dba_free_space
      GROUP BY tablespace_name) free,
     (SELECT tablespace_name, Sum(bytes) / 1024 / 1024 AS MB
      FROM dba_data_files
      GROUP BY tablespace_name) total
WHERE free.tablespace_name = total.tablespace_name;
SPOOL OFF
EXIT;
