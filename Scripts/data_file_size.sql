use thyrocare

-- Create temporary table to store drive free space
CREATE TABLE #DriveSpace (
    DriveLetter CHAR(1),
    MBFree BIGINT
);
-- Populate drive free space using xp_fixeddrives
INSERT INTO #DriveSpace
EXEC xp_fixeddrives;

-- Main query to get database file details
SELECT 
    DB_NAME(mf.database_id) AS DatabaseName,
    mf.name AS FileName,
    LEFT(mf.physical_name, 1) AS DriveLetter,
    mf.physical_name AS PhysicalFilePath,
    CAST(mf.size * 8.0 / 1024 AS DECIMAL(18,2)) AS AllocatedSpace_MB,
    CAST(mf.size * 8.0 / 1024 - FILEPROPERTY(mf.name, 'SpaceUsed') * 8.0 / 1024 AS DECIMAL(18,2)) AS FreeSpaceInFile_MB,
    ds.MBFree AS DriveFreeSpace_MB
FROM 
    sys.master_files mf
LEFT JOIN 
    #DriveSpace ds ON LEFT(mf.physical_name, 1) = ds.DriveLetter
WHERE 
    mf.type_desc = 'Log' and DB_name(mf.database_id)='Thyrocare'  -- Only data files (exclude log files)
ORDER BY 
    DriveLetter, DatabaseName;

-- Clean up
DROP TABLE #DriveSpace;
