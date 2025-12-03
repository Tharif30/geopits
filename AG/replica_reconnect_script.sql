DECLARE
    @LocalReplica SYSNAME,
    @AGName       SYSNAME,
    @EventTime    DATETIME = GETDATE(),
    @DisconnectTime DATETIME,
    @ProfileName  SYSNAME   = 'SAPINT_ADMIN',
    @Recipients   NVARCHAR(MAX) = 'hpcldbasupport@datapatroltech.com',
    @Subject      NVARCHAR(255),
    @HTMLBody     NVARCHAR(MAX);

-- 1. Identify local replica and AG name
SELECT 
    @LocalReplica = ar.replica_server_name,
    @AGName       = ag.name
FROM sys.dm_hadr_availability_replica_states ars
JOIN sys.availability_replicas ar ON ars.replica_id = ar.replica_id
JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
WHERE ars.is_local = 1;


-- 2. Check if local replica is disconnected
IF EXISTS (
    SELECT 1
    FROM sys.dm_hadr_availability_replica_states ars
    WHERE ars.is_local = 1
      AND ars.connected_state_desc = 'DISCONNECTED'
)
BEGIN
    SET @DisconnectTime = GETDATE();

    -- 3. Restart the local HADR endpoint
    ALTER ENDPOINT [hadr_endpoint] STATE = STARTED;

    -- 4. Wait for 30 seconds to allow reconnection
    WAITFOR DELAY '00:00:30';

    -- 5. Re-collect all replica statuses for the AG
    DECLARE @StatusTable TABLE (
        ReplicaName SYSNAME,
        RoleDesc NVARCHAR(60),
        StateDesc NVARCHAR(60),
        SyncState NVARCHAR(60),
        Timestamp NVARCHAR(25)
    );

    INSERT INTO @StatusTable(ReplicaName, RoleDesc, StateDesc, SyncState, Timestamp)
    SELECT 
        ar.replica_server_name,
        ars.role_desc,
        ars.connected_state_desc,
        ars.synchronization_health_desc,
        CONVERT(NVARCHAR, GETDATE(), 120)
    FROM sys.dm_hadr_availability_replica_states ars
    JOIN sys.availability_replicas ar ON ars.replica_id = ar.replica_id
    JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
    WHERE ag.name = @AGName;

    -- 6. Build email content with styled HTML
    SET @Subject = 'DR disconnected and reconnected to the Availability group';

    SET @HTMLBody = 
    N'<html><body>' +
    N'<h3 style="color:red;">DR Replica Disconnection Recovery</h3>' +
    N'<p><b>Availability Group:</b> ' + @AGName + '<br>' +
    N'<b>Local Replica:</b> ' + @LocalReplica + '<br>' +
    N'<b>Disconnected At:</b> ' + CONVERT(NVARCHAR, @DisconnectTime, 120) + '<br>' +
    N'<b>Endpoint Restarted At:</b> ' + CONVERT(NVARCHAR, GETDATE(), 120) + '</p>' +

    N'<table border="1" cellpadding="6" cellspacing="0" ' +
    N'style="border-collapse: collapse; font-family: Calibri; font-size: 14px;">' +
    N'<tr style="background-color:#003366; color:white;">' +
    N'<th>Replica Name</th><th>Role</th><th>Connection Status</th><th>Sync State</th><th>Timestamp</th>' +
    N'</tr>';

    DECLARE @rep SYSNAME, @role NVARCHAR(60), @state NVARCHAR(60), @sync NVARCHAR(60), @time NVARCHAR(25);
    DECLARE c CURSOR FOR
    SELECT ReplicaName, RoleDesc, StateDesc, SyncState, Timestamp FROM @StatusTable;

    OPEN c;
    FETCH NEXT FROM c INTO @rep, @role, @state, @sync, @time;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @HTMLBody += 
            N'<tr>' +
            N'<td>' + ISNULL(@rep, 'UNKNOWN') + N'</td>' +
            N'<td>' + ISNULL(@role, 'UNKNOWN') + N'</td>' +
            N'<td>' + ISNULL(@state, 'UNKNOWN') + N'</td>' +
            N'<td>' + ISNULL(@sync, 'UNKNOWN') + N'</td>' +
            N'<td>' + @time + N'</td>' +
            N'</tr>';

        FETCH NEXT FROM c INTO @rep, @role, @state, @sync, @time;
    END

    CLOSE c; DEALLOCATE c;

    SET @HTMLBody += N'</table></body></html>';

    -- 7. Send email
    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = @ProfileName,
        @recipients   = @Recipients,
		@copy_recipients='asgarkhan@hpcl.in',
		@blind_copy_recipients='naresh.k@datapatroltech.com',
        @subject      = @Subject,
        @body         = @HTMLBody,
        @body_format  = 'HTML';
END
