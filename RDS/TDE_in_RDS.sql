--RDS TDE

use msdb;
select * from sys.procedures where name like '%tde%';
select * from sys.procedures where name like '%encrypt%';

--Procedure to be used:
rds_backup_tde_certificate
rds_drop_tde_certificate
rds_restore_tde_certificate


--Backup Certificate
USE [msdb]
GO

DECLARE @RC int
DECLARE @certificate_name sysname
DECLARE @certificate_file_s3_arn nvarchar(2048)
DECLARE @private_key_file_s3_arn nvarchar(2048)
DECLARE @kms_password_key_arn nvarchar(2048)
DECLARE @overwrite_s3_files int

-- TODO: Set parameter values here.

EXECUTE @RC = [dbo].[rds_backup_tde_certificate]
@certificate_name='RDSTDECertificate20230219T011345'
,@certificate_file_s3_arn='arn: aws : s3: : :ataws-database-backup/Permanent/2023/04/RDSTDECertificate20230219T011345.cer'
,@private_key_file_s3_arn='arn: aws : s3: : : ataws-database-backup/Permanent/2023/04/RDSTDECertificate20230219T011345.pvk'
,@kms_password_key_arn='arn: aws : kms : ap-south-1:186051682200: key/mrk-fbede0e4214c421f84f326b0118e18d3'
@overwrite_s3_files=1
GO

--Restore Certificate
USE [msdb]
GO

IDECLARE @RC int
DECLARE @certificate_name sysname
DECLARE @certificate_file_s3_arn nvarchar(2048)
DECLARE @private_key_file_s3_arn nvarchar(2048)
DECLARE @kms_password_key_arn nvarchar(2048)



EXECUTE @RC = [dbo].[rds_restore_tde_certificate]
@certificate_name='RDSTDECertificate20230219T011345'
,@certificate_file_s3_arn='arn: aws : s3: : :ataws-database-backup/Permanent/2023/04/RDSTDECertificate20230219T011345.cer'
,@private_key_file_s3_arn='arn: aws : s3 :: :ataws-database-backup/Permanent/2023/04/RDSTDECertificate20230219T011345.pvk'
,@kms_password_key_arn='arn:aws:kms:ap-south-1:186051682200:key/mrk-fbede0e4214c421f84f326b0118e18d3'
GO