SELECT
    t.name AS TableName,
    i1.name AS Index1,
    i2.name AS Index2,
    i1cols.index_columns AS Index1Cols,
    i2cols.index_columns AS Index2Cols
FROM sys.indexes i1
JOIN sys.indexes i2
    ON i1.object_id = i2.object_id
   AND i1.index_id < i2.index_id
JOIN sys.tables t
    ON i1.object_id = t.object_id
CROSS APPLY (
    SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
    FROM sys.index_columns ic
    JOIN sys.columns c
        ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE ic.object_id = i1.object_id AND ic.index_id = i1.index_id AND ic.is_included_column = 0
) i1cols(index_columns)
CROSS APPLY (
    SELECT STRING_AGG(c.name, ',') WITHIN GROUP (ORDER BY ic.key_ordinal)
    FROM sys.index_columns ic
    JOIN sys.columns c
        ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE ic.object_id = i2.object_id AND ic.index_id = i2.index_id AND ic.is_included_column = 0
) i2cols(index_columns)
WHERE i1cols.index_columns LIKE i2cols.index_columns + '%'
  OR i2cols.index_columns LIKE i1cols.index_columns + '%'
ORDER BY t.name, i1.name, i2.name;
