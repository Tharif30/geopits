--Verify Masked Columns
SELECT c.name AS column_name, t.name AS table_name, c.is_masked, c.masking_function
FROM sys.masked_columns AS c
JOIN sys.tables AS t ON c.object_id = t.object_id
WHERE is_masked = 1;


--alter the existing columns on a table
ALTER TABLE Employee2
ALTER COLUMN Email ADD MASKED WITH (FUNCTION = 'email()');


-- Grant unmask permission
GRANT UNMASK TO ManagerUser;

-- Revoke unmask permission
REVOKE UNMASK FROM ManagerUser;