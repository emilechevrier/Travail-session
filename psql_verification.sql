WITH employee_var AS (
    SELECT 'employee'::text AS emp_name
)
SELECT
    grantee AS "NomGroupe",
    privilege_type
FROM
    information_schema.role_table_grants, employee_var
WHERE
    grantee = employee_var.emp_name
GROUP BY grantee, privilege_type
UNION
SELECT
    rolname AS "NomGroupe",
    CASE 
        WHEN rolsuper = true THEN 'SUPER_USER'
        ELSE 'REGULAR_USER'
    END AS privilege_type
FROM
    pg_roles, employee_var
WHERE
    rolname = employee_var.emp_name;
