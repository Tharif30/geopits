SELECT 
    b.database_name,
    b.backup_start_date,
    b.backup_finish_date,
    b.backup_size / 1024 / 1024 AS backup_size_MB,
    b.compressed_backup_size / 1024 / 1024 AS compressed_size_MB,
    CASE b.type 
        WHEN 'L' THEN 'Log Backup' 
        ELSE b.type END AS backup_type
FROM msdb.dbo.backupset b
WHERE b.type = 'L'   -- L = Log backup
ORDER BY b.backup_start_date DESC;
