-- =====================================================================
-- 02_load_data.sql   |   PostgreSQL
-- Loads the cleaned CSVs (data/cleaned/) using psql's \copy command.
--
-- HOW TO RUN (psql only - \copy is a psql command, it does not work in pgAdmin's Query Tool):
--   1. Open a terminal inside the project folder (so the relative paths below work), then:
--        psql -U postgres -d ecom_india -f sql_postgres/02_load_data.sql
--   2. pgAdmin users: right-click each table > Import/Export Data > choose the CSV,
--      Format = csv, Header = Yes, and load in this order:
--      customers, sellers, products, orders, order_items, payments, returns.
--
-- Blank CSV cells are loaded as NULL automatically.
-- =====================================================================
SET search_path TO ecom;

\copy customers   FROM 'data/cleaned/customers.csv'   WITH (FORMAT csv, HEADER true)
\copy sellers     FROM 'data/cleaned/sellers.csv'     WITH (FORMAT csv, HEADER true)
\copy products    FROM 'data/cleaned/products.csv'    WITH (FORMAT csv, HEADER true)
\copy orders      FROM 'data/cleaned/orders.csv'      WITH (FORMAT csv, HEADER true)
\copy order_items FROM 'data/cleaned/order_items.csv' WITH (FORMAT csv, HEADER true)
\copy payments    FROM 'data/cleaned/payments.csv'    WITH (FORMAT csv, HEADER true)
\copy returns     FROM 'data/cleaned/returns.csv'     WITH (FORMAT csv, HEADER true)

-- Quick row-count check (expected: 6000, 900, 1500, 16091, 24986, 16091, 1891)
SELECT 'customers' AS tbl, COUNT(*) AS rows_loaded FROM customers UNION ALL
SELECT 'sellers',     COUNT(*) FROM sellers      UNION ALL
SELECT 'products',    COUNT(*) FROM products     UNION ALL
SELECT 'orders',      COUNT(*) FROM orders       UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items  UNION ALL
SELECT 'payments',    COUNT(*) FROM payments     UNION ALL
SELECT 'returns',     COUNT(*) FROM returns;
