--Constraints
USE University ;

SELECT * FROM INFORMATION_SCHEMA.TABLES;

EXEC sp_columns Marks;

ALTER TABLE STUDENT 
ADD CONSTRAINT UNIQUEID UNIQUE(Student_ID);

ALTER TABLE STUDENT
ALTER COLUMN Student_ID INT NOT NULL ; 

SELECT CONSTRAINT_NAME,
     TABLE_SCHEMA ,
     TABLE_NAME,
     CONSTRAINT_TYPE
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
   WHERE TABLE_NAME='Student';

EXEC sp_rename 'Marks.Marks','Cum_marks','Column';

ALTER TABLE MARKS 
ADD SEM_1 TINYINT NOT NULL CHECK (Sem_1>0) ;

ALTER TABLE MARKS
ADD SEM_2 TINYINT NOT NULL CHECK(SEM_2>0) ;

ALTER TABLE MARKS 
ADD SEM_3 TINYINT NOT NULL CHECK(SEM_3>0);

INSERT INTO STUDENT VALUES(12345,'CSE');
INSERT INTO STUDENT(Student_ID,DEPT_ID) 
	VALUES
		(12346,'CSE'),
		(12347,'CSE'),
		(12348,'CSE'),
		(12349,'CSE'),
		(12350,'CSE'),
		(12351,'CSE');

insert into Student values(1233433,'CSE')

SELECT * FROM Student;

update Student set Dept_ID ='a' 
where Dept_ID='CSE';

insert into Dept (Dept_ID,Dept_name)  
values ('a','CSE');

insert into Dept (Dept_ID,Dept_name)
values('b','DS');

insert into Dept (Dept_id,Dept_name)
values('c','AIML')

SELECT * FROM Staff;


