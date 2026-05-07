import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:geocent/models/category_item.dart';
import 'package:geocent/services/spending_service.dart';
import 'package:provider/provider.dart';

class CreateCategorySheet extends StatefulWidget {
  final String transactionId;
  final List<CategoryItem> availableIcons;

  const CreateCategorySheet({
    super.key,
    required this.transactionId,
    required this.availableIcons,
  });

  @override
  State<CreateCategorySheet> createState() => _CreateCategorySheetState();
}

class _CreateCategorySheetState extends State<CreateCategorySheet> {
  final TextEditingController _controller = TextEditingController();
  CategoryItem? _selectedIcon;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        border: null,
        middle: Text(
          'New Category',
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: const Color(0xFF1D1D1F),
          ),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            var name = _controller.text.trim();
            if (name.isNotEmpty && _selectedIcon != null) {
              final spending = context.read<SpendingService>();
              final existingCategories = spending.categories;

              // Check for duplicates (case-insensitive)
              if (existingCategories.any(
                (cat) => cat.name.toLowerCase() == name.toLowerCase(),
              )) {
                // Show an alert if a duplicate is found
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const Text('Duplicate Category'),
                    content: Text('A category named "$name" already exists.'),
                    actions: [
                      CupertinoDialogAction(
                        isDefaultAction: true,
                        child: const Text('OK'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                );
                return; // Stop execution
              }

              // Capitalize the first letter
              name = name.substring(0, 1).toUpperCase() + name.substring(1);

              final newCategory = CategoryItem(
                name: name,
                icon: _selectedIcon!.icon,
                color: _selectedIcon!.color,
              );
              spending.addCategory(newCategory);
              spending.updateCategory(widget.transactionId, name);
              Navigator.pop(context);
            }
          },
          child: Text(
            'Create',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0071E3),
            ),
          ),
        ),
      ),
      child: DefaultTextStyle(
        style: GoogleFonts.spaceGrotesk(
          color: const Color(0xFF1D1D1F),
          decoration: TextDecoration.none,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NAME',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.systemGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: _controller,
                  placeholder: 'e.g. Entertainment',
                  maxLength: 30,
                  placeholderStyle: GoogleFonts.spaceGrotesk(
                    color: CupertinoColors.systemGrey4,
                  ),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1D1D1F),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.systemGrey6,
                        width: 1.5,
                      ),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 32),
                Text(
                  'SELECT ICON',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.systemGrey,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                        ),
                    itemCount: widget.availableIcons.length,
                    itemBuilder: (context, index) {
                      final item = widget.availableIcons[index];
                      final isSelected = _selectedIcon == item;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? item.color.withValues(alpha: 0.15)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? item.color
                                  : CupertinoColors.transparent,
                              width: 2,
                            ),
                          ),
                          child: HugeIcon(
                            icon: item.icon,
                            color: isSelected
                                ? item.color
                                : CupertinoColors.systemGrey2,
                            size: 26,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
