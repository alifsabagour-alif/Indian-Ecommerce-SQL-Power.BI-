# Power BI Dashboard Guide

This folder contains everything you need to build the dashboard in **Power BI Desktop (free)** in about 1-2 hours:
the data model, all DAX measures (`dax_measures.dax`), page layouts and a validation table to prove your numbers are right.

> Save your finished report as `powerbi/ecommerce_dashboard.pbix`. Dashboard screenshots (`powerbi_page1.png` to `powerbi_page6.png`) are in this folder.
> The steps below show how the report was built; the measures can also be created from `dax_measures.dax`.

## Step 1 - Load the data
1. Power BI Desktop > **Get data > Text/CSV** and load the 7 files from `data/cleaned/`
   (`customers, sellers, products, orders, order_items, payments, returns`). Click **Transform Data**.
2. In **Power Query** check the types:
   - `orders`: the 4 `order_*` timestamp columns -> Date/Time; `delivery_days`, `delay_days`, `is_late`, `is_valid_sale` -> Whole number
   - `order_items`: `price`, `freight_value`, `line_total` -> Fixed decimal number
   - `payments`: `payment_value` -> Fixed decimal number
   - `returns`: `return_requested_date`, `return_resolved_date` -> Date/Time
3. Add two helper columns (**Add Column > Custom Column**):
   - in `orders`: name `order_date`, formula `Date.From([order_purchase_timestamp])`
   - in `returns`: name `return_date`, formula `Date.From([return_requested_date])`
4. **Close & Apply**.

## Step 2 - Create the Date table and measures
Open `dax_measures.dax` and paste the `Date` table definition (Modeling > **New table**), then each measure (Modeling > **New measure**).
Create a separate empty table called `_Measures` (Home > Enter data) and put the measures there to keep the Fields pane tidy.

## Step 3 - Model view (relationships)
| From (one side) | To (many side) | Active? |
|---|---|---|
| customers[customer_id] | orders[customer_id] | Yes |
| orders[order_id] | order_items[order_id] | Yes |
| orders[order_id] | payments[order_id] | Yes (one-to-one) |
| products[product_id] | order_items[product_id] | Yes |
| sellers[seller_id] | order_items[seller_id] | Yes |
| products[product_id] | returns[product_id] | Yes |
| Date[Date] | orders[order_date] | Yes |
| orders[order_id] | returns[order_id] | **No (inactive)** |
| Date[Date] | returns[return_date] | **No (inactive)** |

Why are two relationships inactive? `orders -> order_items <- products -> returns <- orders` would form a loop, and Power BI
does not allow two active paths between the same tables. We keep `returns -> products` active because **return rate by category
is the most important return analysis**. Return-by-month uses the inactive Date relationship through the `Returns By Request Date`
measure (`USERELATIONSHIP`).

All relationships: single direction (the "one" side filters the "many" side).

Known limitation of this model: `Return Rate %` is only valid when sliced by **product / category** (or with no filter).
Do not slice it by month or state - use `Returns By Request Date` for monthly return counts.

## Step 4 - Build 4 report pages

**Page 1 - Executive Summary**
- Cards: `Revenue`, `Valid Orders`, `Avg Order Value`, `Active Customers`, `Revenue YoY %`
- Line chart: Date[Year-Month] x `Revenue` (add a second line: `Revenue LY` for the 2024 months)
- Clustered column: Date[Month] x `Revenue`, legend = Date[Year] (shows the Oct-Nov festive spike)
- Slicers: Date[Year], Date[Festive Season], customers[customer_state]

**Page 2 - Products, Customers & Sellers**
- Bar chart: products[product_category_name] x `Revenue` (top 10)
- Treemap: category x `Units Sold`
- Filled map / bar: customers[customer_state] x `Revenue`
- Donut: `Repeat Customers` vs one-time (use the `Repeat Customer %` card)
- Table: top 10 sellers (sellers[seller_id], seller_city, `Revenue`, `Valid Orders`)

**Page 3 - Delivery & Payments**
- Cards: `Late Delivery %`, `Avg Delivery Days`, `Cancel Rate %`, `Failed Payment %`
- Column chart: Date[Year-Month] x `Late Delivery %`
- Bar chart: payments[payment_method] x `Valid Orders` (or count of payments); second chart `Failed Payment %` by method
- Matrix: payment_method x order value band (create a calculated column on `payments` with `SWITCH(TRUE(), ...)`)

**Page 4 - Returns**
- Cards: `Return Requests`, `Return Rate %`, `Approved Returns %`, `Avg Days To Resolve`
- Bar chart: products[product_category_name] x `Return Rate %` (sort descending; conditional colour > 20%)
- Bar chart: returns[return_reason] x `Return Requests`
- Stacked column: returns[return_status] x `Return Requests`, legend = returns[resolution_type]
- Line chart: Date[Year-Month] x `Returns By Request Date`

Design tips: one colour theme (View > Themes), titles that state the insight ("Fashion has 3x the return rate"), the same slicer panel on every page (Sync slicers).

## Step 5 - Validation table (your numbers must match)
These values were computed independently in SQL (MySQL/MariaDB), Python and Excel and all three agree.
With **no filters** your measures must show:

| Measure | Expected value |
|---|---|
| Revenue | 287,167,340 (about ₹28.72 Cr) |
| Valid Orders | 13,808 |
| Avg Order Value | 20,797.17 |
| Units Sold | 21,420 |
| Active Customers | 5,642 |
| Freight Collected | 3,913,746.06 |
| Revenue 2023 / 2024 | 141,686,597 / 145,480,743 (YoY +2.68%) |
| Festive Revenue Share % | about 38.2% (38.3% in 2023, 38.1% in 2024) |
| Repeat Customers / % | 3,099 / 54.9% |
| Total Orders / Cancel Rate % | 16,091 / 2.81% |
| Delivered Orders / Late Delivery % | 14,121 / 52.48% |
| Avg Delivery Days | 7.77 |
| Failed Payment % | 2.19% (NetBanking 6.75%) |
| Return Requests | 1,891 |
| Delivered Units | 21,906 |
| Return Rate % | 8.63% (fashion_women 28.02%, fashion_men 26.85%, footwear 23.54%) |
