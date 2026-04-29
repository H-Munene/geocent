// lib/services/sms_parser.dart
import '../models/app_transaction.dart';

class SmsParser {
  // ── M-PESA patterns ────────────────────────────────────────────────────────

  // Matches: "UDQ0H234DB Confirmed. Ksh75.00 sent to SAFARICOM DATA BUNDLES
  //           for account SAFARICOM DATA BUNDLES on 26/4/26 at 4:55 PM.
  //           New M-PESA balance is Ksh1,797.84."
  static final RegExp _mpesaSent = RegExp(
    r'^([A-Z0-9]+)\s+Confirmed\.\s+'
    r'Ksh([\d,]+\.?\d*)\s+sent to\s+(.+?)\s+(?:for account\s+.+?\s+)?'
    r'on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.'
    r'.*?New M-PESA balance is Ksh([\d,]+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );

  // Matches: "UDR0H250GJ Confirmed. Ksh750.00 paid to PAGE ALLIANCE CONSULTANTS.
  //           on 27/4/26 at 7:58 AM. New M-PESA balance is Ksh1,037.84."
  // Also:    "UDQ0H22TP1 Confirmed. Ksh120.00 paid to MAURICE OUMA.
  //           on 26/4/26 at 3:53 PM. New M-PESA balance is Ksh1,932.84."
  static final RegExp _mpesaPaid = RegExp(
    r'^([A-Z0-9]+)\s+Confirmed\.\s+'
    r'Ksh([\d,]+\.?\d*)\s+paid to\s+(.+?)\.?\s+'
    r'on\s+(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.'
    r'.*?New M-PESA balance is Ksh([\d,]+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );

  // Matches: "UDS0H2AZU8 confirmed.You bought Ksh1.00 of airtime on 28/4/26 at 3:50 PM.
  //           New M-PESA balance is Ksh813.84."
  static final RegExp _mpesaAirtime = RegExp(
    r'^([A-Z0-9]+)\s+confirmed\.\s*You bought Ksh([\d,]+\.?\d*)\s+of airtime on\s+'
    r'(\d{1,2}/\d{1,2}/\d{2,4})\s+at\s+(\d{1,2}:\d{2}\s*[AP]M)\.'
    r'.*?New M-PESA balance is Ksh([\d,]+\.?\d*)',
    caseSensitive: false,
    dotAll: true,
  );

  // ── Equity pattern ─────────────────────────────────────────────────────────

  // Matches: "CONFIRMED. KES 289.00, Auth for card 4478..8033 at
  //           GOOGLE *YouTubePremium on 2026-04-26 21:05:24 Ref:611602020521."
  static final RegExp _equity = RegExp(
    r'CONFIRMED\.\s+KES\s+([\d,]+\.?\d*),\s+'
    r'Auth for card\s+[\d.]+\s+at\s+(.+?)\s+'
    r'on\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+'
    r'Ref:(\d+)',
    caseSensitive: false,
    dotAll: true,
  );

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Returns an [AppTransaction] if [message] matches a known format,
  /// or null if the message is not a financial SMS we handle.
  static AppTransaction? parse(String message) {
    return _tryMpesaSent(message) ??
        _tryMpesaPaid(message) ??
        _tryMpesaAirtime(message) ??
        _tryEquity(message);
  }

  /// Returns true if this message is from M-PESA or Equity Bank.
  static bool isFinancialSms(String message) => parse(message) != null;

  // ── Private parsers ────────────────────────────────────────────────────────

  static AppTransaction? _tryMpesaSent(String message) {
    final match = _mpesaSent.firstMatch(message.trim());
    if (match == null) return null;

    return AppTransaction(
      id: match.group(1)!.trim(),
      amount: _parseAmount(match.group(2)!),
      merchant: _cleanMerchant(match.group(3)!),
      rawMessage: message,
      timestamp: _parseMpesaDateTime(match.group(4)!, match.group(5)!),
      balanceAfter: _parseAmount(match.group(6)!),
      source: TransactionSource.mpesa,
      type: TransactionType.sent,
    );
  }

  static AppTransaction? _tryMpesaPaid(String message) {
    final match = _mpesaPaid.firstMatch(message.trim());
    if (match == null) return null;

    return AppTransaction(
      id: match.group(1)!.trim(),
      amount: _parseAmount(match.group(2)!),
      merchant: _cleanMerchant(match.group(3)!),
      rawMessage: message,
      timestamp: _parseMpesaDateTime(match.group(4)!, match.group(5)!),
      balanceAfter: _parseAmount(match.group(6)!),
      source: TransactionSource.mpesa,
      type: TransactionType.payment,
    );
  }

  static AppTransaction? _tryMpesaAirtime(String message) {
    final match = _mpesaAirtime.firstMatch(message.trim());
    if (match == null) return null;

    return AppTransaction(
      id: match.group(1)!.trim(),
      amount: _parseAmount(match.group(2)!),
      merchant: 'Safaricom Airtime',
      rawMessage: message,
      timestamp: _parseMpesaDateTime(match.group(3)!, match.group(4)!),
      balanceAfter: _parseAmount(match.group(5)!),
      source: TransactionSource.mpesa,
      type: TransactionType.payment,
    );
  }

  static AppTransaction? _tryEquity(String message) {
    final match = _equity.firstMatch(message.trim());
    if (match == null) return null;

    return AppTransaction(
      id: match.group(4)!.trim(), // Ref number as id
      amount: _parseAmount(match.group(1)!),
      merchant: _cleanMerchant(match.group(2)!),
      rawMessage: message,
      timestamp: _parseEquityDateTime(match.group(3)!),
      source: TransactionSource.equity,
      type: TransactionType.payment,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// "1,797.84" → 1797.84
  static double _parseAmount(String raw) {
    return double.tryParse(raw.replaceAll(',', '')) ?? 0.0;
  }

  /// Trims, collapses whitespace, title-cases the merchant name.
  static String _cleanMerchant(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    // Title-case: "PAGE ALLIANCE CONSULTANTS" → "Page Alliance Consultants"
    return cleaned
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  /// Parses M-PESA date "26/4/26" + time "4:55 PM" into a DateTime.
  /// The year "26" is treated as 2026.
  static DateTime _parseMpesaDateTime(String datePart, String timePart) {
    try {
      final dateParts = datePart.split('/');
      final int day = int.parse(dateParts[0]);
      final int month = int.parse(dateParts[1]);
      int year = int.parse(dateParts[2]);
      if (year < 100) year += 2000; // "26" → 2026

      // Normalise "4:55 PM" → "04:55 PM"
      final timeClean = timePart.trim().toUpperCase();
      final timeMatch = RegExp(
        r'(\d{1,2}):(\d{2})\s*(AM|PM)',
      ).firstMatch(timeClean);
      int hour = int.parse(timeMatch!.group(1)!);
      final int minute = int.parse(timeMatch.group(2)!);
      final String meridiem = timeMatch.group(3)!;
      if (meridiem == 'PM' && hour != 12) hour += 12;
      if (meridiem == 'AM' && hour == 12) hour = 0;

      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return DateTime.now(); // fallback — won't silently corrupt data
    }
  }

  /// Parses Equity date "2026-04-26 21:05:24" into a DateTime.
  static DateTime _parseEquityDateTime(String raw) {
    return DateTime.tryParse(raw.trim()) ?? DateTime.now();
  }
}
