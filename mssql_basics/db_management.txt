
--Task 1
--creating the database storage and log file in different location

CREATE DATABASE temp_database
ON 
(
    NAME = temp_db_Data,
    FILENAME = 'C:\Users\Public\change_db_location\temp_db.mdf',   -- Data file path
    SIZE = 10MB,                              -- Initial size
    MAXSIZE = 100MB,                          -- Max size
    FILEGROWTH = 5MB                           -- Growth increment
)
LOG ON
(
    NAME = temp_db_Log,
    FILENAME = 'C:\Users\Public\change_db_location\temp_db.ldf',   -- Log file path
    SIZE = 5MB,
    MAXSIZE = 50MB,
    FILEGROWTH = 2MB
);

use temp_database;

create table temp( test int);
select * from temp;

--Task 2 
--change the location of existing database log and data file
SELECT name, physical_name
FROM sys.master_files
WHERE database_id = DB_ID('temp_database');

ALTER DATABASE temp_database SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

--detach the database manually
--manually change the location of the file

CREATE DATABASE temp_database
ON 
( FILENAME = 'C:\Users\Public\change_db_location\change_db_location2\temp_db.mdf' )
LOG ON 
( FILENAME = 'C:\Users\Public\change_db_location\change_db_location2\temp_db.ldf' )
FOR ATTACH;

ALTER DATABASE temp_database SET MULTI_USER;

SELECT name, physical_name
FROM sys.master_files
WHERE database_id = DB_ID('temp_database');

--Task 3
USE temp_database;
select count(*) from temp;
alter table temp add test_3 int;

insert into temp 
select * from temp;
--262144 rows were inserted

--Task 4
--changing into single user
ALTER DATABASE CompanyDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

--changing into multi user
ALTER DATABASE companyDB SET MULTI_USER;

--Task 5
--creating data files on multiple locations 
-- Create a new database with multiple data files
CREATE DATABASE CompanyDB
ON 
-- Primary File (Default Storage)
PRIMARY
(
    NAME = 'CompanyDB_Primary',
    FILENAME = 'C:\Users\Public\change_db_location\CompanyDB_Primary.mdf',
    SIZE = 20MB,
    MAXSIZE = 500MB,
    FILEGROWTH = 10MB
),

-- Finance File Group
FILEGROUP FinanceGroup
(
    NAME = 'CompanyDB_Finance1',
    FILENAME = 'C:\Users\Public\change_db_location\change_db_location2\CompanyDB_Finance1.ndf',
    SIZE = 20MB,
    MAXSIZE = 300MB,
    FILEGROWTH = 5MB
),
(
    NAME = 'CompanyDB_Finance2',
    FILENAME = 'C:\Users\Public\change_db_location\location3\CompanyDB_Finance2.ndf',
    SIZE = 20MB,
    MAXSIZE = 300MB,
    FILEGROWTH = 5MB
),

-- HR File Group
FILEGROUP HRGroup
(
    NAME = 'CompanyDB_HR1',
    FILENAME = 'C:\Users\Public\change_db_location\location4\CompanyDB_HR1.ndf',
    SIZE = 20MB,
    MAXSIZE = 300MB,
    FILEGROWTH = 5MB
),
(
    NAME = 'CompanyDB_HR2',
    FILENAME = 'C:\Users\Public\change_db_location\location5\CompanyDB_HR2.ndf',
    SIZE = 20MB,
    MAXSIZE = 300MB,
    FILEGROWTH = 5MB
)

LOG ON
(
    NAME = 'CompanyDB_Log',
    FILENAME = 'C:\Users\Public\change_db_location\LogFiles\CompanyDB_Log.ldf',
    SIZE = 10MB,
    MAXSIZE = 200MB,
    FILEGROWTH = 5MB
);


--task 6 
--storing the data in different file groups
--such as finance for finance file group and hr for hr finance 
USE CompanyDB;
GO

CREATE TABLE FinanceData
(
    TransactionID INT PRIMARY KEY,
    Amount DECIMAL(18, 2),
    Department NVARCHAR(50)
) ON FinanceGroup;  -- Store in FinanceGroup

CREATE TABLE HRData
(
    EmployeeID INT PRIMARY KEY,
    Name NVARCHAR(100),
    Salary DECIMAL(18, 2),
    Department NVARCHAR(50)
) ON HRGroup;  -- Store in HRGroup










