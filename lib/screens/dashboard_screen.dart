import 'package:flutter/material.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:telephony/telephony.dart' as tele;

import '../constants/app_constants.dart';
import '../services/database_service.dart';
import '../services/sms_parser_service.dart';
import '../widgets/expense_card.dart';
import 'report_screen.dart';
import 'all_transactions_screen.dart';
import 'package:flutter/services.dart';
import 'settings_screen.dart'; // Agar folder alag hai toh path theek kar lena
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_snackbar.dart';

class BudgetDashboard extends StatefulWidget {
  const BudgetDashboard({super.key});
  @override
  State<BudgetDashboard> createState() => _BudgetDashboardState();
}

class _BudgetDashboardState extends State<BudgetDashboard> {
  List<Map<String, dynamic>> _expenses = [];
  final tele.Telephony telephony = tele.Telephony.instance;
  DateTime _selectedMonth = DateTime.now();
  final TextEditingController _searchController = TextEditingController();

  late ScrollController _scrollController;
  bool _isCardHidden = false;
  bool _isSearching = false;

  String? _activeCategoryFilter;
  String _transactionTypeFilter = 'Debit'; // 'All', 'Debit', 'Credit'

  double _totalSpends = 0.0, _totalToday = 0.0, _totalYesterday = 0.0, _totalWeek = 0.0;
  final List<String> _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

  Set<int> _selectedIds = {};

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadExpensesFromDB();
    _initializeSmsEngine();

    _scrollController = ScrollController();
    _scrollController.addListener(() {
      // 180 pixels ke baad flag true hoga
      if (_scrollController.offset > 180 && !_isCardHidden) {
        setState(() => _isCardHidden = true);
      } else if (_scrollController.offset <= 180 && _isCardHidden) {
        setState(() => _isCardHidden = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeSmsEngine() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != null && permissionsGranted) {
      await _scanAndSaveExpenses();
      _setupLiveSmsListener();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SMS Permissions required.")));
    }
  }

  void _setupLiveSmsListener() {
    telephony.listenIncomingSms(
      onNewMessage: (tele.SmsMessage message) async {
        if (message.body != null && message.date != null) {
          DateTime date = DateTime.fromMillisecondsSinceEpoch(message.date!);
          var expenseData = SmsParserService.parseMessage(message.body!, date, message.address ?? '');
          if (expenseData != null) {
            await DatabaseHelper.instance.insertExpense(expenseData);
            await _loadExpensesFromDB();
          }
        }
      },
      listenInBackground: true,
      onBackgroundMessage: backgroundMessageHandler,
    );
  }

  Future<void> _scanAndSaveExpenses() async {
    int addedCount = 0;
    int rejectedCount = 0;
    try {
      DateTime? lastSavedDate = await DatabaseHelper.instance.getLatestExpenseDate();
      final SmsQuery query = SmsQuery();
      List<SmsMessage> messages = await query.querySms(
        kinds: [SmsQueryKind.inbox],
        count: lastSavedDate == null ? 2000 : 200, //-- count removed - full storage scan karenge.
      );

      // DEBUG 1: Check karo plugin kitne total messages laya
      debugPrint("DEBUG: Total SMS Found in Phone: ${messages.length}");

      DateTime now = DateTime.now();
      DateTime cutoffDate = DateTime(now.year, now.month - 2, now.day);

      for (var msg in messages) {
        if (msg.body != null && msg.date != null) {
          String lowerBody = msg.body!.toLowerCase();
          bool isBankMsg = AppConstants.knownBanks.any((bank) => lowerBody.contains(bank));

          if (msg.date!.isBefore(cutoffDate)) {
            continue;
          }

          if (lastSavedDate != null && !msg.date!.isAfter(lastSavedDate)) break;

          try {
            var expenseData = SmsParserService.parseMessage(msg.body!, msg.date!, msg.address ?? '');
            if (expenseData != null) {
              int result = await DatabaseHelper.instance.insertExpense(expenseData);
              if (result != 0) addedCount++;
            } else if (isBankMsg) {
              // 2. Agar bank message hoke bhi reject hua toh yahan body print hogi
              rejectedCount++;
              debugPrint("DEBUG REJECTED: ${msg.body}");
            }
          } catch (e) {
            // 3. Agar kisi SMS ki wajah se app fati toh
            debugPrint("DEBUG CRASH: $e on message: ${msg.body}");
          }
        }
      }

      // 4. Final summary log
      debugPrint("DEBUG SUMMARY: Added: $addedCount, Rejected Bank SMS: $rejectedCount");

      await _loadExpensesFromDB();
      // ---> UPDATE: NAYA POPUP LOGIC <---
      if (mounted) {
        if (addedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sync complete: $addedCount new records tracked."), backgroundColor: Colors.green));
        } else {
          CustomSnackBar.show(context: context, message: "No records found to sync.");
        }
      }
      // ----------------------------------
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  Future<void> _loadExpensesFromDB() async {
    // ---> NAYA LOGIC: SETTING READ KAREIN <---
    final prefs = await SharedPreferences.getInstance();
    bool includeHidden = prefs.getBool('show_hidden_globally') ?? false;

    // Database call mein includeHidden pass kar diya
    final dbData = await DatabaseHelper.instance.getAllExpenses(includeHidden: includeHidden);
    // -----------------------------------------

    List<Map<String, dynamic>> filteredData = [];
    double total = 0, tToday = 0, tYesterday = 0, tWeek = 0;
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime startOfWeek = today.subtract(Duration(days: now.weekday - 1));

    String searchQuery = _searchController.text.trim().toLowerCase();

    for (var exp in dbData) {
      if (exp['date'] == null) continue;
      DateTime expDate = DateTime.parse(exp['date']);

      if (expDate.year == _selectedMonth.year && expDate.month == _selectedMonth.month) {
        if (_activeCategoryFilter != null && (exp['category'] ?? 'Other') != _activeCategoryFilter) continue;
        if (_transactionTypeFilter != 'All' && (exp['type'] ?? 'Unknown') != _transactionTypeFilter) continue;

        if (searchQuery.isNotEmpty) {
          String body = (exp['body'] ?? '').toString().toLowerCase();
          String merchant = (exp['merchant'] ?? '').toString().toLowerCase();
          String account = (exp['account'] ?? '').toString().toLowerCase();
          String amount = (exp['amount'] ?? '').toString().toLowerCase();
          if (!body.contains(searchQuery) && !merchant.contains(searchQuery) && !account.contains(searchQuery) && !amount.contains(searchQuery)) continue;
        }

        filteredData.add(exp);

        bool isExpense = (exp['is_expense'] == null || exp['is_expense'] == 1);
        if (isExpense) {
          double amt = (exp['amount'] ?? 0.0).toDouble();
          String type = exp['type'] ?? 'Debit';

          // ---> NAYA LOGIC: CREDIT MINUS DEBIT CALCULATION <---
          double finalAmtToAdd = 0.0;

          if (_transactionTypeFilter == 'All') {
            // 'All' mode mein Income plus, aur Kharcha minus
            finalAmtToAdd = (type == 'Credit') ? amt : -amt;
          } else {
            // Debit ya Credit specific filter ho toh normal addition
            finalAmtToAdd = amt;
          }
          // ----------------------------------------------------

          total += finalAmtToAdd;
          DateTime expDay = DateTime(expDate.year, expDate.month, expDate.day);

          if (expDay.isAtSameMomentAs(today)) {
            tToday += finalAmtToAdd;
          } else if (expDay.isAtSameMomentAs(yesterday)) {
            tYesterday += finalAmtToAdd;
          } else if (expDay.isAfter(yesterday) || expDay.isAtSameMomentAs(startOfWeek) || expDay.isAfter(startOfWeek)) {
            tWeek += finalAmtToAdd;
          }
        }
      }
    }

    setState(() {
      _expenses = filteredData;
      _totalSpends = total;
      _totalToday = tToday;
      _totalYesterday = tYesterday;
      _totalWeek = tWeek + tToday + tYesterday;
    });
  }

  void _changeMonth(int offset) {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset));
    _loadExpensesFromDB();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Widget _buildSectionHeader(String title, double total) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: AppConstants.primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Text(
              "Total: ₹${total.toStringAsFixed(0)}",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseDetails(BuildContext context, {Map<String, dynamic>? exp}) {
    final bool isNew = exp == null;

    // ---> UPDATE 1: Ab 'is_manual' database flag se check hoga <---
    final bool isManual = isNew || (exp['is_manual'] == 1);

    final TextEditingController amountCtrl = TextEditingController(text: isNew ? '' : exp['amount'].toString());
    final TextEditingController merchantCtrl = TextEditingController(text: isNew ? '' : exp['merchant']);
    final TextEditingController bodyCtrl = TextEditingController(text: isNew ? '' : (exp['body'] ?? ''));

    String txType = isNew ? 'Debit' : (exp['type'] ?? 'Debit');
    bool isExpenseModal = isNew ? true : (exp['is_expense'] == null || exp['is_expense'] == 1);

    List<String> currentCategories = (txType == 'Credit') ? AppConstants.incomeCategories : AppConstants.categories;
    String selectedCategory = isNew ? (txType == 'Credit' ? currentCategories.first : 'Other') : (exp['category'] ?? SmsParserService.getFallbackCategory(exp['merchant']));

    if (!currentCategories.contains(selectedCategory)) selectedCategory = currentCategories.first;

    final String bodyText = isNew ? '' : (exp['body'] ?? "Original SMS content is unavailable.");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            currentCategories = (txType == 'Credit') ? AppConstants.incomeCategories : AppConstants.categories;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            isNew ? (txType == 'Credit' ? "Add Income" : "Add Expense") : "Edit Transaction",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: txType == 'Credit' ? Colors.green : AppConstants.primaryColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                setModalState(() {
                                  txType = (txType == 'Credit') ? 'Debit' : 'Credit';
                                  selectedCategory = (txType == 'Credit') ? AppConstants.incomeCategories.first : 'Other';
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: txType == 'Credit' ? Colors.green.shade50 : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: txType == 'Credit' ? Colors.green.shade300 : Colors.red.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      txType == 'Credit' ? "INCOME" : "EXPENSE",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: txType == 'Credit' ? Colors.green.shade700 : Colors.red.shade700),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.swap_horiz, size: 16, color: txType == 'Credit' ? Colors.green.shade700 : Colors.red.shade700),
                                  ],
                                ),
                              ),
                            ),
                            if (!isNew) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon((exp['is_hidden'] == 1) ? Icons.visibility_off : Icons.visibility, color: Colors.orange, size: 24),
                                onPressed: () async {
                                  int newStatus = (exp['is_hidden'] == 1) ? 0 : 1;
                                  await DatabaseHelper.instance.toggleHideExpense(exp['id'], newStatus);
                                  await _loadExpensesFromDB();
                                  if (context.mounted) Navigator.pop(context);
                                },
                              ),
                            ],
                            if (isManual && !isNew) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                                onPressed: () async {
                                  await DatabaseHelper.instance.deleteExpense(exp['id']);
                                  await _loadExpensesFromDB();
                                  if (context.mounted) Navigator.pop(context);
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      readOnly: !isManual,
                      decoration: InputDecoration(
                        labelText: "Amount (₹)",
                        prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: !isManual,
                        fillColor: !isManual ? Colors.grey.shade100 : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: merchantCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: "Merchant / Title",
                        prefixIcon: const Icon(Icons.storefront, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isManual) ...[
                      TextField(
                        controller: bodyCtrl,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: "Note (Optional)",
                          prefixIcon: const Icon(Icons.notes, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (!isManual) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Original SMS Text",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: bodyText));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!"), backgroundColor: Colors.green));
                            },
                            child: const Icon(Icons.copy, size: 16, color: AppConstants.primaryColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(bodyText, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4)),
                      ),
                      const SizedBox(height: 20),
                    ],

                    SizedBox(
                      height: 28,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            txType == 'Credit' ? "Valid Income (Include in Total)" : "Valid Expense (Include in Total)",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txType == 'Credit' ? Colors.green : Colors.red),
                          ),
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, value: isExpenseModal, activeThumbColor: txType == 'Credit' ? Colors.green : Colors.red, onChanged: (val) => setModalState(() => isExpenseModal = val)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      "Assign Category",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 150, // 3 lines ki fixed height
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(), // Smooth iPhone jaisa scroll
                        child: Wrap(
                          spacing: 8.0,
                          runSpacing: 10.0,
                          children: currentCategories.map((String c) {
                            bool isSelected = selectedCategory == c;
                            Color catColor = AppConstants.getCategoryColor(c);

                            return ChoiceChip(
                              label: Text(c),
                              selected: isSelected,
                              showCheckmark: false,
                              avatar: Icon(AppConstants.getCategoryIcon(c), color: isSelected ? Colors.white : catColor, size: 18),
                              selectedColor: catColor,
                              backgroundColor: catColor.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(color: isSelected ? catColor : Colors.transparent),
                              ),
                              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13.0),
                              onSelected: (bool selected) {
                                if (selected) setModalState(() => selectedCategory = c);
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: txType == 'Credit' ? Colors.green : AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          if (amountCtrl.text.isEmpty || merchantCtrl.text.isEmpty) return;
                          double amt = double.tryParse(amountCtrl.text) ?? 0.0;
                          String newMerchant = merchantCtrl.text;
                          final db = await DatabaseHelper.instance.database;
                          int finalExpenseFlag = isExpenseModal ? 1 : 0;

                          if (isNew) {
                            // ---> UPDATE 2: Nayi entry save karte time 'is_manual: 1' bhejna hai <---
                            await DatabaseHelper.instance.insertExpense({
                              'amount': amt, 'merchant': newMerchant, 'date': DateTime.now().toIso8601String(),
                              'type': txType, 'body': bodyCtrl.text.isNotEmpty ? bodyCtrl.text : '',
                              'category': selectedCategory, 'is_expense': finalExpenseFlag,
                              'is_edited': 0, 'is_manual': 1, // <-- Yahan add kiya
                            });
                          } else {
                            // ---> UPDATE 3: Agar edit ho raha hai, toh 'is_edited' hamesha 1 hoga <---
                            int newIsEdited = 1;

                            if (isManual) {
                              await db.update('expenses', {'amount': amt, 'merchant': newMerchant, 'body': bodyCtrl.text, 'category': selectedCategory, 'is_edited': newIsEdited, 'is_expense': finalExpenseFlag, 'type': txType}, where: 'id = ?', whereArgs: [exp['id']]);
                            } else {
                              await db.update('expenses', {'merchant': newMerchant, 'category': selectedCategory, 'is_edited': newIsEdited, 'is_expense': finalExpenseFlag, 'type': txType}, where: 'id = ?', whereArgs: [exp['id']]);
                            }
                          }
                          await _loadExpensesFromDB();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Saved successfully."), backgroundColor: txType == 'Credit' ? Colors.green : AppConstants.primaryColor));
                          }
                        },
                        child: const Text("Save Changes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showBulkCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Change Category (Bulk Edit)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                  ),
                  const SizedBox(height: 20),

                  // 1. EXPENSE CATEGORIES SECTION
                  const Text(
                    "EXPENSE CATEGORIES",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Wrap(spacing: 8.0, runSpacing: 10.0, children: AppConstants.categories.map((c) => _buildBulkChip(ctx, c, 'Debit')).toList()),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. INCOME CATEGORIES SECTION
                  const Text(
                    "INCOME CATEGORIES",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100), // Income ki categories kam hain toh iski height thodi kam rakhi hai
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Wrap(spacing: 8.0, runSpacing: 10.0, children: AppConstants.incomeCategories.map((c) => _buildBulkChip(ctx, c, 'Credit')).toList()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBulkChip(BuildContext ctx, String category, String txType) {
    Color catColor = AppConstants.getCategoryColor(category);

    return ActionChip(
      label: Text(category),
      avatar: Icon(AppConstants.getCategoryIcon(category), color: catColor, size: 18),
      backgroundColor: catColor.withValues(alpha: 0.1),

      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4.0),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.transparent),
      ),

      labelStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 13.0),

      // Jaise hi tap hoga, ye block chalega aur DB update karega
      onPressed: () async {
        try {
          final db = await DatabaseHelper.instance.database;

          // Agar by chance kisi wajah se selection clear ho gaya ho
          if (_selectedIds.isEmpty) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records selected!"), backgroundColor: Colors.red));
            }
            return;
          }

          int updateCount = _selectedIds.length;
          String idsPlaceholders = List.filled(updateCount, '?').join(',');

          // Database ko update karo
          int rowsAffected = await db.update(
            'expenses',
            {
              'category': category,
              'type': txType,
              'is_edited': 1, // Record ko edited mark karna
            },
            where: 'id IN ($idsPlaceholders)',
            whereArgs: _selectedIds.toList(),
          );

          // Dashboard screen se selection hatao
          setState(() {
            _selectedIds.clear();
          });

          // Naya data load karo
          await _loadExpensesFromDB();

          // 1. Pehle popup band karo (ctx use karke)
          if (ctx.mounted) {
            Navigator.pop(ctx);
          }

          // 2. Fir success/error message dikhao (main context use karke)
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Successfully updated $rowsAffected items to $category!"), backgroundColor: txType == 'Credit' ? Colors.green : AppConstants.primaryColor));
          }
        } catch (e) {
          debugPrint("🔥 BULK EDIT ERROR: $e");

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e"), backgroundColor: Colors.red));
          }
        }
      },
    );
  }

  List<Widget> _buildExpenseListItems() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime startOfWeek = today.subtract(Duration(days: now.weekday - 1));

    List<Map<String, dynamic>> tList = [], yList = [], wList = [], mList = [];
    double tTot = 0, yTot = 0, wTot = 0, mTot = 0;

    for (var exp in _expenses) {
      DateTime expDay = DateTime.parse(exp['date']);
      expDay = DateTime(expDay.year, expDay.month, expDay.day);
      double amt = exp['amount'];
      bool isExp = (exp['is_expense'] == null || exp['is_expense'] == 1);

      if (expDay.isAtSameMomentAs(today)) {
        tList.add(exp);
        if (isExp) tTot += amt;
      } else if (expDay.isAtSameMomentAs(yesterday)) {
        yList.add(exp);
        if (isExp) yTot += amt;
      } else if (expDay.isAfter(yesterday) || expDay.isAtSameMomentAs(startOfWeek) || expDay.isAfter(startOfWeek)) {
        wList.add(exp);
        if (isExp) wTot += amt;
      } else {
        mList.add(exp);
        if (isExp) mTot += amt;
      }
    }

    List<Widget> listItems = [];
    if (tList.isNotEmpty) {
      listItems.add(_buildSectionHeader("TODAY", tTot));
      listItems.addAll(
        tList.map(
          (exp) => ExpenseCard(
            exp: exp,
            isSelected: _selectedIds.contains(exp['id']),
            onLongPress: () => _toggleSelection(exp['id']),
            onTap: () {
              if (_selectedIds.isNotEmpty) {
                _toggleSelection(exp['id']); // Agar mode on hai toh tap se select hoga
              } else {
                _showExpenseDetails(context, exp: exp); // Normal tap par edit khulega
              }
            },
            onRefresh: _loadExpensesFromDB,
            onEdit: (c, e) => _showExpenseDetails(c, exp: e),
          ),
        ),
      );
    }
    if (yList.isNotEmpty) {
      listItems.add(_buildSectionHeader("YESTERDAY", yTot));
      listItems.addAll(
        yList.map(
          (exp) => ExpenseCard(
            exp: exp,
            isSelected: _selectedIds.contains(exp['id']),
            onLongPress: () => _toggleSelection(exp['id']),
            onTap: () {
              if (_selectedIds.isNotEmpty) {
                _toggleSelection(exp['id']); // Agar mode on hai toh tap se select hoga
              } else {
                _showExpenseDetails(context, exp: exp); // Normal tap par edit khulega
              }
            },
            onRefresh: _loadExpensesFromDB,
            onEdit: (c, e) => _showExpenseDetails(c, exp: e),
          ),
        ),
      );
    }
    if (wList.isNotEmpty) {
      listItems.add(_buildSectionHeader("THIS WEEK", tTot + yTot + wTot));
      listItems.addAll(
        wList.map(
          (exp) => ExpenseCard(
            exp: exp,
            isSelected: _selectedIds.contains(exp['id']),
            onLongPress: () => _toggleSelection(exp['id']),
            onTap: () {
              if (_selectedIds.isNotEmpty) {
                _toggleSelection(exp['id']); // Agar mode on hai toh tap se select hoga
              } else {
                _showExpenseDetails(context, exp: exp); // Normal tap par edit khulega
              }
            },
            onRefresh: _loadExpensesFromDB,
            onEdit: (c, e) => _showExpenseDetails(c, exp: e),
          ),
        ),
      );
    }
    if (mList.isNotEmpty) {
      listItems.add(_buildSectionHeader("THIS MONTH", tTot + yTot + wTot + mTot));
      listItems.addAll(
        mList.map(
          (exp) => ExpenseCard(
            exp: exp,
            isSelected: _selectedIds.contains(exp['id']),
            onLongPress: () => _toggleSelection(exp['id']),
            onTap: () {
              if (_selectedIds.isNotEmpty) {
                _toggleSelection(exp['id']); // Agar mode on hai toh tap se select hoga
              } else {
                _showExpenseDetails(context, exp: exp); // Normal tap par edit khulega
              }
            },
            onRefresh: _loadExpensesFromDB,
            onEdit: (c, e) => _showExpenseDetails(c, exp: e),
          ),
        ),
      );
    }
    return listItems;
  }

  @override
  Widget build(BuildContext context) {
    // ---> DYNAMIC TEXT & CIRCULAR ARROW LOGIC START <---
    String cardTitle;
    IconData? titleIcon;

    // Sabhi state ke liye Premium Midnight Blue gradient
    List<Color> cardGradient = [const Color(0xFF0F172A), const Color(0xFF3B82F6)];

    if (_transactionTypeFilter == 'Credit') {
      cardTitle = "Total Income";
      titleIcon = Icons.arrow_downward_rounded;
    } else if (_transactionTypeFilter == 'Debit') {
      cardTitle = "Total Expense";
      titleIcon = Icons.arrow_upward_rounded;
    } else {
      cardTitle = "Net Balance";
      // Net Balance ke liye Wallet Icon laga diya
      titleIcon = Icons.account_balance_wallet_rounded;
    }
    // ---> DYNAMIC LOGIC END <---

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppConstants.primaryColor,
        elevation: 0, // Elevation hata diya kyuki shadow sticky header me aayegi
        title: const Text("Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          /* IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Data',
            onPressed: () async {
              bool? confirmDelete = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      SizedBox(width: 8),
                      Text("Delete All Data?"),
                    ],
                  ),
                  content: const Text("Permanently delete all expense records? Cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Delete All"),
                    ),
                  ],
                ),
              );
              if (confirmDelete == true) {
                await DatabaseHelper.instance.clearAllData();
                await _loadExpensesFromDB();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All data reset."), backgroundColor: Colors.redAccent));
              }
            },
          ), */
          IconButton(
            icon: const Icon(Icons.list_alt_rounded),
            tooltip: 'All Transactions & Export',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AllTransactionsScreen())).then((_) => _loadExpensesFromDB()),
          ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Sync Latest', onPressed: _scanAndSaveExpenses),
          IconButton(icon: const Icon(Icons.add_circle_outline, size: 26), tooltip: 'Add Manual', onPressed: () => _showExpenseDetails(context)),
          // ---> NAYA LOGIC: SETTINGS BUTTON <---
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            // ---> UPDATE: async lagaya aur Navigator ko await kiya <---
            onPressed: () async {
              // Yahan code ruka rahega jab tak aap settings se wapas nahi aate
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              // Wapas aate hi database aur preferences dobara load ho jayenge!
              _loadExpensesFromDB();
            },
            // ---------------------------------------------------------
          ),
          // ------------------------------------
        ],
      ),

      // ---> STACK KA USE: Taki naya Sticky Header list ke theek upar overlap kare <---
      body: Stack(
        children: [
          // 1. AAPKI ORIGINAL SCROLLING LIST
          ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              if (!_isSearching)
                // Card ka full design aur data display yahan hoga
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! > 0) {
                        _changeMonth(-1);
                      } else if (details.primaryVelocity! < 0) {
                        _changeMonth(1);
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      // ---> NAYA MIDNIGHT BLUE GRADIENT <---
                      gradient: LinearGradient(colors: cardGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                      boxShadow: [BoxShadow(color: cardGradient[1].withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: Stack(
                      children: [
                        // Graphics (Background Shapes)
                        Positioned(
                          right: -50,
                          top: -50,
                          child: Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
                          ),
                        ),
                        Positioned(
                          left: -80,
                          bottom: -60,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
                          ),
                        ),
                        Positioned(
                          left: 60,
                          top: -100,
                          child: Transform.rotate(angle: 0.5, child: Container(width: 30, height: 400, color: Colors.white.withValues(alpha: 0.06))),
                        ),

                        // Main Content
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Branding
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.credit_card, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "BUDGETGUARD",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2.0, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        "${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}",
                                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.calendar_month, color: Colors.white70, size: 16),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Title & Icon (Left)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (titleIcon != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                                      child: Icon(titleIcon, color: Colors.white, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    cardTitle,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 15, letterSpacing: 0.5),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              // Amount (Center)
                              Center(
                                child: Text(
                                  "₹ ${_formatIndianCurrency(_totalSpends)}",
                                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Stats Footer
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildMiniStat("TODAY", _totalToday), _buildMiniStat("YESTERDAY", _totalYesterday), _buildMiniStat("WEEK", _totalWeek)]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // ---> NAYA ANIMATED SWIPE INDICATOR <---
              if (!_isSearching)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Row(
                      key: ValueKey(_selectedMonth.month), // Month change hote hi animation trigger hogi
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 20,
                          height: 8,
                          decoration: BoxDecoration(color: AppConstants.primaryColor, borderRadius: BorderRadius.circular(4)),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: Colors.grey.shade300, shape: BoxShape.circle),
                        ),
                      ],
                    ),
                  ),
                ),

              if (_activeCategoryFilter != null && !_isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Filtered by: $_activeCategoryFilter",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() => _activeCategoryFilter = null);
                          _loadExpensesFromDB();
                        },
                        icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                        label: const Text("Clear", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),

              if (!_isSearching)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Transactions",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppConstants.primaryColor, fontSize: 15),
                          ),
                          IconButton(
                            icon: const Icon(Icons.search, size: 22, color: AppConstants.primaryColor),
                            onPressed: () => setState(() => _isSearching = true),
                          ),
                        ],
                      ),
                      Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<String>(
                          value: _transactionTypeFilter,
                          style: const TextStyle(fontSize: 12, color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: AppConstants.primaryColor, size: 20),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() => _transactionTypeFilter = newValue);
                              _loadExpensesFromDB();
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'Debit', child: Text("Debits Only")),
                            DropdownMenuItem(value: 'Credit', child: Text("Credits Only")),
                            DropdownMenuItem(value: 'All', child: Text("All")),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isSearching = false;
                                _searchController.clear();
                                _loadExpensesFromDB();
                                FocusScope.of(context).unfocus();
                              });
                            },
                            child: const Icon(Icons.arrow_back, color: AppConstants.primaryColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: (value) => _loadExpensesFromDB(),
                              decoration: InputDecoration(
                                hintText: "Search SMS, Amount, Merchant...",
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                fillColor: Colors.grey.shade100,
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Search Results",
                            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Total: ₹${_expenses.fold(0.0, (sum, item) => sum + ((item['is_expense'] == 1 || item['is_expense'] == null) ? item['amount'] : 0.0)).toStringAsFixed(0)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppConstants.primaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),

              if (_expenses.isEmpty)
                Container(
                  height: 250,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.query_stats, size: 60, color: AppConstants.primaryColor.withValues(alpha: 0.5)),
                      const SizedBox(height: 10),
                      const Text("No analytical data found.", style: TextStyle(fontSize: 16)),
                    ],
                  ),
                )
              else
                ..._buildExpenseListItems(),
            ],
          ),

          // 2. STICKY MINI HEADER (Wapas original blue theme)
          // 2. STICKY MINI HEADER (Premium aesthetic)
          // 2. STICKY MINI HEADER
          // 2. STICKY MINI HEADER
          // 2. STICKY MINI HEADER
          // 2. STICKY MINI HEADER
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: _isCardHidden && !_isSearching ? 0 : -100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: cardGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                boxShadow: [BoxShadow(color: cardGradient[1].withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            if (titleIcon != null) ...[
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                                child: Icon(titleIcon, color: Colors.white, size: 10),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              cardTitle.toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.0, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}",
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    // ---> INDIAN CURRENCY FORMATTER YAHAN LAGA DIYA <---
                    Text(
                      "₹ ${_formatIndianCurrency(_totalSpends)}",
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: _selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showBulkCategoryPicker(context),
              backgroundColor: AppConstants.primaryColor,
              icon: const Icon(Icons.edit, color: Colors.white),
              label: Text(
                "Change Category (${_selectedIds.length})",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : FloatingActionButton(
              child: const Icon(Icons.pie_chart_outline, size: 30),
              onPressed: () async {
                final returnedCategory = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportScreen(selectedMonth: _selectedMonth, filteredExpenses: _expenses),
                  ),
                );
                if (returnedCategory != null && returnedCategory is String) {
                  setState(() => _activeCategoryFilter = returnedCategory);
                }
                _loadExpensesFromDB();
              },
            ),
    );
  }

  Widget _buildMiniStat(String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Text(
          "₹${_formatIndianCurrency(amount)}", // Yahan bhi formatter lag gaya
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  String _formatIndianCurrency(double amount) {
    String val = amount.toStringAsFixed(0);
    if (val.length <= 3) return val;

    String lastThree = val.substring(val.length - 3);
    String otherNumbers = val.substring(0, val.length - 3);

    if (otherNumbers.isNotEmpty) {
      // Regular expression se 2-2 digits ke groups banayenge
      otherNumbers = otherNumbers.replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (match) => ',');
    }
    return "$otherNumbers,$lastThree";
  }
}
