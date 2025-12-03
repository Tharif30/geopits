DECLARE 
    @ThresholdMinutes INT = 60,
    @HTMLBody NVARCHAR(MAX) = '',
    @Subject NVARCHAR(255),
    @EventTime DATETIME = GETDATE(),
    @Recipients NVARCHAR(MAX) = ''

-- Temp table to hold data
DECLARE @AlertTable TABLE (
    ReplicaName SYSNAME,
    AGName SYSNAME,
    DatabaseName SYSNAME,
    SyncState NVARCHAR(60),
    LogSendQueueMB FLOAT,
    LogSendRateMBPerMin FLOAT,
    EstimatedLatencyMinutes FLOAT
)

-- Collect data
INSERT INTO @AlertTable
SELECT 
    ar.replica_server_name,
    ag.name AS AGName,
    d.name AS DatabaseName,
    drs.synchronization_state_desc AS SyncState,
    drs.log_send_queue_size / 1024.0 / 1024.0 AS LogSendQueueMB,
    CASE 
        WHEN drs.log_send_rate > 0 THEN (drs.log_send_rate / 1024.0 / 1024.0) * 60 
        ELSE NULL
    END AS LogSendRateMBPerMin,
    CASE 
        WHEN drs.log_send_rate > 0 THEN 
            (drs.log_send_queue_size / 1024.0 / 1024.0) / ((drs.log_send_rate / 1024.0 / 1024.0) * 60)
        ELSE NULL
    END AS EstimatedLatencyMinutes
FROM sys.dm_hadr_database_replica_states drs
JOIN sys.availability_replicas ar ON drs.replica_id = ar.replica_id
JOIN sys.databases d ON drs.database_id = d.database_id
JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
WHERE drs.is_local = 0
  AND drs.log_send_queue_size > 0;

-- Build email only if delay exceeds threshold
IF EXISTS (
    SELECT 1 FROM @AlertTable WHERE EstimatedLatencyMinutes > @ThresholdMinutes
)
BEGIN
    SET @Subject = 'ALERT: Grouped Log Send Latency Detected by Replica'

    SET @HTMLBody = 
    N'<html><body>' +
    N'<h3 style="color:red;">Log Send Queue Latency Alert</h3>' +
    N'<p>The following replicas have one or more databases with log send latency exceeding ' + CAST(@ThresholdMinutes AS NVARCHAR) + ' minutes:</p>';

    DECLARE @CurrentReplica SYSNAME = NULL;

    -- Cursor through each row sorted by Replica
    DECLARE AlertCursor CURSOR FOR
    SELECT ReplicaName, AGName, DatabaseName, SyncState, LogSendQueueMB, LogSendRateMBPerMin, EstimatedLatencyMinutes
    FROM @AlertTable
    WHERE EstimatedLatencyMinutes > @ThresholdMinutes
    ORDER BY ReplicaName, DatabaseName;

    DECLARE 
        @Replica SYSNAME,
        @AG SYSNAME,
        @DB SYSNAME,
        @SyncState NVARCHAR(60),
        @Queue FLOAT,
        @Rate FLOAT,
        @Latency FLOAT;

    OPEN AlertCursor;
    FETCH NEXT FROM AlertCursor INTO @Replica, @AG, @DB, @SyncState, @Queue, @Rate, @Latency;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Start a new section if replica changed
        IF @CurrentReplica IS NULL OR @Replica <> @CurrentReplica
        BEGIN
            IF @CurrentReplica IS NOT NULL
                SET @HTMLBody += N'</table><br/>';

            SET @HTMLBody += N'<h4 style="color:blue;">Replica: ' + @Replica + N'</h4>' +
            N'<table border="1" cellpadding="6" cellspacing="0" style="border-collapse: collapse; font-family: Calibri; font-size: 14px;">' +
            N'<tr style="background-color:#f2f2f2;"><th>Database</th><th>AG Name</th><th>Sync State</th><th>Queue (MB)</th><th>Send Rate (MB/min)</th><th>Estimated Latency (min)</th></tr>';

            SET @CurrentReplica = @Replica;
        END

        -- Add row
        SET @HTMLBody += 
            N'<tr><td>' + @DB + N'</td>' +
            N'<td>' + @AG + N'</td>' +
            N'<td>' + @SyncState + N'</td>' +
            N'<td>' + FORMAT(@Queue, 'N2') + N'</td>' +
            N'<td>' + ISNULL(FORMAT(@Rate, 'N2'), 'N/A') + N'</td>' +
            N'<td>' + ISNULL(FORMAT(@Latency, 'N2'), 'N/A') + N'</td></tr>';

        FETCH NEXT FROM AlertCursor INTO @Replica, @AG, @DB, @SyncState, @Queue, @Rate, @Latency;
    END

    CLOSE AlertCursor;
    DEALLOCATE AlertCursor;

    -- Close last table
    SET @HTMLBody += N'</table></body></html>';

    -- Send mail
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = '',
        @recipients = @Recipients,
        @subject = @Subject,
        @body = @HTMLBody,
        @body_format = 'HTML';
END
