from __future__ import annotations

import argparse
import json
import os
from copy import deepcopy
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, urlparse


REPO_ROOT = Path(__file__).resolve().parents[2]
PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNTIME_DIR = PROJECT_ROOT / "runtime"
SEEDS_DIR = RUNTIME_DIR / "seeds"
EXPORTS_DIR = RUNTIME_DIR / "exports"
BOOTSTRAP_ASSET_FILE = REPO_ROOT / "fixtures" / "bootstrap_data.json"
SEPARATE_DIRECTORY_SEEDS = ("org", "stores", "org_roles", "store_roles")
DEFAULT_DEVICE_SEED = {
    "data": [
        {
            "orgId": "org_001",
            "deviceId": "active-device-001",
            "make": "Seeder",
            "model": "Ready Unit",
            "lat": 1.3521,
            "lan": 103.8198,
            "status": "active",
            "registered_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "message": "Device registration active.",
        },
        {
            "orgId": "org_001",
            "deviceId": "pending-device-001",
            "make": "Seeder",
            "model": "Review Unit",
            "lat": 1.3521,
            "lan": 103.8198,
            "status": "pending",
            "registered_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "message": "Device registration is pending approval.",
        },
        {
            "orgId": "org_001",
            "deviceId": "inactive-device-001",
            "make": "Seeder",
            "model": "Blocked Unit",
            "lat": 0.0,
            "lan": 0.0,
            "status": "inactive",
            "registered_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z",
            "message": "Device is inactive. Contact support.",
        }
    ]
}

ENTITY_ASSET_FILES = {
    "orders": REPO_ROOT / "fixtures" / "order_list.json",
    "products": REPO_ROOT / "fixtures" / "product_data.json",
    "customers": REPO_ROOT / "fixtures" / "customer_data.json",
    "credits": REPO_ROOT / "fixtures" / "credit_data.json",
    "tables": REPO_ROOT / "fixtures" / "table_data.json",
}

ENTITY_TOKEN_ENV = {
    "orders": "MOCK_SERVER_ORDERS_EXPORT_TOKEN",
    "products": "MOCK_SERVER_PRODUCTS_EXPORT_TOKEN",
    "customers": "MOCK_SERVER_CUSTOMERS_EXPORT_TOKEN",
    "credits": "MOCK_SERVER_CREDITS_EXPORT_TOKEN",
    "tables": "MOCK_SERVER_TABLES_EXPORT_TOKEN",
}

ENVIRONMENT_CONFIG = {
    "development": {
        "db_name_id": "store_dev",
        "auto_sync_enabled": False,
        "periodic_duration_seconds": 300,
    },
    "test": {
        "db_name_id": "store_test",
        "auto_sync_enabled": False,
        "periodic_duration_seconds": 1,
    },
    "production": {
        "db_name_id": "store_prod",
        "auto_sync_enabled": True,
        "periodic_duration_seconds": 900,
    },
}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _normalize_environment(value: str | None) -> str:
    raw = (value or "development").strip().lower()
    aliases = {
        "dev": "development",
        "development": "development",
        "test": "test",
        "qa": "test",
        "prod": "production",
        "production": "production",
    }
    return aliases.get(raw, "development")


def _normalize_order_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id", row.get("id"))
    if remote_id is not None:
        row["remote_id"] = remote_id
    if not row.get("local_id") and remote_id is not None:
        row["local_id"] = f"order-seed-{remote_id}"

    payments = row.get("payments")
    if isinstance(payments, list):
        for payment in payments:
            if not isinstance(payment, dict):
                continue
            payment_remote_id = payment.get("remote_id", payment.get("id"))
            if payment_remote_id is not None:
                payment["remote_id"] = payment_remote_id
            if not payment.get("local_id") and payment_remote_id is not None:
                payment["local_id"] = f"order-payment-seed-{payment_remote_id}"
    return row


def _normalize_product_variant(variant: dict[str, Any]) -> dict[str, Any]:
    remote_id = variant.get("remote_id", variant.get("id"))
    if remote_id is not None:
        variant["remote_id"] = remote_id
    if not variant.get("local_id") and remote_id is not None:
        variant["local_id"] = f"var_{remote_id}"

    product_data = variant.get("product_data")
    if isinstance(product_data, dict):
        product_remote_id = product_data.get("remote_id", product_data.get("id"))
        if product_remote_id is not None:
            product_data["remote_id"] = product_remote_id
        if not product_data.get("local_id") and product_remote_id is not None:
            product_data["local_id"] = f"prod_{product_remote_id}"
    return variant


def _normalize_product_category(category: dict[str, Any]) -> dict[str, Any]:
    remote_id = category.get("remote_id", category.get("id"))
    if remote_id is not None:
        category["remote_id"] = remote_id
    if not category.get("local_id") and remote_id is not None:
        category["local_id"] = f"cat_{remote_id}"

    variants = category.get("product_variants")
    if isinstance(variants, list):
        category["product_variants"] = [
            _normalize_product_variant(variant) if isinstance(variant, dict) else variant
            for variant in variants
        ]
    return category


def _normalize_credit_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id", row.get("id"))
    if remote_id is not None:
        row["remote_id"] = remote_id
    if not row.get("local_id") and remote_id is not None:
        row["local_id"] = f"credit-seed-{remote_id}"
    return row


def _normalize_credit_repayment_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id", row.get("id"))
    if remote_id is not None:
        row["remote_id"] = remote_id
    if not row.get("local_id") and remote_id is not None:
        row["local_id"] = f"credit-repayment-seed-{remote_id}"
    return row


def _normalize_floor_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id", row.get("floor_id") or row.get("floorId"))
    if remote_id is not None:
        row["remote_id"] = remote_id
    return row


def _normalize_table_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id", row.get("table_id") or row.get("tableId"))
    if remote_id is not None:
        row["remote_id"] = remote_id
    return row


def _normalize_customer_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id", row.get("customerId"))
    if remote_id is not None:
        row["remote_id"] = remote_id
    return row


def _normalize_store_role_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id")
    if remote_id is None:
        customer_id = row.get("customerId") or ""
        org_id = row.get("orgId") or row.get("org_id") or ""
        store_id = row.get("storeId") or row.get("store_id") or ""
        role = row.get("role") or ""
        if customer_id or org_id or store_id or role:
            remote_id = f"{org_id}:{store_id}:{customer_id}:{role}"
    if remote_id is not None:
        row["remote_id"] = remote_id
    return row


def _normalize_organisation_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id", row.get("orgId"))
    if remote_id is not None:
        row["remote_id"] = remote_id
    return row


def _normalize_store_directory_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id", row.get("store_id"))
    if remote_id is not None:
        row["remote_id"] = remote_id
    return row


def _normalize_org_role_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id")
    if remote_id is None:
        customer_id = row.get("customerId") or ""
        org_id = row.get("orgId") or row.get("org_id") or ""
        role = row.get("role") or row.get("organisationRole") or ""
        if customer_id or org_id or role:
            remote_id = f"{org_id}:{customer_id}:{role}"
    if remote_id is not None:
        row["remote_id"] = remote_id
    return row


def _normalize_store_seed_row(row: dict[str, Any]) -> dict[str, Any]:
    remote_id = row.get("remote_id") or row.get("storeId") or row.get("store_id")
    if remote_id is not None:
        row["remote_id"] = remote_id
    return row


def _normalize_device_row(row: dict[str, Any]) -> dict[str, Any]:
    if row.get("status") is None:
        row["status"] = "active"
    if row.get("message") is None:
        row["message"] = "Device registration active."
    return row


def _merge_default_device_rows(existing_rows: list[Any]) -> list[dict[str, Any]]:
    merged = [
        _normalize_device_row(deepcopy(row))
        for row in existing_rows
        if isinstance(row, dict)
    ]
    for default_row in DEFAULT_DEVICE_SEED["data"]:
        default_device = _normalize_device_row(deepcopy(default_row))
        already_present = next(
            (
                row
                for row in merged
                if row.get("orgId") == default_device.get("orgId")
                and row.get("deviceId") == default_device.get("deviceId")
            ),
            None,
        )
        if already_present is None:
            merged.append(default_device)
    return merged


def _require_non_empty_string(payload: dict[str, Any], key: str) -> str:
    value = payload.get(key)
    if isinstance(value, str) and value.strip():
        return value.strip()
    raise ValueError(f"{key} is required.")


def _require_number(payload: dict[str, Any], key: str) -> float:
    value = payload.get(key)
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            pass
    raise ValueError(f"{key} is required.")


def _derive_org_roles(payload: dict[str, Any]) -> list[dict[str, Any]]:
    explicit_rows = payload.get("org_roles")
    if isinstance(explicit_rows, list) and explicit_rows:
        return [
            _normalize_org_role_row(row)
            for row in explicit_rows
            if isinstance(row, dict)
        ]

    rows = payload.get("data")
    if not isinstance(rows, list):
        return []

    derived: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        derived.append(
            _normalize_org_role_row(
                {
                    "customerId": row.get("customerId"),
                    "orgId": row.get("orgId"),
                    "customer_name": row.get("name"),
                    "email": row.get("email"),
                    "role": row.get("role"),
                }
            )
        )
    return derived


def _first_non_empty(*values: Any) -> Any:
    for value in values:
        if value is None:
            continue
        if isinstance(value, str) and value == "":
            continue
        return value
    return None


def _upsert_rows(existing_rows: list[Any], incoming_rows: list[Any], identity_fn) -> list[dict[str, Any]]:
    merged = [deepcopy(row) for row in existing_rows if isinstance(row, dict)]
    for raw_row in incoming_rows:
        if not isinstance(raw_row, dict):
            continue
        row = deepcopy(raw_row)
        identity = identity_fn(row)
        if identity is None:
            merged.append(row)
            continue
        index = next(
            (idx for idx, current in enumerate(merged) if identity_fn(current) == identity),
            None,
        )
        if index is None:
            merged.append(row)
        else:
            merged[index] = {**merged[index], **row}
    return merged


def _normalize_seed_payload(entity: str, payload: dict[str, Any]) -> dict[str, Any]:
    normalized = deepcopy(payload)
    if entity == "orders":
        rows = normalized.get("data")
        if not isinstance(rows, list):
            return normalized
        normalized["data"] = [
            _normalize_order_row(row) if isinstance(row, dict) else row
            for row in rows
        ]
    elif entity == "products":
        rows = normalized.get("data")
        if not isinstance(rows, list):
            return normalized
        normalized["data"] = [
            _normalize_product_category(row) if isinstance(row, dict) else row
            for row in rows
        ]
    elif entity == "customers":
        rows = normalized.get("data")
        if isinstance(rows, list):
            normalized["data"] = [
                _normalize_customer_row(row) if isinstance(row, dict) else row
                for row in rows
            ]
        roles = normalized.get("store_roles")
        if isinstance(roles, list):
            normalized["store_roles"] = [
                _normalize_store_role_row(row) if isinstance(row, dict) else row
                for row in roles
            ]
        normalized["org_roles"] = _derive_org_roles(normalized)
    elif entity == "credits":
        rows = normalized.get("data")
        if not isinstance(rows, list):
            return normalized
        normalized["data"] = [
            _normalize_credit_row(row) if isinstance(row, dict) else row
            for row in rows
        ]
        repayments = normalized.get("repayments")
        if isinstance(repayments, list):
            normalized["repayments"] = [
                _normalize_credit_repayment_row(row) if isinstance(row, dict) else row
                for row in repayments
            ]
    elif entity == "tables":
        floors = normalized.get("floors")
        if isinstance(floors, list):
            normalized["floors"] = [
                _normalize_floor_row(row) if isinstance(row, dict) else row
                for row in floors
            ]
        tables = normalized.get("tables")
        if isinstance(tables, list):
            normalized["tables"] = [
                _normalize_table_row(row) if isinstance(row, dict) else row
                for row in tables
            ]
    elif entity == "bootstrap":
        organisations = normalized.get("organisations")
        if isinstance(organisations, list):
            normalized["organisations"] = [
                _normalize_organisation_row(row) if isinstance(row, dict) else row
                for row in organisations
            ]
        stores = normalized.get("stores")
        if isinstance(stores, list):
            normalized["stores"] = [
                _normalize_store_directory_row(row) if isinstance(row, dict) else row
                for row in stores
            ]
        org_roles = normalized.get("org_roles")
        if isinstance(org_roles, list):
            normalized["org_roles"] = [
                _normalize_org_role_row(row) if isinstance(row, dict) else row
                for row in org_roles
            ]
    elif entity == "org":
        rows = normalized.get("data")
        if isinstance(rows, list):
            normalized["data"] = [
                _normalize_organisation_row(row) if isinstance(row, dict) else row
                for row in rows
            ]
    elif entity == "stores":
        rows = normalized.get("data")
        if isinstance(rows, list):
            normalized["data"] = [
                _normalize_store_seed_row(row) if isinstance(row, dict) else row
                for row in rows
            ]
    elif entity == "org_roles":
        rows = normalized.get("data")
        if isinstance(rows, list):
            normalized["data"] = [
                _normalize_org_role_row(row) if isinstance(row, dict) else row
                for row in rows
            ]
    elif entity == "store_roles":
        rows = normalized.get("data")
        if isinstance(rows, list):
            normalized["data"] = [
                _normalize_store_role_row(row) if isinstance(row, dict) else row
                for row in rows
            ]
    elif entity == "devices":
        rows = normalized.get("data")
        if isinstance(rows, list):
            normalized["data"] = [
                _normalize_device_row(row) if isinstance(row, dict) else row
                for row in rows
            ]
    return normalized


class MockDataStore:
    def __init__(self) -> None:
        SEEDS_DIR.mkdir(parents=True, exist_ok=True)
        EXPORTS_DIR.mkdir(parents=True, exist_ok=True)
        self._ensure_seed_files()
        self._ensure_export_files()
        self._seed_snapshots = {
            path.stem: path.read_text(encoding="utf-8")
            for path in SEEDS_DIR.glob("*.json")
        }

    def _ensure_seed_files(self) -> None:
        for entity, asset_path in ENTITY_ASSET_FILES.items():
            target = self.seed_path(entity)
            if not target.exists():
                target.write_text(asset_path.read_text(), encoding="utf-8")
            payload = json.loads(target.read_text(encoding="utf-8"))
            normalized = _normalize_seed_payload(entity, payload)
            if normalized != payload:
                target.write_text(json.dumps(normalized, indent=2), encoding="utf-8")
        for entity in SEPARATE_DIRECTORY_SEEDS:
            target = self.seed_path(entity)
            if not target.exists():
                continue
            payload = json.loads(target.read_text(encoding="utf-8"))
            normalized = _normalize_seed_payload(entity, payload)
            if normalized != payload:
                target.write_text(json.dumps(normalized, indent=2), encoding="utf-8")
        bootstrap_target = self.seed_path("bootstrap")
        if not bootstrap_target.exists():
            bootstrap_target.write_text(BOOTSTRAP_ASSET_FILE.read_text(), encoding="utf-8")
        bootstrap_payload = json.loads(bootstrap_target.read_text(encoding="utf-8"))
        normalized_bootstrap = _normalize_seed_payload("bootstrap", bootstrap_payload)
        if normalized_bootstrap != bootstrap_payload:
            bootstrap_target.write_text(json.dumps(normalized_bootstrap, indent=2), encoding="utf-8")
        devices_target = self.seed_path("devices")
        if not devices_target.exists():
            devices_target.write_text(json.dumps(DEFAULT_DEVICE_SEED, indent=2), encoding="utf-8")
        original_device_payload = json.loads(devices_target.read_text(encoding="utf-8"))
        device_payload = deepcopy(original_device_payload)
        device_payload["data"] = _merge_default_device_rows(device_payload.get("data", []))
        normalized_devices = _normalize_seed_payload("devices", device_payload)
        if normalized_devices != original_device_payload:
            devices_target.write_text(json.dumps(normalized_devices, indent=2), encoding="utf-8")

    def _ensure_export_files(self) -> None:
        for entity in ENTITY_ASSET_FILES:
            target = self.export_path(entity)
            if not target.exists():
                target.write_text(
                    json.dumps(
                        {
                            "entity": entity,
                            "request_count": 0,
                            "last_received_at": None,
                            "requests": [],
                        },
                        indent=2,
                    ),
                    encoding="utf-8",
                )

    def seed_path(self, entity: str) -> Path:
        return SEEDS_DIR / f"{entity}.json"

    def has_seed(self, entity: str) -> bool:
        return self.seed_path(entity).exists()

    def export_path(self, entity: str) -> Path:
        return EXPORTS_DIR / f"{entity}.json"

    def load_seed(self, entity: str) -> dict[str, Any]:
        return json.loads(self.seed_path(entity).read_text(encoding="utf-8"))

    def write_seed(self, entity: str, payload: dict[str, Any]) -> None:
        normalized = _normalize_seed_payload(entity, payload)
        self.seed_path(entity).write_text(json.dumps(normalized, indent=2), encoding="utf-8")

    def load_exports(self, entity: str) -> dict[str, Any]:
        return json.loads(self.export_path(entity).read_text(encoding="utf-8"))

    def append_export(self, entity: str, payload: dict[str, Any], headers: dict[str, str]) -> dict[str, Any]:
        self._apply_export_to_seeds(entity, payload)
        current = self.load_exports(entity)
        current["request_count"] = int(current.get("request_count", 0)) + 1
        current["last_received_at"] = _now_iso()
        current.setdefault("requests", []).append(
            {
                "received_at": current["last_received_at"],
                "headers": headers,
                "payload": payload,
            }
        )
        self.export_path(entity).write_text(json.dumps(current, indent=2), encoding="utf-8")
        return current

    def _apply_export_to_seeds(self, entity: str, payload: dict[str, Any]) -> None:
        if entity == "orders":
            seed = self.load_seed("orders")
            seed["data"] = _upsert_rows(
                seed.get("data", []),
                payload.get("data", []),
                lambda row: _first_non_empty(row.get("local_id"), row.get("remote_id"), row.get("order_id"), row.get("id")),
            )
            self.write_seed("orders", seed)
            return

        if entity == "customers":
            seed = self.load_seed("customers")
            merged_customers = _upsert_rows(
                seed.get("data", []),
                payload.get("data", []),
                lambda row: _first_non_empty(row.get("customerId"), row.get("remote_id")),
            )
            merged_store_roles = _upsert_rows(
                seed.get("store_roles", []),
                payload.get("store_roles", []),
                lambda row: _first_non_empty(
                    row.get("remote_id"),
                    f"{row.get('orgId') or row.get('org_id') or ''}:{row.get('storeId') or row.get('store_id') or ''}:{row.get('customerId') or ''}:{row.get('role') or ''}",
                ),
            )
            merged_org_roles = _upsert_rows(
                seed.get("org_roles", []),
                payload.get("org_roles", []),
                lambda row: _first_non_empty(
                    row.get("remote_id"),
                    f"{row.get('orgId') or row.get('org_id') or ''}:{row.get('customerId') or ''}:{row.get('role') or row.get('organisationRole') or ''}",
                ),
            )
            seed["data"] = merged_customers
            seed["store_roles"] = merged_store_roles
            seed["org_roles"] = merged_org_roles
            self.write_seed("customers", seed)
            self.write_seed("store_roles", {"data": merged_store_roles})
            self.write_seed("org_roles", {"data": merged_org_roles})
            return

        if entity == "credits":
            seed = self.load_seed("credits")
            seed["data"] = _upsert_rows(
                seed.get("data", []),
                payload.get("data", []),
                lambda row: _first_non_empty(row.get("local_id"), row.get("remote_id"), row.get("id")),
            )
            seed["repayments"] = _upsert_rows(
                seed.get("repayments", []),
                payload.get("repayments", []),
                lambda row: _first_non_empty(row.get("local_id"), row.get("remote_id"), row.get("id")),
            )
            seed["allocations"] = _upsert_rows(
                seed.get("allocations", []),
                payload.get("allocations", []),
                lambda row: _first_non_empty(
                    f"{row.get('repayment_local_id') or row.get('repayment_remote_id') or row.get('repayment_id')}:{row.get('credit_local_id') or row.get('credit_remote_id') or row.get('credit_id')}",
                ),
            )
            self.write_seed("credits", seed)
            return

        if entity == "products":
            seed = self.load_seed("products")
            seed["data"] = _upsert_rows(
                seed.get("data", []),
                payload.get("data", []),
                lambda row: _first_non_empty(row.get("localId"), row.get("categoryId"), row.get("id"), row.get("remote_id")),
            )
            self.write_seed("products", seed)
            return

        if entity == "tables":
            seed = self.load_seed("tables")
            seed["floors"] = _upsert_rows(
                seed.get("floors", []),
                payload.get("floors", []),
                lambda row: _first_non_empty(row.get("remote_id"), row.get("floor_id"), row.get("floorId")),
            )
            seed["tables"] = _upsert_rows(
                seed.get("tables", []),
                payload.get("tables", []),
                lambda row: _first_non_empty(row.get("remote_id"), row.get("table_id"), row.get("tableId")),
            )
            self.write_seed("tables", seed)

    def reset_exports(self) -> None:
        for entity in ENTITY_ASSET_FILES:
            self.export_path(entity).write_text(
                json.dumps(
                    {
                        "entity": entity,
                        "request_count": 0,
                        "last_received_at": None,
                        "requests": [],
                    },
                    indent=2,
                ),
                encoding="utf-8",
            )

    def reset_runtime(self) -> None:
        for entity, text in self._seed_snapshots.items():
            self.seed_path(entity).write_text(text, encoding="utf-8")
        self.reset_exports()

    def register_device(self, payload: dict[str, Any]) -> dict[str, Any]:
        org_id = _require_non_empty_string(payload, "orgId")
        device_id = _require_non_empty_string(payload, "deviceId")
        make = _require_non_empty_string(payload, "make")
        model = _require_non_empty_string(payload, "model")
        lat = _require_number(payload, "lat")
        lan = _require_number(payload, "lan")

        devices = self.load_seed("devices")
        rows = [row for row in devices.get("data", []) if isinstance(row, dict)]
        now = _now_iso()
        existing = next(
            (
                row
                for row in rows
                if row.get("orgId") == org_id and row.get("deviceId") == device_id
            ),
            None,
        )

        if existing is None:
            existing = _normalize_device_row(
                {
                    "orgId": org_id,
                    "deviceId": device_id,
                    "make": make,
                    "model": model,
                    "lat": lat,
                    "lan": lan,
                    "status": "active",
                    "registered_at": now,
                    "updated_at": now,
                    "message": "Device registration active.",
                }
            )
            rows.append(existing)
        else:
            existing["make"] = make
            existing["model"] = model
            existing["lat"] = lat
            existing["lan"] = lan
            existing["updated_at"] = now
            if not existing.get("message"):
                existing["message"] = "Device registration active." if existing.get("status") == "active" else "Device is not active."

        devices["data"] = rows
        self.write_seed("devices", devices)
        return existing

    def list_devices(self, org_id: str | None, device_id: str | None) -> dict[str, Any]:
        devices = self.load_seed("devices")
        rows = [row for row in devices.get("data", []) if isinstance(row, dict)]
        filtered = [
            row
            for row in rows
            if (org_id is None or row.get("orgId") == org_id)
            and (device_id is None or row.get("deviceId") == device_id)
        ]
        return {
            "data": filtered,
            "total_count": len(filtered),
        }


def _matches_scope(item: dict[str, Any], org_id: str | None, store_id: str | None) -> bool:
    if org_id is not None and item.get("orgId") not in {None, org_id}:
        return False
    if store_id is not None and item.get("storeId") not in {None, store_id}:
        return False
    return True


def _filter_seed_payload(entity: str, payload: dict[str, Any], org_id: str | None, store_id: str | None) -> dict[str, Any]:
    filtered = deepcopy(payload)
    if entity == "customers":
        rows = filtered.get("data", [])
        if isinstance(rows, list):
            filtered["data"] = [row for row in rows if isinstance(row, dict) and _matches_scope(row, org_id, store_id)]
        roles = filtered.get("store_roles", [])
        if isinstance(roles, list):
            filtered["store_roles"] = [row for row in roles if isinstance(row, dict) and _matches_scope(row, org_id, store_id)]
        org_roles = filtered.get("org_roles", [])
        if isinstance(org_roles, list):
            allowed_customer_ids = {
                row.get("customerId")
                for row in filtered.get("data", [])
                if isinstance(row, dict) and row.get("customerId") is not None
            }
            filtered["org_roles"] = [
                row
                for row in org_roles
                if isinstance(row, dict)
                and (org_id is None or row.get("orgId") == org_id or row.get("org_id") == org_id)
                and (not allowed_customer_ids or row.get("customerId") in allowed_customer_ids)
            ]
        return filtered

    if entity == "credits":
        rows = filtered.get("data", [])
        if isinstance(rows, list):
            filtered["data"] = [row for row in rows if isinstance(row, dict) and _matches_scope(row, org_id, store_id)]
        repayments = filtered.get("repayments", [])
        if isinstance(repayments, list):
            filtered["repayments"] = [
                row for row in repayments if isinstance(row, dict) and _matches_scope(row, org_id, store_id)
            ]
        allocations = filtered.get("allocations", [])
        if isinstance(allocations, list):
            filtered["allocations"] = [
                row for row in allocations if isinstance(row, dict) and _matches_scope(row, org_id, store_id)
            ]
        return filtered

    if entity == "tables":
        floors = filtered.get("floors", [])
        if isinstance(floors, list):
            filtered["floors"] = [row for row in floors if isinstance(row, dict) and _matches_scope(row, org_id, store_id)]
        tables = filtered.get("tables", [])
        if isinstance(tables, list):
            filtered["tables"] = [row for row in tables if isinstance(row, dict) and _matches_scope(row, org_id, store_id)]
        return filtered

    rows = filtered.get("data", [])
    if isinstance(rows, list) and rows and all(isinstance(row, dict) for row in rows):
        scoped_rows = [row for row in rows if _matches_scope(row, org_id, store_id)]
        if scoped_rows:
            filtered["data"] = scoped_rows
    return filtered


def _parse_positive_int(value: str | None, default: int) -> int:
    if value is None or value == "":
        return default
    try:
        parsed = int(value)
    except ValueError:
        return default
    return parsed if parsed > 0 else default


def _parse_offset_cursor(cursor: str | None) -> int:
    if cursor is None or cursor == "":
        return 0
    try:
        parsed = int(cursor)
    except ValueError:
        return 0
    return parsed if parsed >= 0 else 0


def _paginate_list(rows: list[Any], limit: int, cursor: str | None) -> tuple[list[Any], str | None, int]:
    offset = _parse_offset_cursor(cursor)
    total_count = len(rows)
    batch = rows[offset : offset + limit]
    next_offset = offset + len(batch)
    next_cursor = str(next_offset) if next_offset < total_count else None
    return batch, next_cursor, total_count


def _count_product_variants(rows: list[Any]) -> int:
    total = 0
    for row in rows:
        if isinstance(row, dict):
            variants = row.get("product_variants", [])
            if isinstance(variants, list):
                total += len(variants)
    return total


def _paginate_import_payload(entity: str, payload: dict[str, Any], limit: int, cursor: str | None) -> dict[str, Any]:
    paged = deepcopy(payload)
    if entity == "customers":
        customer_rows = [row for row in paged.get("data", []) if isinstance(row, dict)]
        batch, next_cursor, total_count = _paginate_list(customer_rows, limit, cursor)
        allowed_customer_ids = {
            row.get("customerId")
            for row in batch
            if isinstance(row, dict) and row.get("customerId") is not None
        }
        paged["data"] = batch
        paged["store_roles"] = [
            row
            for row in paged.get("store_roles", [])
            if isinstance(row, dict) and row.get("customerId") in allowed_customer_ids
        ]
        paged["org_roles"] = [
            row
            for row in paged.get("org_roles", [])
            if isinstance(row, dict) and row.get("customerId") in allowed_customer_ids
        ]
        paged["total_count"] = total_count
        paged["batch_count"] = len(batch)
        paged["next_cursor"] = next_cursor
        paged["has_more"] = next_cursor is not None
        return paged

    if entity == "tables":
        floor_rows = [row for row in paged.get("floors", []) if isinstance(row, dict)]
        table_rows = [row for row in paged.get("tables", []) if isinstance(row, dict)]
        combined_rows = [
            {"kind": "floor", "row": row}
            for row in floor_rows
        ] + [
            {"kind": "table", "row": row}
            for row in table_rows
        ]
        batch, next_cursor, total_count = _paginate_list(combined_rows, limit, cursor)
        paged["floors"] = [entry["row"] for entry in batch if entry.get("kind") == "floor"]
        paged["tables"] = [entry["row"] for entry in batch if entry.get("kind") == "table"]
        paged["total_count"] = total_count
        paged["batch_count"] = len(batch)
        paged["next_cursor"] = next_cursor
        paged["has_more"] = next_cursor is not None
        return paged

    data_rows = paged.get("data", [])
    if not isinstance(data_rows, list):
        paged["total_count"] = 0
        paged["batch_count"] = 0
        paged["next_cursor"] = None
        paged["has_more"] = False
        return paged

    batch, next_cursor, total_row_count = _paginate_list(data_rows, limit, cursor)
    paged["data"] = batch
    if entity == "products":
        total_count = _count_product_variants(data_rows)
        batch_count = _count_product_variants(batch)
    else:
        total_count = total_row_count
        batch_count = len(batch)
    paged["total_count"] = total_count
    paged["batch_count"] = batch_count
    paged["next_cursor"] = next_cursor
    paged["has_more"] = next_cursor is not None
    return paged


def _to_org_row(row: dict[str, Any]) -> dict[str, Any]:
    normalized = _normalize_organisation_row(deepcopy(row))
    if "org_name" not in normalized and "orgName" in normalized:
        normalized["org_name"] = normalized.get("orgName")
    if "org_code" not in normalized and "orgCode" in normalized:
        normalized["org_code"] = normalized.get("orgCode")
    return normalized


def _to_store_row(row: dict[str, Any]) -> dict[str, Any]:
    normalized = _normalize_store_directory_row(deepcopy(row))
    field_map = {
        "orgId": "org_id",
        "orgName": "org_name",
        "orgCode": "org_code",
        "storeId": "store_id",
        "serviceInstanceId": "service_instance_id",
        "storeName": "store_name",
        "uniqueId": "unique_id",
        "contactEmail": "contact_email",
        "contactPerson": "contact_person",
        "serviceVariantType": "service_variant_type",
    }
    for source, target in field_map.items():
        if target not in normalized and source in normalized:
            normalized[target] = normalized.get(source)
    return normalized


def _compose_customer_payload(store: MockDataStore, org_id: str | None, store_id: str | None) -> dict[str, Any]:
    customer_payload = _filter_seed_payload("customers", store.load_seed("customers"), org_id, store_id)

    if store.has_seed("store_roles"):
        role_payload = _filter_seed_payload("store_roles", store.load_seed("store_roles"), org_id, store_id)
        customer_payload["store_roles"] = role_payload.get("data", [])

    if store.has_seed("org_roles"):
        org_roles_payload = _filter_seed_payload("org_roles", store.load_seed("org_roles"), org_id, None)
        customer_payload["org_roles"] = org_roles_payload.get("data", [])
    else:
        customer_payload["org_roles"] = _derive_org_roles(customer_payload)

    return customer_payload


def _compose_bootstrap_payload(store: MockDataStore, org_code: str | None, org_id: str | None) -> dict[str, Any] | None:
    if not all(store.has_seed(entity) for entity in SEPARATE_DIRECTORY_SEEDS):
        return None

    org_payload = _normalize_seed_payload("org", store.load_seed("org"))
    stores_payload = _normalize_seed_payload("stores", store.load_seed("stores"))
    org_roles_payload = _normalize_seed_payload("org_roles", store.load_seed("org_roles"))

    organisations = [
        _to_org_row(row)
        for row in org_payload.get("data", [])
        if isinstance(row, dict)
    ]
    organisation = next(
        (
            row
            for row in organisations
            if (org_code is not None and row.get("org_code") == org_code)
            or (org_id is not None and row.get("orgId") == org_id)
        ),
        None,
    )
    if organisation is None:
        return None

    resolved_org_id = organisation.get("orgId")
    stores = [
        _to_store_row(row)
        for row in stores_payload.get("data", [])
        if isinstance(row, dict) and (row.get("orgId") == resolved_org_id or row.get("org_id") == resolved_org_id)
    ]
    customer_payload = _compose_customer_payload(store, resolved_org_id, None)
    org_roles = [
        row
        for row in org_roles_payload.get("data", [])
        if isinstance(row, dict) and (row.get("orgId") == resolved_org_id or row.get("org_id") == resolved_org_id)
    ]

    return {
        "organisation": organisation,
        "stores": stores,
        **customer_payload,
        "org_roles": org_roles if org_roles else customer_payload.get("org_roles", []),
    }


def _compose_remote_config_payload(
    store: MockDataStore,
    *,
    base_url: str,
    org_code: str | None,
    org_id: str | None,
    environment: str | None,
) -> dict[str, Any] | None:
    bootstrap = _compose_bootstrap_payload(store, org_code, org_id)
    if bootstrap is None:
        return None

    stores = [row for row in bootstrap.get("stores", []) if isinstance(row, dict)]
    default_store = stores[0] if stores else None
    resolved_environment = _normalize_environment(environment)
    environment_config = ENVIRONMENT_CONFIG[resolved_environment]
    return {
        "db_name_id": environment_config["db_name_id"],
        "environment": resolved_environment,
        "bootstrap": {
            "lookup_url": f"{base_url}/api/bootstrap",
            "device_registration_url": f"{base_url}/api/devices/register",
        },
        "sync": {
            "base_url": base_url,
            "auto_sync_enabled": environment_config["auto_sync_enabled"],
            "periodic_duration_seconds": environment_config["periodic_duration_seconds"],
            "orders": {
                "import_path": "/api/orders/import",
                "export_path": "/api/orders/export",
                "export_token": os.getenv("MOCK_SERVER_ORDERS_EXPORT_TOKEN", "orders-token"),
            },
            "products": {
                "import_path": "/api/products/import",
                "export_path": "/api/products/export",
                "export_token": os.getenv("MOCK_SERVER_PRODUCTS_EXPORT_TOKEN", "products-token"),
            },
            "customers": {
                "import_path": "/api/customers/import",
                "export_path": "/api/customers/export",
                "export_token": os.getenv("MOCK_SERVER_CUSTOMERS_EXPORT_TOKEN", "customers-token"),
            },
            "credits": {
                "import_path": "/api/credits/import",
                "export_path": "/api/credits/export",
                "export_token": os.getenv("MOCK_SERVER_CREDITS_EXPORT_TOKEN", "credits-token"),
            },
            "tables": {
                "import_path": "/api/tables/import",
                "export_path": "/api/tables/export",
                "export_token": os.getenv("MOCK_SERVER_TABLES_EXPORT_TOKEN", "tables-token"),
            },
        },
        "session_duration_hours": 12,
        "default_store": default_store,
        "test_store": default_store,
        "stores": stores,
        "asset_paths": {
            "orders": "fixtures/order_list.json",
            "products": "fixtures/product_data.json",
            "customers": "fixtures/customer_data.json",
        },
        "default_login": {
            "email": "alice@example.com",
            "password": "alicepass",
        },
    }


class MockRequestHandler(BaseHTTPRequestHandler):
    store = MockDataStore()
    server_version = "PosMockRemote/0.1"

    def _json_response(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _base_url(self) -> str:
        host = self.headers.get("Host")
        if host:
            return f"http://{host}"
        server_host, server_port = self.server.server_address[:2]
        return f"http://{server_host}:{server_port}"

    def _read_json_body(self) -> dict[str, Any]:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(content_length) if content_length > 0 else b"{}"
        try:
            decoded = json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError as error:
            raise ValueError(f"Invalid JSON body: {error}") from error
        if not isinstance(decoded, dict):
            raise ValueError("Expected a JSON object request body.")
        return decoded

    def _require_export_token(self, entity: str) -> bool:
        env_name = ENTITY_TOKEN_ENV[entity]
        expected = os.getenv(env_name, "")
        if not expected:
            return True
        actual = self.headers.get("Authorization", "")
        return actual == f"Bearer {expected}"

    def _handle_import(self, entity: str, query: dict[str, list[str]]) -> None:
        org_id = query.get("orgId", [None])[0]
        store_id = query.get("storeId", [None])[0]
        limit = _parse_positive_int(query.get("limit", [None])[0], 500)
        cursor = query.get("cursor", [None])[0]
        if entity == "customers":
            filtered = _compose_customer_payload(self.store, org_id, store_id)
        else:
            payload = self.store.load_seed(entity)
            filtered = _filter_seed_payload(entity, payload, org_id, store_id)
        paged = _paginate_import_payload(entity, filtered, limit, cursor)
        self._json_response(
            HTTPStatus.OK,
            {
                "entity": entity,
                "source": "seed",
                "orgId": org_id,
                "storeId": store_id,
                **paged,
            },
        )

    def _handle_bootstrap(self, query: dict[str, list[str]]) -> None:
        org_code = query.get("orgCode", [None])[0]
        org_id = query.get("orgId", [None])[0]
        environment = _normalize_environment(query.get("environment", [None])[0])
        composed = _compose_bootstrap_payload(self.store, org_code, org_id)
        if composed is not None:
            resolved_org_id = composed.get("organisation", {}).get("orgId") if isinstance(composed.get("organisation"), dict) else None
            if resolved_org_id is not None:
                composed["config_url"] = f"{self._base_url()}/api/config?orgId={resolved_org_id}&environment={environment}"
            self._json_response(HTTPStatus.OK, composed)
            return
        payload = self.store.load_seed("bootstrap")
        organisations = payload.get("organisations", [])
        stores = payload.get("stores", [])
        organisation = next(
            (
                row
                for row in organisations
                if isinstance(row, dict)
                and ((org_code is not None and row.get("org_code") == org_code) or (org_id is not None and row.get("orgId") == org_id))
            ),
            None,
        )
        if organisation is None:
            self._json_response(HTTPStatus.NOT_FOUND, {"ok": False, "message": "Organisation not found."})
            return

        resolved_org_id = organisation.get("orgId")
        filtered_stores = [
            row for row in stores if isinstance(row, dict) and row.get("org_id") == resolved_org_id
        ]
        customer_payload = self.store.load_seed("customers")
        filtered_customers = _filter_seed_payload("customers", customer_payload, resolved_org_id, None)
        self._json_response(
            HTTPStatus.OK,
            {
                "organisation": organisation,
                "stores": filtered_stores,
                **filtered_customers,
                "org_roles": _derive_org_roles(filtered_customers),
                "config_url": f"{self._base_url()}/api/config?orgId={resolved_org_id}&environment={environment}",
            },
        )

    def _handle_config(self, query: dict[str, list[str]]) -> None:
        org_code = query.get("orgCode", [None])[0]
        org_id = query.get("orgId", [None])[0]
        environment = query.get("environment", [None])[0]
        payload = _compose_remote_config_payload(
            self.store,
            base_url=self._base_url(),
            org_code=org_code,
            org_id=org_id,
            environment=environment,
        )
        if payload is None:
            self._json_response(HTTPStatus.NOT_FOUND, {"ok": False, "message": "Organisation config not found."})
            return
        self._json_response(HTTPStatus.OK, payload)

    def _handle_export(self, entity: str) -> None:
        if not self._require_export_token(entity):
            self._json_response(
                HTTPStatus.UNAUTHORIZED,
                {
                    "ok": False,
                    "message": f"Missing or invalid bearer token for {entity} export.",
                },
            )
            return

        try:
            payload = self._read_json_body()
        except ValueError as error:
            self._json_response(HTTPStatus.BAD_REQUEST, {"ok": False, "message": str(error)})
            return

        updated = self.store.append_export(
          entity,
          payload,
          {
              "Authorization": self.headers.get("Authorization", ""),
              "Content-Type": self.headers.get("Content-Type", ""),
          },
        )
        self._json_response(
            HTTPStatus.OK,
            {
                "ok": True,
                "entity": entity,
                "request_count": updated["request_count"],
                "last_received_at": updated["last_received_at"],
            },
        )

    def _handle_device_registration(self) -> None:
        try:
            payload = self._read_json_body()
            registration = self.store.register_device(payload)
        except ValueError as error:
            self._json_response(HTTPStatus.BAD_REQUEST, {"ok": False, "message": str(error)})
            return

        status = registration.get("status", "inactive")
        message = registration.get("message") or (
            "Device registration active." if status == "active" else "Device is not active."
        )
        self._json_response(
            HTTPStatus.OK,
            {
                **registration,
                "ok": True,
                "message": message,
            },
        )

    def _handle_device_list(self, query: dict[str, list[str]]) -> None:
        org_id = query.get("orgId", [None])[0]
        device_id = query.get("deviceId", [None])[0]
        payload = self.store.list_devices(org_id, device_id)
        self._json_response(
            HTTPStatus.OK,
            {
                "ok": True,
                "orgId": org_id,
                "deviceId": device_id,
                **payload,
            },
        )

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        path = parsed.path.rstrip("/")

        if path == "/health":
            self._json_response(
                HTTPStatus.OK,
                {
                    "ok": True,
                    "service": "pos-mock-remote-server",
                    "time": _now_iso(),
                },
            )
            return

        if path == "/api/bootstrap":
            self._handle_bootstrap(query)
            return

        if path == "/api/config":
            self._handle_config(query)
            return

        if path == "/api/devices/registrations":
            self._handle_device_list(query)
            return

        if path in {"/api/orders/import", "/api/products/import", "/api/customers/import", "/api/credits/import", "/api/tables/import"}:
            entity = path.split("/")[2]
            self._handle_import(entity, query)
            return

        if path in {"/api/orders/exports", "/api/products/exports", "/api/customers/exports", "/api/credits/exports", "/api/tables/exports"}:
            entity = path.split("/")[2]
            self._json_response(HTTPStatus.OK, self.store.load_exports(entity))
            return

        self._json_response(HTTPStatus.NOT_FOUND, {"ok": False, "message": f"Unknown route: {path}"})

    def do_POST(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path.rstrip("/")

        if path in {"/api/orders/export", "/api/products/export", "/api/customers/export", "/api/credits/export", "/api/tables/export"}:
            entity = path.split("/")[2]
            self._handle_export(entity)
            return

        if path == "/api/devices/register":
            self._handle_device_registration()
            return

        if path == "/api/reset":
            self.store.reset_runtime()
            self._json_response(HTTPStatus.OK, {"ok": True, "message": "Runtime seeds and export history reset."})
            return

        self._json_response(HTTPStatus.NOT_FOUND, {"ok": False, "message": f"Unknown route: {path}"})

    def log_message(self, format: str, *args: Any) -> None:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        message = format % args
        print(f"[{timestamp}] {self.address_string()} {message}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run the POS mock remote server.")
    parser.add_argument("--host", default="127.0.0.1", help="Host interface to bind.")
    parser.add_argument("--port", type=int, default=8080, help="Port to bind.")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    server = ThreadingHTTPServer((args.host, args.port), MockRequestHandler)
    print(f"POS mock remote server listening on http://{args.host}:{args.port}")
    print("Available endpoints: /health, /api/bootstrap, /api/config, /api/devices/register, /api/devices/registrations, /api/{orders|products|customers|credits|tables}/{import|export|exports}, /api/reset")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down mock remote server.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())