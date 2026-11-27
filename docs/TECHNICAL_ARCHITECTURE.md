# Technical Architecture

This document provides an overview of the rendering logic and state management strategies implemented in Geocent.

## 1. Map Rendering Logic
Geocent renders maps with MapLibre GL (`maplibre_gl`) using OpenStreetMap vector tiles served by [OpenFreeMap](https://openfreemap.org) (styles: Liberty, Positron, Dark; no API key). Marker styling runs as native style expressions on the GPU, so the UI thread stays responsive with thousands of markers. Style URLs live in `lib/utils/map_styles.dart`.

### Data-Driven Layers
Today's places are written to one GeoJSON source (`places-source`), drawn by two layers:
- **`places-dots` (circle layer)**: lightweight, category-coloured dots.
- **`places-callouts` (symbol layer)**: price/merchant callout images, rendered by `createCalloutImage` and registered with `addImage`.

A `hotspots-heatmap` layer sits below the dots.

Switching styles discards custom sources, layers and images, so `_onStyleLoaded` in `map_screen.dart` re-adds them after every style load.

**Visual Hierarchy**
Dots act as fallbacks when zoomed out, while detailed callouts appear when zoomed in. If callouts collide, dots remain visible beneath them.

### Zoom Expressions
Opacity is set with `step` expressions on the camera zoom:
- **Callouts** are hidden below zoom 11.0.
- **Dots** are hidden below zoom 9.0.

### Collision & Priority
- `icon-allow-overlap` is off, so MapLibre's collision engine hides overlapping callouts.
- Each feature carries a `sortKey` property used by `symbol-sort-key`. The selected place gets -1,000,000 and the GeoJSON is re-pushed, so it wins collision.

### Interaction
- Taps arrive through `onFeatureTapped`; the feature id maps back to a `MapPlace`.
- MapLibre has no per-feature long-press callback, so long presses call `queryRenderedFeatures` at the touch point.

## 2. State Management (Unified State)
Geocent uses the `provider` package for state management, primarily handled by the `SpendingService`.

### The SpendingService
`SpendingService` acts as the source of truth for transaction and map state. It maintains in-memory lists:
- `_periodTransactions`: Transactions within the active filter (e.g., Today, This Week).
- `_mappedTransactions`: Transactions with valid GPS coordinates.
- `_paginatedMessages`: A paginated, filterable list of all messages.

### The BudgetService
`BudgetService` manages category-specific spending limits, coordinating with `BudgetRepository` for persistence and `TransactionRepository` for progress calculations. Percentage usage is calculated dynamically based on the requested period.

### Database-to-UI Synchronization
The app follows a unidirectional data flow to prevent race conditions:
1. **Action**: User modifies data or the background service saves a new SMS.
2. **Persistence**: The action is routed through `TransactionRepository` and executed against SQLite.
3. **Refresh**: `SpendingService.refresh()` queries the database for the updated state.
4. **Rebuild**: `notifyListeners()` triggers the Map, Messages List, and Analytics widgets to rebuild with synchronized data.

### Isolate Boundary Synchronization
Transactions arriving via `SmsService` in the background run in a separate Dart isolate.
- The background isolate writes the transaction to SQLite.
- It broadcasts an event via `FlutterBackgroundService().invoke('transaction_saved')`.
- The main UI isolate listens for this event and triggers `SpendingService.refresh()`.
