-- =====================================================================
-- 04_analysis_queries.sql   |   MySQL 8.0+   |   Level: basic -> medium
-- Business questions answered with SQL on the ecom_india database.
--
-- KEY BUSINESS RULES (used everywhere below)
--   * "Valid sale"  = order_status = 'delivered' AND payment_status = 'approved'
--                     (stored as orders.is_valid_sale = 1)
--   * Revenue       = SUM(order_items.price) of valid sales (freight shown separately)
--   * AOV           = Revenue / number of valid orders
--   * Return rate   = return requests / delivered order lines
-- =====================================================================
USE ecom_india;

-- #####################################################################
-- SECTION A : BUSINESS OVERVIEW
-- #####################################################################

-- Q1. How many orders are in each status?  (basic: GROUP BY)
SELECT order_status,
       COUNT(*)                                         AS orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- Q2. Headline KPIs  (basic: JOIN + aggregates)
SELECT COUNT(DISTINCT o.order_id)                              AS valid_orders,
       COUNT(DISTINCT o.customer_id)                           AS active_customers,
       COUNT(*)                                                AS items_sold,
       ROUND(SUM(oi.price), 2)                                 AS revenue,
       ROUND(SUM(oi.freight_value), 2)                         AS freight_collected,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2)    AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.is_valid_sale = 1;

-- #####################################################################
-- SECTION B : SALES TREND OVER TIME
-- #####################################################################

-- Q3. Monthly revenue and orders  (basic)
SELECT o.order_year_month,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2)    AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.is_valid_sale = 1
GROUP BY o.order_year_month
ORDER BY o.order_year_month;

-- Q4. Month-over-month revenue growth %  (medium: CTE + LAG window function)
WITH monthly AS (
    SELECT o.order_year_month AS ym, SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.is_valid_sale = 1
    GROUP BY o.order_year_month
)
SELECT ym,
       ROUND(revenue, 2) AS revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY ym))
                 / LAG(revenue) OVER (ORDER BY ym), 2) AS mom_growth_pct
FROM monthly
ORDER BY ym;

-- Q5. Year-over-year comparison  (medium: CTE + self join)
WITH yearly AS (
    SELECT o.purchase_year AS yr,
           COUNT(DISTINCT o.order_id) AS orders,
           SUM(oi.price)              AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.is_valid_sale = 1
    GROUP BY o.purchase_year
)
SELECT cur.yr,
       cur.orders,
       ROUND(cur.revenue, 2) AS revenue,
       ROUND(100 * (cur.revenue - prev.revenue) / prev.revenue, 2) AS revenue_yoy_pct
FROM yearly cur
LEFT JOIN yearly prev ON prev.yr = cur.yr - 1
ORDER BY cur.yr;

-- Q6. How much of the yearly revenue comes from the festive months (Oct + Nov)?
SELECT o.purchase_year,
       ROUND(SUM(CASE WHEN o.purchase_month IN (10, 11) THEN oi.price ELSE 0 END), 2) AS festive_revenue,
       ROUND(SUM(oi.price), 2)                                                         AS total_revenue,
       ROUND(100 * SUM(CASE WHEN o.purchase_month IN (10, 11) THEN oi.price ELSE 0 END)
                 / SUM(oi.price), 2)                                                   AS festive_share_pct
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.is_valid_sale = 1
GROUP BY o.purchase_year
ORDER BY o.purchase_year;

-- Q7. Which weekday and which hour do customers order the most?  (basic date functions)
SELECT DAYNAME(order_purchase_timestamp) AS weekday,
       COUNT(*)                          AS orders
FROM orders
GROUP BY DAYNAME(order_purchase_timestamp), DAYOFWEEK(order_purchase_timestamp)
ORDER BY DAYOFWEEK(order_purchase_timestamp);

SELECT HOUR(order_purchase_timestamp) AS hour_of_day,
       COUNT(*)                       AS orders
FROM orders
GROUP BY HOUR(order_purchase_timestamp)
ORDER BY hour_of_day;

-- #####################################################################
-- SECTION C : PRODUCTS & CATEGORIES
-- #####################################################################

-- Q8. Revenue, units and average price by category  (basic)
SELECT p.product_category_name       AS category,
       COUNT(*)                      AS units_sold,
       ROUND(SUM(oi.price), 2)       AS revenue,
       ROUND(AVG(oi.price), 2)       AS avg_price
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.is_valid_sale = 1
GROUP BY p.product_category_name
ORDER BY revenue DESC;

-- Q9. Pareto: running % of revenue by category  (medium: window SUM OVER)
WITH cat AS (
    SELECT p.product_category_name AS category, SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.is_valid_sale = 1
    GROUP BY p.product_category_name
)
SELECT category,
       ROUND(revenue, 2) AS revenue,
       ROUND(100 * revenue / SUM(revenue) OVER (), 2)                               AS pct_of_total,
       ROUND(100 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 2) AS cumulative_pct
FROM cat
ORDER BY revenue DESC;

-- Q10. Top 10 products by revenue  (basic)
SELECT oi.product_id,
       p.product_category_name AS category,
       COUNT(*)                AS units_sold,
       ROUND(SUM(oi.price), 2) AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.is_valid_sale = 1
GROUP BY oi.product_id, p.product_category_name
ORDER BY revenue DESC
LIMIT 10;

-- Q11. Best-selling category in every year  (medium: RANK per group)
WITH cat_year AS (
    SELECT o.purchase_year AS yr, p.product_category_name AS category, SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.is_valid_sale = 1
    GROUP BY o.purchase_year, p.product_category_name
), ranked AS (
    SELECT *, RANK() OVER (PARTITION BY yr ORDER BY revenue DESC) AS rnk
    FROM cat_year
)
SELECT yr, rnk, category, ROUND(revenue, 2) AS revenue
FROM ranked
WHERE rnk <= 3
ORDER BY yr, rnk;

-- #####################################################################
-- SECTION D : CUSTOMERS & GEOGRAPHY
-- #####################################################################

-- Q12. Revenue by customer state (top 10)  (basic)
SELECT c.customer_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2)    AS revenue
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.is_valid_sale = 1
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;

-- Q13. Revenue by customer city (top 10)
SELECT c.customer_city, c.customer_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2)    AS revenue
FROM orders o
JOIN customers c    ON c.customer_id = o.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.is_valid_sale = 1
GROUP BY c.customer_city, c.customer_state
ORDER BY revenue DESC
LIMIT 10;

-- Q14. One-time vs repeat customers  (medium: subquery / CTE)
WITH cust_orders AS (
    SELECT customer_id, COUNT(*) AS valid_orders
    FROM orders
    WHERE is_valid_sale = 1
    GROUP BY customer_id
)
SELECT CASE WHEN valid_orders = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
       COUNT(*)                                                       AS customers,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)               AS pct_customers,
       SUM(valid_orders)                                              AS orders
FROM cust_orders
GROUP BY customer_type;

-- Q15. Top 10 customers by lifetime spend  (medium: DENSE_RANK)
SELECT *
FROM (
    SELECT o.customer_id,
           COUNT(DISTINCT o.order_id) AS orders,
           ROUND(SUM(oi.price), 2)    AS total_spent,
           DENSE_RANK() OVER (ORDER BY SUM(oi.price) DESC) AS spend_rank
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.is_valid_sale = 1
    GROUP BY o.customer_id
) t
WHERE spend_rank <= 10
ORDER BY spend_rank;

-- Q16. RFM-lite customer segments  (medium: NTILE + CASE)
--   R = days since last order (lower is better)  F = number of orders  M = money spent
--   Reference date = day after the last order in the data (so the query never changes).
WITH rfm_base AS (
    SELECT o.customer_id,
           DATEDIFF((SELECT MAX(order_purchase_timestamp) FROM orders) + INTERVAL 1 DAY,
                    MAX(o.order_purchase_timestamp)) AS recency_days,
           COUNT(DISTINCT o.order_id)                AS frequency,
           SUM(oi.price)                             AS monetary
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.is_valid_sale = 1
    GROUP BY o.customer_id
), rfm_score AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY recency_days DESC, customer_id) AS r_score,   -- 4 = most recent (customer_id breaks ties)
           NTILE(4) OVER (ORDER BY frequency, customer_id)         AS f_score,
           NTILE(4) OVER (ORDER BY monetary, customer_id)          AS m_score
    FROM rfm_base
)
SELECT CASE
           WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions'
           WHEN f_score >= 3 AND m_score >= 3                  THEN 'Loyal / big spenders'
           WHEN r_score >= 3                                   THEN 'Recent customers'
           WHEN r_score = 1 AND (f_score >= 3 OR m_score >= 3) THEN 'At risk (was good, now quiet)'
           ELSE 'Others'
       END                       AS segment,
       COUNT(*)                  AS customers,
       ROUND(SUM(monetary), 2)   AS revenue,
       ROUND(AVG(monetary), 2)   AS avg_spend
FROM rfm_score
GROUP BY segment
ORDER BY revenue DESC;

-- #####################################################################
-- SECTION E : SELLERS
-- #####################################################################

-- Q17. Top 10 sellers by revenue  (basic)
SELECT s.seller_id, s.seller_city, s.seller_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price), 2)    AS revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN sellers s      ON s.seller_id = oi.seller_id
WHERE o.is_valid_sale = 1
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY revenue DESC
LIMIT 10;

-- Q18. Seller concentration: what share of revenue comes from the top 10% of sellers?
WITH seller_rev AS (
    SELECT oi.seller_id, SUM(oi.price) AS revenue
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.is_valid_sale = 1
    GROUP BY oi.seller_id
), ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY revenue DESC) AS decile
    FROM seller_rev
)
SELECT decile,
       COUNT(*)                                          AS sellers,
       ROUND(SUM(revenue), 2)                            AS revenue,
       ROUND(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS pct_of_revenue
FROM ranked
GROUP BY decile
ORDER BY decile;

-- #####################################################################
-- SECTION F : DELIVERY PERFORMANCE
-- #####################################################################

-- Q19. Average delivery time and % of late deliveries by customer state  (basic)
SELECT c.customer_state,
       COUNT(*)                        AS delivered_orders,
       ROUND(AVG(o.delivery_days), 2)  AS avg_delivery_days,
       ROUND(100 * AVG(o.is_late), 2)  AS late_pct
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
HAVING COUNT(*) >= 100
ORDER BY late_pct DESC;

-- Q20. Late-delivery % by month  (basic)
SELECT order_year_month,
       COUNT(*)                       AS delivered_orders,
       ROUND(100 * AVG(is_late), 2)   AS late_pct
FROM orders
WHERE order_status = 'delivered'
GROUP BY order_year_month
ORDER BY order_year_month;

-- #####################################################################
-- SECTION G : PAYMENTS
-- #####################################################################

-- Q21. Payment method mix: orders, value, share  (basic)
SELECT p.payment_method,
       COUNT(*)                                          AS orders,
       ROUND(SUM(p.payment_value), 2)                    AS payment_value,
       ROUND(AVG(p.payment_value), 2)                    AS avg_payment,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct_of_orders
FROM payments p
GROUP BY p.payment_method
ORDER BY orders DESC;

-- Q22. Failed-payment rate by method  (basic: conditional aggregation)
SELECT payment_method,
       COUNT(*)                                                        AS payments,
       SUM(payment_status = 'failed')                                  AS failed,
       ROUND(100 * SUM(payment_status = 'failed') / COUNT(*), 2)       AS failed_pct
FROM payments
GROUP BY payment_method
ORDER BY failed_pct DESC;

-- Q23. Does a high basket value push customers to EMI?  (basic: CASE buckets)
SELECT CASE WHEN payment_value < 5000   THEN '1. Under 5k'
            WHEN payment_value < 20000  THEN '2. 5k - 20k'
            WHEN payment_value < 50000  THEN '3. 20k - 50k'
            ELSE                             '4. 50k +' END AS order_value_band,
       COUNT(*)                                               AS orders,
       ROUND(100 * SUM(payment_method = 'EMI') / COUNT(*), 2) AS emi_pct
FROM payments
GROUP BY order_value_band
ORDER BY order_value_band;

-- Q24. Cancellation rate by payment method  (medium: JOIN + conditional aggregation)
SELECT p.payment_method,
       COUNT(*)                                                         AS orders,
       SUM(o.order_status = 'canceled')                                 AS canceled,
       ROUND(100 * SUM(o.order_status = 'canceled') / COUNT(*), 2)      AS cancel_pct
FROM orders o
JOIN payments p ON p.order_id = o.order_id
GROUP BY p.payment_method
ORDER BY cancel_pct DESC;

-- #####################################################################
-- SECTION H : RETURNS
-- #####################################################################

-- Q25. Why do customers return products?  (basic)
SELECT return_reason,
       COUNT(*)                                          AS returns,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct_of_returns
FROM returns
GROUP BY return_reason
ORDER BY returns DESC;

-- Q26. Return rate by category = return requests / delivered units  (medium: two CTEs)
WITH units AS (
    SELECT p.product_category_name AS category, COUNT(*) AS delivered_units
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p     ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_category_name
), rets AS (
    SELECT p.product_category_name AS category, COUNT(*) AS return_requests
    FROM returns r
    JOIN products p ON p.product_id = r.product_id
    GROUP BY p.product_category_name
)
SELECT u.category, u.delivered_units, r.return_requests,
       ROUND(100 * r.return_requests / u.delivered_units, 2) AS return_rate_pct
FROM units u
JOIN rets r ON r.category = u.category
ORDER BY return_rate_pct DESC;

-- Q27. Top return reason inside each category  (medium: ROW_NUMBER per group)
WITH cat_reason AS (
    SELECT p.product_category_name AS category, r.return_reason, COUNT(*) AS returns
    FROM returns r JOIN products p ON p.product_id = r.product_id
    GROUP BY p.product_category_name, r.return_reason
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY category ORDER BY returns DESC) AS rn
    FROM cat_reason
)
SELECT category, return_reason AS top_reason, returns
FROM ranked
WHERE rn = 1
ORDER BY returns DESC;

-- Q28. Do late deliveries cause more returns?  (medium)
SELECT CASE WHEN o.is_late = 1 THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(DISTINCT o.order_id)                              AS delivered_orders,
       COUNT(DISTINCT r.order_id)                              AS orders_with_return,
       ROUND(100 * COUNT(DISTINCT r.order_id) / COUNT(DISTINCT o.order_id), 2) AS orders_returned_pct
FROM orders o
LEFT JOIN returns r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY delivery;

-- Q29. How are return requests resolved, and how fast?  (basic)
SELECT return_status, resolution_type,
       COUNT(*)                            AS returns,
       ROUND(AVG(return_resolution_days),1) AS avg_days_to_resolve
FROM returns
GROUP BY return_status, resolution_type
ORDER BY return_status, returns DESC;

-- Q30. Seller return rate  (medium/advanced)
--   The returns table has no seller_id, so each return is attributed to the FIRST
--   matching order line (order_id + product_id) using ROW_NUMBER().
WITH matched AS (
    SELECT r.return_id, oi.seller_id,
           ROW_NUMBER() OVER (PARTITION BY r.return_id ORDER BY oi.order_item_id) AS rn
    FROM returns r
    JOIN order_items oi ON oi.order_id = r.order_id AND oi.product_id = r.product_id
), seller_returns AS (
    SELECT seller_id, COUNT(*) AS return_requests FROM matched WHERE rn = 1 GROUP BY seller_id
), seller_units AS (
    SELECT oi.seller_id, COUNT(*) AS delivered_units
    FROM orders o JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)
SELECT u.seller_id, u.delivered_units, COALESCE(r.return_requests, 0) AS return_requests,
       ROUND(100 * COALESCE(r.return_requests, 0) / u.delivered_units, 2) AS return_rate_pct
FROM seller_units u
LEFT JOIN seller_returns r ON r.seller_id = u.seller_id
WHERE u.delivered_units >= 30      -- ignore sellers with very few sales
ORDER BY return_rate_pct DESC
LIMIT 10;
