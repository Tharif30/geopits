Create Database University;

use University;

Create table Student (
	Student_ID INT PRIMARY KEY,
	DEPT_ID CHAR(5),
	);
CREATE TABLE Dept (
    Dept_ID CHAR(5) PRIMARY KEY,       
    Dept_Name VARCHAR(25),             
);

CREATE TABLE Student_Details (
    Student_ID INT PRIMARY KEY,      
    Student_Name VARCHAR(50),          
    DOB DATE,                          
    FOREIGN KEY (Student_ID) REFERENCES Student(Student_ID)  
);
CREATE TABLE Staff (
    Staff_ID INT PRIMARY KEY,         
    Staff_Name VARCHAR(50),           
    Dept_ID CHAR(5),                  
    Salary SMALLMONEY,                
    FOREIGN KEY (Dept_ID) REFERENCES Dept(Dept_ID)  
);

CREATE TABLE Marks (
    Student_ID INT,                    
    Marks INT,                          
    PRIMARY KEY (Student_ID),           
    FOREIGN KEY (Student_ID) REFERENCES Student(Student_ID)  
);

SELECT * FROM INFORMATION_SCHEMA.TABLES;

