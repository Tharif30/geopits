--Option 1

ALTER DATABASE TREDS
SET ENCRYPTION ON;
GO


--option 2
--Step 1: Create a new certificate in master
USE master;

CREATE CERTIFICATE DBABD_2026
    WITH SUBJECT = 'TDE_cert',
    EXPIRY_DATE = '2027-06-07 00:25:00:000';

--Step 2: Backup the Certificate
--Step 3: Create Database Encryption Key(can be skipped if already database encrypted)

USE DBABD;
GO
CREATE DATABASE ENCRYPTION KEY
WITH ALGORITHM = AES_256
ENCRYPTION BY SERVER CERTIFICATE DBABD_2026;
GO

--Alter the database certificate
USE DBABD;
GO

ALTER DATABASE ENCRYPTION KEY
ENCRYPTION BY SERVER CERTIFICATE DBABD_2026;
GO


---if needed

USE master;
GO

CREATE MASTER KEY
ENCRYPTION BY PASSWORD = 'StrongPassword@123!';
GO

select * from sys.databases where is_encrypted=1


--check status
SELECT 
    db.name              AS database_name,
    dek.encryptor_type   AS encryptor_type,
    cert.name            AS certificate_name,
    cert.certificate_id  AS certificate_id,
    cert.start_date      AS cert_start_date,
    cert.expiry_date     AS cert_expiry_date
FROM sys.dm_database_encryption_keys dek
JOIN sys.databases db   ON db.database_id  = dek.database_id
JOIN sys.certificates cert ON cert.thumbprint = dek.encryptor_thumbprint
