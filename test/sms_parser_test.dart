import 'package:flutter_test/flutter_test.dart';
import 'package:geocent/models/app_transaction.dart';
import 'package:geocent/services/sms_parser.dart';

void main() {
  group('M-PESA', () {
    test('sent to, with "for account" clause', () {
      final tx = SmsParser.parse(
        'UDQ0H234DB Confirmed. Ksh75.00 sent to SAFARICOM DATA BUNDLES '
        'for account SAFARICOM DATA BUNDLES on 26/4/26 at 4:55 PM. '
        'New M-PESA balance is Ksh1,797.84.',
      )!;
      expect(tx.id, 'UDQ0H234DB');
      expect(tx.amount, 75.0);
      expect(tx.merchant, 'Safaricom Data Bundles');
      expect(tx.timestamp, DateTime(2026, 4, 26, 16, 55));
      expect(tx.balanceAfter, 1797.84);
      expect(tx.source, TransactionSource.mpesa);
      expect(tx.type, TransactionType.sent);
    });

    test('sent to a person strips the trailing phone number', () {
      final tx = SmsParser.parse(
        'UDQ0H234DC Confirmed. Ksh1,200.00 sent to JANE DOE 0712345678 '
        'on 1/5/26 at 9:05 AM. New M-PESA balance is Ksh500.00.',
      )!;
      expect(tx.merchant, 'Jane Doe');
      expect(tx.amount, 1200.0);
    });

    test('paid to', () {
      final tx = SmsParser.parse(
        'UDR0H250GJ Confirmed. Ksh750.00 paid to PAGE ALLIANCE CONSULTANTS. '
        'on 27/4/26 at 7:58 AM. New M-PESA balance is Ksh1,037.84.',
      )!;
      expect(tx.merchant, 'Page Alliance Consultants');
      expect(tx.type, TransactionType.payment);
      expect(tx.timestamp, DateTime(2026, 4, 27, 7, 58));
    });

    test('airtime', () {
      final tx = SmsParser.parse(
        'UDS0H2AZU8 confirmed.You bought Ksh1.00 of airtime on 28/4/26 at '
        '3:50 PM. New M-PESA balance is Ksh813.84.',
      )!;
      expect(tx.merchant, 'Safaricom Airtime');
      expect(tx.amount, 1.0);
      expect(tx.balanceAfter, 813.84);
    });

    test('12 AM and 12 PM map to 00:xx and 12:xx', () {
      String msg(String t) =>
          'ABC123 Confirmed. Ksh10.00 paid to SHOP. on 2/5/26 at $t. '
          'New M-PESA balance is Ksh1.00.';
      expect(SmsParser.parse(msg('12:10 AM'))!.timestamp.hour, 0);
      expect(SmsParser.parse(msg('12:10 PM'))!.timestamp.hour, 12);
    });

    test('impossible date is rejected instead of defaulting to now', () {
      expect(
        SmsParser.parse(
          'ABC123 Confirmed. Ksh10.00 paid to SHOP. on 2/13/26 at 1:00 PM. '
          'New M-PESA balance is Ksh1.00.',
        ),
        isNull,
      );
    });
  });

  group('Equity', () {
    test('KES card auth with space-separated thousands', () {
      final tx = SmsParser.parse(
        'CONFIRMED. KES 1 306.00, Auth for card 4478..8033 at '
        'GOOGLE *YouTubePremium on 2026-04-26 21:05:24 Ref:611602020521.',
      )!;
      expect(tx.id, '611602020521');
      expect(tx.amount, 1306.0);
      expect(tx.merchant, 'Google *youtubepremium');
      expect(tx.timestamp, DateTime(2026, 4, 26, 21, 5, 24));
      expect(tx.source, TransactionSource.equity);
    });
  });

  test('non-financial SMS returns null', () {
    expect(SmsParser.parse('Your OTP is 123456'), isNull);
    expect(SmsParser.isFinancialSms('Hello there'), isFalse);
  });
}
