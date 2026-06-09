# Technical Architecture

This document provides an overview of the rendering logic and state management strategies implemented in Geocent.

## 1. Mapbox Rendering Logic
Geocent utilizes a high-performance rendering strategy on top of Mapbox. Rendering heavy lifting is delegated directly to the Mapbox Native GPU to ensure the UI thread remains responsive even with thousands of markers.

### Dual-Manager Strategy
Two separate annotation managers are used concurrently:
- **CircleAnnotationManager (Dots)**: Renders lightweight, color-coded circles.
- **PointAnnotationManager (Callouts)**: Renders detailed text/image callouts (price and merchant).

**Visual Hierarchy**
Dots act as fallbacks when zoomed out, while detailed callouts appear when zoomed in. If callouts collide, dots remain visible beneath them.

### Native GPU Zoom Expressions
To manage performance and visual clutter, `setStyleLayerProperty` applies native step expressions based on the camera's zoom level:
- **Callouts** are set to opacity: 0.0 below zoom level 13.0, and 1.0 above.
- **Dots** are hidden below 11.0 and visible above 11.0.

Because these rules are executed on the GPU, panning and zooming remain smooth regardless of the number of transactions loaded.

### Collision & Priority
- `IconAllowOverlap` is disabled to leverage Mapbox's native collision engine for hiding overlapping callouts.
- When a user selects a transaction, the `symbolSortKey` for that specific annotation is updated to -1,000,000.0. This ensures the selected marker renders on top of others.

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
