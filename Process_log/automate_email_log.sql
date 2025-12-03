SET ANSI_NULLS, QUOTED_IDENTIFIER ON;
GO

DECLARE @SuccessHTML NVARCHAR(MAX),
        @FailedHTML NVARCHAR(MAX),
        @htmlBody NVARCHAR(MAX),
        @ReportDate NVARCHAR(50);

-- Set the report date string (e.g., yesterday's date)
SET @ReportDate = CONVERT(NVARCHAR(30), CAST(DATEADD(DAY, -1, GETDATE()) AS DATE), 120);

-- Build the HTML table for Successful Logins
SET @SuccessHTML = 
N'<h2>Successful Logins</h2>' +
N'<table border="1" style="border-collapse:collapse;">' +
N'<tr>' +
N'<th>LoginName</th>' +
N'<th>HostName</th>' +
N'<th>LastLogin</th>' +
N'<th>SuccessfulLogins</th>' +
N'</tr>' +
(
    SELECT
      (
        SELECT 
          N'<tr>' +
          N'<td>' + ISNULL(LoginName, N'N/A') + N'</td>' +
          N'<td>' + REPLACE(REPLACE(ISNULL(HostName, N'N/A'), N'<', N''), N'>', N'') + N'</td>' +
          N'<td style="color:green;">' + CONVERT(NVARCHAR(30), LastLogin, 120) + N'</td>' +
          N'<td style="color:green;">' + CAST(SuccessfulLogins AS NVARCHAR(10)) + N'</td>' +
          N'</tr>'
        FROM LoginAuditSuccessDaily
        WHERE AttemptDate = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)
        FOR XML PATH(''), TYPE
      ).value('.', 'NVARCHAR(MAX)')
) +
N'</table>';

-- Build the HTML table for Failed Logins (using LastAttempt column)
SET @FailedHTML = 
N'<h2>Failed Logins</h2>' +
N'<table border="1" style="border-collapse:collapse;">' +
N'<tr>' +
N'<th>LoginName</th>' +
N'<th>HostName</th>' +
N'<th>LastAttempt</th>' +
N'<th>FailedLogins</th>' +
N'</tr>' +
(
    SELECT
      (
        SELECT 
          N'<tr>' +
          N'<td>' + ISNULL(LoginName, N'N/A') + N'</td>' +
          N'<td>' + REPLACE(REPLACE(ISNULL(HostName, N'N/A'), N'<', N''), N'>', N'') + N'</td>' +
          N'<td style="color:red;">' + CONVERT(NVARCHAR(30), LastAttempt, 120) + N'</td>' +
          N'<td style="color:red;">' + CAST(FailedLogins AS NVARCHAR(10)) + N'</td>' +
          N'</tr>'
        FROM LoginAuditFailedDaily
        WHERE AttemptDate = CAST(DATEADD(DAY, -1, GETDATE()) AS DATE)
        FOR XML PATH(''), TYPE
      ).value('.', 'NVARCHAR(MAX)')
) +
N'</table>';

-- Build the complete HTML email body
SET @htmlBody = 
N'<html><body>' +
N'<h1>Login Report for ' + @ReportDate + N'</h1>' +
@SuccessHTML + N'<br /><br />' + @FailedHTML +
N'<br /><br /><p>Thanks,</p>' +
N'<p>Your Team</p>' +
N'</body></html>';

-- Send the email using Database Mail
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = ''                        -- Replace with your Database Mail profile name
    @recipients = '',         -- Replace with your recipient email address
    @subject = 'Daily Login Audit Report',
    @body = @htmlBody,
    @body_format = 'HTML';
GO
