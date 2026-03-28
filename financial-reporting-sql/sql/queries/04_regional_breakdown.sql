-- ============================================================
-- DACH REGIONAL ANALYSIS
-- Country/region performance, market share, growth trends
-- ============================================================

-- 1. Revenue by DACH Country with Market Share
WITH country_revenue AS (
    SELECT
        c.country_code,
        CASE c.country_code
            WHEN 'DE' THEN 'Deutschland'
            WHEN 'AT' THEN 'Österreich'
            WHEN 'CH' THEN 'Schweiz'
        END AS country_name,
        SUM(f.line_total) AS revenue,
        SUM(f.line_total - f.cost_total) AS gross_profit,
        COUNT(DISTINCT f.customer_id) AS customers,
        COUNT(DISTINCT f.invoice_id) AS orders
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_id = c.customer_id
    GROUP BY c.country_code
)
SELECT
    country_code,
    country_name,
    ROUND(revenue, 2) AS revenue,
    ROUND(gross_profit, 2) AS gross_profit,
    ROUND(gross_profit * 100.0 / NULLIF(revenue, 0), 1) AS margin_pct,
    customers,
    orders,
    ROUND(revenue / orders, 2) AS avg_order_value,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 1) AS market_share_pct
FROM country_revenue
ORDER BY revenue DESC;


-- 2. Regional Revenue Trend (Monthly by Country)
SELECT
    strftime('%Y-%m', f.invoice_date) AS month,
    c.country_code,
    SUM(f.line_total) AS revenue,
    COUNT(DISTINCT f.customer_id) AS active_customers,
    SUM(f.line_total) / COUNT(DISTINCT f.customer_id) AS revenue_per_customer
FROM fact_sales f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY strftime('%Y-%m', f.invoice_date), c.country_code
ORDER BY month, c.country_code;


-- 3. City-Level Performance (Top Cities per Country)
WITH city_perf AS (
    SELECT
        c.country_code,
        c.city,
        SUM(f.line_total) AS revenue,
        COUNT(DISTINCT f.customer_id) AS customers,
        ROW_NUMBER() OVER (PARTITION BY c.country_code ORDER BY SUM(f.line_total) DESC) AS city_rank
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_id = c.customer_id
    GROUP BY c.country_code, c.city
)
SELECT
    country_code,
    city,
    ROUND(revenue, 2) AS revenue,
    customers,
    city_rank
FROM city_perf
WHERE city_rank <= 5
ORDER BY country_code, city_rank;


-- 4. Segment Performance by Region
SELECT
    c.country_code,
    c.segment,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    SUM(f.line_total) AS revenue,
    ROUND(AVG(f.line_total), 2) AS avg_line_value,
    ROUND(SUM(f.line_total) * 100.0 /
        SUM(SUM(f.line_total)) OVER (PARTITION BY c.country_code), 1) AS segment_share_pct
FROM fact_sales f
JOIN dim_customer c ON f.customer_id = c.customer_id
GROUP BY c.country_code, c.segment
ORDER BY c.country_code, revenue DESC;


-- 5. Sales Rep Performance by Region
SELECT
    r.region,
    r.rep_name,
    SUM(f.line_total) AS revenue,
    SUM(f.line_total - f.cost_total) AS gross_profit,
    COUNT(DISTINCT f.customer_id) AS accounts,
    COUNT(DISTINCT f.invoice_id) AS deals,
    ROUND(SUM(f.line_total) / COUNT(DISTINCT f.invoice_id), 2) AS avg_deal_size,
    RANK() OVER (PARTITION BY r.region ORDER BY SUM(f.line_total) DESC) AS rank_in_region
FROM fact_sales f
JOIN dim_sales_rep r ON f.rep_id = r.rep_id
GROUP BY r.region, r.rep_name
ORDER BY r.region, revenue DESC;
