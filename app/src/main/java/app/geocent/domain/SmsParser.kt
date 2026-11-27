package app.geocent.domain

import app.geocent.domain.model.Currency
import app.geocent.domain.model.TransactionSource
import app.geocent.domain.model.TransactionType
import java.time.DateTimeException
import java.time.LocalDateTime

/** A financial SMS turned into structured data, before it is stored. */
data class ParsedTransaction(
    /** M-PESA transaction code or Equity reference number. */
    val id: String,
    val amount: Double,
    val currency: String,
    val merchant: String,
    val rawMessage: String,
    /** Wall-clock time as written in the SMS (local time). */
    val timestamp: LocalDateTime,
    val balanceAfter: Double?,
    val source: TransactionSource,
    val type: TransactionType,
)

/**
 * Parses M-PESA (sent, paid, airtime) and Equity card-authorisation SMS.
 * Returns null for anything it doesn't recognise or whose date is invalid,
 * so a bad message is skipped instead of being stored with a made-up date.
 */
object SmsParser {

    private val OPTIONS = setOf(RegexOption.IGNORE_CASE, RegexOption.DOT_MATCHES_ALL)
    private const val AMOUNT = """([\d, ]+\.?\d*)"""
    private const val MPESA_DATE = """(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)"""
    private const val MPESA_BALANCE = """.*?New M-PESA balance is Ksh$AMOUNT"""

    // "UDQ0H234DB Confirmed. Ksh75.00 sent to SAFARICOM DATA BUNDLES for account
    //  SAFARICOM DATA BUNDLES on 26/4/26 at 4:55 PM. New M-PESA balance is Ksh1,797.84."
    private val mpesaSent = Regex(
        """^([A-Z0-9]+)\s+Confirmed\.\s+Ksh$AMOUNT\s+sent to\s+(.+?)\s+""" +
            """(?:for account\s+.+?\s+)?on\s+$MPESA_DATE\.?\s*$MPESA_BALANCE""",
        OPTIONS,
    )

    // "UDR0H250GJ Confirmed. Ksh750.00 paid to PAGE ALLIANCE CONSULTANTS.
    //  on 27/4/26 at 7:58 AM. New M-PESA balance is Ksh1,037.84."
    private val mpesaPaid = Regex(
        """^([A-Z0-9]+)\s+Confirmed\.\s+Ksh$AMOUNT\s+paid to\s+(.+?)\.?\s+""" +
            """on\s+$MPESA_DATE\.?\s*$MPESA_BALANCE""",
        OPTIONS,
    )

    // "UDS0H2AZU8 confirmed.You bought Ksh1.00 of airtime on 28/4/26 at 3:50 PM.
    //  New M-PESA balance is Ksh813.84."
    private val mpesaAirtime = Regex(
        """^([A-Z0-9]+)\s+confirmed\.\s*You bought Ksh$AMOUNT\s+of airtime on\s+""" +
            """$MPESA_DATE\.?\s*$MPESA_BALANCE""",
        OPTIONS,
    )

    // "CONFIRMED. KES 289.00, Auth for card 4478..8033 at GOOGLE *YouTubePremium
    //  on 2026-04-26 21:05:24 Ref:611602020521."  Also USD and "KES 1 306.00".
    private val equity = Regex(
        """CONFIRMED\.\s+(KES|USD)\s+$AMOUNT,\s+Auth for card\s+[\d.]+\s+at\s+(.+?)\s+""" +
            """on\s+(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})\s+Ref:(\d+)""",
        OPTIONS,
    )

    private val mpesaTime = Regex("""(\d{1,2}):(\d{2})\s*(AM|PM)""", RegexOption.IGNORE_CASE)
    private val trailingPhone = Regex("""\s+\d{9,10}$""")
    private val whitespace = Regex("""\s+""")

    fun parse(message: String): ParsedTransaction? {
        val text = message.trim()
        return parseMpesaTransfer(text, message, mpesaSent, TransactionType.SENT)
            ?: parseMpesaTransfer(text, message, mpesaPaid, TransactionType.PAYMENT)
            ?: parseAirtime(text, message)
            ?: parseEquity(text, message)
    }

    fun isFinancialSms(message: String): Boolean = parse(message) != null

    private fun parseMpesaTransfer(
        text: String,
        raw: String,
        regex: Regex,
        type: TransactionType,
    ): ParsedTransaction? {
        val g = regex.find(text)?.groupValues ?: return null
        val timestamp = mpesaDateTime(g[4], g[5]) ?: return null
        return ParsedTransaction(
            id = g[1].trim(),
            amount = amount(g[2]),
            currency = Currency.KES,
            merchant = cleanMerchant(g[3]),
            rawMessage = raw,
            timestamp = timestamp,
            balanceAfter = amount(g[6]),
            source = TransactionSource.MPESA,
            type = type,
        )
    }

    private fun parseAirtime(text: String, raw: String): ParsedTransaction? {
        val g = mpesaAirtime.find(text)?.groupValues ?: return null
        val timestamp = mpesaDateTime(g[3], g[4]) ?: return null
        return ParsedTransaction(
            id = g[1].trim(),
            amount = amount(g[2]),
            currency = Currency.KES,
            merchant = "Safaricom Airtime",
            rawMessage = raw,
            timestamp = timestamp,
            balanceAfter = amount(g[5]),
            source = TransactionSource.MPESA,
            type = TransactionType.PAYMENT,
        )
    }

    private fun parseEquity(text: String, raw: String): ParsedTransaction? {
        val g = equity.find(text)?.groupValues ?: return null
        val timestamp = try {
            LocalDateTime.of(
                g[4].toInt(), g[5].toInt(), g[6].toInt(),
                g[7].toInt(), g[8].toInt(), g[9].toInt(),
            )
        } catch (_: DateTimeException) {
            return null
        }
        return ParsedTransaction(
            id = g[10].trim(),
            amount = amount(g[2]),
            currency = g[1].uppercase(),
            merchant = cleanMerchant(g[3]),
            rawMessage = raw,
            timestamp = timestamp,
            balanceAfter = null,
            source = TransactionSource.EQUITY,
            type = TransactionType.PAYMENT,
        )
    }

    /** "1,797.84" or "1 306.00" -> 1797.84 / 1306.0 */
    private fun amount(raw: String): Double =
        raw.replace(",", "").replace(" ", "").toDoubleOrNull() ?: 0.0

    /** Trims, strips a trailing phone number, collapses spaces and title-cases. */
    private fun cleanMerchant(raw: String): String =
        raw.trim()
            .replace(trailingPhone, "")
            .replace(whitespace, " ")
            .split(" ")
            .joinToString(" ") { word ->
                if (word.isEmpty()) word
                else word[0].uppercaseChar() + word.substring(1).lowercase()
            }

    /** "26/4/26" + "4:55 PM" -> 2026-04-26T16:55. Null if the date is impossible. */
    private fun mpesaDateTime(datePart: String, timePart: String): LocalDateTime? {
        val (day, month, rawYear) = datePart.split("/").map { it.toInt() }
        val year = if (rawYear < 100) rawYear + 2000 else rawYear
        val t = mpesaTime.find(timePart.trim()) ?: return null
        var hour = t.groupValues[1].toInt()
        val minute = t.groupValues[2].toInt()
        val pm = t.groupValues[3].equals("PM", ignoreCase = true)
        if (pm && hour != 12) hour += 12
        if (!pm && hour == 12) hour = 0
        return try {
            LocalDateTime.of(year, month, day, hour, minute)
        } catch (_: DateTimeException) {
            null
        }
    }
}
