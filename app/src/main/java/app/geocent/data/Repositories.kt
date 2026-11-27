package app.geocent.data

import app.geocent.data.db.BudgetDao
import app.geocent.data.db.BudgetEntity
import app.geocent.data.db.CategoryDao
import app.geocent.data.db.CategoryEntity
import app.geocent.data.db.HotspotDao
import app.geocent.data.db.HotspotEntity
import app.geocent.domain.Hotspots
import app.geocent.domain.SpendPoint
import app.geocent.domain.model.Currency
import app.geocent.data.db.MerchantCategoryDao
import app.geocent.data.db.MerchantCategoryEntity
import app.geocent.data.db.TransactionDao
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.ParsedTransaction
import app.geocent.domain.boundingBox
import app.geocent.domain.model.BudgetPeriod
import app.geocent.domain.toEpochMillis
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.time.ZoneId
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TransactionRepository @Inject constructor(
    private val transactions: TransactionDao,
    private val merchantCategories: MerchantCategoryDao,
) {
    /**
     * Stores a parsed SMS unless it is a duplicate or was forgotten.
     * Applies the learned category for its merchant. Returns the stored row,
     * or null if nothing was saved.
     */
    suspend fun save(parsed: ParsedTransaction, zone: ZoneId = ZoneId.systemDefault()): TransactionEntity? {
        if (transactions.isKnown(parsed.id)) return null
        val entity = TransactionEntity(
            id = parsed.id,
            amount = parsed.amount,
            currency = parsed.currency,
            merchant = parsed.merchant,
            rawMessage = parsed.rawMessage,
            timestamp = parsed.timestamp.toEpochMillis(zone),
            balanceAfter = parsed.balanceAfter,
            source = parsed.source,
            type = parsed.type,
            category = merchantCategories.categoryFor(parsed.merchant),
        )
        return entity.takeIf { transactions.insert(it) != -1L }
    }

    suspend fun get(id: String) = transactions.get(id)

    suspend fun setLocation(ids: List<String>, lat: Double, lng: Double) {
        if (ids.isNotEmpty()) transactions.setLocation(ids, lat, lng)
    }

    /** Sets the category and remembers it for each merchant involved. */
    suspend fun setCategory(ids: List<String>, category: String) {
        if (ids.isEmpty()) return
        transactions.setCategory(ids, category)
        val now = System.currentTimeMillis()
        merchantCategories.upsert(
            transactions.merchantsOf(ids).map { MerchantCategoryEntity(it, category, now) },
        )
    }

    suspend fun forget(ids: List<String>) {
        if (ids.isNotEmpty()) transactions.forget(ids)
    }

    fun observeMapped() = transactions.observeMapped()
    fun observeBetween(start: Long, end: Long) = transactions.observeBetween(start, end)
    fun observeByCategory(category: String) = transactions.observeByCategory(category)
    fun observeActionableCount() = transactions.observeActionableCount()

    fun observeMessages(filter: MessageFilter, search: String?, age: MessageAge, limit: Int) =
        transactions.observeRaw(MessageQuery.build(filter, search, age, limit))

    /** Live summary of spending within [radiusMeters] of a point since [sinceMillis]. */
    fun observeAreaSpending(lat: Double, lng: Double, radiusMeters: Double, sinceMillis: Long): Flow<AreaSummary> {
        val box = boundingBox(lat, lng, radiusMeters)
        return transactions.observeInBox(box.minLat, box.maxLat, box.minLng, box.maxLng, sinceMillis)
            .map { summarizeArea(it, lat, lng, radiusMeters) }
    }

    suspend fun categoryTotals(start: Long, end: Long) = transactions.categoryTotals(start, end)
    suspend fun recipientTotals(start: Long, end: Long) = transactions.recipientTotals(start, end)
    suspend fun dailyCategoryTotals(start: Long, end: Long) = transactions.dailyCategoryTotals(start, end)
    suspend fun totalSpending(start: Long, end: Long) = transactions.totalSpending(start, end)
    suspend fun categorySpending(category: String, start: Long, end: Long) =
        transactions.categorySpending(category, start, end)
}

@Singleton
class CategoryRepository @Inject constructor(private val categories: CategoryDao) {
    fun observeAll() = categories.observeAll()

    suspend fun add(name: String, iconKey: Int, colorArgb: Long) {
        categories.upsert(CategoryEntity(name.trim(), iconKey, colorArgb, categories.nextSortOrder()))
    }

    suspend fun delete(name: String) = categories.delete(name)
}

@Singleton
class BudgetRepository @Inject constructor(private val budgets: BudgetDao) {
    fun observeAll() = budgets.observeAll()

    suspend fun forCategory(category: String) = budgets.forCategory(category)

    /** One budget per category: updates the existing one or creates it. */
    suspend fun save(category: String, limit: Double, period: BudgetPeriod) {
        val existing = budgets.forCategory(category)
        budgets.upsert(
            BudgetEntity(
                id = existing?.id ?: UUID.randomUUID().toString(),
                categoryName = category,
                amountLimit = limit,
                period = period,
                updatedAt = System.currentTimeMillis(),
                // A changed limit or period starts alerts afresh.
                lastNotifiedThreshold = 0,
                lastNotifiedAt = null,
            ),
        )
    }

    suspend fun delete(id: String) = budgets.delete(id)
    suspend fun markNotified(id: String, threshold: Int, at: Long) = budgets.markNotified(id, threshold, at)
}

@Singleton
class HotspotRepository @Inject constructor(
    private val hotspots: HotspotDao,
    private val transactions: TransactionDao,
) {
    fun observeAll() = hotspots.observeAll()
    suspend fun all() = hotspots.all()
    suspend fun get(id: String) = hotspots.get(id)
    suspend fun markNotified(id: String, at: Long) = hotspots.markNotified(id, at)

    /**
     * Re-clusters geotagged spending and replaces the stored hotspots.
     * Hotspots that survive (same spot, see [Hotspots.assignIds]) keep their
     * id and alert cooldown. Returns the new set.
     */
    suspend fun recompute(): List<HotspotEntity> {
        val points = transactions.mapped()
            .filter { it.type.isSpending && it.currency == Currency.KES }
            .map { SpendPoint(it.id, it.latitude!!, it.longitude!!, it.amount) }
        if (points.size < Hotspots.MIN_GEOTAGGED) {
            hotspots.replaceAll(emptyList())
            return emptyList()
        }
        val previous = hotspots.all()
        val cooldowns = previous.associate { it.id to it.lastNotifiedAt }
        val result = Hotspots.assignIds(
            Hotspots.cluster(points), previous,
            previousId = { it.id }, previousLat = { it.latitude }, previousLng = { it.longitude },
            newId = { UUID.randomUUID().toString() },
        ).map { (id, c) ->
            HotspotEntity(
                id = id,
                latitude = c.latitude,
                longitude = c.longitude,
                radius = c.radiusMeters,
                avgSpend = c.averageSpend,
                totalSpend = c.totalSpend,
                transactionCount = c.count,
                lastNotifiedAt = cooldowns[id],
            )
        }
        hotspots.replaceAll(result)
        return result
    }
}
