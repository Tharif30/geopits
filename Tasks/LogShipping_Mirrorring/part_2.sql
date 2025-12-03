
use geo


select count(*) from table1; 

select * from sys.tables

SELECT name, protocol_desc, type_desc, state_desc, port FROM sys.tcp_endpoints;

ALTER DATABASE mirror SET PARTNER OFF;

restore database mirror with recovery

SELECT @@SERVERNAME, SERVERPROPERTY('InstanceName');
ALTER DATABASE mirror SET PARTNER = 'TCP://localhost:5022';

SELECT local_net_address, local_tcp_port 
FROM sys.dm_exec_connections 
WHERE local_net_address IS NOT NULL;

SELECT servicename, service_account 
FROM sys.dm_server_services;

GRANT CONNECT ON ENDPOINT::Mirroring TO [NT Service\MSSQL$SECONDARYSERVER];
