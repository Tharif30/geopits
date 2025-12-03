
use geo

select * from Sys.tables

create table table_2(test1 int identity,test int );

insert into table_2 
select test from table_2

select count(*) from table_2; 

CREATE ENDPOINT MirroringEndpoint
STATE = STARTED
AS TCP (LISTENER_PORT = 5022)
FOR DATABASE_MIRRORING (ROLE = PARTNER);

SELECT @@SERVERNAME, SERVERPROPERTY('InstanceName');

SELECT name, state_desc, protocol_desc, local_net_address, port 
FROM sys.dm_exec_connections 
WHERE local_net_address IS NOT NULL;

ALTER DATABASE mirror SET PARTNER = 'TCP://localhost:5023';
ALTER DATABASE mirror SET PARTNER = 'TCP://localhost:5023';

 drop database mirror
ALTER DATABASE mirror SET PARTNER off;

SELECT name, state_desc, port 
FROM sys.tcp_endpoints 
WHERE type_desc = 'DATABASE_MIRRORING';

SELECT local_net_address, local_tcp_port 
FROM sys.dm_exec_connections 
WHERE local_net_address IS NOT NULL;


SELECT servicename, service_account 
FROM sys.dm_server_services;

GRANT CONNECT ON ENDPOINT::Mirroring TO [NT Service\MSSQLSERVER];


use mirror

create table table_test(value int identity,test int);

insert into table_test 
select test from table_test

