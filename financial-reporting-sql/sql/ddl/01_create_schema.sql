-- Financial Reporting Schema
-- Star schema for retail analytics in DACH region

CREATE TABLE IF NOT EXISTS dim_customer (
    customer_id TEXT PRIMARY KEY,
    customer_name TEXT NOT NULL,
    company_name TEXT,
    city TEXT,
    country_code TEXT CHECK(country_code IN ('DE', 'AT', 'CH')),
    region TEXT,
    segment TEXT CHECK(segment IN ('Enterprise', 'Mittelstand', 'Kleinunternehmen', 'Privatkunde')),
    registration_date DATE,
    credit_limit REAL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS dim_product (
    product_id TEXT PRIMARY KEY,
    product_name TEXT NOT NULL,
    category TEXT,
    subcategory TEXT,
    brand TEXT,
    unit_cost REAL,
    list_price REAL,
    is_active INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE,
    year INTEGER,
    quarter INTEGER,
    month INTEGER,
    month_name TEXT,
    week_iso INTEGER,
    day_of_week INTEGER,
    day_name TEXT,
    is_weekend INTEGER,
    fiscal_year INTEGER,
    fiscal_quarter INTEGER
);

CREATE TABLE IF NOT EXISTS dim_sales_rep (
    rep_id TEXT PRIMARY KEY,
    rep_name TEXT,
    team TEXT,
    region TEXT,
    hire_date DATE
);

CREATE TABLE IF NOT EXISTS fact_sales (
    invoice_id TEXT,
    invoice_date DATE,
    date_key INTEGER,
    customer_id TEXT,
    product_id TEXT,
    rep_id TEXT,
    quantity INTEGER,
    unit_price REAL,
    discount_pct REAL DEFAULT 0,
    line_total REAL,
    cost_total REAL,
    currency TEXT DEFAULT 'EUR',
    FOREIGN KEY (customer_id) REFERENCES dim_customer(customer_id),
    FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (rep_id) REFERENCES dim_sales_rep(rep_id)
);

CREATE TABLE IF NOT EXISTS fact_budget (
    budget_id INTEGER PRIMARY KEY AUTOINCREMENT,
    year INTEGER,
    month INTEGER,
    category TEXT,
    region TEXT,
    budget_amount REAL,
    currency TEXT DEFAULT 'EUR'
);

-- Indexes for query performance
CREATE INDEX IF NOT EXISTS idx_sales_date ON fact_sales(date_key);
CREATE INDEX IF NOT EXISTS idx_sales_customer ON fact_sales(customer_id);
CREATE INDEX IF NOT EXISTS idx_sales_product ON fact_sales(product_id);
CREATE INDEX IF NOT EXISTS idx_sales_invoice_date ON fact_sales(invoice_date);
