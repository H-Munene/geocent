import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocent/models/budget_progress.dart';
import 'package:geocent/services/budget_service.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:geocent/widgets/create_budget_sheet.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  String _selectedPeriod = 'Daily';

  @override
  Widget build(BuildContext context) {
    // Watch SpendingService to rebuild when transactions are categorized
    context.watch<SpendingService>();

    return CupertinoPageScaffold(
      backgroundColor: Colors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        border: null,
        middle: Text(
          'Budgets',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add_circled, size: 28),
          onPressed: () {
            showCupertinoModalPopup(
              context: context,
              builder: (context) => const CreateBudgetSheet(),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: CupertinoSegmentedControl<String>(
                groupValue: _selectedPeriod,
                onValueChanged: (value) {
                  setState(() {
                    _selectedPeriod = value;
                  });
                },
                children: const {
                  'Daily': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Daily'),
                  ),
                  'Weekly': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Weekly'),
                  ),
                  'Monthly': Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Monthly'),
                  ),
                },
              ),
            ),
            Expanded(
              child: FutureBuilder<List<BudgetProgress>>(
                future: context.watch<BudgetService>().getBudgetProgress(
                  _selectedPeriod,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  final progressItems = snapshot.data ?? [];

                  if (progressItems.isEmpty) {
                    return const Center(
                      child: Text(
                        'No budgets set for this period.\nTap + to add one.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CupertinoColors.systemGrey),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: progressItems.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (context) => CreateBudgetSheet(
                                budget: progressItems[index].budget,
                              ),
                            );
                          },
                          child: BudgetCard(progress: progressItems[index]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetCard extends StatelessWidget {
  final BudgetProgress progress;

  const BudgetCard({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final category = spendingService.getCategoryByName(progress.categoryName);

    // Progress Color Logic
    Color progressColor = CupertinoColors.systemGreen;
    if (progress.percentageUsed >= 0.8) {
      progressColor = CupertinoColors.systemRed;
    } else if (progress.percentageUsed >= 0.5) {
      progressColor = CupertinoColors.systemOrange;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.systemGrey4.withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (category != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: spendingService
                        .getCategoryColor(progress.categoryName)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: HugeIcon(
                    icon: category.icon,
                    size: 20,
                    color: spendingService.getCategoryColor(
                      progress.categoryName,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                progress.categoryName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'KES ${progress.totalSpentInPeriod.toInt()} / ${progress.amountLimit.toInt()}',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.percentageUsed.clamp(0.0, 1.0),
              backgroundColor: CupertinoColors.systemGrey6,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
