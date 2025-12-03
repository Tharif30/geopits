use master


CREATE LOGIN [PrashantKumar] 
WITH PASSWORD = 'Prashanth@2025';

USE dbloanguard;
GO

CREATE USER [PrashantKumar] FOR LOGIN [PrashantKumar];

ALTER ROLE db_datareader ADD MEMBER [PrashantKumar];

-- Check database roles for the user
USE dbloanguard;
GO
SELECT dp.name AS DatabaseUser, 
       r.name AS DatabaseRole
FROM sys.database_principals dp
JOIN sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
WHERE dp.name = 'PrashantKumar';
