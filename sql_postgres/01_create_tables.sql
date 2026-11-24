-- =====================================================================
-- 01_create_tables.sql   |   PostgreSQL 13+
-- Creates a schema and all 7 tables with primary & foreign keys.
-- Run order: 01 -> 02 -> 03 -> 04 -> 05   (use psql or pgAdmin's Query Tool)
-- Tip: create an empty database first (e.g. CREATE DATABASE ecom_india;) and connect to it.
-- =====================================================================
DROP SCHEMA IF EXISTS ecom CASCADE;
CREATE SCHEMA ecom;
SET search_path TO ecom;   -- every table below is created inside the 'ecom' schema

-- ---------- Dimension-like tables ----------
CREATE TABLE customers (
    customer_id               CHAR(32)    PRIMARY KEY,
    customer_unique_id        CHAR(32)    NOT NULL,
    customer_zip_code_prefix  INT,
    customer_city             VARCHAR(50),
    customer_state            CHAR(2)
);

CREATE TABLE sellers (
    seller_id               CHAR(32)    PRIMARY KEY,
    seller_zip_code_prefix  INT,
    seller_city             VARCHAR(50),
    seller_state            CHAR(2)
);

CREATE TABLE products (
    product_id             CHAR(32)     PRIMARY KEY,
    product_category_name  VARCHAR(50),
    product_weight_g       INT,
    product_length_cm      INT,
    product_height_cm      INT,
    product_width_cm       INT
);

-- ---------- Fact-like tables ----------
CREATE TABLE orders (
    order_id                       CHAR(32)    PRIMARY KEY,
    customer_id                    CHAR(32)    NOT NULL,
    order_purchase_timestamp       TIMESTAMP    NOT NULL,
    order_status                   VARCHAR(20) NOT NULL,
    order_approved_at              TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP,
    delivery_days                  INT,          -- calendar days: delivered - purchase
    delay_days                     INT,          -- calendar days: delivered - estimated (>0 = late)
    is_late                        SMALLINT,      -- 1 = delivered after estimate
    purchase_year                  INT,
    purchase_month                 INT,
    order_year_month               CHAR(7),      -- e.g. 2023-10
    is_valid_sale                  SMALLINT,      -- 1 = delivered AND payment approved
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_id             CHAR(32)       NOT NULL,
    order_item_id        INT            NOT NULL,
    product_id           CHAR(32)       NOT NULL,
    seller_id            CHAR(32)       NOT NULL,
    shipping_limit_date  TIMESTAMP,
    price                DECIMAL(12,2)  NOT NULL,
    freight_value        DECIMAL(10,2)  NOT NULL,
    line_total           DECIMAL(12,2)  NOT NULL,   -- price + freight_value
    PRIMARY KEY (order_id, order_item_id),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (seller_id)  REFERENCES sellers(seller_id)
);

CREATE TABLE payments (
    payment_id            CHAR(32)       PRIMARY KEY,
    order_id              CHAR(32)       NOT NULL,
    payment_method        VARCHAR(20),
    payment_value         DECIMAL(12,2),
    payment_installments  INT,
    payment_status        VARCHAR(20),
    FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

CREATE TABLE returns (
    return_id               CHAR(32)     PRIMARY KEY,
    order_id                CHAR(32)     NOT NULL,
    product_id              CHAR(32)     NOT NULL,
    return_reason           VARCHAR(30),
    return_requested_date   TIMESTAMP,
    return_resolved_date    TIMESTAMP,                 -- NULL while return is pending
    return_status           VARCHAR(20),
    resolution_type         VARCHAR(30),
    return_resolution_days  INT,
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ---------- Indexes to make JOINs faster ----------
CREATE INDEX idx_orders_customer  ON orders(customer_id);
CREATE INDEX idx_orders_month     ON orders(order_year_month);
CREATE INDEX idx_items_product    ON order_items(product_id);
CREATE INDEX idx_items_seller     ON order_items(seller_id);
CREATE INDEX idx_payments_order   ON payments(order_id);
CREATE INDEX idx_returns_order    ON returns(order_id, product_id);
