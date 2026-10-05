/* ============================================================
   SQL SERVER DATABASE MIRRORING
   PRE-CHECK / POST-CHECK
   Run on BOTH PRINCIPAL and MIRROR servers
   ============================================================ */

---------------------------------------------------------------
-- 1. SERVER / SQL VERSION
---------------------------------------------------------------
SELECT
    @@SERVERNAME AS ServerName,
    SERVERPROPERTY('MachineName') AS MachineName,
    SERVERPROPERTY('InstanceName') AS InstanceName,
    SERVERPROPERTY('ProductVersion') AS SQLVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('Edition') AS Edition,
    GETDATE() AS CheckTime;


---------------------------------------------------------------
-- 2. DATABASE MIRRORING STATUS
---------------------------------------------------------------
SELECT
    DB_NAME(database_id) AS DatabaseName,
    mirroring_role_desc AS MirroringRole,
    mirroring_state_desc AS MirroringState,
    mirroring_safety_level_desc AS SafetyLevel,
    mirroring_partner_name AS PartnerServer,
    mirroring_witness_name AS WitnessServer,
    mirroring_witness_state_desc AS WitnessState
FROM sys.database_mirroring
WHERE mirroring_guid IS NOT NULL
ORDER BY DB_NAME(database_id);


---------------------------------------------------------------
-- 3. DATABASE STATUS
---------------------------------------------------------------
SELECT
    name AS DatabaseName,
    state_desc AS DatabaseState,
    user_access_desc AS UserAccess,
    recovery_model_desc AS RecoveryModel
FROM sys.databases
WHERE name IN
(
    SELECT DB_NAME(database_id)
    FROM sys.database_mirroring
    WHERE mirroring_guid IS NOT NULL
)
ORDER BY name;


---------------------------------------------------------------
-- 4. MIRRORING ENDPOINT STATUS
---------------------------------------------------------------
SELECT
    name AS EndpointName,
    state_desc AS EndpointState,
    role_desc AS EndpointRole,
    connection_auth_desc AS Authentication
FROM sys.database_mirroring_endpoints;


---------------------------------------------------------------
-- 5. MIRRORING PARTNER CONNECTION
---------------------------------------------------------------
SELECT
    DB_NAME(database_id) AS DatabaseName,
    mirroring_role_desc,
    mirroring_state_desc,
    mirroring_connection_timeout,
    mirroring_partner_instance
FROM sys.database_mirroring
WHERE mirroring_guid IS NOT NULL;


---------------------------------------------------------------
-- 6. DATABASE FILE STATUS
---------------------------------------------------------------
SELECT
    DB_NAME(database_id) AS DatabaseName,
    type_desc AS FileType,
    physical_name,
    size / 128.0 AS SizeMB,
    state_desc
FROM sys.master_files
WHERE database_id IN
(
    SELECT database_id
    FROM sys.database_mirroring
    WHERE mirroring_guid IS NOT NULL
)
ORDER BY DB_NAME(database_id), type_desc;


---------------------------------------------------------------
-- 7. SQL SERVER SERVICES / STARTUP INFORMATION
---------------------------------------------------------------
SELECT
    sqlserver_start_time AS SQLServerStartTime,
    DATEDIFF(MINUTE, sqlserver_start_time, GETDATE()) AS MinutesSinceStartup
FROM sys.dm_os_sys_info;


---------------------------------------------------------------
-- 8. RECENT SQL SERVER ERRORS
---------------------------------------------------------------
EXEC sys.xp_readerrorlog
    0,              -- Current error log
    1,              -- SQL Server error log
    N'error',
    NULL,
    NULL,
    NULL,
    N'desc';


---------------------------------------------------------------
-- 9. MIRRORING EVENTS FROM ERROR LOG
---------------------------------------------------------------
EXEC sys.xp_readerrorlog
    0,
    1,
    N'mirror',
    NULL,
    NULL,
    NULL,
    N'desc';


---------------------------------------------------------------
-- 10. FINAL SUMMARY
---------------------------------------------------------------
SELECT
    @@SERVERNAME AS ServerName,
    GETDATE() AS CheckTime,
    DB_NAME(database_id) AS DatabaseName,
    mirroring_role_desc AS Role,
    mirroring_state_desc AS MirroringState,
    mirroring_safety_level_desc AS SafetyLevel
FROM sys.database_mirroring
WHERE mirroring_guid IS NOT NULL
ORDER BY DatabaseName;