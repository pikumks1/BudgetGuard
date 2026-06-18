import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../constants/app_constants.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AllTransactionsScreen extends StatefulWidget {
  const AllTransactionsScreen({super.key});
  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  List<Map<String, dynamic>> _allData = [];
  List<Map<String, dynamic>> _filteredData = [];
  String _searchQuery = "", _selectedType = "All", _selectedCategory = "All", _selectedPayMode = "All";
  final List<String> _types = ["All", "Debit", "Credit"];
  List<String> _categories = ["All"];
  List<String> _payModes = ["All"];

  // ---> NAYA VARIABLE: Date filter track karne ke liye <---
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();

    // ---> NAYA LOGIC: By default is mahine ka data dikhega <---
    DateTime now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0), // Month ka aakhiri din
    );

    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    bool includeHidden = prefs.getBool('show_hidden_globally') ?? false;

    // Setting ko database call mein pass kar diya
    final data = await DatabaseHelper.instance.getAllExpenses(includeHidden: includeHidden);
    // -----------------------------------------------
    Set<String> catSet = {"All"}, paySet = {"All"};
    for (var row in data) {
      if (row['category'] != null) catSet.add(row['category']);
      if (row['payMode'] != null) paySet.add(row['payMode']);
    }
    setState(() {
      _allData = data;
      _categories = catSet.toList();
      _payModes = paySet.toList();
      _applyFilters();
    });
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = _allData;

    // ---> NAYA LOGIC: Date range se filter karna <---
    if (_selectedDateRange != null) {
      DateTime start = _selectedDateRange!.start;
      DateTime end = _selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));

      temp = temp.where((e) {
        if (e['date'] == null) return false;
        DateTime dt = DateTime.parse(e['date']);
        return dt.isAfter(start.subtract(const Duration(seconds: 1))) && dt.isBefore(end);
      }).toList();
    }

    if (_selectedType != "All") temp = temp.where((e) => e['type'] == _selectedType).toList();
    if (_selectedCategory != "All") temp = temp.where((e) => e['category'] == _selectedCategory).toList();
    if (_selectedPayMode != "All") temp = temp.where((e) => (e['payMode'] ?? 'Unknown') == _selectedPayMode).toList();

    if (_searchQuery.isNotEmpty) {
      temp = temp.where((e) {
        final searchLower = _searchQuery.toLowerCase();
        return (e['merchant'] ?? "").toString().toLowerCase().contains(searchLower) || (e['amount'] ?? "").toString().toLowerCase().contains(searchLower) || (e['account'] ?? "").toString().toLowerCase().contains(searchLower) || (e['body'] ?? "").toString().toLowerCase().contains(searchLower);
      }).toList();
    }
    setState(() => _filteredData = temp);
  }

  // ---> NAYA WIDGET: Date Picker Button <---
  Widget _buildDateFilter() {
    String label = "This Month";

    if (_selectedDateRange != null) {
      DateTime now = DateTime.now();
      DateTime start = _selectedDateRange!.start;
      DateTime end = _selectedDateRange!.end;

      // Agar properly current month select nahi hai, toh exact dates dikhao
      if (!(start.year == now.year && start.month == now.month && start.day == 1 && end.year == now.year && end.month == now.month && end.day == DateTime(now.year, now.month + 1, 0).day)) {
        label = "${start.day}/${start.month}/${start.year.toString().substring(2)} - ${end.day}/${end.month}/${end.year.toString().substring(2)}";
      }
    } else {
      label = "All Time";
    }

    return InkWell(
      onTap: () async {
        DateTimeRange? picked = await showDateRangePicker(
          context: context,
          initialDateRange: _selectedDateRange,
          firstDate: DateTime(2020),
          lastDate: DateTime(2050),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(colorScheme: const ColorScheme.light(primary: AppConstants.primaryColor)),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDateRange = picked);
          _applyFilters();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month, size: 16, color: AppConstants.primaryColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
            ),
            if (_selectedDateRange != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() => _selectedDateRange = null); // Clear karne par All Time ka data aa jayega
                  _applyFilters();
                },
                child: const Icon(Icons.close, size: 16, color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Transactions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.download_rounded), tooltip: 'Export Filtered Data', onPressed: () async => await ExportService.exportToCSV(context, _filteredData, 'Filtered_Transactions'))],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _applyFilters();
                  },
                  decoration: InputDecoration(
                    hintText: "Search Merchant, SMS or Account...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // ---> DATE FILTER YAHAN ADD HUA HAI <---
                      _buildDateFilter(),
                      const SizedBox(width: 8),
                      _buildDropdown("Type", _types, _selectedType, (val) {
                        setState(() => _selectedType = val!);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _buildDropdown("Category", _categories, _selectedCategory, (val) {
                        setState(() => _selectedCategory = val!);
                        _applyFilters();
                      }),
                      const SizedBox(width: 8),
                      _buildDropdown("Mode", _payModes, _selectedPayMode, (val) {
                        setState(() => _selectedPayMode = val!);
                        _applyFilters();
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _filteredData.isEmpty
                ? const Center(child: Text("No matching transactions found."))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                        columnSpacing: 20,
                        dataRowMinHeight: 45,
                        dataRowMaxHeight: 60,
                        columns: const [
                          DataColumn(
                            label: Text("Date", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text("Merchant", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text("Amount", style: TextStyle(fontWeight: FontWeight.bold)),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text("Category", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text("Type", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text("Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text("Account", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text("Valid Expense?", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text("Edited?", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          DataColumn(
                            label: Text("SMS / Body", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                        rows: _filteredData.map((exp) {
                          DateTime dt = DateTime.parse(exp['date']);
                          bool isExpense = (exp['is_expense'] == null || exp['is_expense'] == 1);
                          bool isEdited = (exp['is_edited'] == 1);
                          bool isCredit = (exp['type'] == 'Credit');

                          String sign = isCredit ? '+' : '-';
                          Color amountColor = isCredit ? Colors.green : Colors.red;

                          return DataRow(
                            cells: [
                              DataCell(Text("${dt.day}/${dt.month}/${dt.year}")),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    exp['merchant'] ?? '-',
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  "$sign ₹${exp['amount']}",
                                  style: TextStyle(color: amountColor, fontWeight: FontWeight.bold),
                                ),
                              ),
                              DataCell(Text(exp['category'] ?? '-')),
                              DataCell(Text(exp['type'] ?? '-')),
                              DataCell(Text(exp['payMode'] ?? '-')),
                              DataCell(Text(exp['account'] ?? '-')),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: isExpense ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    isExpense ? 'Yes' : 'No',
                                    style: TextStyle(color: isExpense ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              DataCell(Text(isEdited ? 'Yes' : 'No', style: TextStyle(color: isEdited ? Colors.orange : Colors.grey))),
                              DataCell(
                                InkWell(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: const Text(
                                            "Original SMS Content",
                                            style: TextStyle(color: AppConstants.primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          content: SingleChildScrollView(child: Text(exp['body'] ?? 'No data', style: const TextStyle(fontSize: 14, height: 1.5))),
                                          actions: [
                                            // ---> NAYA LOGIC: COPY BUTTON <---
                                            TextButton.icon(
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: exp['body'] ?? ''));
                                                Navigator.pop(context); // Popup close karne ke liye
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SMS copied to clipboard!"), backgroundColor: Colors.green, duration: Duration(seconds: 2)));
                                              },
                                              icon: const Icon(Icons.copy, size: 18, color: AppConstants.primaryColor),
                                              label: const Text(
                                                "Copy",
                                                style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            // ----------------------------------
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text(
                                                "Close",
                                                style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                  child: SizedBox(
                                    width: 200,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          exp['body'] ?? '-',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          "Tap to read full",
                                          style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String selectedValue, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isDense: true,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          onChanged: onChanged,
          items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value == "All" ? "$label (All)" : value))).toList(),
        ),
      ),
    );
  }
}
