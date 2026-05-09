# Technical Architecture

This document provides a detailed overview of the complex rendering logic and state management strategies implemented in Geocent.

## 1. Mapbox Rendering Logic
Geocent utilizes an advanced, high-performance rendering strategy on top of Mapbox. Instead of relying on Flutter to redraw thousands of markers�which would block the UI thread�we delegate the heavy lifting directly to the Mapbox Native GPU.

### Dual-Manager Strategy
We use two separate annotation managers concurrently:
- **CircleAnnotationManager (Dots)**: Renders lightweight, color-coded circles.
- **PointAnnotationManager (Callouts)**: Renders detailed text/image callouts (price and merchant).

**Why two managers?**
To achieve a clean visual hierarchy. Dots act as fallbacks when zoomed out, while detailed callouts appear when zoomed in. If callouts collide, dots remain visible beneath them.

### Native GPU Zoom Expressions
To manage performance and visual clutter, we use Mapbox's setStyleLayerProperty to apply native step expressions based on the camera's zoom level:
- **Callouts** are set to opacity: 0.0 below zoom level 13.0, and 1.0 above.
- **Dots** are hidden below 11.0 to declutter a city-level view, and visible above 11.0.

Because these rules are passed down to the GPU, panning and zooming remain perfectly smooth at 60/120fps regardless of the number of transactions loaded.

### Collision & Priority
- We disable IconAllowOverlap to let Mapbox's native collision engine hide overlapping callouts.
- When a user taps a marker or selects a transaction from the list, we dynamically update the symbolSortKey for that specific annotation to -1000000.0. This ensures the selected marker always wins the collision calculation and renders on top.

## 2. State Management (Unified State)
Geocent uses the provider package to maintain a "Unified State" approach, primarily managed by the SpendingService.

### The SpendingService
SpendingService acts as the primary source of truth for transaction and map state. It extends ChangeNotifier and maintains in-memory lists:
- _periodTransactions: Transactions within the current filter (e.g., Today, This Week).
- _mappedTransactions: Transactions with valid GPS coordinates.
- _paginatedMessages: A paginated, filterable list of all messages.

### The BudgetService
BudgetService manages the state of category-specific spending limits. It coordinates with BudgetRepository for persistence and TransactionRepository for real-time progress calculations. It recalculates percentage usage dynamically based on the requested period (Daily, Weekly, or Monthly).

### Database-to-UI Synchronization
To avoid race conditions and stale data, the app strictly follows a unidirectional data flow:
1. **Action**: User modifies data (e.g., updates a category) or background service saves a new SMS.
2. **Persistence**: The action is routed through TransactionRepository and executed directly against SQLite.
3. **Refresh**: The SpendingService.refresh() method is called. This queries the database for the freshest state and updates the in-memory lists.
4. **Rebuild**: notifyListeners() is called, prompting the Map, Messages List, and Analytics widgets to rebuild simultaneously with synchronized data.

### Isolate Boundary Synchronization
Transactions often arrive via SmsService while the app is in the background (running in a separate Dart isolate).
- The background isolate writes the transaction to SQLite.
- It then uses FlutterBackgroundService().invoke('transaction_saved') to broadcast an event.
- The main UI isolate listens for this event and triggers SpendingService.refresh(), ensuring the map and lists update in real-time if the app is open.
