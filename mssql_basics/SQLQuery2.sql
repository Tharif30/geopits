USE TEST;

create table table_1(
col_1 int primary key ,
col_2 int ,
);

create table table_2(
 col1 int primary key,
 col2 int ,
 foreign key (col2) references table_1(col_1),
);

alter table table_1
add col3 int unique,
	col4 decimal(3,2),
	col5 SMALLMoney
	 ;

ALTER TABLE TABLE_1
add constraint check_COL check(table_1.col5>14);

alter table table_1
drop constraint check_col;

alter table table_1
alter column col4 int ;

SELECT CONSTRAINT_NAME,
     TABLE_SCHEMA ,
     TABLE_NAME,
     CONSTRAINT_TYPE
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
   WHERE TABLE_NAME='table_2';

alter table table_2 
add col_3 varchar(14),
    col4 int,
	col5 int default 20;

insert into table_1 values(14,90,17,19,15);

select * from table_1;

insert into table_2(col1,col2,col_3,col4) values(12,12,'17',19);