-- ============================================================
-- EXECUTIVE KPI DASHBOARD QUERIES
-- Management-level metrics, anomaly detection, forecasting support
-- ============================================================

-- 1. Executive Summary KPIs
SELECT
    'Total Revenue' AS kpi,
    ROUND(SUM(line_total), 2) AS value,
    'EUR' AS unit
FROM fact_sales
UNION ALL
SELECT
    'Gross Profit',
    ROUND(SUM(line_total - cost_total), 2),
    'EUR'
FROM fact_sales
UNION ALL
SELECT
    'Gross Margin %',
    ROUND(SUM(line_total - cost_total) * 100.0 / SUM(line_total), 1),
    '%'
FROM fact_sales
UNION ALL
SELECT
    'Total Orders',
    COUNT(DISTINCT invoice_id),
    'count'
FROM fact_sales
UNION ALL
SELECT
    'Active Customers',
    COUNT(DISTINCT customer_id),
    'count'
FROM fact_sales
UNION ALL
SELECT
    'Avg Order Value',
    ROUND(SUM(line_total) / COUNT(DISTINCT invoice_id), 2),
    'EUR'
FROM fact_sales
UNION ALL
SELECT
    'Products Sold',
    COUNT(DISTINCT product_id),
    'count'
FROM fact_sales;


-- 2. Month-over-Month Dashboard
WITH monthly AS (
    SELECT
        strftime('%Y-%m', invoice_date) AS month,
        SUM(line_total) AS revenue,
        SUM(line_total - cost_total) AS profit,
        COUNT(DISTINCT invoice_id) AS orders,
        COUNT(DISTINCT customer_id) AS customers
    FROM fact_sales
    GROUP BY strftime('%Y-%m', invoice_date)
)
SELECT
    month,
    ROUND(revenue, 2) AS revenue,
    ROUND(profit, 2) AS profit,
    orders,
    customers,
    ROUND(revenue / orders, 2) AS aov,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) * 100.0
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0), 1
    ) AS mom_growth_pct
FROM monthly
ORDER BY month;


-- 3. Revenue Anomaly Detection (Z-Score Method)
WITH daily_revenue AS (
    SELECT
        invoice_date AS day,
        SUM(line_total) AS revenue
    FROM fact_sales
    GROUP BY invoice_date
),
stats AS (
    SELECT
        AVG(revenue) AS mean_rev,
        -- Standard deviation calculation for SQLite
        SQRT(AVG(revenue * revenue) - AVG(revenue) * AVG(revenue)) AS stddev_rev
    FROM daily_revenue
)
SELECT
    d.day,
    ROUND(d.revenue, 2) AS revenue,
    ROUND(s.mean_rev, 2) AS avg_daily,
    ROUND((d.revenue - s.mean_rev) / NULLIF(s.stddev_rev, 0), 2) AS z_score,
    CASE
        WHEN ABS((d.revenue - s.mean_rev) / NULLIF(s.stddev_rev, 0)) > 2 THEN 'ANOMALY'
        WHEN ABS((d.revenue - s.mean_rev) / NULLIF(s.stddev_rev, 0)) > 1.5 THEN 'WARNING'
        ELSE 'NORMAL'
    END AS status
FROM daily_revenue d, stats s
WHERE ABS((d.revenue - s.mean_rev) / NULLIF(s.stddev_rev, 0)) > 1.5
ORDER BY ABS((d.revenue - s.mean_rev) / NULLIF(s.stddev_rev, 0)) DESC
LIMIT 20;


-- 4. Sales Pipeline Velocity
WITH order_metrics AS (
    SELECT
        strftime('%Y-%m', invoice_date) AS month,
        customer_id,
        invoice_id,
        SUM(line_total) AS order_value,
        COUNT(DISTINCT product_id) AS items_per_order
    FROM fact_sales
    GROUP BY strftime('%Y-%m', invoice_date), customer_id, invoice_id
)
SELECT
    month,
    COUNT(DISTINCT invoice_id) AS total_orders,
    ROUND(AVG(order_value), 2) AS avg_order_value,
    ROUND(AVG(items_per_order), 1) AS avg_items_per_order,
    COUNT(DISTINCT customer_id) AS unique_buyers,
    ROUND(SUM(order_value), 2) AS total_revenue
FROM order_metrics
GROUP BY month
ORDER BY month;


-- 5. Discount Impact Analysis
SELECT
    CASE
        WHEN discount_pct = 0 THEN 'No Discount'
        WHEN discount_pct <= 10 THEN '1-10%'
        WHEN discount_pct <= 20 THEN '11-20%'
        ELSE '21%+'
    END AS discount_band,
    COUNT(*) AS line_items,
    ROUND(SUM(line_total), 2) AS revenue,
    ROUND(SUM(line_total - cost_total), 2) AS gross_profit,
    ROUND(SUM(line_total - cost_total) * 100.0 / NULLIF(SUM(line_total), 0), 1) AS margin_pct,
    ROUND(SUM(quantity * unit_price * discount_pct / 100.0), 2) AS discount_amount_given
FROM fact_sales
GROUP BY
    CASE
        WHEN discount_pct = 0 THEN 'No Discount'
        WHEN discount_pct <= 10 THEN '1-10%'
        WHEN discount_pct <= 20 THEN '11-20%'
        ELSE '21%+'
    END
ORDER BY MIN(discount_pct);
