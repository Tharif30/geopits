--row count
SELECT 
    'transaction' AS table_name,
    COUNT_BIG(*) AS row_count
FROM dbo.[transaction]

UNION ALL

SELECT 
    'transaction_details',
    COUNT_BIG(*)
FROM dbo.transaction_details;

--date range
SELECT
    'transaction' AS table_name,
    MIN(transaction_date) AS min_date,
    MAX(transaction_date) AS max_date,
    COUNT_BIG(*) AS row_count
FROM dbo.[transaction]

UNION ALL

SELECT
    'transaction_details',
    MIN(transaction_date),
    MAX(transaction_date),
    COUNT_BIG(*)
FROM dbo.transaction_details;


--data distribution
SELECT
    YEAR(transaction_date) AS transaction_year,
    COUNT_BIG(*) AS row_count,
    SUM(transaction_amount) AS total_amount
FROM dbo.[transaction]
GROUP BY YEAR(transaction_date)
ORDER BY transaction_year;

SELECT
    YEAR(transaction_date) AS transaction_year,
    COUNT_BIG(*) AS row_count,
    SUM(total_amount) AS total_amount,
    SUM(quantity) AS total_quantity
FROM dbo.transaction_details
GROUP BY YEAR(transaction_date)
ORDER BY transaction_year;

--index
SELECT
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,
    i.is_unique,
    i.is_primary_key,
    i.is_disabled
FROM sys.indexes i
WHERE i.object_id IN
(
    OBJECT_ID('dbo.transaction'),
    OBJECT_ID('dbo.transaction_details')
)
ORDER BY table_name, index_id;


--
EXEC sp_helpindex 'dbo.transaction';
EXEC sp_helpindex 'dbo.transaction_details';

--primary_key
SELECT
    t.name AS table_name,
    i.name AS primary_key_name,
    c.name AS column_name
FROM sys.tables t
JOIN sys.indexes i
    ON t.object_id = i.object_id
JOIN sys.index_columns ic
    ON i.object_id = ic.object_id
   AND i.index_id = ic.index_id
JOIN sys.columns c
    ON ic.object_id = c.object_id
   AND ic.column_id = c.column_id
WHERE
    t.name IN ('transaction', 'transaction_details')
    AND i.is_primary_key = 1
ORDER BY
    t.name,
    ic.key_ordinal;


    --foreign key
    SELECT
    fk.name AS foreign_key_name,
    OBJECT_NAME(fk.parent_object_id) AS child_table,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS child_column,
    OBJECT_NAME(fk.referenced_object_id) AS parent_table,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS parent_column
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc
    ON fk.object_id = fkc.constraint_object_id
WHERE
    fk.parent_object_id IN
    (
        OBJECT_ID('dbo.transaction'),
        OBJECT_ID('dbo.transaction_details')
    );


--size
EXEC sp_spaceused 'dbo.transaction';
EXEC sp_spaceused 'dbo.transaction_details';



--index with key order
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS schema_name,
    OBJECT_NAME(i.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,

    STRING_AGG(
        CASE
            WHEN ic.is_included_column = 0
            THEN QUOTENAME(c.name)
                 + CASE
                       WHEN ic.is_descending_key = 1
                       THEN ' DESC'
                       ELSE ' ASC'
                   END
        END,
        ', '
    ) WITHIN GROUP (ORDER BY ic.key_ordinal) AS key_columns,

    STRING_AGG(
        CASE
            WHEN ic.is_included_column = 1
            THEN QUOTENAME(c.name)
        END,
        ', '
    ) AS include_columns

FROM sys.indexes AS i
JOIN sys.index_columns AS ic
    ON  i.object_id = ic.object_id
    AND i.index_id  = ic.index_id
JOIN sys.columns AS c
    ON  ic.object_id = c.object_id
    AND ic.column_id = c.column_id

WHERE i.object_id IN
(
    OBJECT_ID('dbo.[transaction]'),
    OBJECT_ID('dbo.transaction_details')
)
AND i.index_id > 0

GROUP BY
    i.object_id,
    i.name,
    i.type_desc

ORDER BY
    table_name,
    index_name;



