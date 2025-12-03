--index name and type
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
WHERE i.object_id = OBJECT_ID('dbo.applicationDocuments')
  --AND c.name = 'createdon'
ORDER BY i.name, ic.index_column_id;


--count of index in the table
SELECT 
    t.name AS TableName,
    COUNT(i.index_id) AS TotalIndexes
FROM 
    sys.tables AS t
    INNER JOIN sys.indexes AS i ON t.object_id = i.object_id
WHERE 
    i.type > 0  -- Exclude heap (type 0 = heap, no clustered index)
    AND t.name = 'applicationDocuments'
    AND SCHEMA_NAME(t.schema_id) = 'dbo'
GROUP BY 
    t.name;