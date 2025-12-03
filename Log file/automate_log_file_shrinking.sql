
DECLARE @CurrentHour INT = DATEPART(HOUR, GETDATE());
DECLARE @CurrentFileSizeMB BIGINT;
DECLARE @FileName SYSNAME = 'vasdev_sel_log';  -- Logical file name
DECLARE @DBName SYSNAME = 'vasdev_sel';        -- Database name

-- Condition: Between 9 PM and 10 PM
IF @CurrentHour >= 21 AND @CurrentHour < 22
BEGIN
    SELECT @CurrentFileSizeMB = size * 8 / 1024
    FROM sys.master_files
    WHERE database_id = DB_ID(@DBName)
      AND name = @FileName;

    -- Condition: File size > 35 GB (35840 MB)
    IF @CurrentFileSizeMB > 35840
    BEGIN
        EXEC('USE [' + @DBName + ']; DBCC SHRINKFILE (N''' + @FileName + ''', 1024);');
    END
END


modify this for the two databases and time between 1.30 AM to 2:00AM