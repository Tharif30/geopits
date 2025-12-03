import re

# Reserved column names to flag
reserved_words = {"date", "type", "time", "max"}

def lint_sql(query):
    issues = []

    # Rule 2.1: SELECT must use NOLOCK
    if "select" in query.lower():
        select_statements = re.findall(r"select.*?from.*?(\w+)", query, flags=re.IGNORECASE | re.DOTALL)
        for stmt in select_statements:
            if "nolock" not in stmt.lower():
                issues.append("SELECT statement missing NOLOCK.")

    # Rule 2.1: NOLOCK should not be used in UPDATE/DELETE target
    if re.search(r"update\s+\w+\s+set", query, re.IGNORECASE) or re.search(r"delete\s+from\s+\w+", query, re.IGNORECASE):
        if "(nolock)" in query.lower():
            issues.append("NOLOCK used in UPDATE/DELETE target table, which is not allowed.")

    # Rule 2.18: Avoid SELECT *
    if re.search(r"select\s+\*", query, re.IGNORECASE):
        issues.append("Avoid using SELECT *. Specify column names instead.")

    # Rule 2.16: UPDATE/DELETE must have WHERE clause
    if re.search(r"update\s+.*?set.*?\n", query, re.IGNORECASE | re.DOTALL) and "where" not in query.lower():
        issues.append("UPDATE statement missing WHERE clause.")
    if re.search(r"delete\s+from\s+.*?\n", query, re.IGNORECASE | re.DOTALL) and "where" not in query.lower():
        issues.append("DELETE statement missing WHERE clause.")

    # Rule 2.5: Avoid joining more than 2 tables
    join_count = len(re.findall(r"join", query, re.IGNORECASE))
    if join_count > 2:
        issues.append("More than two JOINs found. Consider using temp tables.")

    # Rule 2.15: Avoid DISTINCT
    if re.search(r"select\s+distinct", query, re.IGNORECASE):
        issues.append("Avoid using DISTINCT unless absolutely necessary.")

    # Rule 2.12: Subqueries (in/not in) instead of EXISTS/NOT EXISTS
    if re.search(r"in\s*\(\s*select", query, re.IGNORECASE):
        issues.append("Avoid subqueries in WHERE. Use EXISTS/NOT EXISTS instead.")
    if re.search(r"not in\s*\(\s*select", query, re.IGNORECASE):
        issues.append("Avoid NOT IN with subqueries. Use NOT EXISTS instead.")

    # Rule 2.8: Missing AS keyword for alias
    if re.search(r"\s+\w+\s+\w+", query) and " as " not in query.lower():
        issues.append("Alias used without AS keyword.")

    # Rule 2.7: Reserved word as column name
    for word in reserved_words:
        if re.search(rf"\b{word}\b", query, re.IGNORECASE):
            issues.append(f"'{word}' is a reserved word and should not be used as a column name.")

    return issues

def fix_sql(query):
    # Rule 2.1: Ensure NOLOCK for SELECT statements
    def add_nolock(match):
        table = match.group(1)
        return f"FROM {table} (NOLOCK)"
    query = re.sub(r"FROM\s+(\w+)(?!\s*\(NOLOCK\))", add_nolock, query, flags=re.IGNORECASE)

    # Rule 2.18: Replace SELECT * with SELECT <columns> placeholder
    query = re.sub(r"SELECT\s+\*", "SELECT <specify_columns>", query, flags=re.IGNORECASE)

    # Rule 2.16: Add WHERE 1=1 to UPDATE/DELETE without WHERE
    if re.search(r"update\s+.*?set.*?\n", query, re.IGNORECASE | re.DOTALL) and "where" not in query.lower():
        query += "\n-- WARNING: WHERE clause added for safety\nWHERE 1=1"
    if re.search(r"delete\s+from\s+.*?\n", query, re.IGNORECASE | re.DOTALL) and "where" not in query.lower():
        query += "\n-- WARNING: WHERE clause added for safety\nWHERE 1=1"

    # Rule 2.15: Warn about DISTINCT
    query = re.sub(r"SELECT\s+DISTINCT", "-- WARNING: Avoid DISTINCT\nSELECT", query, flags=re.IGNORECASE)

    # Rule 2.12: Convert IN/NOT IN to EXISTS/NOT EXISTS placeholder
    query = re.sub(r"\bIN\b\s*\(\s*SELECT.*?\)", "-- REPLACE WITH EXISTS", query, flags=re.IGNORECASE | re.DOTALL)
    query = re.sub(r"\bNOT IN\b\s*\(\s*SELECT.*?\)", "-- REPLACE WITH NOT EXISTS", query, flags=re.IGNORECASE | re.DOTALL)

    return query

# Example usage
if __name__ == "__main__":
    sample_query = """
SELECT * 
FROM PortfolioUnsettled 
WHERE VenueCode = 'NSE';

UPDATE PortfolioUnsettled 
SET dpqty = dpqty + u.LEDGERBALANCE 
FROM PortfolioUnsettled p(NOLOCK) 
INNER JOIN Users u(NOLOCK) ON p.USERCODE = u.USERCODE;

DELETE FROM #TempPayout 
WHERE VoucherID IN (SELECT VoucherID FROM UD_DSReceivable (NOLOCK));
    """

    result = lint_sql(sample_query)
    if result:
        print("Issues found:")
        for issue in result:
            print("-", issue)
        print("\nSuggested Fix:\")
        print(fix_sql(sample_query))
    else:
        print("No issues found. Query follows standards.")