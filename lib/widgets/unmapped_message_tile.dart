import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_tut/models/app_transaction.dart';
import 'package:mapbox_tut/screens/location_picker_screen.dart';
import 'category_dropdown_widget.dart';

class UnmappedMessageTile extends StatelessWidget {
  final AppTransaction transaction;
  final bool showDivider;

  const UnmappedMessageTile({
    super.key,
    required this.transaction,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final bool needsMapping = transaction.latitude == null;

    Widget content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.merchant),
                    Text(needsMapping ? 'Needs mapping' : 'Needs categorization'),
                  ],
                ),
              ),
              Text(transaction.formattedAmount),
            ],
          ),
        ),
        if (showDivider) const Divider(),
      ],
    );

    return GestureDetector(
      onTap: () {
        if (needsMapping) {
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) =>
                  LocationPickerScreen(transaction: transaction),
            ),
          );
        } else {
          showCupertinoDialog(
            context: context,
            barrierDismissible: true,
            builder: (context) => Center(
              child: CategoryDropdownWidget(
                transactionId: transaction.id,
                currentCategory: transaction.category,
                onCategorySelected: () => Navigator.pop(context),
              ),
            ),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: content,
    );
  }
}
