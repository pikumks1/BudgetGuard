import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants/app_constants.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ReportScreen extends StatefulWidget {
  final DateTime selectedMonth;
  // ---> NAYA PARAMETER: Main screen se filter hua data seedha yahan aayega <---
  final List<Map<String, dynamic>> filteredExpenses;

  const ReportScreen({super.key, required this.selectedMonth, required this.filteredExpenses});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  Map<String, double> categoryTotals = {};
  double totalSpent = 0.0;
  final PageController _pageController = PageController();
  int _currentChartIndex = 0;
  final List<String> _chartTypes = ['Donut', 'Bar', 'Line'];

  @override
  void initState() {
    super.initState();
    _generateReport(); // Ab ye async nahi raha
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---> YAHAN DATABASE KI JAGAH DIRECT FILTERED DATA USE HOGA <---
  void _generateReport() {
    Map<String, double> tempTotals = {};
    double tempSpent = 0.0;

    for (var exp in widget.filteredExpenses) {
      // Wahi same condition jo main screen ke total ke liye hai
      bool isExpense = (exp['is_expense'] == null || exp['is_expense'] == 1);

      if (isExpense) {
        String category = exp['category'] ?? 'Other';
        double amount = (exp['amount'] ?? 0.0).toDouble();
        tempTotals[category] = (tempTotals[category] ?? 0) + amount;
        tempSpent += amount;
      }
    }
    setState(() {
      categoryTotals = tempTotals;
      totalSpent = tempSpent;
    });
  }

  @override
  Widget build(BuildContext context) {
    List<MapEntry<String, double>> entries = categoryTotals.entries.toList();
    double maxY = entries.isEmpty ? 10 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.3;
    const List<String> monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    String formattedMonth = "${monthNames[widget.selectedMonth.month - 1]} ${widget.selectedMonth.year}";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Fiscal Analytics",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppConstants.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: categoryTotals.isEmpty || totalSpent == 0
          ? const Center(
              child: Text("No analytical data for this filter.", style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppConstants.primaryColor, Color(0xFF004080)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Filtered Spend in $formattedMonth",
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "₹ ${totalSpent.toStringAsFixed(0)}",
                            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${_chartTypes[_currentChartIndex]} Analysis",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                        ),
                        Container(
                          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                          child: PopupMenuButton<int>(
                            icon: const Icon(Icons.tune, color: AppConstants.primaryColor, size: 22),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (int index) => _pageController.animateToPage(index, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut),
                            itemBuilder: (context) => const [PopupMenuItem(value: 0, child: Text("Donut Chart")), PopupMenuItem(value: 1, child: Text("Bar Chart")), PopupMenuItem(value: 2, child: Text("Line Chart"))],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 300,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) => setState(() => _currentChartIndex = index),
                        children: [
                          // 1. SYNCFUSION DONUT CHART (Smooth lines & Animation)
                          SfCircularChart(
                            margin: EdgeInsets.zero,
                            series: <CircularSeries>[
                              DoughnutSeries<MapEntry<String, double>, String>(
                                // Pie ki jagah Doughnut!
                                dataSource: entries,
                                animationDuration: 1000, // <-- 1.5 Seconds ki smooth entry
                                //animationDelay: 300, // <-- Swipe khatam hone ka wait karega
                                xValueMapper: (MapEntry<String, double> data, _) => data.key,
                                yValueMapper: (MapEntry<String, double> data, _) => data.value,
                                pointColorMapper: (MapEntry<String, double> data, _) => AppConstants.categoryColors[data.key] ?? Colors.grey,
                                radius: '65%',
                                innerRadius: '45%', // Yeh isko center se khokhla (Donut) banayega
                                dataLabelMapper: (MapEntry<String, double> data, _) {
                                  double percentage = totalSpent > 0 ? (data.value / totalSpent) * 100 : 0;
                                  return '${data.key}\n(${percentage.toStringAsFixed(1)}%)';
                                },
                                dataLabelSettings: const DataLabelSettings(
                                  isVisible: true,
                                  labelPosition: ChartDataLabelPosition.outside,
                                  useSeriesColor: true,
                                  connectorLineSettings: ConnectorLineSettings(type: ConnectorType.curve, length: '15%'),
                                  textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  labelIntersectAction: LabelIntersectAction.shift, // Overlap rokenge
                                ),
                              ),
                            ],
                          ),

                          // 2. SYNCFUSION BAR CHART (Animation & Permanent % Label)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, right: 10, left: 10),
                            child: SfCartesianChart(
                              margin: EdgeInsets.zero,
                              plotAreaBorderWidth: 0,
                              primaryXAxis: const CategoryAxis(
                                majorGridLines: MajorGridLines(width: 0),
                                axisLine: AxisLine(width: 0),
                                labelStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                labelRotation: -45, // Category ka naam fit karne ke liye rotate kiya
                              ),
                              primaryYAxis: const NumericAxis(isVisible: false), // Left wali numbers ki line hata di
                              series: <CartesianSeries>[
                                ColumnSeries<MapEntry<String, double>, String>(
                                  // Vertical Bars
                                  dataSource: entries,
                                  animationDuration: 0, // <-- 1.5 Seconds ki vertical growth
                                  //animationDelay: 300, // <-- Swipe khatam hone ka wait karega
                                  xValueMapper: (MapEntry<String, double> data, _) => data.key,
                                  yValueMapper: (MapEntry<String, double> data, _) => data.value,
                                  pointColorMapper: (MapEntry<String, double> data, _) => AppConstants.categoryColors[data.key] ?? AppConstants.primaryColor,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                  dataLabelMapper: (MapEntry<String, double> data, _) {
                                    double percentage = totalSpent > 0 ? (data.value / totalSpent) * 100 : 0;
                                    return '${percentage.toStringAsFixed(1)}%'; // Bar ke upar % label
                                  },
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: true,
                                    labelAlignment: ChartDataLabelAlignment.outer,
                                    textStyle: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 3. SYNCFUSION LINE CHART (Smooth Curved Line with Animation)
                          Padding(
                            padding: const EdgeInsets.only(top: 10.0, right: 10, left: 10),
                            child: SfCartesianChart(
                              margin: const EdgeInsets.only(top: 15), // <-- 1. Upar 15px ki saaf jagah de di
                              plotAreaBorderWidth: 0,
                              primaryXAxis: const CategoryAxis(
                                majorGridLines: MajorGridLines(width: 0),
                                axisLine: AxisLine(width: 0),
                                labelStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                labelRotation: -45,
                              ),
                              primaryYAxis: const NumericAxis(
                                isVisible: false,
                                rangePadding: ChartRangePadding.additional, // <-- 2. MAGIC FIX: Graph auto-scale hoke thoda neeche dab jayega
                              ),
                              series: <CartesianSeries>[
                                SplineSeries<MapEntry<String, double>, String>(
                                  // Spline ka matlab hai curved (smooth) line
                                  dataSource: entries,
                                  animationDuration: 0, // <-- 1.5 Seconds mein left to right draw hoga
                                  //animationDelay: 0, // <-- Swipe khatam hone ka wait karega
                                  xValueMapper: (MapEntry<String, double> data, _) => data.key,
                                  yValueMapper: (MapEntry<String, double> data, _) => data.value,
                                  color: AppConstants.primaryColor,
                                  width: 4,
                                  markerSettings: const MarkerSettings(isVisible: true, color: Colors.white, borderWidth: 2),
                                  dataLabelMapper: (MapEntry<String, double> data, _) {
                                    double percentage = totalSpent > 0 ? (data.value / totalSpent) * 100 : 0;
                                    return '${percentage.toStringAsFixed(1)}%'; // Point ke upar % label
                                  },
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: true,
                                    labelAlignment: ChartDataLabelAlignment.top,
                                    textStyle: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentChartIndex == index ? 12 : 8,
                          height: 8,
                          decoration: BoxDecoration(color: _currentChartIndex == index ? AppConstants.primaryColor : Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.6, crossAxisSpacing: 12, mainAxisSpacing: 12),
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final color = AppConstants.categoryColors[entry.key] ?? Colors.grey;
                        double percentage = totalSpent > 0 ? (entry.value / totalSpent) * 100 : 0;
                        return InkWell(
                          onTap: () => Navigator.pop(context, entry.key),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                  child: Icon(AppConstants.getCategoryIcon(entry.key), color: color, size: 24),
                                ),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text("(${percentage.toStringAsFixed(1)}%) ₹${entry.value.toStringAsFixed(0)}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
