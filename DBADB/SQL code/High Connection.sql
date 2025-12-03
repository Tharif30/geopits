set nocount on
declare @count int
select @count=count(*) from sys.sysprocesses where spid>50 and dbid > 4 and status <> 'sleeping'
if (@count >= 100)
BEGIN
declare @profile varchar(100) = '' --Change
declare @recipient varchar(max) = ''--Change
declare @cc varchar(max)= ''
declare @bcc varchar(max)= ''
declare @body nvarchar(max)
declare @sub varchar(100)='Client Name High Connection Alert('+(select @@SERVERNAME)+'): '+(select convert(varchar,getdate(),0))+'' --Change
declare @xml nvarchar(max)
declare @SQL table([Server] varchar(200),HostName varchar(200),DBName varchar(200),ProgramName varchar(200),total int)
insert into @SQL
select @@SERVERNAME,hostname,DB_NAME(DBID) AS [Database Name],program_name,COUNT(*)as total from sys.sysprocesses where spid>50 and dbid > 4 and status <> 'sleeping'
group by hostname,dbid,program_name
SELECT @xml = CAST((
    SELECT 
        [Server] AS 'td',
        '',
        Hostname AS 'td',
        '',
        DBName AS 'td',
        '',
        ProgramName AS 'td',
        '',
        total AS 'td'
    FROM @SQL 
    ORDER BY total DESC
    FOR XML PATH('tr'), ELEMENTS
) AS NVARCHAR(max));

SET @body = '
<html>
    <head>
        <style>
            body {
                font-family: Arial, sans-serif;
                background-color: #f4f4f4;
                margin: 20px;
            }
            table {
                width: 100%;
                border-collapse: collapse;
                margin: 20px 0;
                box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            }
            th, td {
                padding: 12px;
                text-align: left;
                border: 1px solid #dddddd;
            }
            th {
                background-color: #4CAF50;
                color: white;
            }
            tr:nth-child(even) {
                background-color: #f2f2f2;
            }
            h2 {
                color: #333;
            }
            .content {
                margin-bottom: 20px;
            }
            .highlight {
                color: #d9534f; /* Bootstrap Danger color */
                font-weight: bold;
            }
        </style>
    </head>
    <body>
        <div class="content">
            <p>Dear Team,</p>
            <p>Please find below the details of the current database connections for the server <strong>'+@@SERVERNAME+'</strong>:</p>
            <h4>Total Connections Exceeded limit 100: <span class="highlight">' + CAST(@count AS VARCHAR(10)) + '</span></h4>
        </div>
        <table>
            <tr>
                <th>Server</th>
                <th>Host Name</th>
                <th>Database Name</th>
                <th>Program Name</th>
                <th>Total Connections</th>
            </tr>' + @xml + '
        </table>
        <p>If you have any questions or need further information, feel free to reach out.</p>
        <p>Best Regards,<br>MSSQL Team</p>
    </body>
</html>';--Change Team


--select @body  
if(@xml is not null)
BEGIN
EXEC msdb.dbo.sp_send_dbmail
@profile_name=@profile,
@body=@body,
@body_format='html',
@recipients=@recipient,
@copy_recipients =@cc,
@blind_copy_recipients = @bcc,
@subject=@sub;
END
END
select * from @SQL
SET NOCOUNT OFF

