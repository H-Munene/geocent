# Database Schema & Data Layer

Geocent uses an offline-first architecture powered by SQLite (sqflite). This ensures privacy, fast loading times, and zero reliance on a continuous internet connection.

## 1. Architectural Decisions
- **Repository Pattern**: All raw SQL queries and data logic are abstracted behind TransactionRepository. The UI and Service layers never write SQL directly.
- **Singleton Database Helper**: DatabaseHelper manages the single connection pool to prevent locking issues, handles migrations, and defines strict column constants to prevent typo-related bugs.
- **Isolate-Safe**: The database is the single source of truth. Background isolates (SMS listening) and the foreground UI isolate communicate safely by writing to the database and broadcasting update events.

## 2. Data Integrity & Privacy
Privacy and security are fundamental to Geocent's design, given the sensitive nature of financial and geospatial data:
- **Offline-First by Design**: All transaction and location data is stored entirely locally on the user's device in a singleton SQLite database. 
- **Zero Cloud Sync**: The application operates without remote servers, ensuring that the user's spending habits and geo-verified visits are never transmitted to third parties.
- **Strict Data Deletion**: We've disabled Android's allowBackup and fullBackupContent features to guarantee that when the app is uninstalled, all local data—including the database—is completely wiped from the device and any associated cloud backups.

## 3. Table Definitions

### Table: transactions
Stores every parsed financial message.
- id (TEXT, PRIMARY KEY): The unique receipt/reference number (e.g., M-PESA code).
- amount (REAL, NOT NULL): The parsed numerical value.
- merchant (TEXT, NOT NULL): The normalized name of the recipient/sender.
- raw_message (TEXT, NOT NULL): The original SMS text.
- timestamp (TEXT, NOT NULL): ISO8601 formatted date of the transaction.
- balance_after (REAL): The account balance after the transaction (optional).
- source (TEXT, NOT NULL): The origin (e.g., 'mpesa', 'equity').
- type (TEXT, NOT NULL): 'sent', 'payment', 'received', or 'unknown'.
- latitude (REAL): Captured GPS latitude.
- longitude (REAL): Captured GPS longitude.
- category (TEXT): The user-assigned category name.

*Index*: idx_transactions_timestamp ensures blazing-fast retrieval for period-based queries.

### Table: spending_limits
Stores user-configured budget limits.
- period (TEXT, PRIMARY KEY): 'daily', 'weekly', or 'monthly'.
- limit_amount (REAL, NOT NULL): The maximum budget for the period.
- updated_at (TEXT, NOT NULL): Timestamp of the last change.

### Table: merchant_categories (Auto-Categorization)
Powers the intelligent categorization engine.
- merchant_name (TEXT, PRIMARY KEY): The normalized merchant name.
- category_name (TEXT, NOT NULL): The preferred category for this merchant.
- updated_at (TEXT, NOT NULL): Timestamp of the last mapping change.

## 4. Core Repository Logic (TransactionRepository)

### Auto-Categorization Engine
The repository automatically handles merchant categorization without relying on the UI state:
- **Auto-Apply (save)**: When a new transaction is inserted, the repository checks the merchant_categories table. If a mapping exists, the category is injected into the transaction before insertion.
- **Auto-Learn (updateCategory, updateCategories)**: Whenever a user manually assigns a category, the repository updates the transactions table AND 'learns' the preference by upserting into the merchant_categories table. 

### Geospatial Updates
- **updateLocation**: Updates a specific transaction's latitude and longitude when the background service successfully secures a GPS fix shortly after an SMS arrives.

## 5. Models
- **AppTransaction**: An immutable data class representing a single database row. It includes a copyWith method to facilitate safe, immutable state updates (e.g., attaching a category or location) before persisting back to the database.
