# Database Schema

Geocent stores everything locally in a Room (SQLite) database, `geocent.db`. The exported schema is in `app/schemas/`. Entities are in `app/src/main/java/app/geocent/data/db/Entities.kt`.

## Privacy

- **Offline-first:** transactions, locations and budgets never leave the device. Map tiles are the only network traffic.
- **No backups:** `allowBackup` and `fullBackupContent` are off, so uninstalling the app removes all data.

## Conventions

- **Times:** epoch milliseconds (UTC instants). Day grouping in SQL uses `date(timestamp / 1000, 'unixepoch', 'localtime')`.
- **Spending:** totals count only outgoing payments (`type IN ('SENT','PAYMENT')`) in KES. USD is stored but summed separately.
- **Enums:** stored by name (`MPESA`, `PAYMENT`, `WEEKLY`, …).

## Tables

### `transactions`
One parsed financial SMS.

| Column | Type | Notes |
|---|---|---|
| `id` | TEXT PK | M-PESA code or Equity reference |
| `amount` | REAL | |
| `currency` | TEXT | `KES` or `USD` |
| `merchant` | TEXT | Cleaned, title-cased |
| `raw_message` | TEXT | Original SMS |
| `timestamp` | INTEGER | Epoch ms |
| `balance_after` | REAL? | M-PESA only |
| `source` | TEXT | `MPESA`, `EQUITY` |
| `type` | TEXT | `SENT`, `PAYMENT`, `RECEIVED`, `UNKNOWN` |
| `latitude`, `longitude` | REAL? | Null until placed |
| `category` | TEXT? | Null until categorised |

Indexed on `timestamp`, `category` and (`latitude`, `longitude`).

### `ignored_transactions`
Ids the user chose to forget. Imports skip them.

### `merchant_categories`
`merchant_name` (PK) → `category_name`. This is learned whenever a payment is categorised and applied to that merchant's future payments.

### `categories`
`name` (PK), `icon_key` (into `CategoryCatalog`), `color_argb`, `sort_order`. The 16 defaults are seeded on first launch. Deleting a category clears it from payments, merchant mappings and its budget.

### `budgets`
`id` (PK), `category_name` (unique), `amount_limit`, `period` (`DAILY`/`WEEKLY`/`MONTHLY`), `updated_at`, `last_notified_threshold` (0/50/80/100), `last_notified_at`. Alert state resets each period.

### `hotspots`
`id` (PK, stable across re-clustering), `latitude`, `longitude`, `radius`, `avg_spend`, `total_spend`, `transaction_count`, `last_notified_at` (for the 6-hour cooldown).

## Settings (DataStore, not Room)
Onboarding done, chosen import range, last import time, map style, active hotspot.
