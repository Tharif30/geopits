	USE DBADB;
	GO

	SET NOCOUNT ON;

	DECLARE @server_name NVARCHAR(255) = @@SERVERNAME;

	-- Temporary table to hold email data
	DECLARE @EmailData TABLE (
	  JobId NVARCHAR(255),
	  JobName NVARCHAR(255),
	  StepName NVARCHAR(255),
	  Schedule NVARCHAR(255),
	  FailureCount INT,
	  FailureTimes NVARCHAR(MAX),
	  FailureMessages NVARCHAR(MAX),
	  FirstFailureTime DATETIME,
	  LastFailureTime DATETIME,
	  JobStartTime DATETIME,
	  JobFailureStepNumber INT -- Added to track step number
	);

	WITH RankedFailures AS (
	  SELECT 
		j.sql_server_agent_job_id,
		j.sql_server_agent_job_name,
		jf.job_failure_step_name,
		jf.job_step_failure_message,
		jf.job_failure_time_utc,
		jf.job_failure_step_number, -- Added step number
		j.Frequency,
		j.StartTime,
		j.EndTime,
		ROW_NUMBER() OVER (PARTITION BY j.sql_server_agent_job_id ORDER BY jf.job_failure_time_utc DESC) AS rn
	  FROM 
		[DBADB].[dbo].[sql_server_agent_job] j
	  JOIN 
		[DBADB].[dbo].[sql_server_agent_job_failure] jf ON j.sql_server_agent_job_id = jf.sql_server_agent_job_id
	  WHERE 
		jf.has_email_been_sent_to_operator = 0 
		AND (ticket_status IS NULL OR ticket_status <> 'Open') 
	)

	, ScheduleCTE AS (
	  SELECT 
		j.sql_server_agent_job_id,
		CASE 
		  WHEN j.Frequency = 'Daily' THEN 
			CASE 
			  WHEN j.DailyFrequency LIKE '%Repeat%' 
			  THEN 'Every day from ' + CAST(j.StartTime AS NVARCHAR(8)) + 
				 ' to ' + CAST(j.EndTime AS NVARCHAR(8)) + 
				 ', repeats every ' + 
				 NULLIF(CAST(SUBSTRING(j.DailyFrequency, CHARINDEX('every ', j.DailyFrequency) + 6, LEN(j.DailyFrequency)) AS NVARCHAR), '') + '.'
			  ELSE 'Every day at ' + CAST(j.StartTime AS NVARCHAR(8)) + '.'
			END
		  WHEN j.Frequency = 'Weekly' THEN 
			'Every ' + REPLACE(j.DayInterval, ' ', ', ') + 
			' starts at ' + CAST(j.StartTime AS NVARCHAR(8)) + 
			CASE 
			  WHEN j.DailyFrequency LIKE '%Repeat%' THEN 
				', repeats every ' + 
				NULLIF(CAST(SUBSTRING(j.DailyFrequency, CHARINDEX('every ', j.DailyFrequency) + 6, LEN(j.DailyFrequency)) AS NVARCHAR), '') + '.'
			  ELSE '.' 
			END
		  WHEN j.Frequency = 'Monthly' THEN 
			'On the ' + 
			CASE 
			  WHEN j.DayInterval LIKE '%1%' THEN '1st '
			  WHEN j.DayInterval LIKE '%2%' THEN '2nd '
			  WHEN j.DayInterval LIKE '%3%' THEN '3rd '
			  WHEN j.DayInterval LIKE '%4%' THEN '4th '
			  WHEN j.DayInterval LIKE '%5%' THEN '5th '
			  WHEN j.DayInterval LIKE '%last%' THEN 'Last '
			  ELSE 'Unknown '
			END + 
			'day of the month at ' + CAST(j.StartTime AS NVARCHAR(8)) +
			CASE 
			  WHEN j.DailyFrequency LIKE '%Repeat%' THEN 
				', repeats every ' + 
				NULLIF(CAST(SUBSTRING(j.DailyFrequency, CHARINDEX('every ', j.DailyFrequency) + 6, LEN(j.DailyFrequency)) AS NVARCHAR), '') + '.'
			  ELSE '.' 
			END
		  ELSE 'Other frequency or Not scheduled'
		END AS Schedule
	  FROM 
		[DBADB].[dbo].[sql_server_agent_job] j
	)

	-- Main Query to get aggregated job failure details
	INSERT INTO @EmailData (JobId, JobName, StepName, Schedule, FailureCount, FailureTimes, FailureMessages, FirstFailureTime, LastFailureTime, JobStartTime, JobFailureStepNumber)
	SELECT 
	  j.sql_server_agent_job_id,
	  j.sql_server_agent_job_name,
	  jf.job_failure_step_name,
	  sc.Schedule,
	  COUNT(jf.job_failure_time_utc) AS FailureCount,
	  STUFF((SELECT ', ' + CONVERT(NVARCHAR, jf_inner.job_failure_time_utc, 120)
		  FROM [DBADB].[dbo].[sql_server_agent_job_failure] jf_inner
		  WHERE jf_inner.sql_server_agent_job_id = j.sql_server_agent_job_id
		  FOR XML PATH('')), 1, 2, '') AS FailureTimes,
	  CASE 
		WHEN NULLIF(LTRIM(RTRIM(jf.job_step_failure_message)), '') IS NOT NULL AND NULLIF(LTRIM(RTRIM(jf.job_failure_message)), '') IS NOT NULL
		  THEN LTRIM(RTRIM(jf.job_step_failure_message)) + ' | ' + LTRIM(RTRIM(jf.job_failure_message))
		WHEN NULLIF(LTRIM(RTRIM(jf.job_step_failure_message)), '') IS NOT NULL
		  THEN LTRIM(RTRIM(jf.job_step_failure_message))
		WHEN NULLIF(LTRIM(RTRIM(jf.job_failure_message)), '') IS NOT NULL
		  THEN LTRIM(RTRIM(jf.job_failure_message))
		ELSE 'No error message available'
	  END AS FailureMessages,
	  MIN(jf.job_failure_time_utc) AS FirstFailureTime,
	  MAX(jf.job_failure_time_utc) AS LastFailureTime,
	  MIN(jf.job_start_time_utc) AS JobStartTime,
	  MAX(jf.job_failure_step_number) AS JobFailureStepNumber -- Get the step number
	FROM 
	  [DBADB].[dbo].[sql_server_agent_job] j
	JOIN 
	  [DBADB].[dbo].[sql_server_agent_job_failure] jf ON j.sql_server_agent_job_id = jf.sql_server_agent_job_id
	JOIN 
	  ScheduleCTE sc ON j.sql_server_agent_job_id = sc.sql_server_agent_job_id
	WHERE 
	  jf.has_email_been_sent_to_operator = 0 
	  AND (ticket_status IS NULL OR ticket_status <> 'Open') 

	GROUP BY 
	  j.sql_server_agent_job_id, j.sql_server_agent_job_name, jf.job_failure_step_name, sc.Schedule , jf.job_failure_message,jf.job_step_failure_message;

	-- Prepare email content
	DECLARE @subject NVARCHAR(255),
		@body NVARCHAR(MAX),
		@JobId NVARCHAR(255),
		@JobName NVARCHAR(255),
		@StepName NVARCHAR(255),
		@Schedule NVARCHAR(255),
		@FailureCount INT,
		@FailureTimes NVARCHAR(MAX),
		@FailureMessages NVARCHAR(MAX),
		@FirstFailureTime DATETIME,
		@LastFailureTime DATETIME,
		@JobStartTime DATETIME,
		@JobFailureStepNumber INT;

	DECLARE EmailCursor CURSOR FOR 
	SELECT JobId, JobName, StepName, Schedule, FailureCount, FailureTimes, FailureMessages, FirstFailureTime, LastFailureTime, JobStartTime, JobFailureStepNumber
	FROM @EmailData;

	OPEN EmailCursor;
	FETCH NEXT FROM EmailCursor INTO 
	  @JobId, @JobName, @StepName, @Schedule, @FailureCount, @FailureTimes, @FailureMessages, @FirstFailureTime, @LastFailureTime, @JobStartTime, @JobFailureStepNumber;

	WHILE @@FETCH_STATUS = 0
	BEGIN
	  ---- Check if job failure occurred without step failure (step number = 0)
	  --IF @JobFailureStepNumber = 0
	  --BEGIN
	  --  SET @StepName = NULL;
	  --END

	  -- Set email subject
	  SET @subject = 'Retailscan' + @server_name + ' ' + @JobName + ' Failed Alert -> Open';

	  -- Prepare email body based on the number of failures
	  IF @FailureCount > 1
	  BEGIN
		-- Multiple failures HTML format
		SET @body = 
		  '<html>
		  <head>
			 <style>
		body {
		  font-family: Arial, sans-serif;
		  background-color: #ffffff;
		  color: #333;
		}
		h2 {
		  color: #d9534f;
		  text-align: center;
		}
		table {
		  width: 100%;
		  border-collapse: collapse;
		  margin: 20px 0;
		  background-color: #ffffff;
		  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
		}
		th, td {
		  padding: 12px;
		  border: 1px solid #ddd;
		  text-align: left;
		}
		th {
		  background-color: #343a40;
		  color: #ffffff;
		}
		tr:nth-child(even) {
		  background-color: #f9f9f9;
		}
		tr:hover {
		  background-color: #f1f1f1;
		}
		p {
		  text-align: center;
		  margin-top: 20px;
		  font-weight: bold;
		}
	  </style>
		  </head>
		  <body>
			<h2>Job Failure Alert </h2>
			<table>
			  <tr><th>Job Name</th><td>' + @JobName + '</td></tr>
			  <tr><th>Step Name</th><td>' + ISNULL(@StepName, 'Job Failure - No Step Failure') + '</td></tr>
			  <tr><th>Error Messages</th><td>' + ISNULL(@FailureMessages, 'N/A') + '</td></tr>
			  <tr><th>Failure Count</th><td>' + CAST(@FailureCount AS NVARCHAR) + '</td></tr>
			  <tr><th>First Start Time</th><td>' + CONVERT(NVARCHAR, @JobStartTime, 120) + '</td></tr>
			  <tr><th>First Failure Time</th><td>' + CONVERT(NVARCHAR, @FirstFailureTime, 120) + '</td></tr>
			  <tr><th>Last Failure Time</th><td>' + CONVERT(NVARCHAR, @LastFailureTime, 120) + '</td></tr>
			  <tr><th>Schedule</th><td>' + @Schedule + '</td></tr>
			</table>
		  </body>
		  </html>';
	  END
	  ELSE
	  BEGIN
		-- Single failure HTML format
		SET @body = 
		  '<html>
		  <head>
			 <style>
		body {
		  font-family: Arial, sans-serif;
		  background-color: #ffffff;
		  color: #333;
		}
		h2 {
		  color: #d9534f;
		  text-align: center;
		}
		table {
		  width: 100%;
		  border-collapse: collapse;
		  margin: 20px 0;
		  background-color: #ffffff;
		  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
		}
		th, td {
		  padding: 12px;
		  border: 1px solid #ddd;
		  text-align: left;
		}
		th {
		  background-color: #343a40;
		  color: #ffffff;
		}
		tr:nth-child(even) {
		  background-color: #f9f9f9;
		}
		tr:hover {
		  background-color: #f1f1f1;
		}
		p {
		  text-align: center;
		  margin-top: 20px;
		  font-weight: bold;
		}
	  </style>
		  </head>
		  <body>
			<h2>Job Failure Alert </h2>
			<table>
			  <tr><th>Job Name</th><td>' + @JobName + '</td></tr>
			  <tr><th>Step Name</th><td>' + ISNULL(@StepName, 'Job Failure - No Step Failure') + '</td></tr>
			  <tr><th>Error Message</th><td>' + ISNULL(@FailureMessages, 'N/A') + '</td></tr>
			  <tr><th>Job Start Time</th><td>' + CONVERT(NVARCHAR, @JobStartTime, 120) + '</td></tr>
			  <tr><th>Failure Time</th><td>' + CONVERT(NVARCHAR, @LastFailureTime, 120) + '</td></tr>
			  <tr><th>Schedule</th><td>' + @Schedule + '</td></tr>
			</table>
		  </body>
		  </html>';
	  END

	  -- Send the email
	  EXEC msdb.dbo.sp_send_dbmail
			@profile_name = 'DBA', -- Change
			@recipients = 'mssqlalerts@geopits.com', -- --Changemssqlsupport@geopits.com
			@subject = @subject,
			@body = @body,
			@body_format = 'HTML';

	  -- Update the failure record
	  UPDATE [DBADB].[dbo].[sql_server_agent_job_failure]
	  SET 
		has_email_been_sent_to_operator = 1,
		ticket_status = 'Open'
	  WHERE sql_server_agent_job_id = @JobId AND has_email_been_sent_to_operator = 0;

	  FETCH NEXT FROM EmailCursor INTO 
		@JobId, @JobName, @StepName, @Schedule, @FailureCount, @FailureTimes, @FailureMessages, @FirstFailureTime, @LastFailureTime, @JobStartTime, @JobFailureStepNumber;
	END

	CLOSE EmailCursor;
	DEALLOCATE EmailCursor;

	SET NOCOUNT OFF;
	GO