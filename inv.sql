SELECT
    COMPANY_ID_PK,
    TRAN_ID,
    FLAG,
    TABLENAME,
    XMLDATA,
    CREATED_BY,
    CREATED_ON,
    TRAIL_ID_PK,
    COUNT(*) AS DuplicateCount
FROM TREDSPRODDB_ARCHIVAL.dbo.FCS_AUDIT_TRAIL_Archival
GROUP BY
    COMPANY_ID_PK,
    TRAN_ID,
    FLAG,
    TABLENAME,
    XMLDATA,
    CREATED_BY,
    CREATED_ON,
    TRAIL_ID_PK
HAVING COUNT(*) > 1
ORDER BY CREATED_ON;

;WITH Duplicates AS
(
    SELECT *,
           RN = ROW_NUMBER() OVER
           (
               PARTITION BY
                   COMPANY_ID_PK,
                   TRAN_ID,
                   FLAG,
                   TABLENAME,
                   XMLDATA,
                   CREATED_BY,
                   CREATED_ON,
                   TRAIL_ID_PK
               ORDER BY (SELECT NULL)
           )
    FROM TREDSPRODDB_ARCHIVAL.dbo.FCS_AUDIT_TRAIL_Archival
)
SELECT *
FROM Duplicates
WHERE RN > 1;


;WITH Duplicates AS
(
    SELECT *,
           RN = ROW_NUMBER() OVER
           (
               PARTITION BY
                   COMPANY_ID_PK,
                   TRAN_ID,
                   FLAG,
                   TABLENAME,
                   XMLDATA,
                   CREATED_BY,
                   CREATED_ON,
                   TRAIL_ID_PK
               ORDER BY (SELECT NULL)
           )
    FROM TREDSPRODDB_ARCHIVAL.dbo.FCS_AUDIT_TRAIL_Archival
)
DELETE
FROM Duplicates
WHERE RN > 1;