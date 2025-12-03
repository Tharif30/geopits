--------------------------------------------------------------------------------------
--Author:tharif
--Date:12-11-15
--Logic Description
--checks if the Web_VAS account logs in from unauthorized IP addresses
--Inserts unauthorized login attempts into WebVasLoginAudit
--Sends an HTML-formatted email alert with the login details
-----------------------------------------------------------------------------------------------
CREATE TRIGGER [trg_WebVAS_IPCheck_1]
    ON ALL SERVER
    FOR LOGON
AS
BEGIN
    IF TRIGGER_NESTLEVEL() > 1
        RETURN;

    DECLARE 
        @LoginName   NVARCHAR(100),
        @IPAddress   NVARCHAR(50),
        @AlertMessage NVARCHAR(4000),
        @HTMLBody     NVARCHAR(MAX);

    SET @LoginName = ORIGINAL_LOGIN();

    IF @LoginName = 'Web_VAS'
    BEGIN
        SELECT @IPAddress = client_net_address
        FROM sys.dm_exec_connections
        WHERE session_id = @@SPID;

        IF @IPAddress NOT IN ('172.31.5.171', '13.234.211.64', '172.31.45.251', '13.203.183.57', '23.226.124.197')
        BEGIN
            SET @AlertMessage = CONCAT(
                'ALERT: Web_VAS login from unauthorized IP (', 
                ISNULL(@IPAddress, 'Unknown'), 
                ') at ', 
                CONVERT(VARCHAR(30), GETDATE(), 120)
            );

           
            IF EXISTS (
                SELECT 1
                FROM dbadb.dbo.WebVasLoginAudit
                WHERE LoginName = @LoginName
                  AND IPAddress = @IPAddress
                  AND DATEDIFF(SECOND, LoginTime, GETDATE()) < 10
            )
                RETURN;

            INSERT INTO dbadb.dbo.WebVasLoginAudit (LoginName, IPAddress, AlertMessage)
            VALUES (@LoginName, @IPAddress, @AlertMessage);

            -- Build an HTML formatted email body
            SET @HTMLBody = CONCAT(
                '<html><body>',
                '<p><b style="color:red;">', @AlertMessage, '</b></p>',
                '<p><b>Login Name:</b> ', @LoginName, '<br>',
                '<b>IP Address:</b> ', ISNULL(@IPAddress, 'Unknown'), '<br>',
                '<b>Time:</b> ', CONVERT(VARCHAR(30), GETDATE(), 120), '</p>',
                '</body></html>'
            );

            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'tharif', --CHANGE 1
                @recipients = 'mohamed@geopits.com', --CHANGE 2
                @subject = 'ALERT: Unauthorized Web_VAS login detected',
                @body = @HTMLBody,
                @body_format = 'HTML';
        END
    END
END
GO
