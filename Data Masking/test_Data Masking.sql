CREATE DATABASE TestDB
GO
 
USE TestDB
GO
 
CREATE TABLE Employee
(  
   ID INT IDENTITY (1,1) NOT NULL PRIMARY KEY CLUSTERED,
   FirstName VARCHAR(50),
   LastName VARCHAR(50),
   Email VARCHAR(100) MASKED WITH (FUNCTION = 'email()') NULL,
   WorkPhoneNumber VARCHAR(50) MASKED WITH (FUNCTION = 'partial(1,"XXXXXXX",0)'),
   ServicePeriodInYears INT MASKED WITH (FUNCTION = 'random(100, 300)'),
   BirthDate DATE MASKED WITH (FUNCTION = 'datetime("Y")') NULL,
   Salary MONEY MASKED WITH (FUNCTION = 'default()')
)
GO
 
-- Insert random data into the Employee table
INSERT INTO Employee (FirstName, LastName, Email, WorkPhoneNumber, ServicePeriodInYears, BirthDate, Salary)
VALUES
    ('John', 'Doe', 'john.doe@mytestcompany.com', '1234567', 5, '1990-05-15', 55000.00),
    ('Jane', 'Smith', 'jane.smith@mytestcompany.com', '7654321', 8, '1985-11-22', 65000.00),
    ('Michael', 'Johnson', 'michael.johnson@mytestcompany.com', '2345678', 3, '1995-07-10', 48000.00),
    ('Aram', 'Melikyan', 'aram.melikyan@mytestcompany.com', '8765432', 6, '1993-02-18', 60000.00),
    ('Sos', 'Sargsyan', 'sos.sargsyan@mytestcompany.com', '3456789', 10, '1980-08-30', 75000.00),
    ('Ann', 'Petrosyan', 'a.petrosyan@mytestcompany.com', '1234567', 5, '1990-05-15', 55000.00);
 
GO

SELECT * FROM Employee

--CREATE USER TestUser WITHOUT LOGIN
 
--GRANT SELECT ON Employee TO TestUser

--EXECUTE AS USER = 'TestUser'
 
--SELECT *
--FROM Employee
 
--REVERT

CREATE TABLE Employee2
(  
   ID INT IDENTITY (1,1) NOT NULL PRIMARY KEY CLUSTERED,
   FirstName VARCHAR(50),
   LastName VARCHAR(50),
   Email VARCHAR(100)  NULL,
   WorkPhoneNumber VARCHAR(50),
   ServicePeriodInYears INT ,
   BirthDate DATE  NULL,
   Salary MONEY 
)
GO

INSERT INTO Employee2 (FirstName, LastName, Email, WorkPhoneNumber, ServicePeriodInYears, BirthDate, Salary)
VALUES
    ('John', 'Doe', 'john.doe@mytestcompany.com', '1234567', 5, '1990-05-15', 55000.00),
    ('Jane', 'Smith', 'jane.smith@mytestcompany.com', '7654321', 8, '1985-11-22', 65000.00),
    ('Michael', 'Johnson', 'michael.johnson@mytestcompany.com', '2345678', 3, '1995-07-10', 48000.00),
    ('Aram', 'Melikyan', 'aram.melikyan@mytestcompany.com', '8765432', 6, '1993-02-18', 60000.00),
    ('Sos', 'Sargsyan', 'sos.sargsyan@mytestcompany.com', '3456789', 10, '1980-08-30', 75000.00),
    ('Ann', 'Petrosyan', 'a.petrosyan@mytestcompany.com', '1234567', 5, '1990-05-15', 55000.00);
 
GO

Select * from Employee2

ALTER TABLE Employee2
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');

ALTER TABLE Employee2
ALTER COLUMN WorkPhoneNumber ADD MASKED WITH (FUNCTION = 'partial(1,"XXXXXXX",0)')

 
SELECT * FROM Employee2
 
CREATE Login TestUser with password='Test123'
CREATE USER TestUser for login TestUser

GRANT SELECT ON Employee2 TO TestUser
GRANT SELECT ON Employee TO TestUser

use testdb

select * from employee2

-- Grant unmask permission
GRANT UNMASK TO TestUser;

-- Revoke unmask permission
REVOKE UNMASK FROM TestUser;