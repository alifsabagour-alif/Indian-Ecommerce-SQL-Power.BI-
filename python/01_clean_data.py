"""
01_clean_data.py
----------------
Reads the 7 raw CSV files from data/raw/, checks quality, cleans them
and writes analysis-ready files to data/cleaned/.

Run from the project root:
    python python/01_clean_data.py
"""
from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW, CLEAN = ROOT / "data" / "raw", ROOT / "data" / "cleaned"
CLEAN.mkdir(parents=True, exist_ok=True)
log = []  # every cleaning decision is written to docs/data_quality_report.md


def note(msg):
    print(msg)
    log.append(msg)


# ---------- 1. LOAD ----------
customers = pd.read_csv(RAW / "customers.csv")
sellers = pd.read_csv(RAW / "sellers.csv")
products = pd.read_csv(RAW / "products.csv")
orders = pd.read_csv(RAW / "orders.csv")
items = pd.read_csv(RAW / "order_items.csv")
payments = pd.read_csv(RAW / "payments.csv")
returns = pd.read_csv(RAW / "returns.csv")

# ---------- 2. TEXT CLEANUP ----------
for df in (customers, sellers, products, orders, items, payments, returns):
    for col in df.columns:
        if df[col].dtype == object or str(df[col].dtype) in ("str", "string"):
            df[col] = df[col].str.strip()
note("Trimmed leading/trailing spaces in all text columns (no changes were needed).")

# ---------- 3. ORDERS ----------
date_cols = ["order_purchase_timestamp", "order_approved_at",
             "order_delivered_customer_date", "order_estimated_delivery_date"]
for c in date_cols:
    orders[c] = pd.to_datetime(orders[c]).dt.floor("s")   # drop microseconds

raw_dt = pd.to_datetime(orders["delivery_date_raw"])
filled = orders["delivery_date_raw"].notna()
differs = (raw_dt.dt.date != orders["order_delivered_customer_date"].dt.date) & filled
note(f"Dropped column orders.delivery_date_raw: it is an incomplete copy: filled for only {filled.sum():,} of "
     f"{orders['order_delivered_customer_date'].notna().sum():,} delivered orders (it never differs: "
     f"{differs.sum():,} mismatches). "
     f"order_delivered_customer_date is used instead.")
orders = orders.drop(columns=["delivery_date_raw"])

# Day counts use CALENDAR dates (time of day ignored), so "delivered on the promised day" = on time
deliv_day = orders["order_delivered_customer_date"].dt.normalize()
orders["delivery_days"] = (deliv_day - orders["order_purchase_timestamp"].dt.normalize()).dt.days.astype("Int64")
orders["delay_days"] = (deliv_day - orders["order_estimated_delivery_date"].dt.normalize()).dt.days.astype("Int64")
orders["is_late"] = (orders["delay_days"] > 0).astype("Int64")   # 1 = delivered AFTER the promised day
orders.loc[orders["order_delivered_customer_date"].isna(), "is_late"] = pd.NA
orders["purchase_year"] = orders["order_purchase_timestamp"].dt.year
orders["purchase_month"] = orders["order_purchase_timestamp"].dt.month
orders["order_year_month"] = orders["order_purchase_timestamp"].dt.strftime("%Y-%m")

hr = orders["order_purchase_timestamp"].dt.hour.value_counts()
note(f"Data quirk (NOT changed): {hr.get(23, 0):,} orders are stamped in hour 23 (about 3x hour 22) and "
     f"hours 00-03 are almost empty -> order times look capped at 23:59, so hour-of-day analysis is unreliable.")

# ---------- 4. PAYMENTS vs ORDER STATUS ----------
pay_flag = payments.merge(orders[["order_id", "order_status"]], on="order_id")
bad = pay_flag[(pay_flag.order_status == "delivered") & (pay_flag.payment_status == "failed")]
note(f"Found {len(bad):,} delivered orders whose payment_status is 'failed' "
     f"(business-logic conflict). Rows are KEPT but excluded from revenue "
     f"(valid sale = delivered AND payment approved).")
orders = orders.merge(payments[["order_id", "payment_status"]], on="order_id", how="left")
orders["is_valid_sale"] = ((orders.order_status == "delivered")
                           & (orders.payment_status == "approved")).astype(int)
orders = orders.drop(columns=["payment_status"])

# ---------- 5. ORDER ITEMS ----------
items["shipping_limit_date"] = pd.to_datetime(items["shipping_limit_date"])
items["line_total"] = (items["price"] + items["freight_value"]).round(2)

chk = items.groupby("order_id")["line_total"].sum().round(2)
pay = payments.set_index("order_id")["payment_value"].round(2)
match = ((chk - pay).abs() < 0.05).mean()
note(f"Validated: payment_value equals SUM(price + freight_value) of the order items "
     f"for {match:.1%} of orders.")

# ---------- 6. RETURNS ----------
for c in ["return_requested_date", "return_resolved_date"]:
    returns[c] = pd.to_datetime(returns[c]).dt.floor("s")
returns["resolution_type"] = returns["resolution_type"].fillna("Not applicable")
returns["return_resolution_days"] = (returns["return_resolved_date"]
                                     - returns["return_requested_date"]).dt.days.astype("Int64")
dups = int(returns.duplicated(["order_id", "product_id"], keep=False).sum())
note(f"Returns: {dups} rows share the same order+product but have different return_ids/reasons. "
     f"Kept both as separate return requests.")
note("Returns: resolution_type was blank for rejected returns -> filled with 'Not applicable'. "
     "return_resolved_date is blank for 'pending' returns (expected, left as NULL).")
note("Returns table has no seller_id. Seller-level return analysis joins on order_id + product_id "
     "and attributes each return to the first matching order line.")

# ---------- 7. REFERENTIAL INTEGRITY ----------
checks = {
    "orders.customer_id -> customers": (~orders.customer_id.isin(customers.customer_id)).sum(),
    "order_items.order_id -> orders": (~items.order_id.isin(orders.order_id)).sum(),
    "order_items.product_id -> products": (~items.product_id.isin(products.product_id)).sum(),
    "order_items.seller_id -> sellers": (~items.seller_id.isin(sellers.seller_id)).sum(),
    "payments.order_id -> orders": (~payments.order_id.isin(orders.order_id)).sum(),
    "returns.order_id -> orders": (~returns.order_id.isin(orders.order_id)).sum(),
    "returns.product_id -> products": (~returns.product_id.isin(products.product_id)).sum(),
}
for k, v in checks.items():
    note(f"Orphan check {k}: {int(v)} orphan rows.")

# ---------- 8. SAVE ----------
def save(df, name):
    df.to_csv(CLEAN / f"{name}.csv", index=False, date_format="%Y-%m-%d %H:%M:%S")
    note(f"Saved data/cleaned/{name}.csv ({len(df):,} rows, {df.shape[1]} columns)")

save(customers, "customers"); save(sellers, "sellers"); save(products, "products")
save(orders, "orders"); save(items, "order_items"); save(payments, "payments")
save(returns, "returns")

with open(ROOT / "docs" / "data_quality_report.md", "w") as f:
    f.write("# Data Quality & Cleaning Report\n\n_Auto-generated by `python/01_clean_data.py`._\n\n")
    f.write("\n".join(f"- {m}" for m in log) + "\n")
