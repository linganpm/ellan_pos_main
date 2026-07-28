# POS Mock Remote Server

Local Python server that simulates remote import/export APIs for:

- orders
- products
- customers
- credits
- tables

It uses the JSON fixture files already present in this repository under `fixtures/` as the import seed data.

## Features

- `GET /health` health check
- `GET /api/orders/import`
- `POST /api/orders/export`
- `GET /api/products/import`
- `POST /api/products/export`
- `GET /api/customers/import`
- `POST /api/customers/export`
- `GET /api/credits/import`
- `POST /api/credits/export`
- `GET /api/tables/import`
- `POST /api/tables/export`
- `GET /api/{entity}/exports` to inspect captured export payloads
- `POST /api/reset` to clear captured exports

## Run

From the repository root:

```bash
./.venv/bin/python -m mock_remote_server.mock_remote_server --host 127.0.0.1 --port 8080
```

Or directly:

```bash
./.venv/bin/python mock_remote_server/mock_remote_server/server.py --host 127.0.0.1 --port 8080
```

## Optional Export Token Checks

If you want the mock server to enforce bearer tokens on export endpoints, set one or more of these environment variables before starting the server:

- `MOCK_SERVER_ORDERS_EXPORT_TOKEN`
- `MOCK_SERVER_PRODUCTS_EXPORT_TOKEN`
- `MOCK_SERVER_CUSTOMERS_EXPORT_TOKEN`
- `MOCK_SERVER_CREDITS_EXPORT_TOKEN`
- `MOCK_SERVER_TABLES_EXPORT_TOKEN`

Example:

```bash
export MOCK_SERVER_ORDERS_EXPORT_TOKEN=orders-token
export MOCK_SERVER_PRODUCTS_EXPORT_TOKEN=products-token
export MOCK_SERVER_CREDITS_EXPORT_TOKEN=credits-token
./.venv/bin/python -m mock_remote_server.mock_remote_server
```

## Query Parameters

Import endpoints accept optional query params:

- `orgId`
- `storeId`

Filtering is applied where the payload contains those fields. For product seed data, the bundled asset is category-based and does not carry store scope, so the full seeded payload is returned.

The tables import/export payload uses `floors` and `tables` arrays, and pagination is applied across the combined floor-table snapshot.

## Runtime Files

The server creates runtime state under:

`mock_remote_server/runtime/`

This stores:

- copied import seed files
- captured export request history
