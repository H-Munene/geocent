package app.geocent.data.db

import android.content.ContentValues
import android.database.sqlite.SQLiteDatabase
import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.sqlite.db.SupportSQLiteDatabase
import app.geocent.domain.CategoryCatalog

@Database(
    entities = [
        TransactionEntity::class,
        IgnoredTransactionEntity::class,
        MerchantCategoryEntity::class,
        CategoryEntity::class,
        BudgetEntity::class,
        HotspotEntity::class,
    ],
    version = 1,
    exportSchema = true,
)
abstract class GeocentDatabase : RoomDatabase() {
    abstract fun transactions(): TransactionDao
    abstract fun merchantCategories(): MerchantCategoryDao
    abstract fun categories(): CategoryDao
    abstract fun budgets(): BudgetDao
    abstract fun hotspots(): HotspotDao

    companion object {
        const val NAME = "geocent.db"

        /** Seeds the default categories the first time the database is created. */
        val seedCallback = object : Callback() {
            override fun onCreate(db: SupportSQLiteDatabase) {
                CategoryCatalog.defaults.forEachIndexed { index, category ->
                    db.insert(
                        "categories",
                        SQLiteDatabase.CONFLICT_IGNORE,
                        ContentValues().apply {
                            put("name", category.name)
                            put("icon_key", category.iconKey)
                            put("color_argb", category.colorArgb)
                            put("sort_order", index)
                        },
                    )
                }
            }
        }
    }
}
