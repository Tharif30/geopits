DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql += 
    'ALTER INDEX [' + i.name + '] ON [' + s.name + '].[' + o.name + '] ' +
    'REBUILD WITH (FILLFACTOR = 90);' + CHAR(13)
FROM 
    sys.indexes i
JOIN 
    sys.objects o ON i.object_id = o.object_id
JOIN 
    sys.schemas s ON o.schema_id = s.schema_id
WHERE 
    i.type IN (1, 2) -- clustered and nonclustered indexes
    AND i.is_disabled = 0
    AND o.type = 'U'; -- user tables only

-- Review the script first (optional)
PRINT @sql;

-- Execute the rebuilds
EXEC sp_executesql @sql;