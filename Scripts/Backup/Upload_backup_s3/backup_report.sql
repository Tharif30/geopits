USE dbadb;
GO

CREATE OR ALTER PROCEDURE dbo.usp_SendBackupUploadReport
(
      @Recipients NVARCHAR(MAX),
      @CopyRecipients  NVARCHAR(MAX) = NULL,
      @MailProfile     SYSNAME
)
AS
BEGIN
    SET NOCOUNT ON;

    Declare @LogFilePath     NVARCHAR(500)='C:\Users\Public\s3_upload\s3upload.log';
    DECLARE
      @JobName               SYSNAME = 'test_upload_s3'
     ,@upload_step_name varchar(40)='upload_backup'
     ,@backup_step_name varchar(40)='Backup'
    , @ServerName            SYSNAME
    , @ReportDate            VARCHAR(20)
    , @JobStatus             VARCHAR(20)
    , @BackupStepDuration    VARCHAR(20)
    , @UploadStepDuration    VARCHAR(20)
    , @TotalJobDuration      VARCHAR(20)
    , @DBBackupCompleted     INT
    , @MissingBackups        INT
    , @Subject varchar(100)
    
    

    SET @ServerName = @@SERVERNAME;
    SET @ReportDate = FORMAT(GETDATE(), 'dd MMM yyyy');
    ----------------------------------------------------------
    -- Load latest S3 Upload Log
    ----------------------------------------------------------

    IF OBJECT_ID('dbadb.dbo.S3UploadLog', 'U') IS NULL
    BEGIN
        CREATE TABLE dbadb.dbo.S3UploadLog
        (
            LogLine NVARCHAR(4000)
        );
    END

    TRUNCATE TABLE dbadb.dbo.S3UploadLog; 

    DECLARE @SQL NVARCHAR(MAX);

    SET @SQL = '
    BULK INSERT dbadb.dbo.S3UploadLog
    FROM ''' + @LogFilePath + '''
    WITH
    (
        ROWTERMINATOR = ''\n''
    );';

    EXEC(@SQL);

    ------------------------------------------------------------
    -- Store Result
    ------------------------------------------------------------
    IF OBJECT_ID('tempdb..#BackupReport') IS NOT NULL
        DROP TABLE #BackupReport;

    ;WITH UploadLog AS
    (
        SELECT LogLine
        FROM dbadb.dbo.S3UploadLog
        WHERE LogLine LIKE '%upload:%'
    ),
    ParsedUpload AS
    (
        SELECT
            UploadedFile,
            FileName,
            S3Path
        FROM UploadLog
        CROSS APPLY
        (
            SELECT
                UploadedFile =
                    LTRIM(RTRIM(
                        SUBSTRING
                        (
                            LogLine,
                            CHARINDEX('upload:',LogLine)+7,
                            CHARINDEX(' to s3://',LogLine)-(CHARINDEX('upload:',LogLine)+7)
                        )
                    )),

                S3Path =
                    LTRIM(RTRIM(
                        SUBSTRING
                        (
                            LogLine,
                            CHARINDEX('s3://',LogLine),
                            LEN(LogLine)
                        )
                    ))
        )A
        CROSS APPLY
        (
            SELECT
                FileName =
                CASE
                    WHEN CHARINDEX('\',REVERSE(A.UploadedFile))>0
                    THEN REVERSE(LEFT(REVERSE(A.UploadedFile),
                                      CHARINDEX('\',REVERSE(A.UploadedFile))-1))
                    ELSE A.UploadedFile
                END
        )B
    ),
BackupInfo AS
(
    SELECT *
    FROM
    (
        SELECT
            bs.database_name,
            'FULL' AS BackupType,
            bs.backup_start_date,
            bs.backup_finish_date,

            Duration =
                CONVERT(varchar(8),
                    DATEADD(SECOND,
                        DATEDIFF(SECOND,
                            bs.backup_start_date,
                            bs.backup_finish_date),
                        0),
                    108),

            BackupSizeMB =
                CAST(bs.backup_size / 1024.0 / 1024 AS DECIMAL(18,2)),

            bmf.physical_device_name,

            BackupFileName =
                CASE
                    WHEN CHARINDEX('\', REVERSE(bmf.physical_device_name)) > 0
                    THEN REVERSE(
                            LEFT(
                                REVERSE(bmf.physical_device_name),
                                CHARINDEX('\', REVERSE(bmf.physical_device_name)) - 1
                            )
                         )
                    ELSE bmf.physical_device_name
                END,

            rn = ROW_NUMBER() OVER
                 (
                     PARTITION BY bs.database_name
                     ORDER BY bs.backup_finish_date DESC
                 )
        FROM msdb.dbo.backupset bs
        INNER JOIN msdb.dbo.backupmediafamily bmf
            ON bs.media_set_id = bmf.media_set_id
        WHERE bs.type = 'D'
    ) t
    WHERE rn = 1
)

    SELECT
          b.database_name                              AS [Database Name]
        , b.BackupType                                AS [Backup Type]
        , b.backup_start_date                         AS [Start Time]
        , b.backup_finish_date                        AS [End Time]
        , b.Duration
        , 'Uploaded'                                  AS [Status]
        , b.BackupSizeMB                              AS [Size (MB)]
        , p.UploadedFile
        , p.S3Path
        , GETDATE()                                   AS backup_upload_complete_time
    INTO #BackupReport
    FROM BackupInfo b
    INNER JOIN ParsedUpload p
        ON b.BackupFileName=p.FileName;

        --select * from #BackupReport

    ------------------------------------------------------------
    -- Summary
    ------------------------------------------------------------
    -- Total databases backed up (from your report table)
    SELECT
        @DBBackupCompleted = COUNT(*)
    FROM #BackupReport;

    -- Missing User Databases (excluding tempdb)
    SELECT
        @MissingBackups =
    (
        SELECT COUNT(*)
        FROM sys.databases
        WHERE database_id <> 4     
    )
    -
    ISNULL(@DBBackupCompleted,0);

    DECLARE @LastInstanceID INT;

    SELECT TOP (1)
        @LastInstanceID = instance_id
    FROM msdb.dbo.sysjobhistory h
    JOIN msdb.dbo.sysjobs j
        ON h.job_id = j.job_id
    WHERE j.name = @JobName
      AND h.step_id = 0
    ORDER BY h.instance_id DESC;

    -- Latest Job Outcome
    ;WITH JobHistory AS
    (
        SELECT TOP (1)
               h.run_status,
               h.run_duration
        FROM msdb.dbo.sysjobs j
        INNER JOIN msdb.dbo.sysjobhistory h
            ON j.job_id=h.job_id
        WHERE j.name=@JobName
          AND h.step_id=0
        ORDER BY h.instance_id DESC
    )
    SELECT
        @JobStatus =
            CASE run_status
                WHEN 0 THEN 'FAILED'
                WHEN 1 THEN 'SUCCESS'
                WHEN 2 THEN 'RETRY'
                WHEN 3 THEN 'CANCELLED'
                WHEN 4 THEN 'IN PROGRESS'
            END,

        @TotalJobDuration =
            RIGHT('00'+CAST(run_duration/10000 AS VARCHAR),2)+':'+
            RIGHT('00'+CAST((run_duration%10000)/100 AS VARCHAR),2)+':'+
            RIGHT('00'+CAST(run_duration%100 AS VARCHAR),2)
    FROM JobHistory;

    -- Backup Step Duration
    SELECT
        @BackupStepDuration =
            RIGHT('00'+CAST(h.run_duration/10000 AS VARCHAR),2)+':'+
            RIGHT('00'+CAST((h.run_duration%10000)/100 AS VARCHAR),2)+':'+
            RIGHT('00'+CAST(h.run_duration%100 AS VARCHAR),2)
    FROM msdb.dbo.sysjobhistory h
    JOIN msdb.dbo.sysjobs j
        ON h.job_id = j.job_id
    JOIN msdb.dbo.sysjobsteps s
        ON s.job_id = j.job_id
       AND s.step_id = h.step_id
    WHERE j.name = @JobName
      AND s.step_name = @backup_step_name
      AND h.instance_id < @LastInstanceID
    ORDER BY h.instance_id DESC;

    ------------------------------------------------------------
    -- Upload Step Duration
    ------------------------------------------------------------
    SELECT
        @UploadStepDuration =
            RIGHT('00'+CAST(h.run_duration/10000 AS VARCHAR),2)+':'+
            RIGHT('00'+CAST((h.run_duration%10000)/100 AS VARCHAR),2)+':'+
            RIGHT('00'+CAST(h.run_duration%100 AS VARCHAR),2)
    FROM msdb.dbo.sysjobhistory h
    JOIN msdb.dbo.sysjobs j
        ON h.job_id = j.job_id
    JOIN msdb.dbo.sysjobsteps s
        ON s.job_id = j.job_id
       AND s.step_id = h.step_id
    WHERE j.name = @JobName
      AND s.step_name = @upload_step_name
      AND h.instance_id < @LastInstanceID
    ORDER BY h.instance_id DESC;

    ------------------------------------------------------------
    -- HTML
    ------------------------------------------------------------
    DECLARE @Body NVARCHAR(MAX);

    SET @Body='
<html>
<head>
<style>

body{
font-family:Calibri;
font-size:11pt;
}

h2{
    color:#1F4E78;
    font-size:18pt;
    font-weight:bold;
    margin-bottom:10px;
}

table{
border-collapse:collapse;
}

th{
background:#1F4E78;
color:white;
padding:6px;
border:1px solid black;
}

td{
padding:5px;
border:1px solid #cccccc;
}

.summary td{
font-weight:bold;
background:#F4F6F6;
}

</style>
</head>
<body>

<h2>SQL Backup Upload Report</h2>

<p style="font-family:Calibri;font-size:11pt;color:#333333;">
    Hi Team,<br><br>
    Please find the Monthly Backup Report below.
</p>

<h3>Backup Run Summary</h3>

<table style="border-collapse:collapse;font-family:Calibri;font-size:11pt;width:550px;">

    <tr style="background-color:#1F4E78;color:white;">
        <th colspan="2" style="padding:8px;border:1px solid #000;text-align:left;">
            Backup Run Summary
        </th>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">Server</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(@ServerName, '') +'</td>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">Job Name</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(@jobname, '') +'</td>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">Report Date</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(@ReportDate, '') +'</td>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">Job Status</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(@JobStatus, '') +'</td>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">DB Backup Completed</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(CAST(@DBBackupCompleted AS varchar(20)), '') +'</td>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">Missing / Not Backed Up</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(CAST(@MissingBackups AS varchar(20)), '') +'</td>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">Backup Step Duration</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(CAST(@BackupStepDuration AS varchar(20)), '') +'</td>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">Upload Step Duration</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(CAST(@UploadStepDuration AS varchar(20)), '') +'</td>
    </tr>

    <tr>
        <td style="font-weight:bold;background:#F2F2F2;border:1px solid #ccc;padding:6px;">Total Job Duration</td>
        <td style="border:1px solid #ccc;padding:6px;">'+ ISNULL(CAST(@TotalJobDuration AS varchar(20)), '') +'</td>
    </tr>

</table>

<br>

<h3>Backup Details</h3>

<table>

<tr>

<th>Database</th>
<th>Backup Type</th>
<th>Start Time</th>
<th>End Time</th>
<th>Backup_Duration</th>
<th>Status</th>
<th>Size (MB)</th>
<th>Uploaded File</th>
<th>S3 Path</th>
<th>Upload Time</th>

</tr>';

    SELECT @Body=@Body+
    '<tr>'+
    '<td>'+ISNULL([Database Name],'')+'</td>'+
    '<td>'+ISNULL([Backup Type],'')+'</td>'+
    '<td>'+CONVERT(VARCHAR,[Start Time],120)+'</td>'+
    '<td>'+CONVERT(VARCHAR,[End Time],120)+'</td>'+
    '<td>'+ISNULL(Duration,'')+'</td>'+
    '<td>'+Status+'</td>'+
    '<td>'+CAST([Size (MB)] AS VARCHAR(30))+'</td>'+
    '<td>'+ISNULL(UploadedFile,'')+'</td>'+
    '<td>'+ISNULL(S3Path,'')+'</td>'+
    '<td>'+CONVERT(VARCHAR,backup_upload_complete_time,120)+'</td>'+
    '</tr>'
    FROM #BackupReport
    ORDER BY [End Time] DESC;

    SET @Body=@Body+'</table></body></html>';

    SET @Subject='Invoicemart SunSystem '+ @SERVERNAME + 'Monthly Backup Report - ' + @ReportDate;


    select @Body
    ------------------------------------------------------------
    -- Send Mail
    --------------------------------------------------------------
    --EXEC msdb.dbo.sp_send_dbmail
    --    @profile_name=@MailProfile,
    --    @recipients=@Recipients,
    --    @subject=@Subject,
    --    @body=@Body,
    --    @body_format='HTML';

END
GO

