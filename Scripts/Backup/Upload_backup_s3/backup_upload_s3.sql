
--Upload backups using aws s3 sync(install aws cli and configure the credentials)
--add below code on the sql server agent as operating system
--if it doesn't work,run as .bat file

@echo off

set AWS_ACCESS_KEY_ID=''
set AWS_SECRET_ACCESS_KEY=''
set AWS_DEFAULT_REGION=us-east-1


aws s3 ls

set BACKUP_FOLDER=C:\Users\Public\s3_upload\New_test
set S3_BUCKET=s3://mssqlbucket-backups
set LOG_FOLDER=C:\Users\Public\s3_upload\S3Upload.log

"C:\Program Files\Amazon\AWSCLIV2\aws.exe" s3 sync "%BACKUP_FOLDER%" "%S3_BUCKET%" > "%LOG_FOLDER%" 2>&1