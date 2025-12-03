DECLARE @htmlBody NVARCHAR(MAX);


SET @htmlBody = 
'<html>
  <head>
    <style>
      table { border-collapse: collapse; width: 100%; }
      th, td { border: 1px solid #ddd; padding: 8px; }
      th { background-color: #f2f2f2; text-align: left; }
    </style>
  </head>
  <body>
    <h2>User Session Log Report</h2>
    <table>
      <tr>
        <th>ID</th>
        <th>Username</th>
        <th>SessionID</th>
        <th>EventTime</th>
        <th>EventType</th>
        <th>Duration</th>
      </tr>';


SELECT @htmlBody = @htmlBody + '
      <tr>
        <td>' + CAST(ID AS NVARCHAR(10)) + '</td>
        <td>' + ISNULL(Username, '') + '</td>
        <td>' + CAST(SessionID AS NVARCHAR(10)) + '</td>
        <td>' + CONVERT(NVARCHAR(20), EventTime, 120) + '</td>
        <td>' + ISNULL(EventType, '') + '</td>
        <td>' + ISNULL(CAST(Duration AS NVARCHAR(20)), '') + '</td>
      </tr>'
FROM UserSessionLog 


SET @htmlBody = @htmlBody + '
    </table>
  </body>
</html>';


EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'Tharif',  
    @recipients = 'mohamedtharif30@gmail.com',      
    @subject = 'User Session Log Report',
    @body = @htmlBody,
    @body_format = 'HTML';
