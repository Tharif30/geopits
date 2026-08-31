SELECT TOP 1
    @@SERVERNAME AS [Server Name],
    CAST(reserved_storage_mb / 1024.0 AS DECIMAL(10,2)) AS [Reserved Storage (GB)],
    CAST(storage_space_used_mb / 1024.0 AS DECIMAL(10,2)) AS [Used Storage (GB)],
    CAST((reserved_storage_mb - storage_space_used_mb) / 1024.0 AS DECIMAL(10,2)) AS [Free Space (GB)],
    CAST((storage_space_used_mb * 100.0 / reserved_storage_mb) AS DECIMAL(5,2)) AS [Used %]
FROM 
    master.sys.server_resource_stats
ORDER BY 
    end_time DESC;