package app.geocent.data.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.RawQuery
import androidx.room.Transaction
import androidx.room.Upsert
import androidx.sqlite.db.SupportSQLiteQuery
import kotlinx.coroutines.flow.Flow

/** Only outgoing KES transactions count as spending in totals. */
private const val SPENDING = "type IN ('SENT', 'PAYMENT') AND currency = 'KES'"

@Dao
interface TransactionDao {

    /** Returns -1 when the id already exists (duplicate SMS). */
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(tx: TransactionEntity): Long

    @Query("SELECT * FROM transactions WHERE id = :id")
    suspend fun get(id: String): TransactionEntity?

    /** True if the id is stored or was deliberately forgotten. */
    @Query(
        """SELECT EXISTS(SELECT 1 FROM transactions WHERE id = :id)
           OR EXISTS(SELECT 1 FROM ignored_transactions WHERE id = :id)""",
    )
    suspend fun isKnown(id: String): Boolean

    @Query("UPDATE transactions SET latitude = :lat, longitude = :lng WHERE id IN (:ids)")
    suspend fun setLocation(ids: List<String>, lat: Double, lng: Double)

    @Query("UPDATE transactions SET category = :category WHERE id IN (:ids)")
    suspend fun setCategory(ids: List<String>, category: String)

    @Query("SELECT DISTINCT merchant FROM transactions WHERE id IN (:ids)")
    suspend fun merchantsOf(ids: List<String>): List<String>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertIgnored(rows: List<IgnoredTransactionEntity>)

    @Query("DELETE FROM transactions WHERE id IN (:ids)")
    suspend fun delete(ids: List<String>)

    /** Removes transactions and remembers their ids so imports skip them. */
    @Transaction
    suspend fun forget(ids: List<String>) {
        insertIgnored(ids.map(::IgnoredTransactionEntity))
        delete(ids)
    }

    @Query("SELECT * FROM transactions WHERE latitude IS NOT NULL AND longitude IS NOT NULL ORDER BY timestamp DESC")
    fun observeMapped(): Flow<List<TransactionEntity>>

    @Query("SELECT * FROM transactions WHERE latitude IS NOT NULL AND longitude IS NOT NULL")
    suspend fun mapped(): List<TransactionEntity>

    @Query("SELECT * FROM transactions WHERE timestamp BETWEEN :start AND :end ORDER BY timestamp DESC")
    fun observeBetween(start: Long, end: Long): Flow<List<TransactionEntity>>

    @Query("SELECT * FROM transactions WHERE category = :category ORDER BY timestamp DESC")
    fun observeByCategory(category: String): Flow<List<TransactionEntity>>

    @Query("SELECT COUNT(*) FROM transactions WHERE latitude IS NULL OR category IS NULL")
    fun observeActionableCount(): Flow<Int>

    @Query("SELECT COUNT(*) FROM transactions WHERE latitude IS NOT NULL AND longitude IS NOT NULL")
    suspend fun countGeotagged(): Int

    /** Geotagged spending inside a lat/lng box; callers refine with an exact distance check. */
    @Query(
        """SELECT * FROM transactions
           WHERE latitude BETWEEN :minLat AND :maxLat
             AND longitude BETWEEN :minLng AND :maxLng
             AND timestamp >= :since AND $SPENDING""",
    )
    fun observeInBox(minLat: Double, maxLat: Double, minLng: Double, maxLng: Double, since: Long): Flow<List<TransactionEntity>>

    /** Messages list: query built by MessageQuery (filters, search, paging). */
    @RawQuery(observedEntities = [TransactionEntity::class])
    fun observeRaw(query: SupportSQLiteQuery): Flow<List<TransactionEntity>>

    @Query(
        """SELECT IFNULL(category, 'Unmapped') AS category, COUNT(*) AS count,
                  SUM(amount) AS total_amount
           FROM transactions
           WHERE timestamp BETWEEN :start AND :end AND $SPENDING
           GROUP BY 1 ORDER BY total_amount DESC""",
    )
    suspend fun categoryTotals(start: Long, end: Long): List<CategoryTotal>

    @Query(
        """SELECT merchant AS recipient, COUNT(*) AS count, SUM(amount) AS total_amount
           FROM transactions
           WHERE timestamp BETWEEN :start AND :end AND $SPENDING
           GROUP BY merchant ORDER BY total_amount DESC""",
    )
    suspend fun recipientTotals(start: Long, end: Long): List<RecipientTotal>

    @Query(
        """SELECT date(timestamp / 1000, 'unixepoch', 'localtime') AS day, category,
                  SUM(amount) AS total_amount
           FROM transactions
           WHERE timestamp BETWEEN :start AND :end AND $SPENDING
           GROUP BY day, category ORDER BY day ASC""",
    )
    suspend fun dailyCategoryTotals(start: Long, end: Long): List<DailyCategoryTotal>

    @Query("SELECT IFNULL(SUM(amount), 0) FROM transactions WHERE timestamp BETWEEN :start AND :end AND $SPENDING")
    suspend fun totalSpending(start: Long, end: Long): Double

    @Query(
        """SELECT IFNULL(SUM(amount), 0) FROM transactions
           WHERE category = :category AND timestamp BETWEEN :start AND :end AND $SPENDING""",
    )
    suspend fun categorySpending(category: String, start: Long, end: Long): Double
}

@Dao
interface MerchantCategoryDao {
    @Query("SELECT category_name FROM merchant_categories WHERE merchant_name = :merchant")
    suspend fun categoryFor(merchant: String): String?

    @Upsert
    suspend fun upsert(rows: List<MerchantCategoryEntity>)
}

@Dao
interface CategoryDao {
    @Query("SELECT * FROM categories ORDER BY sort_order")
    fun observeAll(): Flow<List<CategoryEntity>>

    @Query("SELECT IFNULL(MAX(sort_order), -1) + 1 FROM categories")
    suspend fun nextSortOrder(): Int

    @Upsert
    suspend fun upsert(category: CategoryEntity)

    @Query("DELETE FROM categories WHERE name = :name")
    suspend fun delete(name: String)
}

@Dao
interface BudgetDao {
    @Query("SELECT * FROM budgets ORDER BY category_name")
    fun observeAll(): Flow<List<BudgetEntity>>

    @Query("SELECT * FROM budgets WHERE category_name = :category")
    suspend fun forCategory(category: String): BudgetEntity?

    @Upsert
    suspend fun upsert(budget: BudgetEntity)

    @Query("DELETE FROM budgets WHERE id = :id")
    suspend fun delete(id: String)

    @Query("UPDATE budgets SET last_notified_threshold = :threshold, last_notified_at = :at WHERE id = :id")
    suspend fun markNotified(id: String, threshold: Int, at: Long)
}

@Dao
interface HotspotDao {
    @Query("SELECT * FROM hotspots")
    fun observeAll(): Flow<List<HotspotEntity>>

    @Query("SELECT * FROM hotspots")
    suspend fun all(): List<HotspotEntity>

    @Query("SELECT * FROM hotspots WHERE id = :id")
    suspend fun get(id: String): HotspotEntity?

    @Query("DELETE FROM hotspots")
    suspend fun clear()

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(hotspots: List<HotspotEntity>)

    /** Replaces the whole set in one transaction. */
    @Transaction
    suspend fun replaceAll(hotspots: List<HotspotEntity>) {
        clear()
        insertAll(hotspots)
    }

    @Query("UPDATE hotspots SET last_notified_at = :at WHERE id = :id")
    suspend fun markNotified(id: String, at: Long)
}
