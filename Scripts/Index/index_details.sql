--USE YourDatabaseName;
--GO

SELECT 
    t.name AS TableName,
    c.name AS ColumnName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ic.is_included_column
FROM sys.indexes i
JOIN sys.index_columns ic 
    ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c 
    ON ic.object_id = c.object_id AND ic.column_id = c.column_id
JOIN sys.tables t 
    ON i.object_id = t.object_id
WHERE c.name = 'Amount' and t.name ='Transaction_PaymentStatus'
ORDER BY t.name, i.name;


--USE YourDatabaseName;
--GO

SELECT 
    t.name AS TableName,
    c.name AS ColumnName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    ic.is_included_column
FROM sys.indexes i
INNER JOIN sys.index_columns ic 
    ON i.object_id = ic.object_id AND i.index_id = ic.index_id
INNER JOIN sys.columns c 
    ON ic.object_id = c.object_id AND ic.column_id = c.column_id
INNER JOIN sys.tables t 
    ON i.object_id = t.object_id
WHERE t.name = 'Transaction_TransactionData'
  AND c.name = 'Amount'
ORDER BY i.name;


--USE YourDatabaseName;
--GO
SELECT 
    i.name AS IndexName,
    i.type_desc,
    ic.index_column_id,
    c.name AS ColumnName,
    ic.is_included_column,
    ic.is_descending_key
FROM sys.indexes i
JOIN sys.index_columns ic 
    ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c 
    ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.object_id = OBJECT_ID('dbo.Transaction_TransactionData')
  AND c.name = 'createdon'
ORDER BY i.name, ic.index_column_id;
