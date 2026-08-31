DECLARE @DatabaseName SYSNAME;
DECLARE @BackupFile NVARCHAR(500);
DECLARE @SQL NVARCHAR(MAX);

DECLARE db_cursor CURSOR FAST_FORWARD FOR
SELECT name
FROM sys.databases
WHERE name<>'vasdev_sel'AND database_id<>2 and 
state_desc = 'ONLINE'            -- Exclude RESTORING/STANDBY/OFFLINE
  AND is_read_only = 0                 -- Exclude read-only databases
  AND source_database_id IS NULL;      -- Exclude snapshots

OPEN db_cursor;

FETCH NEXT FROM db_cursor INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @BackupFile =
        'C:\Users\Public\s3_upload\New_test\' +
        @DatabaseName + '_' +
        CONVERT(VARCHAR(8), GETDATE(), 112) + '.bak';

    SET @SQL = '
    BACKUP DATABASE [' + @DatabaseName + ']
    TO DISK = ''' + @BackupFile + '''
    WITH INIT, COMPRESSION, CHECKSUM, STATS = 10;';

    PRINT @SQL;
    EXEC (@SQL);

    FETCH NEXT FROM db_cursor INTO @DatabaseName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;


select * from sys.databases