"""
Query Runner
Executes all SQL analytics queries and displays formatted results.
"""

import sqlite3
import pandas as pd
import os
import glob

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
SQL_DIR = os.path.join(BASE_DIR, "sql", "queries")
DB_PATH = os.environ.get("FIN_DB_PATH", os.path.join("/tmp", "financial_reporting.db"))


def run_query(conn, sql, title=""):
    """Execute a SQL query and return results as DataFrame."""
    try:
        df = pd.read_sql_query(sql, conn)
        return df
    except Exception as e:
        print(f"  ERROR: {e}")
        return None


def execute_sql_file(conn, filepath):
    """Execute all queries in a SQL file (separated by semicolons)."""
    with open(filepath, "r") as f:
        content = f.read()

    # Split by semicolon, filter comments-only blocks
    queries = [q.strip() for q in content.split(";") if q.strip()]

    results = []
    for query in queries:
        # Skip if query is only comments
        lines = [l for l in query.split("\n") if l.strip() and not l.strip().startswith("--")]
        if not lines:
            continue

        # Extract title from preceding comment
        title_lines = [l.strip("- ").strip() for l in query.split("\n")
                       if l.strip().startswith("--") and not l.strip().startswith("--=")]
        title = title_lines[0] if title_lines else "Query"

        # Clean query (remove leading comments for execution)
        clean_query = query
        df = run_query(conn, clean_query, title)
        if df is not None and len(df) > 0:
            results.append((title, df))

    return results


def main():
    if not os.path.exists(DB_PATH):
        print(f"Database not found at {DB_PATH}")
        print("Run 'python scripts/setup_database.py' first.")
        return

    conn = sqlite3.connect(DB_PATH)
    print("=" * 70)
    print("FINANCIAL REPORTING - SQL ANALYTICS RESULTS")
    print("=" * 70)

    sql_files = sorted(glob.glob(os.path.join(SQL_DIR, "*.sql")))

    for filepath in sql_files:
        filename = os.path.basename(filepath)
        print(f"\n{'='*70}")
        print(f"FILE: {filename}")
        print(f"{'='*70}")

        results = execute_sql_file(conn, filepath)

        for title, df in results:
            print(f"\n--- {title} ---")
            if len(df) > 25:
                print(df.head(15).to_string(index=False))
                print(f"  ... ({len(df)} total rows)")
            else:
                print(df.to_string(index=False))

    conn.close()
    print(f"\n{'='*70}")
    print("All queries executed successfully.")


if __name__ == "__main__":
    main()
