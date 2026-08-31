SELECT  
    fk.name AS ForeignKeyName,
    parent_tab.name AS ParentTable,
    ref_tab.name AS ReferencedTable,
    parent_col.name AS ParentColumn,
    ref_col.name AS ReferencedColumn
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc 
    ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.tables parent_tab 
    ON fkc.parent_object_id = parent_tab.object_id
INNER JOIN sys.tables ref_tab 
    ON fkc.referenced_object_id = ref_tab.object_id
INNER JOIN sys.columns parent_col 
    ON fkc.parent_object_id = parent_col.object_id 
    AND fkc.parent_column_id = parent_col.column_id
INNER JOIN sys.columns ref_col 
    ON fkc.referenced_object_id = ref_col.object_id 
    AND fkc.referenced_column_id = ref_col.column_id
ORDER BY fk.name;
