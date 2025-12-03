SELECT 
    DB_NAME(mf.database_id) AS [DatabaseName],
    mf.name AS [LogicalFileName],
    mf.physical_name AS [PhysicalFilePath],
    mf.type_desc AS [FileType],
    CONVERT(DECIMAL(10,2), mf.size * 8.0 / 1024) AS [SizeMB]
FROM 
    sys.master_files mf
WHERE 
    mf.physical_name LIKE 'T:\%'  -- Only files on T: drive
ORDER BY 
    mf.type_desc, DB_NAME(mf.database_id);
