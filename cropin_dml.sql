
USE [master]
GO

CREATE SERVER AUDIT [Audit_SmartfarmDMLMonitoring]
TO FILE 
(	FILEPATH = N'D:\DBA_SQL_Audit\',
	MAXSIZE = 100 MB,
	MAX_ROLLOVER_FILES = 100,
	RESERVE_DISK_SPACE = OFF
) 
WITH (QUEUE_DELAY = 1000, ON_FAILURE = CONTINUE);
GO


ALTER SERVER AUDIT [Audit_SmartfarmDMLMonitoring] WITH (STATE = ON);
GO


USE [SMARTFARM];
GO

CREATE DATABASE AUDIT SPECIFICATION [Audit_TableChanges]
FOR SERVER AUDIT [Audit_SmartfarmDMLMonitoring]
ADD (INSERT ON dbo.CompanyMaster BY PUBLIC),
ADD (DELETE ON dbo.CompanyMaster BY PUBLIC),
ADD (INSERT ON dbo.UserMaster BY PUBLIC),
ADD (DELETE ON dbo.UserMaster BY PUBLIC),
ADD (INSERT ON dbo.FarmerMaster BY PUBLIC),
ADD (DELETE ON dbo.FarmerMaster BY PUBLIC),
ADD (INSERT ON dbo.FarmerCrop BY PUBLIC),
ADD (DELETE ON dbo.FarmerCrop BY PUBLIC)
WITH (STATE = ON);
GO



SELECT
    event_time,
    action_id,
    database_name,
    schema_name,
    object_name,
    statement,
    server_principal_name,
    session_id,
    succeeded,
    file_name
FROM sys.fn_get_audit_file('D:\DBA_SQL_Audit\*.sqlaudit', DEFAULT, DEFAULT)
ORDER BY event_time DESC;

