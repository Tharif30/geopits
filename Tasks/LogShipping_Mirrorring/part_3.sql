ALTER DATABASE db_backup SET READ_WRITE;

SELECT name, is_read_only FROM sys.databases WHERE name = 'db_backup';

SELECT name, state_desc FROM sys.master_files WHERE database_id = DB_ID('db_backup');

create database mirror

use mirror

SELECT name, state_desc, is_read_only 
FROM sys.databases 
WHERE name = 'mirror';

create table table1(test1 int identity,test int );

insert into table1 
select test from table1



SELECT name, protocol_desc, type_desc, state_desc, port FROM sys.tcp_endpoints;
