WITH FirstSPID AS (
    SELECT 
        [InstanceName],
        [StartTime],
        [ElapsedTime],
        [SPID],
        [UserName],
        [ProgramName],
        [DatabaseName],
        [WaitType],
        [StatementText],
        [StoredProcedure],
        [is_closed],
        [logdate],
        [ExecutingSQL],
        ROW_NUMBER() OVER (PARTITION BY SPID ORDER BY StartTime ASC) AS rn
    FROM [DBADB].[dbo].[longqrydetails]
    WHERE starttime >= '2025-07-08 05:00:03.643'
      AND StatementText LIKE '%insert into #tempTable%'
)
SELECT TOP (1000) *
FROM FirstSPID
WHERE rn = 1
ORDER BY StartTime DESC;
