"""Single source of truth for landing-file contracts.

Shared by the Python loader, the AWS Lambda validator and the unit tests,
so a schema change is made in exactly one place.
"""

ENTITY_COLUMNS: dict[str, list[str]] = {
    "customers": [
        "customer_id", "first_name", "last_name", "email",
        "city", "state", "signup_date", "updated_at",
    ],
    "products": [
        "product_id", "product_name", "category", "unit_price", "updated_at",
    ],
    "orders": [
        "order_id", "customer_id", "order_date", "status", "updated_at",
    ],
    "order_items": [
        "order_item_id", "order_id", "product_id",
        "quantity", "unit_price", "discount_pct", "updated_at",
    ],
}

# Load order matters: dimensions before facts.
LOAD_ORDER = ["customers", "products", "orders", "order_items"]
