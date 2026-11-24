# Data Dictionary

Dataset: [ShopIN - Synthetic Indian E-Commerce Dataset](https://www.kaggle.com/datasets/josephbenofficial/shopin) (Kaggle, CC0: Public Domain), orders from **1 Jan 2023 to 31 Dec 2024**. The data is synthetically generated.
Raw files are in `data/raw/`, cleaned files (used by SQL / Python / Excel / Power BI) in `data/cleaned/`.
Columns marked **(derived)** were added by `python/01_clean_data.py`.

## customers (6,000 rows) - one row per customer
| Column | Description |
|---|---|
| customer_id (PK) | Customer key used in orders |
| customer_unique_id | Unique person id (1-to-1 with customer_id in this dataset) |
| customer_zip_code_prefix | 3-digit PIN prefix |
| customer_city / customer_state | City and 2-letter state code (MH, KA, DL ...) |

## sellers (900 rows) - one row per seller
| Column | Description |
|---|---|
| seller_id (PK) | Seller key |
| seller_zip_code_prefix, seller_city, seller_state | Seller location |

## products (1,500 rows) - one row per product
| Column | Description |
|---|---|
| product_id (PK) | Product key |
| product_category_name | One of 25 categories (laptops, jewellery, fashion_women ...) |
| product_weight_g, product_length_cm, product_height_cm, product_width_cm | Physical size |

## orders (16,091 rows) - one row per order
| Column | Description |
|---|---|
| order_id (PK) | Order key |
| customer_id (FK) | Who placed the order |
| order_purchase_timestamp | When the order was placed |
| order_status | delivered, shipped, canceled, invoiced, processing, unavailable, approved |
| order_approved_at | Approval time (seconds precision) |
| order_delivered_customer_date | Delivery time (only for delivered orders) |
| order_estimated_delivery_date | Promised delivery date |
| delivery_days **(derived)** | Calendar days from purchase to delivery |
| delay_days **(derived)** | Calendar days delivered - promised (positive = late) |
| is_late **(derived)** | 1 if delivered after the promised day, 0 if on time, blank if not delivered |
| purchase_year, purchase_month, order_year_month **(derived)** | Date parts, e.g. 2024-10 |
| is_valid_sale **(derived)** | 1 if order is `delivered` AND payment is `approved`. This is the revenue filter. |

Removed column: `delivery_date_raw` (incomplete duplicate of the delivered date).

## order_items (24,986 rows) - one row per product line in an order
| Column | Description |
|---|---|
| order_id, order_item_id (composite PK) | Line number inside the order (1-3) |
| product_id, seller_id (FK) | What was sold and by whom |
| shipping_limit_date | Seller's shipping deadline |
| price | Item price in INR |
| freight_value | Shipping charge in INR |
| line_total **(derived)** | price + freight_value |

## payments (16,091 rows) - exactly one payment per order
| Column | Description |
|---|---|
| payment_id (PK), order_id (FK) | Keys |
| payment_method | UPI, COD, EMI, Credit Card, Debit Card, NetBanking, Wallet |
| payment_value | Amount in INR. Always equals SUM(price + freight_value) of the order |
| payment_installments | 1 for all methods except EMI (3-12) |
| payment_status | approved, failed, refunded |

## returns (1,891 rows) - one row per return request
| Column | Description |
|---|---|
| return_id (PK), order_id, product_id (FK) | Which order and product was returned |
| return_reason | Size issue, Defective, Wrong item, Changed mind, Damaged, Late delivery |
| return_requested_date, return_resolved_date | Request and resolution time (resolved blank while pending) |
| return_status | approved, rejected, pending |
| resolution_type | Refund, Replacement, Store credit, or `Not applicable` (rejected returns) |
| return_resolution_days **(derived)** | Calendar days to resolve |

## Relationships
```
customers 1--* orders 1--* order_items *--1 products
                  |  \                 *--1 sellers
                  |   1--1 payments
                  1--* returns *--1 products
```
