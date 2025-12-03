USE [DBADB]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DBAUnusedIndexReport]
    @subjectcontent NVARCHAR(512),
    @ServerName NVARCHAR(512),
    @Recipient NVARCHAR(MAX),
    @DBProfile NVARCHAR(512)
AS
BEGIN
    BEGIN TRY
        IF 1 = (SELECT COUNT(*) FROM sys.dm_os_sys_info WHERE DATEDIFF(day, sqlserver_start_time, GETDATE()) > 7)
        BEGIN
            -- Create a table in DBADB to store the results if it doesn't exist
            IF NOT EXISTS (SELECT * FROM DBADB.sys.tables WHERE name = 'UnusedIndexes')
            BEGIN
                EXEC('
                CREATE TABLE DBADB.dbo.UnusedIndexes (
                    DatabaseName NVARCHAR(128),
                    ObjectName NVARCHAR(128),
                    IndexName NVARCHAR(128),
                    IndexID INT,
                    UserSeek BIGINT,
                    UserScans BIGINT,
                    UserLookups BIGINT,
                    UserUpdates BIGINT,
                    TableRows BIGINT,
                    DropStatement NVARCHAR(MAX),
                    Logdate DATETIME DEFAULT GETDATE()
                )');
            END

            -- Create a temporary table to store the results
            CREATE TABLE #UnusedIndexes (
                DatabaseName NVARCHAR(128),
                ObjectName NVARCHAR(128),
                IndexName NVARCHAR(128),
                IndexID INT,
                UserSeek BIGINT,
                UserScans BIGINT,
                UserLookups BIGINT,
                UserUpdates BIGINT,
                TableRows BIGINT,
                DropStatement NVARCHAR(MAX)
            );

            -- Collect unused indexes from all user databases
            DECLARE @sql NVARCHAR(MAX);
            SET @sql = N'
            DECLARE @dbName NVARCHAR(128);
            DECLARE dbCursor CURSOR FOR
            SELECT name FROM sys.databases WHERE database_id > 4 AND database_id <> DB_ID(''DBADB''); -- Exclude system databases

            OPEN dbCursor;
            FETCH NEXT FROM dbCursor INTO @dbName;

            WHILE @@FETCH_STATUS = 0
            BEGIN
                DECLARE @dynamicSQL NVARCHAR(MAX) = N''
                USE '' + QUOTENAME(@dbName) + N'';
                INSERT INTO #UnusedIndexes
                SELECT
                    @dbName AS DatabaseName,
                    o.name AS ObjectName,
                    i.name AS IndexName,
                    i.index_id AS IndexID,
                    dm_ius.user_seeks AS UserSeek,
                    dm_ius.user_scans AS UserScans,
                    dm_ius.user_lookups AS UserLookups,
                    dm_ius.user_updates AS UserUpdates,
                    p.TableRows,
                    ''''DROP INDEX '''' + QUOTENAME(i.name) + '''' ON '''' + QUOTENAME(s.name) + ''''.'''' + QUOTENAME(OBJECT_NAME(dm_ius.OBJECT_ID)) AS DropStatement
                FROM sys.dm_db_index_usage_stats dm_ius
                INNER JOIN sys.indexes i ON i.index_id = dm_ius.index_id AND dm_ius.OBJECT_ID = i.OBJECT_ID
                INNER JOIN sys.objects o ON dm_ius.OBJECT_ID = o.OBJECT_ID
                INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
                INNER JOIN (SELECT SUM(p.rows) TableRows, p.index_id, p.OBJECT_ID
                            FROM sys.partitions p GROUP BY p.index_id, p.OBJECT_ID) p
                ON p.index_id = dm_ius.index_id AND dm_ius.OBJECT_ID = p.OBJECT_ID
                WHERE OBJECTPROPERTY(dm_ius.OBJECT_ID, ''''IsUserTable'''') = 1
                AND i.type_desc = ''''nonclustered''''
                AND i.is_primary_key = 0
                AND i.is_unique_constraint = 0
                AND (dm_ius.user_seeks + dm_ius.user_scans + dm_ius.user_lookups) = 0;
                '';

                EXEC sp_executesql @dynamicSQL, N''@dbName NVARCHAR(128)'', @dbName;

                FETCH NEXT FROM dbCursor INTO @dbName;
            END

            CLOSE dbCursor;
            DEALLOCATE dbCursor;
            ';

            EXEC sp_executesql @sql;

            -- Insert the results into the DBADB.UnusedIndexes table
            INSERT INTO DBADB.dbo.UnusedIndexes ([DatabaseName]
              ,[ObjectName]
              ,[IndexName]
              ,[IndexID]
              ,[UserSeek]
              ,[UserScans]
              ,[UserLookups]
              ,[UserUpdates]
              ,[TableRows]
              ,[DropStatement])
            SELECT * FROM #UnusedIndexes;

            -- Compare with previous data and delete old data
            DELETE FROM DBADB.dbo.UnusedIndexes
            WHERE Logdate < DATEADD(day, -90, GETDATE());

            -- Get the total number of unused indexes
            DECLARE @TotalUnusedIndexes INT;
            SELECT @TotalUnusedIndexes = COUNT(*) FROM DBADB.dbo.UnusedIndexes WHERE DATEDIFF(MINUTE, logdate, GETDATE()) < 1;

            -- Get the unused index counts for yesterday and a week before
            DECLARE @YesterdayUnusedIndexes TABLE (DatabaseName NVARCHAR(128), UnusedIndexCount INT);
            DECLARE @WeekBeforeUnusedIndexes TABLE (DatabaseName NVARCHAR(128), UnusedIndexCount INT);

            INSERT INTO @YesterdayUnusedIndexes
            SELECT DatabaseName, COUNT(*) AS UnusedIndexCount
            FROM DBADB.dbo.UnusedIndexes
            WHERE cast(Logdate as date) >=  cast(DATEADD(day, -1, GETDATE()) as date) AND Logdate < cast(GETDATE() as date)
            GROUP BY DatabaseName;

            INSERT INTO @WeekBeforeUnusedIndexes
            SELECT DatabaseName, COUNT(*) AS UnusedIndexCount
            FROM DBADB.dbo.UnusedIndexes
            WHERE cast(Logdate as date) >=  cast(DATEADD(day, -7, GETDATE()) as date) AND Logdate < cast(GETDATE()-6 as date)
            GROUP BY DatabaseName;

            -- Drop the temporary table
            DROP TABLE #UnusedIndexes;

            -- Send email report
			 DECLARE @sqlserver_start_time1 DATETIME;
            SELECT @sqlserver_start_time1 = sqlserver_start_time FROM sys.dm_os_sys_info;
            DECLARE @EmailBody NVARCHAR(MAX);
            SET @EmailBody = '
<html>
<head>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: #333;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 10px;
            border: 1px solid #ddd;
            text-align: left;
        }
        th {
            background-color: #800000; /* Change this color as needed */
            color: white;
        }
        a {
            color: #1a73e8;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .note {
            font-size: 0.9em;
            color: #555;
        }
    </style>
</head>
<body>
    <p>Hi Team,</p>
    <p>We have identified total <strong>' + CAST(@TotalUnusedIndexes AS NVARCHAR(10)) + '</strong> unused indexes on the  <strong>' + @ServerName + '</strong> server.</p>
	<p>The ' + @ServerName + ' SQL Server start time is : <strong>' + CAST(@sqlserver_start_time1 AS NVARCHAR(30)) + '</strong>.</p>
    <p>Unused Index Details:</p>
	<table>
        <thead>
            <tr>
                <th>Database Name</th>
                <th>Number of Unused Indexes Today</th>
                <th>Unused Indexes Yesterday</th>
                <th>Unused Indexes a Week Ago</th>
            </tr>
			</thead>
        <tbody>' +
        (SELECT TOP 15
            '<tr>' +
            '<td>' + ISNULL(ui.DatabaseName, '') + '</td>' +
            '<td>' + CAST(ISNULL(COUNT(*), 0) AS NVARCHAR) + '</td>' +
            '<td>' + CAST(ISNULL(yi.UnusedIndexCount, 0) AS NVARCHAR) + '</td>' +
            '<td>' + CAST(ISNULL(wi.UnusedIndexCount, 0) AS NVARCHAR) + '</td>' +
            '</tr>'
        FROM [DBADB].[dbo].[UnusedIndexes] ui
        LEFT JOIN @YesterdayUnusedIndexes yi ON ui.DatabaseName = yi.DatabaseName
        LEFT JOIN @WeekBeforeUnusedIndexes wi ON ui.DatabaseName = wi.DatabaseName
        WHERE DATEDIFF(MINUTE, ui.logdate, GETDATE()) < 1
        GROUP BY ui.DatabaseName, yi.UnusedIndexCount, wi.UnusedIndexCount
        ORDER BY COUNT(*) DESC
        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)') +
        '</tbody>
    </table>
    <p>If you would like us to review these unused indexes, please send an email to <a href="mailto:teammailid">Team mail ID</a>.</p>
    <p>We will analyze the indexes and provide you with our recommendations.</p>
    <p class="note"><strong>Note:</strong> If the database participates in High Availability and Disaster Recovery (HADR), we need to cross-check with other replicas before making any changes to unused indexes.</p>
    <p>Thank you,<br>Best Regards,<br>MSSQL DBA,<br>Team</br></p>
</body>
</html>';--Change Team and MailID

            -- Send email notification
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @DBProfile,
                @recipients = @Recipient,
                @subject = @subjectcontent,
                @body = @EmailBody,
                @body_format = 'HTML';
        END
        ELSE
        BEGIN
            DECLARE @sqlserver_start_time DATETIME;
            SELECT @sqlserver_start_time = sqlserver_start_time FROM sys.dm_os_sys_info;

            -- Send email notification
            DECLARE @EmailBody1 NVARCHAR(MAX);
            SET @EmailBody1 = '
<html>
<body>
    <p>Hi Team,</p>
    <p>The ' + @ServerName + ' SQL Server start time is less than 7 days: <strong>' + CAST(@sqlserver_start_time AS NVARCHAR(30)) + '</strong>.</p>
    <p>As a result, the unused index details may not be accurate. We recommend waiting until <strong>' + CAST(DATEADD(DAY, 7, @sqlserver_start_time) AS NVARCHAR(30)) + '</strong> for more reliable data.</p>
    <p>Thank you,<br>Best Regards,<br>MSSQL DBA,<br>Team<br></p>
</body>
</html>';--Change Team

            -- Send email notification

			
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = @DBProfile,
                @recipients = @Recipient,
                @subject = @subjectcontent,
                @body = @EmailBody1,
                @body_format = 'HTML';
        END
    END TRY
    BEGIN CATCH
        -- Error handling
        DECLARE @ErrorMessage NVARCHAR(4000);
        DECLARE @ErrorSeverity INT;
        DECLARE @ErrorState INT;

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END;
