package app.geocent.data.db

import androidx.room.ColumnInfo

/** Spending grouped by category ("Unmapped" when uncategorised). */
data class CategoryTotal(
    val category: String,
    val count: Int,
    @ColumnInfo(name = "total_amount") val totalAmount: Double,
)

/** Spending grouped by merchant/recipient. */
data class RecipientTotal(
    val recipient: String,
    val count: Int,
    @ColumnInfo(name = "total_amount") val totalAmount: Double,
)

/** Spending per local calendar day ("yyyy-MM-dd") and category. */
data class DailyCategoryTotal(
    val day: String,
    val category: String?,
    @ColumnInfo(name = "total_amount") val totalAmount: Double,
)
