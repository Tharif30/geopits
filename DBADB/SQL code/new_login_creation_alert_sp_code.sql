USE DBADB;
go

CREATE PROCEDURE dbo.sp_NewLoginNotification
    @subject NVARCHAR(255),
    @profile_name NVARCHAR(255),
    @recipients NVARCHAR(255),
    @cc NVARCHAR(255) = NULL,
    @server_name NVARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    -- Create the newlogins table if it doesn't exist
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'newlogins' AND schema_id = SCHEMA_ID('dbo'))
    BEGIN
        CREATE TABLE dbo.newlogins (
            ServerName NVARCHAR(255),
            LoginName NVARCHAR(255),
            LoginCreationDate DATETIME,
            DatabaseName NVARCHAR(255),
            EmailSent BIT DEFAULT 0
        );
    END

    -- Insert new logins into the newlogins table, avoiding duplicates
    INSERT INTO dbo.newlogins (ServerName, LoginName, LoginCreationDate, DatabaseName)
    SELECT 
        @@SERVERNAME,
        name,
        create_date,
        default_database_name
    FROM sys.server_principals
    WHERE create_date > DATEADD(MINUTE, -10, GETDATE())
      AND name NOT IN  (SELECT LoginName
          FROM dbo.newlogins 
          WHERE ServerName = @@SERVERNAME 
            AND LoginName = sys.server_principals.name 
            AND LoginCreationDate = sys.server_principals.create_date);

    -- Prepare the email body
    DECLARE @xml NVARCHAR(MAX);
    SELECT @xml = CAST((SELECT 
                            @@SERVERNAME AS 'td', '',
                            LoginName AS 'td', '',
                            LoginCreationDate AS 'td', '',
                            DatabaseName AS 'td'
                        FROM DBADB..newlogins
                        WHERE LoginCreationDate > DATEADD(MINUTE, -10, GETDATE()) and EmailSent<>1
                        FOR XML PATH('tr'), ELEMENTS) AS NVARCHAR(MAX));

    DECLARE @body NVARCHAR(MAX);
    SET @body = 
    '<html>
        <head>
            <style>
                table, th, td {
                    border: 1px solid black;
                    border-collapse: collapse;
                    text-align: center;
                }
            </style>
        </head>
        <body>
            <h2>New Logins ' + @server_name + '</h2>
            <table>
                <tr>
                    <th>Server Name</th><th>Login Name</th><th>Login Creation Date</th><th>Database</th>
                </tr>' + @xml + '
            </table>
        </body>
    </html>';

    -- Send the email if there are new logins
    IF (@xml IS NOT NULL)
    BEGIN
        EXEC msdb.dbo.sp_send_dbmail
            @profile_name = @profile_name,
            @body = @body,
            @body_format = 'HTML',
            @recipients = @recipients,
            @copy_recipients = @cc,
            @subject = @subject;

        -- Update the newlogins table to indicate the email has been sent
        UPDATE dbo.newlogins
        SET EmailSent = 1
        WHERE EmailSent = 0;
    END

    SET NOCOUNT OFF;
END;


-- Job step code and change schedule to every 10 mins
Declare @Recipients nvarchar(max),@Subject nvarchar(255),@Profile_name nvarchar(100),@CC nvarchar(max),@ServerName nvarchar(512) ;
SET @Profile_name=''
SET @ServerName= @@SERVERNAME;
SET @Subject='Client Name '+@Servername+' NEW LOGIN CREATION NOTIFICATION ';
SET @Recipients=''
SET @CC=''

EXEC dbadb.dbo.sp_NewLoginNotification
    @subject = @Subject,
    @profile_name =@Profile_name,
    @recipients = @Recipients,
    @cc = @CC,
    @server_name = @ServerName;