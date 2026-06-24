import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../services/database_service.dart';

class ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> exp;
  final VoidCallback onRefresh;
  final Function(BuildContext, Map<String, dynamic>?) onEdit;

  final bool isSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const ExpenseCard({super.key, required this.exp, required this.onRefresh, required this.onEdit, this.isSelected = false, this.onLongPress, this.onTap});

  @override
  Widget build(BuildContext context) {
    bool isExpense = (exp['is_expense'] == null || exp['is_expense'] == 1);
    bool isCredit = (exp['type'] == 'Credit');
    bool isEdited = (exp['is_edited'] == 1);
    DateTime date = DateTime.parse(exp['date']);
    String formattedDate = "${date.day}/${date.month}/${date.year}";
    String category = exp['category'] ?? 'Other';
    Color catColor = AppConstants.getCategoryColor(category);
    String account = exp['account'] ?? 'Cash/Other';

    return Container(
      // 1. Margin vertical kam kiya (6 se 5)
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      clipBehavior: Clip.antiAlias, // Taki left border proper rounded rahe
      decoration: BoxDecoration(
        // Pure White background for premium feel (selection par halka tint)
        color: isSelected ? AppConstants.primaryColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? AppConstants.primaryColor : Colors.grey.shade100, width: 1),

        // 2. PREMIUM COLORED SHADOW (Category ka color glow karega)
        boxShadow: [BoxShadow(color: catColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: IntrinsicHeight(
        // Ye fix karega ki color strip poori height le
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---> 3. PREMIUM LEFT SIDE COLOR INDICATOR <---
            Container(
              width: 6, // Patli sleek line
              color: catColor,
            ),

            // ---> MAIN CONTENT <---
            Expanded(
              child: ListTile(
                // ---> 4. HEIGHT REDUCTION TWEAKS <---
                dense: false,
                visualDensity: const VisualDensity(horizontal: 0, vertical: -0), // Yahan se extra padding hatega
                contentPadding: const EdgeInsets.only(left: 12, right: 16, top: 2, bottom: 2), // Padding tight ki

                onTap: onTap ?? () => onEdit(context, exp),
                onLongPress: onLongPress,

                leading: Container(
                  padding: const EdgeInsets.all(8), // Icon padding kam ki
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10), // Radius thoda sharp kiya
                  ),
                  child: Icon(AppConstants.getCategoryIcon(category), color: catColor, size: 25), // Icon size thoda chota kiya
                ),
                title: Text(
                  exp['merchant'],
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.black87), // Font size tweak
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          "$category • $formattedDate",
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (exp['is_hidden'] == 1) ...[const SizedBox(width: 4), Icon(Icons.visibility_off, size: 12, color: Colors.orange.shade600)],
                    ],
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 90,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          "${isCredit ? '+' : '-'} ₹${exp['amount']}",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: !isExpense ? Colors.grey.shade300 : (isCredit ? Colors.green : Colors.red)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2), // Height gap kam kiya
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isEdited) ...[const Icon(Icons.edit_note, color: Colors.orange, size: 12), const SizedBox(width: 2)],
                        Text(
                          account,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () async {
                            await DatabaseHelper.instance.toggleExpenseStatus(exp['id'], isExpense ? 0 : 1);
                            onRefresh();
                          },
                          borderRadius: BorderRadius.circular(12),
                          // ---> ARROW KO 45 DEGREE ROTATE KIYA <---
                          child: Transform.rotate(
                            angle: 0.7854, // Exactly 45 degrees in radians
                            child: Icon(isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: !isExpense ? Colors.grey.shade400 : (isCredit ? const Color.fromARGB(255, 31, 85, 62) : const Color.fromARGB(255, 119, 14, 14)), size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
