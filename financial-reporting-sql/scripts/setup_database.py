"""
Database Setup Script
Generates realistic financial data and creates SQLite database
for a DACH retail company.
"""

import sqlite3
import pandas as pd
import numpy as np
import os
from datetime import datetime, timedelta

np.random.seed(42)

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
SQL_DIR = os.path.join(BASE_DIR, "sql")

# Use /tmp for SQLite (avoids I/O issues on network mounts)
DB_PATH = os.environ.get("FIN_DB_PATH", os.path.join("/tmp", "financial_reporting.db"))


def create_schema(conn):
    """Create database schema from DDL file."""
    ddl_path = os.path.join(SQL_DIR, "ddl", "01_create_schema.sql")
    with open(ddl_path, "r") as f:
        conn.executescript(f.read())
    print("  Schema created")


def generate_dim_date(conn):
    """Generate date dimension (2024-2025)."""
    dates = pd.date_range("2024-01-01", "2025-12-31")
    dim = pd.DataFrame({
        "date_key": dates.strftime("%Y%m%d").astype(int),
        "full_date": dates.strftime("%Y-%m-%d"),
        "year": dates.year,
        "quarter": dates.quarter,
        "month": dates.month,
        "month_name": dates.strftime("%B"),
        "week_iso": dates.isocalendar().week.astype(int),
        "day_of_week": dates.dayofweek,
        "day_name": dates.strftime("%A"),
        "is_weekend": (dates.dayofweek >= 5).astype(int),
        "fiscal_year": dates.year,
        "fiscal_quarter": dates.quarter,
    })
    dim.to_sql("dim_date", conn, if_exists="replace", index=False)
    print(f"  dim_date: {len(dim)} rows")


def generate_customers(conn, n=1500):
    """Generate DACH customer data."""
    cities = {
        "DE": {"cities": ["Berlin", "München", "Hamburg", "Frankfurt", "Köln", "Stuttgart",
                          "Düsseldorf", "Leipzig", "Dresden", "Nürnberg"],
               "regions": ["Nord", "Süd", "West", "Ost"]},
        "AT": {"cities": ["Wien", "Graz", "Linz", "Salzburg", "Innsbruck"],
               "regions": ["Ost", "West"]},
        "CH": {"cities": ["Zürich", "Bern", "Basel", "Genf", "Luzern"],
               "regions": ["Deutschschweiz", "Romandie"]},
    }

    segments = ["Enterprise", "Mittelstand", "Kleinunternehmen", "Privatkunde"]
    segment_weights = [0.08, 0.22, 0.30, 0.40]
    companies = ["GmbH", "AG", "KG", "e.K.", ""]

    first_names = ["Max", "Anna", "Lukas", "Sophie", "Leon", "Marie", "Felix", "Laura",
                   "Jonas", "Lena", "Tim", "Julia", "Paul", "Sarah", "Moritz", "Emma"]
    last_names = ["Müller", "Schmidt", "Schneider", "Fischer", "Weber", "Meyer",
                  "Wagner", "Becker", "Hoffmann", "Schäfer", "Koch", "Bauer"]

    records = []
    for i in range(n):
        country = np.random.choice(["DE", "AT", "CH"], p=[0.65, 0.20, 0.15])
        city = np.random.choice(cities[country]["cities"])
        region = np.random.choice(cities[country]["regions"])
        segment = np.random.choice(segments, p=segment_weights)
        fname = np.random.choice(first_names)
        lname = np.random.choice(last_names)

        credit = {"Enterprise": 50000, "Mittelstand": 20000, "Kleinunternehmen": 5000, "Privatkunde": 1000}

        records.append({
            "customer_id": f"K{i+1:05d}",
            "customer_name": f"{fname} {lname}",
            "company_name": f"{lname} {np.random.choice(companies)}" if segment != "Privatkunde" else None,
            "city": city,
            "country_code": country,
            "region": region,
            "segment": segment,
            "registration_date": (datetime(2022, 1, 1) + timedelta(days=np.random.randint(0, 1000))).strftime("%Y-%m-%d"),
            "credit_limit": credit[segment] * np.random.uniform(0.5, 2.0),
        })

    df = pd.DataFrame(records)
    df.to_sql("dim_customer", conn, if_exists="replace", index=False)
    print(f"  dim_customer: {len(df)} rows")
    return df


def generate_products(conn, n=200):
    """Generate product catalog."""
    categories = {
        "Elektronik": {"sub": ["Computer", "Zubehör", "Netzwerk", "Drucker"], "price_range": (50, 2000)},
        "Büromaterial": {"sub": ["Papier", "Schreibwaren", "Ordner", "Toner"], "price_range": (5, 150)},
        "Möbel": {"sub": ["Schreibtisch", "Stuhl", "Regal", "Schrank"], "price_range": (100, 1500)},
        "Software": {"sub": ["Lizenz", "Cloud", "Sicherheit", "Analyse"], "price_range": (20, 500)},
        "Dienstleistung": {"sub": ["Beratung", "Wartung", "Schulung", "Support"], "price_range": (50, 300)},
    }
    brands = ["TechPro", "OfficePlus", "DataCore", "SmartWork", "SecureIT", "CloudFirst"]

    records = []
    pid = 1
    for cat, info in categories.items():
        for _ in range(n // len(categories)):
            sub = np.random.choice(info["sub"])
            brand = np.random.choice(brands)
            price = np.random.uniform(*info["price_range"])
            records.append({
                "product_id": f"A{pid:05d}",
                "product_name": f"{brand} {sub} {np.random.randint(100,999)}",
                "category": cat,
                "subcategory": sub,
                "brand": brand,
                "unit_cost": round(price * np.random.uniform(0.35, 0.65), 2),
                "list_price": round(price, 2),
                "is_active": 1 if np.random.random() > 0.05 else 0,
            })
            pid += 1

    df = pd.DataFrame(records)
    df.to_sql("dim_product", conn, if_exists="replace", index=False)
    print(f"  dim_product: {len(df)} rows")
    return df


def generate_sales_reps(conn):
    """Generate sales team."""
    reps = [
        ("V001", "Thomas Braun", "Enterprise", "DE-Nord"),
        ("V002", "Sandra Koch", "Enterprise", "DE-Süd"),
        ("V003", "Michael Weber", "Mittelstand", "DE-West"),
        ("V004", "Lisa Hoffmann", "Mittelstand", "DE-Ost"),
        ("V005", "Andreas Müller", "KMU", "DE-Nord"),
        ("V006", "Julia Schmidt", "KMU", "DE-Süd"),
        ("V007", "Markus Gruber", "Enterprise", "AT"),
        ("V008", "Katharina Bauer", "Mittelstand", "AT"),
        ("V009", "Stefan Meier", "Enterprise", "CH"),
        ("V010", "Nicole Brunner", "Mittelstand", "CH"),
    ]
    df = pd.DataFrame(reps, columns=["rep_id", "rep_name", "team", "region"])
    df["hire_date"] = [
        (datetime(2020, 1, 1) + timedelta(days=np.random.randint(0, 1500))).strftime("%Y-%m-%d")
        for _ in range(len(df))
    ]
    df.to_sql("dim_sales_rep", conn, if_exists="replace", index=False)
    print(f"  dim_sales_rep: {len(df)} rows")
    return df


def generate_sales(conn, customers, products, reps, n=80000):
    """Generate transaction data."""
    cust_ids = customers["customer_id"].tolist()
    prod_ids = products["product_id"].tolist()
    prod_prices = dict(zip(products["product_id"], products["list_price"]))
    prod_costs = dict(zip(products["product_id"], products["unit_cost"]))
    rep_ids = reps["rep_id"].tolist()

    records = []
    invoice_counter = 1

    for _ in range(n // 3):  # ~3 line items per invoice
        inv_date = datetime(2024, 1, 1) + timedelta(
            days=np.random.randint(0, 548),
            hours=np.random.randint(7, 18),
        )
        inv_id = f"RE{invoice_counter:07d}"
        cust = np.random.choice(cust_ids)
        rep = np.random.choice(rep_ids)
        num_items = np.random.choice([1, 2, 3, 4, 5], p=[0.35, 0.30, 0.20, 0.10, 0.05])

        for _ in range(num_items):
            prod = np.random.choice(prod_ids)
            qty = np.random.choice([1, 1, 2, 3, 5, 10], p=[0.40, 0.20, 0.15, 0.10, 0.10, 0.05])
            price = prod_prices[prod]
            cost = prod_costs[prod]
            discount = np.random.choice([0, 0, 0, 5, 10, 15, 20], p=[0.40, 0.15, 0.10, 0.10, 0.10, 0.10, 0.05])
            line_total = round(price * qty * (1 - discount / 100), 2)

            records.append({
                "invoice_id": inv_id,
                "invoice_date": inv_date.strftime("%Y-%m-%d"),
                "date_key": int(inv_date.strftime("%Y%m%d")),
                "customer_id": cust,
                "product_id": prod,
                "rep_id": rep,
                "quantity": qty,
                "unit_price": round(price, 2),
                "discount_pct": discount,
                "line_total": line_total,
                "cost_total": round(cost * qty, 2),
                "currency": "EUR",
            })

        invoice_counter += 1

    df = pd.DataFrame(records)
    df.to_sql("fact_sales", conn, if_exists="replace", index=False)
    print(f"  fact_sales: {len(df):,} rows ({df['invoice_id'].nunique():,} invoices)")
    return df


def generate_budget(conn):
    """Generate monthly budget data."""
    categories = ["Elektronik", "Büromaterial", "Möbel", "Software", "Dienstleistung"]
    regions = ["DE-Nord", "DE-Süd", "DE-West", "DE-Ost", "AT", "CH"]

    records = []
    for year in [2024, 2025]:
        for month in range(1, 13):
            for cat in categories:
                for region in regions:
                    base = np.random.uniform(5000, 50000)
                    seasonal = 1.0 + 0.2 * np.sin(2 * np.pi * (month - 1) / 12)
                    records.append({
                        "year": year,
                        "month": month,
                        "category": cat,
                        "region": region,
                        "budget_amount": round(base * seasonal, 2),
                        "currency": "EUR",
                    })

    df = pd.DataFrame(records)
    df.to_sql("fact_budget", conn, if_exists="replace", index=False)
    print(f"  fact_budget: {len(df):,} rows")


def main():
    os.makedirs(DATA_DIR, exist_ok=True)

    print(f"Setting up Financial Reporting Database...")
    print(f"Database: {DB_PATH}\n")

    conn = sqlite3.connect(DB_PATH)

    print("[1/7] Creating schema...")
    create_schema(conn)

    print("[2/7] Generating date dimension...")
    generate_dim_date(conn)

    print("[3/7] Generating customers...")
    customers = generate_customers(conn)

    print("[4/7] Generating products...")
    products = generate_products(conn)

    print("[5/7] Generating sales reps...")
    reps = generate_sales_reps(conn)

    print("[6/7] Generating sales transactions...")
    sales = generate_sales(conn, customers, products, reps)

    print("[7/7] Generating budget data...")
    generate_budget(conn)

    conn.commit()
    conn.close()

    print(f"\nDatabase ready at: {DB_PATH}")
    print("Run 'python scripts/run_queries.py' to execute analytics queries.")


if __name__ == "__main__":
    main()
