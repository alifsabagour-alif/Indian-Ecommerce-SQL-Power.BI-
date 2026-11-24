# SQL - PostgreSQL version

Same 5 scripts as the MySQL folder (`sql/`), converted to **PostgreSQL 13+**. Both versions give **identical results**
(tested on PostgreSQL 16 and on a MySQL-compatible server: all 30 queries return the same rows).

## How to run
```bash
# 1. create an empty database once
createdb ecom_india            # or in psql:  CREATE DATABASE ecom_india;

# 2. run the scripts from the PROJECT ROOT folder (the \copy paths are relative)
psql -d ecom_india -f sql_postgres/01_create_tables.sql
psql -d ecom_india -f sql_postgres/02_load_data.sql
psql -d ecom_india -f sql_postgres/03_data_quality_checks.sql
psql -d ecom_india -f sql_postgres/04_analysis_queries.sql
psql -d ecom_india -f sql_postgres/05_views_for_powerbi.sql
```
Everything is created in a schema called `ecom`; each script starts with `SET search_path TO ecom;`.
If you use **pgAdmin**, run 01, 03, 04, 05 in the Query Tool, and load the CSVs for step 02 with
right-click table > *Import/Export Data* (Format csv, Header yes), in this order:
customers, sellers, products, orders, order_items, payments, returns.

## What changed from MySQL (good to know for interviews)
| MySQL | PostgreSQL |
|---|---|
| `CREATE DATABASE`, `USE db` | `CREATE SCHEMA`, `SET search_path TO ecom` |
| `TINYINT`, `DATETIME` | `SMALLINT`, `TIMESTAMP` |
| `LOAD DATA LOCAL INFILE` | `\copy ... WITH (FORMAT csv, HEADER true)` (blank cells become NULL automatically) |
| `SUM(status = 'failed')` (true/false counts as 1/0) | `SUM((status = 'failed')::int)` - booleans must be cast |
| `100 * a / b` (decimal result) | `100.0 * a / b` - integer / integer would cut the decimals in PostgreSQL |
| `DAYNAME()`, `DAYOFWEEK()`, `HOUR()` | `TO_CHAR(ts, 'Day')`, `EXTRACT(DOW FROM ts)`, `EXTRACT(HOUR FROM ts)` |
| `DATEDIFF(date1, date2)`, `+ INTERVAL 1 DAY` | `date1 - date2`, `+ 1` on a date |
