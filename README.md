# SQL Analytics - Financial Reporting

## Overview
Advanced SQL analytics project demonstrating financial reporting capabilities for a mid-size DACH retail company. Features complex queries using CTEs, window functions, ROLLUP/CUBE, running totals, YoY comparisons, and cohort analysis — skills essential for data analyst roles in the German-speaking market.

## Key Features
- **Revenue Analysis**: Monthly/quarterly revenue with YoY growth, moving averages
- **Customer Cohort Analysis**: Retention tracking and lifetime value calculations
- **Product Performance**: ABC analysis, contribution margins, cross-sell patterns
- **Regional Reporting**: DACH market segmentation with currency handling
- **Management Dashboard Queries**: Executive KPI views, anomaly detection
- **Window Functions**: RANK, NTILE, LAG/LEAD, running sums, percentile calculations

## Tech Stack
- **SQLite** — Local database engine (syntax compatible with PostgreSQL/Snowflake)
- **Python** — Data generation and query execution wrapper
- **pandas** — Result formatting and export

## Project Structure
```
financial-reporting-sql/
├── sql/
│   ├── ddl/
│   │   └── 01_create_schema.sql      # Table definitions
│   ├── queries/
│   │   ├── 01_revenue_analysis.sql    # Revenue KPIs & trends
│   │   ├── 02_customer_cohorts.sql    # Cohort retention analysis
│   │   ├── 03_product_abc.sql         # ABC product classification
│   │   ├── 04_regional_breakdown.sql  # DACH regional analysis
│   │   └── 05_executive_kpis.sql      # Management dashboard queries
│   └── views/
│       └── analytics_views.sql        # Reusable view definitions
├── scripts/
│   ├── setup_database.py              # Generate data & create DB
│   └── run_queries.py                 # Execute all queries with output
├── data/                              # Generated database & exports
├── requirements.txt
└── README.md
```

## Quick Start
```bash
pip install -r requirements.txt

# Create database with sample financial data
python scripts/setup_database.py

# Run all analytics queries with formatted output
python scripts/run_queries.py
```

## SQL Techniques Demonstrated
| Technique | Example Query |
|-----------|--------------|
| CTEs (WITH clause) | Revenue waterfall analysis |
| Window Functions (RANK, NTILE) | Product ABC classification |
| LAG/LEAD | Month-over-month growth |
| Running Totals | Cumulative revenue tracking |
| CASE WHEN | Business rule classification |
| Subqueries | Top-N per group analysis |
| Date Functions | Fiscal period calculations |
| Aggregation | Multi-level GROUP BY |

## Relevance to DACH Market
- Financial reporting aligned with German accounting periods (HGB)
- DACH regional segmentation (Deutschland/Österreich/Schweiz)
- Multi-currency considerations (EUR/CHF)
- Demonstrates SQL skills required by consulting firms (ALTEN, Accenture, McKinsey)
- Compatible with enterprise BI tools (SAP BW, Power BI, Tableau)

## Author
Muhammad Umer Lari — Data Analyst | Analytics Engineer
