use AdventureWorksLT2022;


Select * from SalesLT.Customer;

SELECT CONSTRAINT_NAME,
     TABLE_SCHEMA ,
     TABLE_NAME,
     CONSTRAINT_TYPE
     FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
   WHERE TABLE_NAME='Customer';

EXEC sp_help 'SalesLT.Customer';

SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Customer';


select count(customerID),title  from SalesLT.Customer Group by title;
--UNION ALL
--select count(customerID) as Female from SalesLT.Customer Group by title having title= 'Mrs.';

select Top 10 * from SalesLT.Customer;

Select * from SalesLT.customer where MiddleName is null;

Select * from salesLT.customer where lastname ='Gates'

select customerID,firstname,LastName from salesLt.Customer order by LastName asc;

select count(customerID),FirstName from SalesLT.Customer group by firstname;

select count(distinct(firstname)) from SalesLT.Customer;

select * from ErrorLog;
