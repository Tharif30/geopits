-- Explicit ALTER ANY LOGIN permission
SELECT 
    'ALTER ANY LOGIN' AS PermissionType,
    pr.name AS LoginName,
    pr.type_desc
FROM sys.server_permissions pe
JOIN sys.server_principals pr
    ON pe.grantee_principal_id = pr.principal_id
WHERE pe.permission_name = 'ALTER ANY LOGIN'

UNION ALL

-- securityadmin role members
SELECT 
    'SECURITYADMIN ROLE' AS PermissionType,
    sp.name,
    sp.type_desc
FROM sys.server_role_members srm
JOIN sys.server_principals sp
    ON srm.member_principal_id = sp.principal_id
JOIN sys.server_principals sr
    ON srm.role_principal_id = sr.principal_id
WHERE sr.name = 'securityadmin'

UNION ALL

-- sysadmin role members
SELECT 
    'SYSADMIN ROLE' AS PermissionType,
    sp.name,
    sp.type_desc
FROM sys.server_role_members srm
JOIN sys.server_principals sp
    ON srm.member_principal_id = sp.principal_id
JOIN sys.server_principals sr
    ON srm.role_principal_id = sr.principal_id
WHERE sr.name = 'sysadmin'
ORDER BY PermissionType, LoginName;