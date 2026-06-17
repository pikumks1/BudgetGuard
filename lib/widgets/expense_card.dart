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

  const ExpenseCard({
    super.key,
    required this.exp,
    required this.onRefresh,
    required this.onEdit,
    this.isSelected = false, // Default false rahega
    this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isExpense = (exp['is_expense'] == null || exp['is_expense'] == 1);
    bool isCredit = (exp['type'] == 'Credit');
    bool isEdited = (exp['is_edited'] == 1);
    DateTime date = DateTime.parse(exp['date']);
    String formattedDate = "${date.day}/${date.month}/${date.year}";
    String category = exp['category'] ?? 'Other';
    Color catColor = AppConstants.categoryColors[category] ?? Colors.grey;
    String account = exp['account'] ?? 'Cash/Other';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        // ---> CARD KA COLOR SELECTION PE CHANGE HOGA <---
        color: isSelected ? AppConstants.primaryColor.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? AppConstants.primaryColor : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        // ---> ON TAP aur LONG PRESS UPDATE <---
        onTap: onTap ?? () => onEdit(context, exp),
        onLongPress: onLongPress,

        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: catColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(AppConstants.getCategoryIcon(category), color: catColor, size: 24),
        ),
        title: Text(
          exp['merchant'],
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Colors.black87),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min, // Taki extra space na le
            children: [
              Text(
                "$category • $formattedDate",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),

              // ---> NAYA LOGIC: DATE KE SATH EYE ICON <---
              if (exp['is_hidden'] == 1) ...[const SizedBox(width: 6), Icon(Icons.visibility_off, size: 14, color: Colors.orange.shade600)],
              // ------------------------------------------
            ],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "${isCredit ? '+' : '-'} ₹${exp['amount']}",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: !isExpense ? Colors.grey.shade400 : (isCredit ? Colors.green : Colors.red)),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isEdited)
                  const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(Icons.edit_note, color: Colors.orange, size: 16),
                  ),

                // --- ACCOUNT NAME ADDED HERE ---
                Text(
                  account,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 4), // Account aur Arrow ke beech ki spacing
                // -------------------------------
                InkWell(
                  onTap: () async {
                    await DatabaseHelper.instance.toggleExpenseStatus(exp['id'], isExpense ? 0 : 1);
                    onRefresh();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Icon(isExpense ? Icons.arrow_outward : Icons.keyboard_return, color: isExpense ? AppConstants.primaryColor : Colors.grey.shade400, size: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
