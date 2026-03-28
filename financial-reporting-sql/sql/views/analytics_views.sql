-- ============================================================
-- ANALYTICS VIEWS
-- Reusable view definitions for dashboards and reporting
-- ============================================================

-- Enriched Sales View (denormalized for BI tools)
CREATE VIEW IF NOT EXISTS v_sales_enriched AS
SELECT
    f.invoice_id,
    f.invoice_date,
    f.date_key,
    d.year,
    d.quarter,
    d.month,
    d.month_name,
    d.week_iso,
    d.day_name,
    d.is_weekend,
    f.customer_id,
    c.customer_name,
    c.company_name,
    c.city AS customer_city,
    c.country_code,
    c.region AS customer_region,
    c.segment,
    f.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    f.rep_id,
    r.rep_name,
    r.team AS rep_team,
    r.region AS rep_region,
    f.quantity,
    f.unit_price,
    f.discount_pct,
    f.line_total AS revenue,
    f.cost_total AS cost,
    f.line_total - f.cost_total AS gross_profit,
    CASE WHEN f.line_total > 0
        THEN ROUND((f.line_total - f.cost_total) * 100.0 / f.line_total, 1)
        ELSE 0
    END AS margin_pct,
    f.currency
FROM fact_sales f
LEFT JOIN dim_date d ON f.date_key = d.date_key
LEFT JOIN dim_customer c ON f.customer_id = c.customer_id
LEFT JOIN dim_product p ON f.product_id = p.product_id
LEFT JOIN dim_sales_rep r ON f.rep_id = r.rep_id;


-- Monthly KPI Summary View
CREATE VIEW IF NOT EXISTS v_monthly_kpis AS
SELECT
    strftime('%Y', invoice_date) AS year,
    CAST(strftime('%m', invoice_date) AS INTEGER) AS month,
    SUM(line_total) AS revenue,
    SUM(line_total - cost_total) AS gross_profit,
    ROUND(SUM(line_total - cost_total) * 100.0 / NULLIF(SUM(line_total), 0), 1) AS margin_pct,
    COUNT(DISTINCT invoice_id) AS orders,
    COUNT(DISTINCT customer_id) AS active_customers,
    COUNT(DISTINCT product_id) AS products_sold,
    SUM(quantity) AS units_sold,
    ROUND(SUM(line_total) / COUNT(DISTINCT invoice_id), 2) AS avg_order_value
FROM fact_sales
GROUP BY strftime('%Y', invoice_date), CAST(strftime('%m', invoice_date) AS INTEGER);


-- Customer 360 View
CREATE VIEW IF NOT EXISTS v_customer_360 AS
SELECT
    c.customer_id,
    c.customer_name,
    c.company_name,
    c.city,
    c.country_code,
    c.segment,
    c.registration_date,
    COUNT(DISTINCT f.invoice_id) AS total_orders,
    SUM(f.line_total) AS total_revenue,
    SUM(f.line_total - f.cost_total) AS total_profit,
    ROUND(AVG(f.line_total), 2) AS avg_line_value,
    MIN(f.invoice_date) AS first_order_date,
    MAX(f.invoice_date) AS last_order_date,
    julianday(MAX(f.invoice_date)) - julianday(MIN(f.invoice_date)) AS customer_tenure_days,
    COUNT(DISTINCT f.product_id) AS distinct_products
FROM dim_customer c
LEFT JOIN fact_sales f ON c.customer_id = f.customer_id
GROUP BY c.customer_id, c.customer_name, c.company_name,
         c.city, c.country_code, c.segment, c.registration_date;


-- Product Performance View
CREATE VIEW IF NOT EXISTS v_product_performance AS
SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.subcategory,
    p.brand,
    p.list_price,
    p.unit_cost,
    SUM(f.quantity) AS total_units_sold,
    SUM(f.line_total) AS total_revenue,
    SUM(f.line_total - f.cost_total) AS total_profit,
    ROUND(SUM(f.line_total - f.cost_total) * 100.0 / NULLIF(SUM(f.line_total), 0), 1) AS margin_pct,
    COUNT(DISTINCT f.invoice_id) AS order_count,
    COUNT(DISTINCT f.customer_id) AS customer_count
FROM dim_product p
LEFT JOIN fact_sales f ON p.product_id = f.product_id
GROUP BY p.product_id, p.product_name, p.category,
         p.subcategory, p.brand, p.list_price, p.unit_cost;
