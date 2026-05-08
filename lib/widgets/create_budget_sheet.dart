import 'package:flutter/cupertino.dart';
import 'package:geocent/models/budget.dart';
import 'package:geocent/services/budget_service.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:geocent/widgets/custom_toast.dart';
import 'package:provider/provider.dart';

class CreateBudgetSheet extends StatefulWidget {
  final Budget? budget;

  const CreateBudgetSheet({super.key, this.budget});

  @override
  State<CreateBudgetSheet> createState() => _CreateBudgetSheetState();
}

class _CreateBudgetSheetState extends State<CreateBudgetSheet> {
  late final TextEditingController _amountController;
  late String _selectedCategory;
  late String _selectedPeriod;

  final List<String> _periods = ['Daily', 'Weekly', 'Monthly'];

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.budget?.amountLimit.toInt().toString() ?? '',
    );
    _selectedCategory = widget.budget?.categoryName ?? 'Dining';
    _selectedPeriod = _capitalize(widget.budget?.period ?? 'Weekly');

    _amountController.addListener(_onChanged);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  void _onChanged() => setState(() {});

  bool get _isUpdate => widget.budget != null;

  bool get _hasChanges {
    if (!_isUpdate) return true;
    final amount = double.tryParse(_amountController.text) ?? 0;
    return amount != widget.budget!.amountLimit ||
        _selectedPeriod.toLowerCase() != widget.budget!.period.toLowerCase();
  }

  bool get _isValid {
    final amount = double.tryParse(_amountController.text);
    return amount != null && amount > 0 && _hasChanges;
  }

  @override
  void dispose() {
    _amountController.removeListener(_onChanged);
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spendingService = context.watch<SpendingService>();
    final categories = spendingService.categories;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isUpdate ? 'Update Budget' : 'Add Budget',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              CupertinoButton(
                padding: EdgeInsets.zero,
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Select Category'),
          SizedBox(
            height: 150,
            child: IgnorePointer(
              ignoring: _isUpdate,
              child: Opacity(
                opacity: _isUpdate ? 0.5 : 1.0,
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: categories.indexWhere(
                      (c) => c.name == _selectedCategory,
                    ),
                  ),
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    setState(() {
                      _selectedCategory = categories[index].name;
                    });
                  },
                  children: categories
                      .map((c) => Center(child: Text(c.name)))
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Amount Limit (Ksh)'),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _amountController,
            placeholder: 'e.g. 5000',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemBackground,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Period'),
          const SizedBox(height: 8),
          CupertinoSegmentedControl<String>(
            groupValue: _selectedPeriod,
            onValueChanged: (value) {
              setState(() {
                _selectedPeriod = value;
              });
            },
            children: {
              for (var p in _periods)
                p: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(p),
                ),
            },
          ),
          const Spacer(),
          CupertinoButton(
            color: _isValid
                ? const Color(0xFF0071E3)
                : CupertinoColors.systemGrey4,
            onPressed: _isValid
                ? () async {
                    final amount = double.tryParse(_amountController.text);
                    if (amount == null || amount <= 0) return;

                    await context.read<BudgetService>().addOrUpdateBudget(
                      categoryName: _selectedCategory,
                      amountLimit: amount,
                      period: _selectedPeriod,
                    );

                    showCustomToast(
                      _isUpdate
                          ? 'Budget updated successfully'
                          : 'Budget created successfully',
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                : null,
            child: Text(
              _isUpdate ? 'Update Budget' : 'Save Budget',
              style: TextStyle(
                color: _isValid
                    ? CupertinoColors.white
                    : CupertinoColors.systemGrey,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
