-- =====================================================================
-- 05_views_for_powerbi.sql   |   PostgreSQL
-- Reusable views. In Power BI use  Get Data > PostgreSQL database  and pick
-- these views (or just import the CSVs from data/cleaned/ if you prefer).
-- =====================================================================
SET search_path TO ecom;

-- One row per order line, enriched with product, seller, customer and order info
CREATE OR REPLACE VIEW vw_sales_detail AS
SELECT oi.order_id,
       oi.order_item_id,
       DATE(o.order_purchase_timestamp) AS order_date,
       o.order_year_month,
       o.purchase_year,
       o.purchase_month,
       o.order_status,
       o.is_valid_sale,
       o.delivery_days,
       o.delay_days,
       o.is_late,
       c.customer_id,
       c.customer_city,
       c.customer_state,
       p.product_id,
       p.product_category_name,
       s.seller_id,
       s.seller_city,
       s.seller_state,
       pay.payment_method,
       pay.payment_status,
       pay.payment_installments,
       oi.price,
       oi.freight_value,
       oi.line_total
FROM order_items oi
JOIN orders    o   ON o.order_id    = oi.order_id
JOIN customers c   ON c.customer_id = o.customer_id
JOIN products  p   ON p.product_id  = oi.product_id
JOIN sellers   s   ON s.seller_id   = oi.seller_id
JOIN payments  pay ON pay.order_id  = oi.order_id;

-- One row per return, with product category and customer state
CREATE OR REPLACE VIEW vw_returns_detail AS
SELECT r.return_id,
       r.order_id,
       DATE(r.return_requested_date) AS return_date,
       r.return_reason,
       r.return_status,
       r.resolution_type,
       r.return_resolution_days,
       p.product_category_name,
       c.customer_state
FROM returns r
JOIN products  p ON p.product_id  = r.product_id
JOIN orders    o ON o.order_id    = r.order_id
JOIN customers c ON c.customer_id = o.customer_id;

-- Monthly KPI table (handy for quick line charts)
CREATE OR REPLACE VIEW vw_monthly_kpis AS
SELECT o.order_year_month,
       COUNT(DISTINCT o.order_id)                           AS valid_orders,
       ROUND(SUM(oi.price), 2)                              AS revenue,
       ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.is_valid_sale = 1
GROUP BY o.order_year_month;
