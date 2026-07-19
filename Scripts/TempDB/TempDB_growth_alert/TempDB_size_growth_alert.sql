SET NOCOUNT ON;

DECLARE @CurrentTempDBSizeGB DECIMAL(18,2);
DECLARE @PreviousSizeGB DECIMAL(18,2);
DECLARE @GrowthGB DECIMAL(18,2);
DECLARE @subject VARCHAR(100);

SELECT @CurrentTempDBSizeGB =
       SUM(size) * 8.0 / 1024 / 1024
FROM tempdb.sys.database_files
WHERE type_desc = 'ROWS';


SELECT TOP 1
       @PreviousSizeGB = TempDBSizeGB
FROM dbo.TempDBGrowthHistory
ORDER BY CaptureTime DESC;

INSERT INTO dbo.TempDBGrowthHistory
(
    TempDBSizeGB
)
VALUES
(
   @CurrentTempDBSizeGB
);

SET @GrowthGB = @CurrentTempDBSizeGB - ISNULL(@PreviousSizeGB,0);

IF @PreviousSizeGB IS NOT NULL
   AND @GrowthGB >= 100
BEGIN
    DECLARE @Body NVARCHAR(MAX);
SET @Body = '
<html>
<head>
<style>
    table
    {
        border-collapse: collapse;
        width: 80%;
    }

    th
    {
        background-color: #007ACC;
        color: white;
        border: 1px solid black;
        padding: 8px;
        text-align: center;
    }

    td
    {
        border: 1px solid black;
        padding: 8px;
        text-align: center;
    }

    body
    {
        font-family: Arial, Helvetica, sans-serif;
        font-size: 12px;
    }
</style>
</head>

<body>

<h2>TempDB Growth Alert</h2>

<p>
TempDB size has increased by <b>' + CAST(@GrowthGB AS VARCHAR(20)) + ' GB</b>
during the last 1 hour on server <b>' + @@SERVERNAME + '</b>.
Please review the workload and investigate any unusually large TempDB-consuming
queries, index maintenance activities, sorting operations, hash joins, or version store growth.
</p>

<table>
<tr>
    <th>Server</th>
    <th>Previous Size (GB)</th>
    <th>Current Size (GB)</th>
    <th>Growth (GB)</th>
    <th>Capture Time</th>
</tr>

<tr>
    <td>' + @@SERVERNAME + '</td>
    <td>' + CAST(@PreviousSizeGB AS VARCHAR(20)) + '</td>
    <td>' + CAST(@CurrentTempDBSizeGB AS VARCHAR(20)) + '</td>
    <td>' + CAST(@GrowthGB AS VARCHAR(20)) + '</td>
    <td>' + CONVERT(VARCHAR(19),GETDATE(),120) + '</td>
</tr>

</table>

<br/>

<p>
<b>Note:</b> This alert is generated when TempDB growth exceeds the configured threshold within a one-hour period.
</p>

</body>
</html>';

    set @subject ='TEMPDB Growth Alert - '+ @@SERVERNAME
    PRINT @Body;

    EXEC msdb.dbo.sp_send_dbmail
        @profile_name = 'th1',--'info@geojit.com',
        @recipients = 'mohamed@geopits.com',--'mssqlalerts@geopits.com',
        @subject = @subject ,
        @body = @Body,
        @body_format = 'HTML';
END;