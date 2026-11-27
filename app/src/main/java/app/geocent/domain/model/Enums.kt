package app.geocent.domain.model

/** Who sent the SMS. Stored by name in the database. */
enum class TransactionSource { MPESA, EQUITY }

/** Direction of money. Only SENT and PAYMENT count as spending. */
enum class TransactionType { SENT, PAYMENT, RECEIVED, UNKNOWN;

    val isSpending: Boolean get() = this == SENT || this == PAYMENT
}

/** Budget window. Weeks start on Sunday (see Periods.kt). */
enum class BudgetPeriod { DAILY, WEEKLY, MONTHLY }

/** ISO 4217 codes the parsers can produce. Totals are only summed per currency. */
object Currency {
    const val KES = "KES"
    const val USD = "USD"
}
