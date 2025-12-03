declare @cntr_value int
declare @v_subject varchar (100)
declare @cpu_usage varchar (50)
declare @cntr_output varchar(50)
set @cntr_value = (SELECT
[cntr_value] FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Manager%'
AND [counter_name] = 'Page life expectancy');
set @v_subject = 'Client Name Alert ! Page life expectancy less than 250  '+ HOST_NAME()
SET @cntr_output= 'Current PLE --> ' + convert(varchar,@cntr_value)
if @cntr_value < 250
begin
EXEC msdb.dbo.sp_send_dbmail 
  @profile_name= '',
@recipients = '',
@copy_recipients ='',
  @subject= @v_subject,
  @body=@cntr_output
end
