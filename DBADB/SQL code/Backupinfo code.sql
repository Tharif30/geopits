USE [DBADB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BackupInfoData](
	[Servername] [varchar](50) NULL,
	[DBNmae] [varchar](70) NULL,
	[BackupStartDate] [datetime] NULL,
	[BackupEndTime] [datetime] NULL,
	[ExpDate] [datetime] NULL,
	[backupType] [varchar](50) NULL,
	[BackupSize] [bigint] NULL,
	[PhysicalDeviceName] [varchar](max) NULL,
	[backupName] [varchar](255) NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY]
GO


INSERT INTO DBADB.dbo.Backupinfodata
SELECT
CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server,
msdb.dbo.backupset.database_name,
msdb.dbo.backupset.backup_start_date,
msdb.dbo.backupset.backup_finish_date,
msdb.dbo.backupset.expiration_date,
CASE msdb..backupset.type
WHEN 'D' THEN 'Database'
WHEN 'L' THEN 'Log'
END AS backup_type,
msdb.dbo.backupset.backup_size,
msdb.dbo.backupmediafamily.physical_device_name,
msdb.dbo.backupset.name AS backupset_name,
msdb.dbo.backupset.description
FROM msdb.dbo.backupmediafamily
INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id
WHERE (CONVERT(datetime, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - 8)
ORDER BY
msdb.dbo.backupset.database_name,
msdb.dbo.backupset.backup_finish_date