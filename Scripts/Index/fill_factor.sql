SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.fill_factor,
    i.is_disabled,
    i.is_padded
FROM
    sys.indexes i
WHERE
    i.type IN (1, 2) -- 1 = Clustered, 2 = Non-Clustered
    AND i.object_id > 100
   AND i.fill_factor > 89
ORDER BY
    SchemaName, TableName, IndexName;
