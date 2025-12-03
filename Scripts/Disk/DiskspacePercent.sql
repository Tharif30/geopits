
DECLARE @new TABLE (
    drivename VARCHAR(10),
    [capacity(GB)] VARCHAR(100),
    [freespace(GB)] VARCHAR(100),
    [Used %] VARCHAR(100)
);

INSERT INTO @new
SELECT DISTINCT 
    vs.volume_mount_point AS drivename,
    CONVERT(DECIMAL(18, 2), vs.total_bytes / 1073741824.0) AS [capacity(GB)],
    CONVERT(DECIMAL(18, 2), vs.available_bytes / 1073741824.0) AS [freespace(GB)],
    CONVERT(DECIMAL(18, 2), (vs.total_bytes - vs.available_bytes) * 1.0 / vs.total_bytes * 100) AS [Used %]
FROM sys.master_files AS f WITH (NOLOCK)
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.[file_id]) AS vs
ORDER BY vs.volume_mount_point

SELECT 
    drivename AS 'drivename', 
    [capacity(GB)] AS '[capacity(GB)]',
    [freespace(GB)] AS '[freespace(GB)]', 
    [Used %] AS '[Used %]'
FROM @new 


--WHERE (drivename = 'C:\' AND [Used %] > 70.0)
--   OR (drivename <> 'C:\' AND [Used %] >= 95.0)