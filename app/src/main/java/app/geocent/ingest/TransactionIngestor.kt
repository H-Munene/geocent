package app.geocent.ingest

import app.geocent.data.TransactionRepository
import app.geocent.data.db.TransactionEntity
import app.geocent.domain.SmsParser
import app.geocent.location.LocationProvider
import app.geocent.notify.BudgetChecker
import app.geocent.notify.Notifier
import javax.inject.Inject
import javax.inject.Singleton

/**
 * The single place an SMS becomes a stored transaction. Live SMS get the full
 * treatment (notification, budget check, GPS); inbox imports are stored
 * quietly because their location at the time is unknown.
 */
@Singleton
class TransactionIngestor @Inject constructor(
    private val repository: TransactionRepository,
    private val location: LocationProvider,
    private val budgets: BudgetChecker,
    private val notifier: Notifier,
) {
    /** Handles a just-received SMS. Returns the stored transaction, or null if skipped. */
    suspend fun ingestLive(body: String): TransactionEntity? {
        val parsed = SmsParser.parse(body) ?: return null
        val saved = repository.save(parsed) ?: return null

        notifier.transaction(saved.id, saved.merchant, formatAmount(saved))
        saved.category?.let { budgets.check(it) }

        // The phone is where the purchase happened, give or take a few minutes.
        location.currentLocation()?.let { repository.setLocation(listOf(saved.id), it.latitude, it.longitude) }
        return saved
    }

    /** Stores an inbox message without notifying or geotagging. True if it was new. */
    suspend fun ingestHistorical(body: String): Boolean {
        val parsed = SmsParser.parse(body) ?: return false
        return repository.save(parsed) != null
    }

    private fun formatAmount(tx: TransactionEntity) =
        if (tx.currency == "KES") Notifier.formatKes(tx.amount) else "${tx.currency} ${"%.2f".format(tx.amount)}"
}
