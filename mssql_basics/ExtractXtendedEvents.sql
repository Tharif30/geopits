/**
<event name="logout" package="sqlserver" timestamp="2025-02-23T09:26:32.827Z">
<data name="is_cached"><value>true</value></data>
<data name="is_recovered"><value>false</value></data>
<data name="is_dac"><value>false</value></data>
<data name="duration"><value>77890000</value></data>
<data name="cpu_time"><value>2687000</value></data>
<data name="page_server_reads"><value>0</value></data>
<data name="physical_reads"><value>1650</value></data>
<data name="logical_reads"><value>90289</value></data>
<data name="writes"><value>1051</value></data>
<action name="username" package="sqlserver"><value>user1</value></action>
<action name="session_id" package="sqlserver"><value>53</value></action>
</event>

<event name="login" package="sqlserver" timestamp="2025-02-23T09:26:32.827Z">
  <data name="is_cached">
    <value>true</value>
  </data>
  <data name="is_recovered">
    <value>false</value>
  </data>
  <data name="is_dac">
    <value>false</value>
  </data>
  <data name="database_id">
    <value>1</value>
  </data>
  <data name="packet_size">
    <value>4096</value>
  </data>
  <data name="options">
    <value>2000002838f4010000000000</value>
  </data>
  <data name="options_text">
    <value />
  </data>
  <data name="database_name">
    <value>master</value>
  </data>
  <action name="username" package="sqlserver">
    <value>user1</value>
  </action>
  <action name="session_id" package="sqlserver">
    <value>53</value>
  </action>
</event>
**/


CREATE TABLE UserSessionLog (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    Username NVARCHAR(255),
    SessionID INT,
    EventTime DATETIME,
    EventType NVARCHAR(100)
);


WITH EventData AS (
    SELECT 
        event_data = CAST(event_data AS XML)
    FROM sys.fn_xe_file_target_read_file('C:\Users\Public\login_0_133847763861490000.xel', NULL, NULL, NULL)
)
INSERT INTO UserSessionLog (Username, SessionID, EventTime, EventType,Duration)
SELECT
    event_data.value('(event/action[@name="username"]/value)[1]', 'NVARCHAR(255)') AS Username,
    event_data.value('(event/action[@name="session_id"]/value)[1]', 'INT') AS SessionID,
    event_data.value('(event/@timestamp)[1]', 'DATETIME') AS EventTime,
    event_data.value('(event/@name)[1]', 'NVARCHAR(100)') AS EventType,
	event_data.value('(event/data[@name="duration"]/value)[1]', 'BIGINT') AS Duration
FROM EventData;

select * from UserSessionLog
ORDER BY EventTime;

ALTER TABLE UserSessionLog
ADD Duration BIGINT;

truncate table usersessionlog
