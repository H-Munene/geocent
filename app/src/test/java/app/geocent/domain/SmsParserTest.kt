package app.geocent.domain

import app.geocent.domain.model.Currency
import app.geocent.domain.model.TransactionSource
import app.geocent.domain.model.TransactionType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDateTime

/** Ported from the Flutter test/sms_parser_test.dart, plus currency cases. */
class SmsParserTest {

    @Test
    fun `M-PESA sent to, with for account clause`() {
        val tx = SmsParser.parse(
            "UDQ0H234DB Confirmed. Ksh75.00 sent to SAFARICOM DATA BUNDLES " +
                "for account SAFARICOM DATA BUNDLES on 26/4/26 at 4:55 PM. " +
                "New M-PESA balance is Ksh1,797.84.",
        )!!
        assertEquals("UDQ0H234DB", tx.id)
        assertEquals(75.0, tx.amount, 0.0)
        assertEquals(Currency.KES, tx.currency)
        assertEquals("Safaricom Data Bundles", tx.merchant)
        assertEquals(LocalDateTime.of(2026, 4, 26, 16, 55), tx.timestamp)
        assertEquals(1797.84, tx.balanceAfter!!, 0.001)
        assertEquals(TransactionSource.MPESA, tx.source)
        assertEquals(TransactionType.SENT, tx.type)
    }

    @Test
    fun `M-PESA sent to a person strips the trailing phone number`() {
        val tx = SmsParser.parse(
            "UDQ0H234DC Confirmed. Ksh1,200.00 sent to JANE DOE 0712345678 " +
                "on 1/5/26 at 9:05 AM. New M-PESA balance is Ksh500.00.",
        )!!
        assertEquals("Jane Doe", tx.merchant)
        assertEquals(1200.0, tx.amount, 0.0)
    }

    @Test
    fun `M-PESA paid to`() {
        val tx = SmsParser.parse(
            "UDR0H250GJ Confirmed. Ksh750.00 paid to PAGE ALLIANCE CONSULTANTS. " +
                "on 27/4/26 at 7:58 AM. New M-PESA balance is Ksh1,037.84.",
        )!!
        assertEquals("Page Alliance Consultants", tx.merchant)
        assertEquals(TransactionType.PAYMENT, tx.type)
        assertEquals(LocalDateTime.of(2026, 4, 27, 7, 58), tx.timestamp)
    }

    @Test
    fun `M-PESA airtime`() {
        val tx = SmsParser.parse(
            "UDS0H2AZU8 confirmed.You bought Ksh1.00 of airtime on 28/4/26 at " +
                "3:50 PM. New M-PESA balance is Ksh813.84.",
        )!!
        assertEquals("Safaricom Airtime", tx.merchant)
        assertEquals(1.0, tx.amount, 0.0)
        assertEquals(813.84, tx.balanceAfter!!, 0.001)
    }

    @Test
    fun `12 AM and 12 PM map to 00 and 12 hours`() {
        fun msg(t: String) =
            "ABC123 Confirmed. Ksh10.00 paid to SHOP. on 2/5/26 at $t. New M-PESA balance is Ksh1.00."
        assertEquals(0, SmsParser.parse(msg("12:10 AM"))!!.timestamp.hour)
        assertEquals(12, SmsParser.parse(msg("12:10 PM"))!!.timestamp.hour)
    }

    @Test
    fun `impossible dates are rejected instead of defaulting to now`() {
        assertNull(
            SmsParser.parse(
                "ABC123 Confirmed. Ksh10.00 paid to SHOP. on 2/13/26 at 1:00 PM. New M-PESA balance is Ksh1.00.",
            ),
        )
        // 31 February also fails (the Flutter version let this roll over to March).
        assertNull(
            SmsParser.parse(
                "ABC123 Confirmed. Ksh10.00 paid to SHOP. on 31/2/26 at 1:00 PM. New M-PESA balance is Ksh1.00.",
            ),
        )
    }

    @Test
    fun `Equity KES card auth with space separated thousands`() {
        val tx = SmsParser.parse(
            "CONFIRMED. KES 1 306.00, Auth for card 4478..8033 at " +
                "GOOGLE *YouTubePremium on 2026-04-26 21:05:24 Ref:611602020521.",
        )!!
        assertEquals("611602020521", tx.id)
        assertEquals(1306.0, tx.amount, 0.0)
        assertEquals(Currency.KES, tx.currency)
        assertEquals("Google *youtubepremium", tx.merchant)
        assertEquals(LocalDateTime.of(2026, 4, 26, 21, 5, 24), tx.timestamp)
        assertEquals(TransactionSource.EQUITY, tx.source)
    }

    @Test
    fun `Equity USD keeps its currency`() {
        val tx = SmsParser.parse(
            "CONFIRMED. USD 9.99, Auth for card 4478..8033 at NETFLIX.COM " +
                "on 2026-05-01 08:00:00 Ref:611602020999.",
        )!!
        assertEquals(Currency.USD, tx.currency)
        assertEquals(9.99, tx.amount, 0.0)
    }

    @Test
    fun `non-financial SMS returns null`() {
        assertNull(SmsParser.parse("Your OTP is 123456"))
        assertFalse(SmsParser.isFinancialSms("Hello there"))
    }
}
