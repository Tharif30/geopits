
create table DBADB.dbo.disk_usage( DriveLetter VARCHAR(10),FreeSpace_GB VARCHAR(100),UsedSpace_GB varchar(100), TotalSpace_GB VARCHAR(100), Percentage_Free varchar(100))

--=======================================================
--=======================================================
--Job step 
--=======================================================
--=======================================================

DECLARE @Result INT
                , @objFSO INT
                , @Drv INT
                , @cDrive VARCHAR(13)
                , @Size VARCHAR(50)
                , @Free VARCHAR(50)
                , @Label varchar(10);
 
CREATE TABLE ##_DriveSpace
                (
                DriveLetter CHAR(1) not null
                , FreeSpace VARCHAR(10) not null
 
                )
 
CREATE TABLE ##_DriveInfo
                (
                DriveLetter CHAR(1)
                , TotalSpace bigint
                , FreeSpace bigint
                , Label varchar(10)
                )
 
INSERT INTO ##_DriveSpace
                EXEC master.dbo.xp_fixeddrives;
 
 
-- Iterate through drive letters.
DECLARE curDriveLetters CURSOR
                FOR SELECT driveletter FROM ##_DriveSpace
 
DECLARE @DriveLetter char(1)
                OPEN curDriveLetters
 
FETCH NEXT FROM curDriveLetters INTO @DriveLetter
WHILE (@@fetch_status <> -1)
BEGIN
                IF (@@fetch_status <> -2)
                BEGIN
 
                                SET @cDrive = 'GetDrive("' + @DriveLetter + '")'
 
                                                EXEC @Result = sp_OACreate 'Scripting.FileSystemObject', @objFSO OUTPUT
 
                                                                IF @Result = 0
 
                                                                                EXEC @Result = sp_OAMethod @objFSO, @cDrive, @Drv OUTPUT
 
                                                                IF @Result = 0
 
                                                                                EXEC @Result = sp_OAGetProperty @Drv,'TotalSize', @Size OUTPUT
 
                                                                IF @Result = 0
 
                                                                                EXEC @Result = sp_OAGetProperty @Drv,'FreeSpace', @Free OUTPUT
 
                                                                IF @Result = 0
 
                                                                                EXEC @Result = sp_OAGetProperty @Drv,'VolumeName', @Label OUTPUT
 
                                                                IF @Result <> 0
 
                                                                                EXEC sp_OADestroy @Drv
                                                                                EXEC sp_OADestroy @objFSO
 
                                                SET @Size = (CONVERT(BIGINT,@Size) / 1048576 )
 
                                                SET @Free = (CONVERT(BIGINT,@Free) / 1048576 )
 
                                                INSERT INTO ##_DriveInfo
                                                                VALUES (@DriveLetter, @Size, @Free, @Label)
 
                END
                FETCH NEXT FROM curDriveLetters INTO @DriveLetter
END
 
CLOSE curDriveLetters
DEALLOCATE curDriveLetters
 
-- Produce report.
INSERT INTO DBADB.dbo.disk_usage
       (DriveLetter, FreeSpace_GB, UsedSpace_GB, TotalSpace_GB, Percentage_Free, date_time)
SELECT DriveLetter
       , FreeSpace/1024 AS [FreeSpace_GB]
       , (TotalSpace - FreeSpace)/1024 AS [UsedSpace_GB]
       , TotalSpace/1024 AS [TotalSpace_GB]
       , (CONVERT(INT, (CONVERT(NUMERIC(9,2),FreeSpace) / CONVERT(NUMERIC(9,2),TotalSpace)) * 100)) AS [Percentage_Free]
       , GETDATE() AS date_time
FROM ##_DriveInfo
ORDER BY [DriveLetter] ASC;
--select * from DBADB.dbo.disk_usage
drop table ##_DriveInfo
drop table ##_DriveSpace