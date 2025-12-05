
USE msdb;
GO

SELECT
s.database_name,
m.physical_device_name,
CAST(s.backup_size / 1024.0 / 1024.0 AS DECIMAL(10, 2)) AS BackupSizeMB,
CAST(s.backup_size / 1024 / 1024 / 1024 AS DECIMAL(10, 2)) AS BackupSizeGB,
s.backup_start_date,
s.backup_finish_date,
s.type,
s.recovery_model
FROM
msdb.dbo.backupset 5
INNER JOIN
msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
WHERE
s.database_name = 'CHarbi' and
s.type ='1'
ORDER BY
s.backup_finish_date DESC;
-- For changing the parameter;
-- D = Database
-- I = Differential database
-- L = Log

----------------------
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
