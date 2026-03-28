-- ============================================================
-- PRODUCT ABC ANALYSIS & PERFORMANCE
-- Pareto classification, margin analysis, cross-sell patterns
-- ============================================================

-- 1. ABC Classification (Pareto Analysis)
WITH product_revenue AS (
    SELECT
        f.product_id,
        p.product_name,
        p.category,
        SUM(f.line_total) AS total_revenue,
        SUM(f.line_total - f.cost_total) AS total_margin,
        SUM(f.quantity) AS total_units,
        COUNT(DISTINCT f.invoice_id) AS order_count
    FROM fact_sales f
    JOIN dim_product p ON f.product_id = p.product_id
    GROUP BY f.product_id, p.product_name, p.category
),
ranked AS (
    SELECT
        *,
        SUM(total_revenue) OVER () AS grand_total,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS rank_num,
        COUNT(*) OVER () AS total_products
    FROM product_revenue
)
SELECT
    product_id,
    product_name,
    category,
    ROUND(total_revenue, 2) AS revenue,
    ROUND(total_margin, 2) AS margin,
    ROUND(total_margin * 100.0 / NULLIF(total_revenue, 0), 1) AS margin_pct,
    total_units,
    order_count,
    ROUND(cumulative_revenue * 100.0 / grand_total, 1) AS cumulative_pct,
    CASE
        WHEN cumulative_revenue * 100.0 / grand_total <= 80 THEN 'A'
        WHEN cumulative_revenue * 100.0 / grand_total <= 95 THEN 'B'
        ELSE 'C'
    END AS abc_class
FROM ranked
ORDER BY total_revenue DESC;


-- 2. Category Performance Summary
SELECT
    p.category,
    COUNT(DISTINCT f.product_id) AS products,
    SUM(f.line_total) AS revenue,
    SUM(f.line_total - f.cost_total) AS gross_profit,
    ROUND(SUM(f.line_total - f.cost_total) * 100.0 / NULLIF(SUM(f.line_total), 0), 1) AS margin_pct,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.line_total) * 1.0 / COUNT(DISTINCT f.invoice_id), 2) AS avg_order_value,
    RANK() OVER (ORDER BY SUM(f.line_total) DESC) AS revenue_rank
FROM fact_sales f
JOIN dim_product p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;


-- 3. Top Products per Category (Top-N per Group)
WITH ranked_products AS (
    SELECT
        p.category,
        p.product_name,
        SUM(f.line_total) AS revenue,
        SUM(f.quantity) AS units,
        ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(f.line_total) DESC) AS rank_in_category
    FROM fact_sales f
    JOIN dim_product p ON f.product_id = p.product_id
    GROUP BY p.category, p.product_name
)
SELECT category, product_name, ROUND(revenue, 2) AS revenue, units
FROM ranked_products
WHERE rank_in_category <= 5
ORDER BY category, rank_in_category;


-- 4. Product Cross-Sell Analysis (Market Basket)
WITH order_products AS (
    SELECT DISTINCT invoice_id, product_id
    FROM fact_sales
),
product_pairs AS (
    SELECT
        a.product_id AS product_a,
        b.product_id AS product_b,
        COUNT(DISTINCT a.invoice_id) AS co_occurrence
    FROM order_products a
    JOIN order_products b ON a.invoice_id = b.invoice_id AND a.product_id < b.product_id
    GROUP BY a.product_id, b.product_id
    HAVING COUNT(DISTINCT a.invoice_id) >= 5
)
SELECT
    pa.product_name AS product_a_name,
    pb.product_name AS product_b_name,
    pp.co_occurrence AS bought_together_count
FROM product_pairs pp
JOIN dim_product pa ON pp.product_a = pa.product_id
JOIN dim_product pb ON pp.product_b = pb.product_id
ORDER BY pp.co_occurrence DESC
LIMIT 20;
