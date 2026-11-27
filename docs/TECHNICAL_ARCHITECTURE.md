# Technical Architecture

Geocent is a single-module native Android app (`app/`) written in Kotlin with Jetpack Compose. All data stays on the device.

## Packages (`app.geocent`)

| Package | Responsibility |
|---|---|
| `domain` | Pure Kotlin logic with no Android dependencies, unit tested: SMS parsing, periods (Sunday-start weeks), geo maths, budget alert rule, place grouping, analytics, hotspot clustering, category catalog |
| `data` | Room database, DAOs and repositories; messages query builder; area and budget summaries; DataStore settings |
| `ingest` | SMS receiver, workers (live SMS, inbox import, hotspot refresh and transitions), geofence and boot receivers |
| `location` | Fused location provider, geofence registration |
| `notify` | Notification channels and budget alert checks |
| `ui` | Compose screens per tab (`map`, `messages`, `budgets`, `analytics`, `profile`), onboarding, location picker, shared components and theme |
| `di` | Hilt modules |

## How a payment flows through the app

1. `SmsReceiver` (manifest receiver, protected by `BROADCAST_SMS`) gets every SMS. If `SmsParser` recognises it, it enqueues an expedited `IngestSmsWorker`. The work is unique per transaction id, so duplicates can't be processed twice.
2. `TransactionIngestor.ingestLive`:
   - stores it (skipping duplicates and forgotten ids) and applies the learned merchant category
   - posts "New expense tracked"
   - checks the category's budget
   - attaches the current location: a fix under 5 minutes old, otherwise a fresh one (30 s timeout)
3. Screens observe Room `Flow`s, so every tab updates by itself. There are no manual refresh events.
4. A new location requests a debounced hotspot refresh.

There is no always-on foreground service. Work runs only when an SMS arrives or a scheduled job is due.

## Map rendering

The Map tab uses MapLibre Native with OpenFreeMap vector styles (`ui/map/MapLibreView.kt`). `installGeocentLayers` adds Geocent's own sources and layers to each style:

- **`places-dots`** (circle layer): category-coloured dots, visible from zoom 9.
- **`places-callouts`** (symbol layer): price-tag images drawn by `CalloutRenderer`, visible from zoom 11.
  - Collision is on, and `symbol-sort-key` decides who wins: selected marker, then multi-payment spots, then smaller amounts.
  - The callout bitmap is vertically symmetric so the dot sits exactly on the coordinate.
- **`area-fill`, `area-line`, `area-pin`**: the "spending around here" radius.

Switching styles drops custom layers, so they are re-added in the style-loaded callback. Today's payments are grouped per identical coordinate (`domain/Places.kt`).

"Spending around here" queries a lat/lng bounding box in SQL, then keeps only points within the exact radius (`data/AreaSpending.kt`).

The heatmap from the Flutter app is not shown for now. It's planned as an optional toggle; the original layer is in commit `a834992`.

## Hotspots and geofences

- `Hotspots.cluster` runs DBSCAN: 100 m neighbourhood, 3 neighbours, centred on the medoid, at least 50 m radius. It needs 10 or more geotagged payments.
- `Hotspots.assignIds` keeps a hotspot's id when a new cluster lies within 150 m of it, so geofences and the 6-hour alert cooldown survive re-clustering.
- `GeofenceManager` registers the 100 nearest hotspots: dwell after 5 minutes, plus exit. This needs location "all the time".
- `HotspotRefreshWorker` runs one minute after new locations, every 12 hours, and after reboot.

## Theme

`ui/theme` implements `DESIGN.md`: light and dark colour tokens, `#0071E3` as the only interactive colour, Space Grotesk for text and tabular Inter for numbers.
