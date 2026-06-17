import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static Future<void> exportToCSV(BuildContext context, List<Map<String, dynamic>> data, String prefix) async {
    try {
      if (data.isEmpty) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data to export.")));
        return;
      }

      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln("Date,Merchant,Amount (INR),Category,Type,PayMode,Account,Included in Total?,SMS/Details");

      for (var exp in data) {
        DateTime dt = DateTime.parse(exp['date']);
        String cleanDate = "${dt.day}/${dt.month}/${dt.year}";
        String merchant = '"${exp['merchant'].toString().replaceAll('"', '""')}"';
        String amount = exp['amount'].toString();
        String category = '"${exp['category'] ?? 'Other'}"';
        String type = '"${exp['type']}"';
        String payMode = '"${exp['payMode'] ?? 'Unknown'}"';
        String account = '"${exp['account'] ?? 'Cash/Other'}"';
        String isExpense = exp['is_expense'] == 1 ? 'Yes' : 'No';
        String body = '"${(exp['body'] ?? 'Manual Entry').toString().replaceAll('"', '""')}"';

        csvBuffer.writeln("$cleanDate,$merchant,$amount,$category,$type,$payMode,$account,$isExpense,$body");
      }

      String path;
      if (Platform.isAndroid) {
        path = "/storage/emulated/0/Download/${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv";
      } else {
        final directory = await getApplicationDocumentsDirectory();
        path = "${directory.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.csv";
      }

      final file = File(path);
      await file.writeAsString(csvBuffer.toString());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("File saved successfully!"),
            backgroundColor: Colors.green.shade600,
            action: SnackBarAction(
              label: 'SHARE',
              textColor: Colors.white,
              onPressed: () async => await SharePlus.instance.share(ShareParams(text: 'My Exported Data', files: [XFile(path)])),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Export Error: $e");
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save data.")));
    }
  }
}
