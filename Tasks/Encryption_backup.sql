create database encrypt_db;

use encrypt_db;

create table test(col int,col_2 int);
 
insert into test values(1,2);
insert into test values(1,3);

--create master key
GO
create MASTER KEY ENCRYPTION BY PASSWORD = '(MostUsed123)'

use encrypt_db
--create certificate 
create certificate test_Certificate 
with subject ='Backup certificate';

--check if the keys are present
SELECT * FROM sys.certificates;
SELECT * FROM sys.symmetric_keys;
SELECT * FROM sys.asymmetric_keys;

--backup master key and certificate
--it is required to decrypt the entire database
BACKUP MASTER KEY
TO FILE = 'C:\Users\Public\Encrypt\DBMasterKey.bak'
ENCRYPTION BY PASSWORD = 'MostUsed123';

Backup certificate test_Certificate
to file = 'C:\Users\Public\Encrypt\test_Certificate.cer'
with Private Key(
	File='C:\Users\Public\Encrypt\test_Certificate.pvk',
	Encryption By Password = 'MostUsed123'
	);


--backup the database
Backup database encrypt_db
to Disk = 'C:\Users\Public\Encrypt\Backups\encrypt_db_backup.bak'
with encryption (
				Algorithm=AES_256,
				Server Certificate=test_Certificate),
				Compression,
				Stats=10
				;

--restore database
RESTORE DATABASE encrypt_db
FROM DISK = 'C:\Users\Public\Encrypt\Backups\encrypt_db_backup.bak'
WITH STATS = 10,replace;
GO


