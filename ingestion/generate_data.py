"""Generate a realistic daily batch of retail source extracts (CSV).

Deliberately includes real-world messiness so the downstream ODS / dbt layers
have something to do:
  * duplicate records for the same key (latest `updated_at` must win)
  * customers who move city  -> exercises the SCD Type 2 snapshot
  * cancelled / returned orders -> exercises accepted_values tests

Usage:
    python -m ingestion.generate_data --batch-date 2026-10-28 --orders 500
"""
from __future__ import annotations

import argparse
import csv
import random
from datetime import date, datetime, timedelta
from pathlib import Path

from ingestion.config import settings
from ingestion.schemas import ENTITY_COLUMNS

FIRST = ["Aarav", "Priya", "Liam", "Emma", "Noah", "Olivia", "Rohan", "Sara", "Mateo", "Mia"]
LAST = ["Sharma", "Patel", "Smith", "Garcia", "Chen", "Nguyen", "Brown", "Rao", "Lopez", "Kim"]
CITIES = [("Boston", "MA"), ("Seattle", "WA"), ("Austin", "TX"), ("Chicago", "IL"),
          ("Denver", "CO"), ("New York", "NY"), ("San Jose", "CA"), ("Atlanta", "GA")]
CATALOG = {
    "Electronics": [("Wireless Earbuds", 79.99), ("USB-C Hub", 39.50), ("Smart Watch", 199.00)],
    "Home": [("Air Fryer", 89.99), ("LED Desk Lamp", 29.99), ("Cotton Throw", 34.00)],
    "Fitness": [("Yoga Mat", 25.00), ("Adjustable Dumbbells", 249.00), ("Resistance Bands", 18.99)],
    "Grocery": [("Cold Brew Pack", 14.99), ("Protein Bars (12)", 22.49), ("Basmati Rice 10lb", 19.99)],
}
STATUSES = ["placed"] * 6 + ["shipped"] * 8 + ["delivered"] * 10 + ["cancelled", "returned"]


def _ts(d: date, rng: random.Random) -> str:
    t = datetime.combine(d, datetime.min.time()) + timedelta(seconds=rng.randint(0, 86_399))
    return t.strftime("%Y-%m-%d %H:%M:%S")


def generate(batch_date: date, n_orders: int, n_customers: int = 200, seed: int | None = None) -> dict[str, list[dict]]:
    rng = random.Random(seed if seed is not None else batch_date.toordinal())

    customers = []
    for cid in range(1, n_customers + 1):
        city, state = rng.choice(CITIES)
        first, last = rng.choice(FIRST), rng.choice(LAST)
        customers.append({
            "customer_id": cid, "first_name": first, "last_name": last,
            "email": f"{first.lower()}.{last.lower()}{cid}@example.com",
            "city": city, "state": state,
            "signup_date": (batch_date - timedelta(days=rng.randint(30, 900))).isoformat(),
            "updated_at": _ts(batch_date - timedelta(days=rng.randint(1, 30)), rng),
        })
    # ~5% of customers relocate today -> new SCD2 version downstream
    for c in rng.sample(customers, k=max(1, n_customers // 20)):
        c["city"], c["state"] = rng.choice(CITIES)
        c["updated_at"] = _ts(batch_date, rng)

    products, pid = [], 1
    for category, items in CATALOG.items():
        for name, price in items:
            products.append({"product_id": pid, "product_name": name, "category": category,
                             "unit_price": f"{price:.2f}", "updated_at": _ts(batch_date - timedelta(days=60), rng)})
            pid += 1

    orders, items, item_id = [], [], 1
    base_order_id = batch_date.toordinal() * 10_000  # unique across days
    for i in range(n_orders):
        oid = base_order_id + i
        orders.append({"order_id": oid, "customer_id": rng.randint(1, n_customers),
                       "order_date": batch_date.isoformat(), "status": rng.choice(STATUSES),
                       "updated_at": _ts(batch_date, rng)})
        for _ in range(rng.randint(1, 4)):
            p = rng.choice(products)
            items.append({"order_item_id": oid * 10 + item_id % 10, "order_id": oid,
                          "product_id": p["product_id"], "quantity": rng.randint(1, 3),
                          "unit_price": p["unit_price"],
                          "discount_pct": rng.choice(["0", "0", "0", "5", "10", "15"]),
                          "updated_at": orders[-1]["updated_at"]})
            item_id += 1

    # Inject duplicates: same order re-sent later with an updated status.
    for o in rng.sample(orders, k=max(1, n_orders // 25)):
        dup = dict(o, status="shipped",
                   updated_at=(datetime.fromisoformat(o["updated_at"]) + timedelta(minutes=45)).strftime("%Y-%m-%d %H:%M:%S"))
        orders.append(dup)

    return {"customers": customers, "products": products, "orders": orders, "order_items": items}


def write_batch(data: dict[str, list[dict]], batch_date: date, out_dir: str | Path) -> list[Path]:
    """Write each entity to <out_dir>/<entity>/dt=YYYY-MM-DD/<entity>_YYYYMMDD.csv (Hive-style partitions)."""
    written = []
    for entity, rows in data.items():
        folder = Path(out_dir) / entity / f"dt={batch_date.isoformat()}"
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / f"{entity}_{batch_date:%Y%m%d}.csv"
        with path.open("w", newline="") as fh:
            writer = csv.DictWriter(fh, fieldnames=ENTITY_COLUMNS[entity], lineterminator="\n")
            writer.writeheader()
            writer.writerows(rows)
        written.append(path)
    return written


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--batch-date", type=date.fromisoformat, default=date.today())
    parser.add_argument("--orders", type=int, default=500)
    parser.add_argument("--out-dir", default=settings.local_landing_dir)
    args = parser.parse_args()

    paths = write_batch(generate(args.batch_date, args.orders), args.batch_date, args.out_dir)
    for p in paths:
        print(f"wrote {p}")


if __name__ == "__main__":
    main()
