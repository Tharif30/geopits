DECLARE @CurrentHour INT = DATEPART(HOUR, GETDATE());
DECLARE @CurrentMinute INT = DATEPART(MINUTE, GETDATE());
DECLARE @DBName SYSNAME;
DECLARE @FileName SYSNAME;
DECLARE @CurrentFileSizeMB BIGINT;
DECLARE @SQL NVARCHAR(2000);

-- 
DECLARE @ThresholdMB INT = 1500;

-- Databases and log file names
DECLARE @Databases TABLE (DBName SYSNAME, LogFile SYSNAME);

INSERT INTO @Databases (DBName, LogFile)
VALUES ('DBLoanguard', 'DBLoanguard_log'),
       ('DBLoanguardHistory', 'DBLoanguardHistory_log');

-- time window check: only between 05:30 and 05:59 AM
IF (@CurrentHour = 5 AND @CurrentMinute >= 30 AND @CurrentMinute < 60)
BEGIN
    DECLARE db_cursor CURSOR FAST_FORWARD FOR
        SELECT DBName, LogFile FROM @Databases;

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DBName, @FileName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Check if log reuse wait allows shrinking
        IF EXISTS (
            SELECT 1
            FROM sys.databases
            WHERE name = @DBName
              AND log_reuse_wait_desc = 'NOTHING'
        )
        BEGIN
            -- Get current file size
            SELECT @CurrentFileSizeMB = size * 8 / 1024
            FROM sys.master_files
            WHERE database_id = DB_ID(@DBName)
              AND name = @FileName;

            IF @CurrentFileSizeMB > @ThresholdMB
            BEGIN
                PRINT 'Shrinking log file for ' + @DBName 
                      + ' (' + CAST(@CurrentFileSizeMB AS VARCHAR(20)) + ' MB)';
                
                SET @SQL = N'USE [' + @DBName + ']; 
                             DBCC SHRINKFILE (N''' + @FileName + ''', 1024);';
                EXEC(@SQL);

                PRINT 'Shrink completed for ' + @DBName 
                      + ' at ' + CONVERT(VARCHAR(30), GETDATE(), 121);
            END
            ELSE
                PRINT 'Log file size for ' + @DBName + ' is below threshold.';
        END
        ELSE
            PRINT 'Skipping ' + @DBName + ' – log_reuse_wait_desc not NOTHING.';

        FETCH NEXT FROM db_cursor INTO @DBName, @FileName;
    END

    CLOSE db_cursor;
    DEALLOCATE db_cursor;
END
ELSE
BEGIN
    PRINT 'Outside maintenance window (5:30 AM – 6:00 AM). Script skipped.';
END;
