-- ============================================================
-- REVENUE ANALYSIS QUERIES
-- Monthly/quarterly revenue, YoY growth, moving averages
-- ============================================================

-- 1. Monthly Revenue with Year-over-Year Growth
WITH monthly_revenue AS (
    SELECT
        strftime('%Y', invoice_date) AS year,
        CAST(strftime('%m', invoice_date) AS INTEGER) AS month,
        SUM(line_total) AS revenue,
        SUM(cost_total) AS cost,
        SUM(line_total) - SUM(cost_total) AS gross_profit,
        COUNT(DISTINCT invoice_id) AS order_count,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM fact_sales
    GROUP BY strftime('%Y', invoice_date), CAST(strftime('%m', invoice_date) AS INTEGER)
),
with_yoy AS (
    SELECT
        m.*,
        ROUND(m.gross_profit * 100.0 / NULLIF(m.revenue, 0), 1) AS margin_pct,
        LAG(m.revenue, 12) OVER (ORDER BY m.year, m.month) AS prev_year_revenue,
        ROUND(
            (m.revenue - LAG(m.revenue, 12) OVER (ORDER BY m.year, m.month))
            * 100.0 / NULLIF(LAG(m.revenue, 12) OVER (ORDER BY m.year, m.month), 0),
        1) AS yoy_growth_pct
    FROM monthly_revenue m
)
SELECT * FROM with_yoy ORDER BY year, month;


-- 2. Quarterly Revenue with Running Total
WITH quarterly AS (
    SELECT
        strftime('%Y', invoice_date) AS year,
        'Q' || ((CAST(strftime('%m', invoice_date) AS INTEGER) - 1) / 3 + 1) AS quarter,
        SUM(line_total) AS revenue,
        SUM(line_total) - SUM(cost_total) AS gross_profit,
        COUNT(DISTINCT customer_id) AS customers
    FROM fact_sales
    GROUP BY strftime('%Y', invoice_date),
             (CAST(strftime('%m', invoice_date) AS INTEGER) - 1) / 3 + 1
)
SELECT
    q.*,
    SUM(q.revenue) OVER (PARTITION BY q.year ORDER BY q.quarter) AS ytd_revenue,
    ROUND(q.gross_profit * 100.0 / NULLIF(q.revenue, 0), 1) AS margin_pct
FROM quarterly q
ORDER BY year, quarter;


-- 3. Revenue by Category with 3-Month Moving Average
WITH monthly_cat AS (
    SELECT
        strftime('%Y-%m', f.invoice_date) AS month,
        p.category,
        SUM(f.line_total) AS revenue
    FROM fact_sales f
    JOIN dim_product p ON f.product_id = p.product_id
    GROUP BY strftime('%Y-%m', f.invoice_date), p.category
)
SELECT
    month,
    category,
    revenue,
    ROUND(AVG(revenue) OVER (
        PARTITION BY category
        ORDER BY month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS moving_avg_3m
FROM monthly_cat
ORDER BY category, month;


-- 4. Revenue Waterfall: Budget vs Actual vs Forecast
WITH actual AS (
    SELECT
        CAST(strftime('%Y', invoice_date) AS INTEGER) AS year,
        CAST(strftime('%m', invoice_date) AS INTEGER) AS month,
        SUM(line_total) AS actual_revenue
    FROM fact_sales
    GROUP BY CAST(strftime('%Y', invoice_date) AS INTEGER),
             CAST(strftime('%m', invoice_date) AS INTEGER)
),
budget AS (
    SELECT year, month, SUM(budget_amount) AS budget_revenue
    FROM fact_budget
    GROUP BY year, month
)
SELECT
    a.year,
    a.month,
    COALESCE(b.budget_revenue, 0) AS budget,
    a.actual_revenue AS actual,
    a.actual_revenue - COALESCE(b.budget_revenue, 0) AS variance,
    ROUND((a.actual_revenue - COALESCE(b.budget_revenue, 0)) * 100.0
          / NULLIF(b.budget_revenue, 0), 1) AS variance_pct
FROM actual a
LEFT JOIN budget b ON a.year = b.year AND a.month = b.month
ORDER BY a.year, a.month;
