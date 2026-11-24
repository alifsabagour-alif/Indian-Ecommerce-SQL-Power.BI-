-- =====================================================================
-- 03_data_quality_checks.sql   |   PostgreSQL
-- Run these after loading. Every check should return 0 problem rows,
-- except the ones marked "EXPECTED" which document known data quirks.
-- =====================================================================
SET search_path TO ecom;

-- 1. Duplicate primary keys (should be 0 - PKs already enforce this)
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_orders FROM orders;

-- 2. NULL checks on important columns (should be 0)
SELECT SUM((customer_id IS NULL)::int)              AS null_customer,
       SUM((order_purchase_timestamp IS NULL)::int) AS null_purchase_date
FROM orders;

-- 3. Orders with no items / no payment (should be 0)
SELECT COUNT(*) AS orders_without_items
FROM orders o LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL;

SELECT COUNT(*) AS orders_without_payment
FROM orders o LEFT JOIN payments p ON p.order_id = o.order_id
WHERE p.order_id IS NULL;

-- 4. Payment value must equal SUM(price + freight) of the order (should be 0 mismatches)
SELECT COUNT(*) AS payment_mismatch
FROM (
    SELECT o.order_id, p.payment_value, SUM(oi.price + oi.freight_value) AS items_total
    FROM orders o
    JOIN payments p     ON p.order_id = o.order_id
    JOIN order_items oi ON oi.order_id = o.order_id
    GROUP BY o.order_id, p.payment_value
    HAVING ABS(p.payment_value - SUM(oi.price + oi.freight_value)) > 0.05
) x;

-- 5. Dates that don't make sense (should be 0)
SELECT COUNT(*) AS delivered_before_purchase
FROM orders WHERE order_delivered_customer_date < order_purchase_timestamp;

-- 6. Delivered date should exist only for delivered orders (should be 0)
SELECT COUNT(*) AS wrong_delivery_dates
FROM orders
WHERE (order_status = 'delivered' AND order_delivered_customer_date IS NULL)
   OR (order_status <> 'delivered' AND order_delivered_customer_date IS NOT NULL);

-- 7. Returns only for delivered orders (should be 0)
SELECT COUNT(*) AS returns_on_non_delivered
FROM returns r JOIN orders o ON o.order_id = r.order_id
WHERE o.order_status <> 'delivered';

-- 8. Returned product must be part of the order (should be 0)
SELECT COUNT(*) AS returns_product_not_in_order
FROM returns r
LEFT JOIN order_items oi ON oi.order_id = r.order_id AND oi.product_id = r.product_id
WHERE oi.order_id IS NULL;

-- 9. EXPECTED: delivered orders with a FAILED payment (business conflict, 313 rows).
--    These are excluded from revenue (see is_valid_sale).
SELECT COUNT(*) AS delivered_but_payment_failed
FROM orders o JOIN payments p ON p.order_id = o.order_id
WHERE o.order_status = 'delivered' AND p.payment_status = 'failed';

-- 10. EXPECTED: canceled orders are all marked 'refunded' in payments (312) or approved (140)
SELECT o.order_status, p.payment_status, COUNT(*) AS orders
FROM orders o JOIN payments p ON p.order_id = o.order_id
WHERE o.order_status = 'canceled'
GROUP BY o.order_status, p.payment_status;

-- 11. EXPECTED: same order + product returned twice with different reasons (1 pair)
SELECT order_id, product_id, COUNT(*) AS return_requests
FROM returns GROUP BY order_id, product_id HAVING COUNT(*) > 1;
