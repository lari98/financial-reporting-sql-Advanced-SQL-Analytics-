-- ============================================================
-- CUSTOMER COHORT ANALYSIS
-- Retention rates, lifetime value, churn detection
-- ============================================================

-- 1. Monthly Cohort Retention Analysis
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(strftime('%Y-%m', invoice_date)) AS cohort_month
    FROM fact_sales
    GROUP BY customer_id
),
customer_activity AS (
    SELECT DISTINCT
        f.customer_id,
        fp.cohort_month,
        strftime('%Y-%m', f.invoice_date) AS activity_month,
        -- Calculate months since first purchase
        (CAST(strftime('%Y', f.invoice_date) AS INTEGER) - CAST(substr(fp.cohort_month, 1, 4) AS INTEGER)) * 12
        + CAST(strftime('%m', f.invoice_date) AS INTEGER) - CAST(substr(fp.cohort_month, 6, 2) AS INTEGER)
        AS months_since_first
    FROM fact_sales f
    JOIN first_purchase fp ON f.customer_id = fp.customer_id
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    cs.cohort_size,
    ca.months_since_first AS month_n,
    COUNT(DISTINCT ca.customer_id) AS active_customers,
    ROUND(COUNT(DISTINCT ca.customer_id) * 100.0 / cs.cohort_size, 1) AS retention_pct
FROM customer_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
WHERE ca.months_since_first BETWEEN 0 AND 11
GROUP BY ca.cohort_month, cs.cohort_size, ca.months_since_first
ORDER BY ca.cohort_month, ca.months_since_first;


-- 2. Customer Lifetime Value (CLV) by Segment
WITH customer_metrics AS (
    SELECT
        f.customer_id,
        c.segment,
        c.country_code,
        MIN(f.invoice_date) AS first_order,
        MAX(f.invoice_date) AS last_order,
        COUNT(DISTINCT f.invoice_id) AS total_orders,
        SUM(f.line_total) AS total_revenue,
        SUM(f.line_total - f.cost_total) AS total_profit,
        AVG(f.line_total) AS avg_order_value,
        julianday(MAX(f.invoice_date)) - julianday(MIN(f.invoice_date)) AS customer_lifespan_days
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_id = c.customer_id
    GROUP BY f.customer_id, c.segment, c.country_code
)
SELECT
    segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_revenue), 2) AS avg_clv,
    ROUND(AVG(total_orders), 1) AS avg_orders,
    ROUND(AVG(avg_order_value), 2) AS avg_order_value,
    ROUND(AVG(total_profit), 2) AS avg_profit_per_customer,
    ROUND(AVG(customer_lifespan_days), 0) AS avg_lifespan_days
FROM customer_metrics
GROUP BY segment
ORDER BY avg_clv DESC;


-- 3. RFM Segmentation (Recency, Frequency, Monetary)
WITH rfm_base AS (
    SELECT
        f.customer_id,
        c.customer_name,
        c.segment,
        julianday('2025-06-30') - julianday(MAX(f.invoice_date)) AS recency_days,
        COUNT(DISTINCT f.invoice_id) AS frequency,
        SUM(f.line_total) AS monetary
    FROM fact_sales f
    JOIN dim_customer c ON f.customer_id = c.customer_id
    GROUP BY f.customer_id, c.customer_name, c.segment
),
rfm_scored AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_base
)
SELECT
    customer_id,
    customer_name,
    segment,
    ROUND(recency_days, 0) AS recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary,
    r_score || f_score || m_score AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
        ELSE 'Needs Attention'
    END AS rfm_segment
FROM rfm_scored
ORDER BY monetary DESC
LIMIT 50;


-- 4. Customer Churn Detection
WITH customer_activity AS (
    SELECT
        customer_id,
        MAX(invoice_date) AS last_purchase,
        COUNT(DISTINCT invoice_id) AS total_orders,
        SUM(line_total) AS total_spent,
        julianday('2025-06-30') - julianday(MAX(invoice_date)) AS days_since_last
    FROM fact_sales
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN days_since_last <= 30 THEN 'Active (0-30 days)'
        WHEN days_since_last <= 90 THEN 'Warm (31-90 days)'
        WHEN days_since_last <= 180 THEN 'Cooling (91-180 days)'
        WHEN days_since_last <= 365 THEN 'At Risk (181-365 days)'
        ELSE 'Churned (365+ days)'
    END AS status,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spent), 2) AS avg_revenue,
    ROUND(SUM(total_spent), 2) AS total_revenue_at_risk
FROM customer_activity
GROUP BY
    CASE
        WHEN days_since_last <= 30 THEN 'Active (0-30 days)'
        WHEN days_since_last <= 90 THEN 'Warm (31-90 days)'
        WHEN days_since_last <= 180 THEN 'Cooling (91-180 days)'
        WHEN days_since_last <= 365 THEN 'At Risk (181-365 days)'
        ELSE 'Churned (365+ days)'
    END
ORDER BY MIN(days_since_last);
