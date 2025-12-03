IF OBJECT_ID('tempdb..#output') IS NOT NULL 
DROP TABLE #output
declare @profile varchar(100) = '' --Change
declare @recipient varchar(max) = '' --Change
declare @cc varchar(max)= ''
declare @bcc varchar(max)= ''
declare @body nvarchar(max)
declare @sub varchar(100)='Client Name Disk Space Alert '+(select @@SERVERNAME)+': '+(select convert(varchar,getdate(),107))+''  --Change
declare @new table (drivename varchar(10),[capacity(MB)] varchar(100),[freespace(MB)] varchar(100),[Used %] varchar(100))
declare @svrName varchar(255)
declare @sql varchar(400)
set @svrName = @@SERVERNAME
set @sql = 'powershell.exe -c "Get-WmiObject -ComputerName ' + QUOTENAME(@svrName,'''') + '-Class Win32_Volume -Filter ''DriveType = 3'' | select name,capacity,freespace | foreach{$_.name+''|''+$_.capacity/1048576+''%''+$_.freespace/1048576+''*''}"'
CREATE TABLE #output
(line varchar(255))
insert #output
EXEC xp_cmdshell @sql
insert into @new
select rtrim(ltrim(SUBSTRING(line,1,CHARINDEX('|',line) -1))) as drivename
   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
   (CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float)/1024,0) as 'capacity(GB)'
   ,round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1,
   (CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float) /1024 ,0)as 'freespace(GB)'
   ,cast(
   (round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
   (CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float),0) - 
   round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('%',line)+1,
   (CHARINDEX('*',line) -1)-CHARINDEX('%',line)) )) as Float),0)) /
   round(cast(rtrim(ltrim(SUBSTRING(line,CHARINDEX('|',line)+1,
   (CHARINDEX('%',line) -1)-CHARINDEX('|',line)) )) as Float),0)
    as decimal(18,2)
	)*100 as 'Used %'
from #output
where line like '[A-Z][:]%'
order by drivename

SET NOCOUNT ON
DECLARE  @xml nvarchar(max)
SELECT @xml = Cast((SELECT drivename AS 'td',
'',
[capacity(MB)] AS 'td',
'',
[freespace(MB)] AS 'td',
'',
[Used %] AS 'td'
FROM @new where [Used %] > 90.00
FOR xml path('tr'), elements) AS NVARCHAR(max))
SET @body =
'<html>
	<head>
		<style>
			table, th, td 
			{
				border: 1px solid black;
				border-collapse: collapse;
				text-align: center;
			}
		</style>
	</head>
	<body>
		<H2>
		High Disk Space Alert: '+@svrName+'
		</H2>
		<table> 
			<tr>
				<th> Drive Name </th> <th> Total Size(GB) </th> <th> Free Space(GB) </th> <th> Used %</th> 
			</tr>'
			SET @body = @body + @xml + '
		</table>
	</body>
</html>'
if(@xml is not null)
BEGIN
EXEC msdb.dbo.Sp_send_dbmail
@profile_name = @profile,
@body = @body,
@body_format ='html',
@recipients = @recipient,
@copy_recipients =@cc,
@blind_copy_recipients = @bcc,
@subject = @sub;
END
SET NOCOUNT OFF
drop table #output