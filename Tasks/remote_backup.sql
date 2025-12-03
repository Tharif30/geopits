create database db_backup;

create table test(i int,j int);
create table test_2(i int, j int);

insert into test_2 
select * from test;

select name,recovery_model_desc 
from sys.databases
where name='db_backup'

EXEC xp_cmdshell 'NET USE \\GEOLAPTOP-47\server_backup 2025 /USER:"GEOLAPTOP-47\mohamed.tharif b" '

EXEC xp_cmdshell 'DIR \\GEOLAPTOP-47\server_backup';

Backup database db_backup
to Disk='\\192.168.1.8\BACKUP\bsss.bak'
with format,compression,stats=10;

SELECT is_member('db_owner') AS IsDBOwner;
-- Allow advanced options to be changed
EXEC sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO

-- Enable xp_cmdshell
EXEC sp_configure 'xp_cmdshell', 1;
GO
RECONFIGURE;
GO
SELECT service_account
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server (%';

EXEC xp_cmdshell 'echo test > \\192.168.1.8\BACKUP\test.txt';

RESTORE DATABASE db_backup
FROM DISK = '\\GEOLAPTOP-47\Users\Public\DB_Backups\New folder\db_backup_Full.bak' 
WITH NORECOVERY, STATS = 10; 