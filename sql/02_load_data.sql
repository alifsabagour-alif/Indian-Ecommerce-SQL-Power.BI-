-- =====================================================================
-- 02_load_data.sql
-- Loads the cleaned CSVs (data/cleaned/) into the tables.
-- Before running:
--   1. Edit the folder path below (use forward slashes, even on Windows).
--   2. Start the client with local_infile enabled:
--        mysql --local-infile=1 -u root -p
--      and run:  SET GLOBAL local_infile = 1;
--   (MySQL Workbench users: Edit Connection > Advanced > add
--    "OPT_LOCAL_INFILE=1" in "Others".)
-- =====================================================================
USE ecom_india;
SET FOREIGN_KEY_CHECKS = 0;

-- >>> CHANGE THE PATH <<<
-- LOAD DATA does not accept a variable for the file path, so use Find & Replace
-- to change  /FULL/PATH/TO/indian-ecommerce-analytics  to your own folder
-- in every statement below (e.g. C:/Users/Alif/Documents/indian-ecommerce-analytics).

LOAD DATA LOCAL INFILE '/FULL/PATH/TO/indian-ecommerce-analytics/data/cleaned/customers.csv'
INTO TABLE customers FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/FULL/PATH/TO/indian-ecommerce-analytics/data/cleaned/sellers.csv'
INTO TABLE sellers FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/FULL/PATH/TO/indian-ecommerce-analytics/data/cleaned/products.csv'
INTO TABLE products FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

-- Blank cells in the CSV become NULL using NULLIF(@var, '')
LOAD DATA LOCAL INFILE '/FULL/PATH/TO/indian-ecommerce-analytics/data/cleaned/orders.csv'
INTO TABLE orders FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, customer_id, order_purchase_timestamp, order_status, order_approved_at,
 @delivered, order_estimated_delivery_date, @deliv_days, @delay_days, @is_late,
 purchase_year, purchase_month, order_year_month, is_valid_sale)
SET order_delivered_customer_date = NULLIF(@delivered, ''),
    delivery_days = NULLIF(@deliv_days, ''),
    delay_days    = NULLIF(@delay_days, ''),
    is_late       = NULLIF(@is_late, '');

LOAD DATA LOCAL INFILE '/FULL/PATH/TO/indian-ecommerce-analytics/data/cleaned/order_items.csv'
INTO TABLE order_items FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/FULL/PATH/TO/indian-ecommerce-analytics/data/cleaned/payments.csv'
INTO TABLE payments FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES;

LOAD DATA LOCAL INFILE '/FULL/PATH/TO/indian-ecommerce-analytics/data/cleaned/returns.csv'
INTO TABLE returns FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(return_id, order_id, product_id, return_reason, return_requested_date,
 @resolved, return_status, resolution_type, @res_days)
SET return_resolved_date   = NULLIF(@resolved, ''),
    return_resolution_days = NULLIF(@res_days, '');

SET FOREIGN_KEY_CHECKS = 1;

-- Quick row-count check (expected: 6000, 900, 1500, 16091, 24986, 16091, 1891)
SELECT 'customers' AS tbl, COUNT(*) AS rows_loaded FROM customers UNION ALL
SELECT 'sellers',     COUNT(*) FROM sellers      UNION ALL
SELECT 'products',    COUNT(*) FROM products     UNION ALL
SELECT 'orders',      COUNT(*) FROM orders       UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items  UNION ALL
SELECT 'payments',    COUNT(*) FROM payments     UNION ALL
SELECT 'returns',     COUNT(*) FROM returns;
