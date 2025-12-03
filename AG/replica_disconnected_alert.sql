DECLARE 
    @PrimaryReplica SYSNAME,
    @EventTime DATETIME = GETDATE(),
    @Subject NVARCHAR(255),
    @HTMLBody NVARCHAR(MAX) = '',
    @Recipients NVARCHAR(MAX) = '',
    @ProfileName SYSNAME = '';

-- Get Primary Replica Name
SELECT 
    @PrimaryReplica = ar.replica_server_name
FROM sys.dm_hadr_availability_group_states ags
JOIN sys.availability_groups ag ON ags.group_id = ag.group_id
JOIN sys.availability_replicas ar ON ags.primary_replica = ar.replica_id;

-- Start HTML body
SET @HTMLBody = 
N'<html><body>' +
N'<h3 style="color:red;">Replica Disconnected Alert</h3>' +
N'<table border="1" cellpadding="6" cellspacing="0" style="border-collapse: collapse; font-family: Calibri; font-size: 14px;">' +
N'<tr style="background-color:#f2f2f2;">' +
N'<th>AG Name</th><th>Primary Replica</th><th>Disconnected Replica</th><th>Time</th></tr>';

-- Cursor to collect disconnected replicas with AG info
DECLARE 
    @Replica SYSNAME,
    @AGName SYSNAME;

DECLARE replica_cursor CURSOR FOR
SELECT 
    ar.replica_server_name,
    ag.name AS AGName
FROM sys.dm_hadr_availability_replica_states ars
JOIN sys.availability_replicas ar ON ars.replica_id = ar.replica_id
JOIN sys.availability_groups ag ON ar.group_id = ag.group_id
WHERE ars.connected_state_desc = 'DISCONNECTED'
  AND ars.role_desc = 'SECONDARY';

OPEN replica_cursor;
FETCH NEXT FROM replica_cursor INTO @Replica, @AGName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @HTMLBody += 
        N'<tr>' +
        N'<td>' + ISNULL(@AGName, 'UNKNOWN') + N'</td>' +
        N'<td>' + ISNULL(@PrimaryReplica, 'UNKNOWN') + N'</td>' +
        N'<td>' + ISNULL(@Replica, 'UNKNOWN') + N'</td>' +
        N'<td>' + CONVERT(NVARCHAR, @EventTime, 120) + N'</td>' +
        N'</tr>';

    FETCH NEXT FROM replica_cursor INTO @Replica, @AGName;
END

CLOSE replica_cursor;
DEALLOCATE replica_cursor;

-- Close HTML
SET @HTMLBody += 
N'</table>' +
N'</body></html>';

-- Send if any rows were added
IF CHARINDEX('<tr>', @HTMLBody) > 0
BEGIN
    SET @Subject = 'ALERT: Replicas Disconnected';

    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = @ProfileName,
        @recipients = @Recipients,
        @subject = @Subject,
        @body = @HTMLBody,
        @body_format = 'HTML';
END
