package app.geocent.data.db

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import app.geocent.domain.model.BudgetPeriod
import app.geocent.domain.model.TransactionSource
import app.geocent.domain.model.TransactionType

/**
 * One parsed financial SMS. Times are epoch milliseconds (UTC instants), so
 * SQL day grouping uses `date(timestamp / 1000, 'unixepoch', 'localtime')`.
 */
@Entity(
    tableName = "transactions",
    indices = [
        Index("timestamp"),
        Index("category"),
        Index(value = ["latitude", "longitude"]),
    ],
)
data class TransactionEntity(
    @PrimaryKey val id: String,
    val amount: Double,
    val currency: String,
    val merchant: String,
    @ColumnInfo(name = "raw_message") val rawMessage: String,
    val timestamp: Long,
    @ColumnInfo(name = "balance_after") val balanceAfter: Double?,
    val source: TransactionSource,
    val type: TransactionType,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val category: String? = null,
) {
    val hasLocation: Boolean get() = latitude != null && longitude != null
}

/** Transactions the user chose to forget; re-imports skip them. */
@Entity(tableName = "ignored_transactions")
data class IgnoredTransactionEntity(@PrimaryKey val id: String)

/** Learned merchant -> category mapping used for auto-categorisation. */
@Entity(tableName = "merchant_categories")
data class MerchantCategoryEntity(
    @PrimaryKey @ColumnInfo(name = "merchant_name") val merchantName: String,
    @ColumnInfo(name = "category_name") val categoryName: String,
    @ColumnInfo(name = "updated_at") val updatedAt: Long,
)

/** A spending category. Defaults are seeded on first launch; users can add more. */
@Entity(tableName = "categories")
data class CategoryEntity(
    @PrimaryKey val name: String,
    /** Key into CategoryCatalog.icons. */
    @ColumnInfo(name = "icon_key") val iconKey: Int,
    /** ARGB colour, e.g. 0xFFFF9500. */
    @ColumnInfo(name = "color_argb") val colorArgb: Long,
    @ColumnInfo(name = "sort_order") val sortOrder: Int,
)

@Entity(
    tableName = "budgets",
    indices = [Index(value = ["category_name"], unique = true)],
)
data class BudgetEntity(
    @PrimaryKey val id: String,
    @ColumnInfo(name = "category_name") val categoryName: String,
    @ColumnInfo(name = "amount_limit") val amountLimit: Double,
    val period: BudgetPeriod,
    @ColumnInfo(name = "updated_at") val updatedAt: Long,
    /** Highest alert already sent this period: 0, 50, 80 or 100. */
    @ColumnInfo(name = "last_notified_threshold") val lastNotifiedThreshold: Int = 0,
    @ColumnInfo(name = "last_notified_at") val lastNotifiedAt: Long? = null,
)

/**
 * A cluster of geotagged spending. [id] stays the same across re-clustering
 * (new clusters are matched to existing ones by proximity) so geofences and
 * alert cooldowns survive.
 */
@Entity(tableName = "hotspots")
data class HotspotEntity(
    @PrimaryKey val id: String,
    val latitude: Double,
    val longitude: Double,
    val radius: Double,
    @ColumnInfo(name = "avg_spend") val avgSpend: Double,
    @ColumnInfo(name = "total_spend") val totalSpend: Double,
    @ColumnInfo(name = "transaction_count") val transactionCount: Int,
    @ColumnInfo(name = "last_notified_at") val lastNotifiedAt: Long? = null,
)
