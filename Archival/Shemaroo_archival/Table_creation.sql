USE [DBADB]
GO

  Create or alter procedure [Table_creation] 
  as Begin
 DECLARE @SourceTableName NVARCHAR(128) = 'dbo.tbl_user_lifecycle';
 DECLARE @DestinationTableName NVARCHAR(128) =@SourceTableName + '_Archive_' + FORMAT(GETDATE(), 'yyyy');
 DECLARE @SQL NVARCHAR(MAX); DECLARE @sSQL NVARCHAR(MAX);

   -- Drop table if exists
  SET @SQL = 'IF OBJECT_ID(''[dbo].[' + @DestinationTableName + ']'', ''U'') IS NOT NULL DROP TABLE [dbo].[' + @DestinationTableName + '];';
  EXEC sp_executesql @SQL;

  -- Create table dynamically
 SET @SQL = 'CREATE TABLE [dbo].[' + @DestinationTableName + '] (' + CHAR(13) + CHAR(10) +
 (
    SELECT STRING_AGG(
        '[' + c.name + '] ' +
        CASE 
            WHEN t.name IN ('varchar','char','nvarchar','nchar') THEN t.name + '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST( CASE WHEN t.name IN    ('nvarchar','nchar') THEN c.max_length/2 ELSE c.max_length END AS VARCHAR(10)) END + ')'
            WHEN t.name IN ('decimal','numeric') THEN t.name + '(' + CAST(c.precision AS VARCHAR(3)) + ',' + CAST(c.scale AS VARCHAR(3)) + ')'
            ELSE t.name
        END +
        CASE WHEN c.is_nullable = 1 THEN ' NULL' ELSE ' NOT NULL' END
        , ',' + CHAR(13) + CHAR(10)
    )
    FROM sys.columns c
    JOIN sys.types t ON c.user_type_id = t.user_type_id
    WHERE c.object_id = OBJECT_ID('dbo.' +@SourceTableName)
) + CHAR(13) + CHAR(10) + ');';

-- Print for debugging
PRINT @SQL;

BEGIN TRY
    EXEC sp_executesql @SQL;
END TRY
BEGIN CATCH
    DECLARE 
        @ErrMsg NVARCHAR(4000),
        @ErrSeverity INT,
        @ErrState INT;

    SELECT 
        @ErrMsg = ERROR_MESSAGE(),
        @ErrSeverity = ERROR_SEVERITY(),
        @ErrState = ERROR_STATE();

    PRINT 'Error: ' + @ErrMsg;

    RAISERROR (@ErrMsg, @ErrSeverity, @ErrState);
END CATCH;



PRINT 'Destination table [' + @DestinationTableName + '] created successfully.';

END;