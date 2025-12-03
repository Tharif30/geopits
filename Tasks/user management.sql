use master;

create login developer with password ='1234';

use temp_database;

select * from sys.tables

create user developer for Login developer;

create role select_permission

--task 1: Giving only the read access for a database
Grant Select on temp to select_permission;

alter role db_datareader drop member de;


create role reader;

grant select on temp to reader

alter role reader add member de

drop user dev