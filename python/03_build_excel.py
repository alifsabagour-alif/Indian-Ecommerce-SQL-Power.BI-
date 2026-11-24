"""
03_build_excel.py
-----------------
Builds excel/ecommerce_analysis.xlsx from the cleaned CSVs.
All summary numbers are LIVE Excel formulas (SUMIFS / COUNTIFS) that read from the
Data_* sheets, so the workbook recalculates if the data changes.

Run from the project root:   python python/03_build_excel.py
"""
from pathlib import Path
import pandas as pd
from openpyxl import Workbook
from openpyxl.chart import BarChart, LineChart, Reference
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

ROOT = Path(__file__).resolve().parents[1]
D = ROOT / "data" / "cleaned"
OUT = ROOT / "excel" / "ecommerce_analysis.xlsx"
OUT.parent.mkdir(exist_ok=True)

# ---------------- load & flatten ----------------
cu = pd.read_csv(D / "customers.csv"); pr = pd.read_csv(D / "products.csv")
od = pd.read_csv(D / "orders.csv"); it = pd.read_csv(D / "order_items.csv")
pa = pd.read_csv(D / "payments.csv"); rt = pd.read_csv(D / "returns.csv")

orders = (od.merge(cu[["customer_id", "customer_state"]], on="customer_id")
            .merge(pa[["order_id", "payment_method", "payment_status", "payment_value"]], on="order_id"))
orders = orders[["order_id", "order_year_month", "purchase_year", "order_status", "is_valid_sale",
                 "payment_method", "payment_status", "customer_state", "is_late", "delivery_days", "payment_value"]]
lines = (it.merge(orders[["order_id", "order_year_month", "purchase_year", "order_status", "is_valid_sale",
                          "customer_state", "payment_method"]], on="order_id")
           .merge(pr[["product_id", "product_category_name"]], on="product_id"))
lines = lines[["order_id", "order_year_month", "purchase_year", "order_status", "is_valid_sale", "customer_state",
               "product_category_name", "seller_id", "payment_method", "price", "freight_value"]]
rets = rt.merge(pr[["product_id", "product_category_name"]], on="product_id")[
    ["return_id", "product_category_name", "return_reason", "return_status", "resolution_type"]]

NL, NO, NR = len(lines) + 1, len(orders) + 1, len(rets) + 1   # last data row of each sheet

# ---------------- styles ----------------
F = "Arial"
H_FILL = PatternFill("solid", fgColor="1F3864"); H_FONT = Font(name=F, bold=True, color="FFFFFF", size=10)
BASE = Font(name=F, size=10); BOLD = Font(name=F, size=10, bold=True)
TITLE = Font(name=F, size=16, bold=True, color="1F3864"); SUB = Font(name=F, size=10, italic=True, color="595959")
KPI_FILL = PatternFill("solid", fgColor="DDEBF7")
thin = Side(style="thin", color="BFBFBF"); BOX = Border(left=thin, right=thin, top=thin, bottom=thin)
INR = '"₹"#,##0'; NUM = "#,##0"; PCT = "0.0%"

def header(ws, row, labels, col=1):
    for i, t in enumerate(labels):
        c = ws.cell(row=row, column=col + i, value=t)
        c.font, c.fill, c.border = H_FONT, H_FILL, BOX
        c.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)

def style_range(ws, r1, r2, c1, c2, fmts):
    for r in range(r1, r2 + 1):
        for c in range(c1, c2 + 1):
            cell = ws.cell(row=r, column=c); cell.font = BASE; cell.border = BOX
            f = fmts.get(c)
            if f: cell.number_format = f

def widths(ws, ws_widths):
    for i, w in enumerate(ws_widths, 1): ws.column_dimensions[get_column_letter(i)].width = w

wb = Workbook()

# ================= DATA SHEETS =================
def dump(name, df):
    ws = wb.create_sheet(name)
    header(ws, 1, list(df.columns))
    for row in df.itertuples(index=False):
        ws.append([None if (isinstance(v, float) and pd.isna(v)) else v for v in row])
    ws.freeze_panes = "A2"; ws.auto_filter.ref = ws.dimensions
    for i in range(1, df.shape[1] + 1): ws.column_dimensions[get_column_letter(i)].width = 18
    return ws

# Data_Lines: A order_id B month C year D status E valid F state G category H seller I pay_method J price K freight
# Data_Orders: A order_id B month C year D status E valid F pay_method G pay_status H state I is_late J deliv_days K value
# Data_Returns: A id B category C reason D status E resolution
dl, do, dr = dump("Data_Lines", lines), dump("Data_Orders", orders), dump("Data_Returns", rets)

LB = lambda col: f"Data_Lines!${col}$2:${col}${NL}"
OB = lambda col: f"Data_Orders!${col}$2:${col}${NO}"
RB = lambda col: f"Data_Returns!${col}$2:${col}${NR}"

# ================= MONTHLY =================
wm = wb.create_sheet("Monthly")
wm["A1"], wm["A1"].font = "Monthly sales trend (valid sales only)", TITLE
wm["A2"], wm["A2"].font = "Valid sale = delivered AND payment approved. Revenue = sum of item price (excl. freight).", SUB
header(wm, 4, ["Month", "Valid orders", "Revenue (₹)", "Avg order value (₹)", "MoM growth %"])
months = sorted(orders.order_year_month.unique())
for i, m in enumerate(months):
    r = 5 + i
    wm.cell(r, 1, m)
    wm.cell(r, 2, f'=COUNTIFS({OB("B")},A{r},{OB("E")},1)')
    wm.cell(r, 3, f'=SUMIFS({LB("J")},{LB("B")},A{r},{LB("E")},1)')
    wm.cell(r, 4, f"=IF(B{r}=0,0,C{r}/B{r})")
    wm.cell(r, 5, f"=IF(C{r-1}=0,0,C{r}/C{r-1}-1)" if i else None)
MR = 4 + len(months)
style_range(wm, 5, MR, 1, 5, {2: NUM, 3: INR, 4: INR, 5: PCT})
r = MR + 1
wm.cell(r, 1, "Total"); wm.cell(r, 2, f"=SUM(B5:B{MR})"); wm.cell(r, 3, f"=SUM(C5:C{MR})"); wm.cell(r, 4, f"=C{r}/B{r}")
style_range(wm, r, r, 1, 5, {2: NUM, 3: INR, 4: INR})
for c in range(1, 6): wm.cell(r, c).font = BOLD
widths(wm, [14, 14, 18, 20, 14]); wm.freeze_panes = "A5"
ch = LineChart(); ch.title = "Monthly revenue (₹)"; ch.height, ch.width = 8.5, 20
ch.add_data(Reference(wm, min_col=3, min_row=4, max_row=MR), titles_from_data=True)
ch.set_categories(Reference(wm, min_col=1, min_row=5, max_row=MR)); ch.legend = None
ch.series[0].smooth = False
ch.y_axis.number_format = '#,##0'; ch.y_axis.delete = False; ch.x_axis.delete = False
wm.add_chart(ch, "G4")

# ================= CATEGORY =================
wc = wb.create_sheet("Category")
wc["A1"], wc["A1"].font = "Category performance & returns", TITLE
wc["A2"], wc["A2"].font = "Return rate = return requests / delivered units of the category (return requests include rejected and pending).", SUB
header(wc, 4, ["Category", "Revenue (₹)", "Units sold", "Avg price (₹)", "% of revenue", "Delivered units",
               "Return requests", "Return rate %"])
cat_order = (lines[lines.is_valid_sale == 1].groupby("product_category_name").price.sum()
             .sort_values(ascending=False).index.tolist())
for i, cname in enumerate(cat_order):
    r = 5 + i
    wc.cell(r, 1, cname)
    wc.cell(r, 2, f'=SUMIFS({LB("J")},{LB("G")},A{r},{LB("E")},1)')
    wc.cell(r, 3, f'=COUNTIFS({LB("G")},A{r},{LB("E")},1)')
    wc.cell(r, 4, f"=IF(C{r}=0,0,B{r}/C{r})")
    wc.cell(r, 5, f"=B{r}/B${5+len(cat_order)}")
    wc.cell(r, 6, f'=COUNTIFS({LB("G")},A{r},{LB("D")},"delivered")')
    wc.cell(r, 7, f'=COUNTIFS({RB("B")},A{r})')
    wc.cell(r, 8, f"=IF(F{r}=0,0,G{r}/F{r})")
CR = 4 + len(cat_order); T = CR + 1
wc.cell(T, 1, "Total")
for col in (2, 3, 6, 7): wc.cell(T, col, f"=SUM({get_column_letter(col)}5:{get_column_letter(col)}{CR})")
wc.cell(T, 4, f"=B{T}/C{T}"); wc.cell(T, 5, f"=SUM(E5:E{CR})"); wc.cell(T, 8, f"=G{T}/F{T}")
style_range(wc, 5, T, 1, 8, {2: INR, 3: NUM, 4: INR, 5: PCT, 6: NUM, 7: NUM, 8: PCT})
for c in range(1, 9): wc.cell(T, c).font = BOLD
widths(wc, [24, 18, 12, 16, 14, 16, 16, 14]); wc.freeze_panes = "A5"

b = BarChart(); b.type = "bar"; b.title = "Revenue by category (₹)"; b.height, b.width = 13, 18
b.add_data(Reference(wc, min_col=2, min_row=4, max_row=CR), titles_from_data=True)
b.set_categories(Reference(wc, min_col=1, min_row=5, max_row=CR)); b.legend = None
b.y_axis.number_format = '#,##0'; b.x_axis.scaling.orientation = "maxMin"; b.y_axis.delete = False; b.x_axis.delete = False
wc.add_chart(b, "J4")
b2 = BarChart(); b2.type = "bar"; b2.title = "Return rate by category"; b2.height, b2.width = 13, 18
b2.add_data(Reference(wc, min_col=8, min_row=4, max_row=CR), titles_from_data=True)
b2.set_categories(Reference(wc, min_col=1, min_row=5, max_row=CR)); b2.legend = None
b2.y_axis.number_format = '0%'; b2.x_axis.scaling.orientation = "maxMin"; b2.y_axis.delete = False; b2.x_axis.delete = False
wc.add_chart(b2, "J32")

# ================= GEOGRAPHY =================
wg = wb.create_sheet("Geography")
wg["A1"], wg["A1"].font = "Sales by customer state (top 15)", TITLE
header(wg, 3, ["State", "Valid orders", "Revenue (₹)", "Avg order value (₹)", "% of total revenue"])
st_order = (lines[lines.is_valid_sale == 1].groupby("customer_state").price.sum()
            .sort_values(ascending=False).index.tolist())
all_states = st_order; top = st_order[:15]
for i, s in enumerate(top):
    r = 4 + i
    wg.cell(r, 1, s)
    wg.cell(r, 2, f'=COUNTIFS({OB("H")},A{r},{OB("E")},1)')
    wg.cell(r, 3, f'=SUMIFS({LB("J")},{LB("F")},A{r},{LB("E")},1)')
    wg.cell(r, 4, f"=IF(B{r}=0,0,C{r}/B{r})")
    wg.cell(r, 5, f'=C{r}/SUMIFS({LB("J")},{LB("E")},1)')
GR = 3 + len(top)
style_range(wg, 4, GR, 1, 5, {2: NUM, 3: INR, 4: INR, 5: PCT})
r = GR + 1
wg.cell(r, 1, "Top 15 total"); wg.cell(r, 2, f"=SUM(B4:B{GR})"); wg.cell(r, 3, f"=SUM(C4:C{GR})"); wg.cell(r, 5, f"=SUM(E4:E{GR})")
style_range(wg, r, r, 1, 5, {2: NUM, 3: INR, 5: PCT})
for c in range(1, 6): wg.cell(r, c).font = BOLD
widths(wg, [16, 14, 18, 20, 18])
b = BarChart(); b.title = "Revenue by state (₹)"; b.height, b.width = 9, 20
b.add_data(Reference(wg, min_col=3, min_row=3, max_row=GR), titles_from_data=True)
b.set_categories(Reference(wg, min_col=1, min_row=4, max_row=GR)); b.legend = None
b.y_axis.number_format = '#,##0'; b.y_axis.delete = False; b.x_axis.delete = False
wg.add_chart(b, "G3")

# ================= PAYMENTS =================
wp = wb.create_sheet("Payments")
wp["A1"], wp["A1"].font = "Payment methods", TITLE
header(wp, 3, ["Payment method", "Orders", "% of orders", "Avg order value (₹)", "Failed payments", "Failed %", "Canceled orders", "Cancel %"])
methods = orders.payment_method.value_counts().index.tolist()
for i, m in enumerate(methods):
    r = 4 + i
    wp.cell(r, 1, m)
    wp.cell(r, 2, f'=COUNTIFS({OB("F")},A{r})')
    wp.cell(r, 3, f"=B{r}/B${4+len(methods)}")
    wp.cell(r, 4, f'=AVERAGEIFS({OB("K")},{OB("F")},A{r})')
    wp.cell(r, 5, f'=COUNTIFS({OB("F")},A{r},{OB("G")},"failed")')
    wp.cell(r, 6, f"=E{r}/B{r}")
    wp.cell(r, 7, f'=COUNTIFS({OB("F")},A{r},{OB("D")},"canceled")')
    wp.cell(r, 8, f"=G{r}/B{r}")
PR = 3 + len(methods); T = PR + 1
wp.cell(T, 1, "Total"); wp.cell(T, 2, f"=SUM(B4:B{PR})"); wp.cell(T, 3, f"=SUM(C4:C{PR})")
wp.cell(T, 5, f"=SUM(E4:E{PR})"); wp.cell(T, 6, f"=E{T}/B{T}"); wp.cell(T, 7, f"=SUM(G4:G{PR})"); wp.cell(T, 8, f"=G{T}/B{T}")
style_range(wp, 4, T, 1, 8, {2: NUM, 3: PCT, 4: INR, 5: NUM, 6: PCT, 7: NUM, 8: PCT})
for c in range(1, 9): wp.cell(T, c).font = BOLD
widths(wp, [18, 12, 12, 20, 16, 12, 16, 12])
b = BarChart(); b.title = "Orders by payment method"; b.height, b.width = 8, 14
b.add_data(Reference(wp, min_col=2, min_row=3, max_row=PR), titles_from_data=True)
b.set_categories(Reference(wp, min_col=1, min_row=4, max_row=PR)); b.legend = None
b.y_axis.delete = False; b.x_axis.delete = False
wp.add_chart(b, "J3")

# ================= RETURN REASONS =================
wr = wb.create_sheet("Returns")
wr["A1"], wr["A1"].font = "Return reasons & resolution", TITLE
header(wr, 3, ["Return reason", "Return requests", "% of returns"])
reasons = rets.return_reason.value_counts().index.tolist()
for i, rs in enumerate(reasons):
    r = 4 + i
    wr.cell(r, 1, rs); wr.cell(r, 2, f'=COUNTIFS({RB("C")},A{r})'); wr.cell(r, 3, f"=B{r}/B${4+len(reasons)}")
RR = 3 + len(reasons); T = RR + 1
wr.cell(T, 1, "Total"); wr.cell(T, 2, f"=SUM(B4:B{RR})"); wr.cell(T, 3, f"=SUM(C4:C{RR})")
style_range(wr, 4, T, 1, 3, {2: NUM, 3: PCT})
for c in range(1, 4): wr.cell(T, c).font = BOLD
header(wr, T + 3, ["Return status", "Return requests", "% of returns"])
s0 = T + 4
for i, stn in enumerate(["approved", "rejected", "pending"]):
    r = s0 + i
    wr.cell(r, 1, stn); wr.cell(r, 2, f'=COUNTIFS({RB("D")},A{r})'); wr.cell(r, 3, f"=B{r}/B${T}")
style_range(wr, s0, s0 + 2, 1, 3, {2: NUM, 3: PCT})
header(wr, s0 + 5, ["Resolution type (approved + pending)", "Return requests", "% of returns"])
q0 = s0 + 6
for i, rtp in enumerate(["Refund", "Replacement", "Store credit"]):
    r = q0 + i
    wr.cell(r, 1, rtp); wr.cell(r, 2, f'=COUNTIFS({RB("E")},A{r})'); wr.cell(r, 3, f"=B{r}/B${T}")
style_range(wr, q0, q0 + 2, 1, 3, {2: NUM, 3: PCT})
widths(wr, [36, 16, 14])
b = BarChart(); b.type = "bar"; b.title = "Return reasons"; b.height, b.width = 8, 14
b.add_data(Reference(wr, min_col=2, min_row=3, max_row=RR), titles_from_data=True)
b.set_categories(Reference(wr, min_col=1, min_row=4, max_row=RR)); b.legend = None
b.x_axis.scaling.orientation = "maxMin"; b.y_axis.delete = False; b.x_axis.delete = False
wr.add_chart(b, "E3")

# ================= DASHBOARD =================
ws = wb["Sheet"]; ws.title = "Dashboard"; wb.move_sheet("Dashboard", offset=-(len(wb.sheetnames) - 1))
ws.sheet_view.showGridLines = False
ws["B2"], ws["B2"].font = "Indian E-commerce - Sales Dashboard", TITLE
ws["B3"], ws["B3"].font = "Jan 2023 - Dec 2024 | all numbers are live formulas on the Data_* sheets", SUB
kpis = [
    ("Revenue (₹)", f'=SUMIFS({LB("J")},{LB("E")},1)', INR),
    ("Valid orders", f'=COUNTIFS({OB("E")},1)', NUM),
    ("Avg order value (₹)", "=C6/D6", INR),
    ("Units sold", f'=COUNTIFS({LB("E")},1)', NUM),
    ("Freight collected (₹)", f'=SUMIFS({LB("K")},{LB("E")},1)', INR),
    ("Cancel rate", f'=COUNTIFS({OB("D")},"canceled")/COUNTA({OB("A")})', PCT),
    ("Late deliveries %", f"=AVERAGE({OB('I')})", PCT),
    ("Return requests / 100 delivered orders", f'=COUNTA({RB("A")})/COUNTIFS({OB("D")},"delivered")*100', "0.0"),
]
for i, (lab, f, fmt) in enumerate(kpis):
    col = 2 + i
    a = ws.cell(5, col, lab); a.font = Font(name=F, size=9, bold=True, color="1F3864"); a.fill = KPI_FILL
    a.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True); a.border = BOX
    v = ws.cell(6, col, f); v.font = Font(name=F, size=14, bold=True); v.fill = KPI_FILL
    v.alignment = Alignment(horizontal="center", vertical="center"); v.number_format = fmt; v.border = BOX
ws.row_dimensions[5].height = 42; ws.row_dimensions[6].height = 34
for c in range(2, 10): ws.column_dimensions[get_column_letter(c)].width = 19
ws.column_dimensions["A"].width = 3
ws["B8"], ws["B8"].font = "Detailed tables are on the other sheets (Monthly, Category, Geography, Payments, Returns).", SUB
# KPI formulas above use C6/D6 => Revenue is in B6, orders in C6. Fix AOV to B6/C6.
ws["D6"] = "=B6/C6"

ch = LineChart(); ch.title = "Monthly revenue (₹)"; ch.height, ch.width = 8.5, 17
ch.add_data(Reference(wm, min_col=3, min_row=4, max_row=MR), titles_from_data=True)
ch.set_categories(Reference(wm, min_col=1, min_row=5, max_row=MR)); ch.legend = None
ch.series[0].smooth = False
ch.y_axis.number_format = '#,##0'; ch.y_axis.delete = False; ch.x_axis.delete = False
ws.add_chart(ch, "B10")
b = BarChart(); b.type = "bar"; b.title = "Top 10 categories by revenue (₹)"; b.height, b.width = 8.5, 17
b.add_data(Reference(wc, min_col=2, min_row=4, max_row=14), titles_from_data=True)
b.set_categories(Reference(wc, min_col=1, min_row=5, max_row=14)); b.legend = None
b.x_axis.scaling.orientation = "maxMin"; b.y_axis.number_format = '#,##0'; b.y_axis.delete = False; b.x_axis.delete = False
ws.add_chart(b, "F10")
b = BarChart(); b.title = "Revenue by state - top 15 (₹)"; b.height, b.width = 8.5, 17
b.add_data(Reference(wg, min_col=3, min_row=3, max_row=GR), titles_from_data=True)
b.set_categories(Reference(wg, min_col=1, min_row=4, max_row=GR)); b.legend = None
b.y_axis.number_format = '#,##0'; b.y_axis.delete = False; b.x_axis.delete = False
ws.add_chart(b, "B28")
b = BarChart(); b.type = "bar"; b.title = "Return rate by category"; b.height, b.width = 8.5, 17
b.add_data(Reference(wc, min_col=8, min_row=4, max_row=CR), titles_from_data=True)
b.set_categories(Reference(wc, min_col=1, min_row=5, max_row=CR)); b.legend = None
b.x_axis.scaling.orientation = "maxMin"; b.y_axis.number_format = '0%'; b.y_axis.delete = False; b.x_axis.delete = False
ws.add_chart(b, "F28")

# ================= NOTES =================
wn = wb.create_sheet("Notes", 1)
notes = [
    ("About this workbook", True),
    ("Built from data/cleaned/*.csv by python/03_build_excel.py. Summary sheets use SUMIFS/COUNTIFS formulas over the Data_* sheets.", False),
    ("", False),
    ("Business rules", True),
    ("Valid sale = order_status 'delivered' AND payment_status 'approved' (column is_valid_sale = 1).", False),
    ("Revenue = sum of item price for valid sales. Freight is shown separately.", False),
    ("Return rate = return requests (any status) / delivered units in the same category.", False),
    ("Late delivery = delivered on a later calendar day than the estimated delivery date.", False),
    ("", False),
    ("Sheets", True),
    ("Dashboard - KPIs + 4 charts | Monthly - trend | Category - revenue & returns | Geography - states | Payments - methods | Returns - reasons", False),
    ("Data_Lines (one row per order item), Data_Orders (one row per order), Data_Returns (one row per return) are the source tables for all formulas.", False),
    ("", False),
    ("Known data caveats", True),
    ("313 delivered orders have a failed payment - they are excluded from revenue.", False),
    ("Order times look capped at 23:59, so no hour-of-day analysis is included.", False),
]
for i, (t, bold) in enumerate(notes, 1):
    c = wn.cell(i, 1, t); c.font = Font(name=F, size=12 if bold else 10, bold=bold, color="1F3864" if bold else "000000")
wn.column_dimensions["A"].width = 140

order = ["Dashboard", "Monthly", "Category", "Geography", "Payments", "Returns", "Notes",
         "Data_Lines", "Data_Orders", "Data_Returns"]
wb._sheets = [wb[n] for n in order]
wb.active = 0
wb.save(OUT)
print("Saved", OUT)
