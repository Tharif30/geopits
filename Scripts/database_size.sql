EXEC sp_MSforeachdb 
'USE [?]; 
SELECT 
  DB_NAME() AS DatabaseName,
  SUM(size) * 8 / 1024 AS SizeMB
FROM sys.master_files
GROUP BY database_id;';
