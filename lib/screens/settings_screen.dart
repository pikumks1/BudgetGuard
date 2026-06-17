import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/database_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showHiddenGlobally = false;

  @override
  void initState() {
    super.initState();
    _loadSetting();
  }

  // SharedPreferences se purani value load karna
  Future<void> _loadSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showHiddenGlobally = prefs.getBool('show_hidden_globally') ?? false;
    });
  }

  // Toggle switch ko change karke save karna
  Future<void> _toggleSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_hidden_globally', value);
    setState(() {
      _showHiddenGlobally = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
      ),
      // Padding ki jagah ListView lagaya taaki multiple items easily aa sakein
      body: ListView(
        padding: const EdgeInsets.only(top: 8.0),
        children: [
          // 1. Show Hidden Transactions Toggle
          SwitchListTile(
            title: const Text("Show Hidden Transactions", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: const Text("Show hidden records on both Dashboard & All Transactions screens."),
            activeColor: AppConstants.primaryColor,
            value: _showHiddenGlobally,
            onChanged: _toggleSetting,
          ),

          const Divider(height: 30), // Ek choti line separation ke liye
          // 2. Data Management Heading
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              "Data Management",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // 3. Delete All Data Button
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              "Delete All Data",
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.redAccent),
            ),
            subtitle: const Text("Permanently remove all expenses and reset app."),
            onTap: () async {
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

              // Agar user ne OK bola, toh database clear karo
              if (confirmDelete == true) {
                await DatabaseHelper.instance.clearAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All data reset successfully."), backgroundColor: Colors.redAccent));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
