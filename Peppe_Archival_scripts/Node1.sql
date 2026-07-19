-----------------------------------------------------------------------------
--Step 1
-----------------------------------------------------------------------------
USE master;
GO

SELECT *
FROM sys.symmetric_keys
WHERE name = '##MS_DatabaseMasterKey##';

-- if not exists Create master key 
USE master;
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'Cool@123';

-- Create certificate
CREATE CERTIFICATE SQLNODE1_Cert
WITH SUBJECT = 'SQLNODE1 Mirroring Certificate',
     EXPIRY_DATE = '2030-12-31';

-- Create the mirroring endpoint using this certificate
CREATE ENDPOINT Mirroring_Endpoint
    STATE = STARTED
    AS TCP (LISTENER_PORT = 5022, LISTENER_IP = ALL)
    FOR DATABASE_MIRRORING (
        AUTHENTICATION = CERTIFICATE SQLNODE1_Cert,
        ENCRYPTION = REQUIRED ALGORITHM AES,
        ROLE = ALL
    );

-- Backup the certificate 
BACKUP CERTIFICATE SQLNODE1_Cert 
TO FILE = 'C:\SQL Server\SQLNODE1_Cert.cer';

-----------------------------------------------------------------------------
--Step 2
-----------------------------------------------------------------------------

USE master;

-- Create a login 
CREATE LOGIN SQLNODE2_Login WITH PASSWORD = 'Cool@123';
CREATE USER  SQLNODE2_User  FOR LOGIN SQLNODE2_Login;

-- Import SQLNODE2's certificate
CREATE CERTIFICATE SQLNODE2_Cert
    AUTHORIZATION SQLNODE2_User
    FROM FILE = 'C:\SQL Server\SQLNODE2_Cert.cer';

-- Grant CONNECT permission on the local endpoint
GRANT CONNECT ON ENDPOINT::Mirroring_Endpoint TO SQLNODE2_Login;
---------------------------------------------------------------
--Before Node 1
---------------------------------------------------------------
ALTER DATABASE [AdventureWorks2019]
SET PARTNER = 'TCP://10.103.135.197:5022';