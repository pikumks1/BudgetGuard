import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../services/database_service.dart';
import 'web_tracker_screen.dart';
/*import 'package:url_launcher/url_launcher.dart';*/
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart';

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
            activeThumbColor: AppConstants.primaryColor,
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
          // 4. Web Tracker Option (The Pro Way)
          ListTile(
            leading: const Icon(Icons.language, color: AppConstants.primaryColor),
            title: const Text("Other Web App - Hisab", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Track your expenses manually on seprate diary."),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () async {
              try {
                // YAHAN APNA ASLI WEBPAGE KA LINK DAAL DENA
                await launchUrl(
                  Uri.parse('https://pikumks1.github.io/Hisab/'),
                  customTabsOptions: CustomTabsOptions(
                    // App ka primary color set kar rahe hain taaki native feel aaye
                    colorSchemes: CustomTabsColorSchemes.defaults(toolbarColor: AppConstants.primaryColor, navigationBarColor: Colors.white),
                    // Scroll karte hi URL bar chhup jayega
                    urlBarHidingEnabled: true,
                    showTitle: true,
                    // Cross(X) ki jagah Back arrow aayega
                    closeButton: CustomTabsCloseButton(icon: CustomTabsCloseButtonIcons.back),
                  ),
                  safariVCOptions: SafariViewControllerOptions(preferredBarTintColor: AppConstants.primaryColor, preferredControlTintColor: Colors.white, barCollapsingEnabled: true),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open tracker."), backgroundColor: Colors.red));
                }
              }
            },
          ),
          /*// 4. Hisab-External Link Option
          ListTile(
            leading: const Icon(Icons.language, color: AppConstants.primaryColor),
            title: const Text("Open Web Hisab", style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text("Keep you manual Hisab seprate from app."),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () async {
              // YAHAN APNA ASLI WEBPAGE KA LINK DAAL DENA
              final Uri url = Uri.parse('https://pikumks1.github.io/Hisab/');

              // InAppBrowserView use karne se yeh app ke andar hi khulega
              if (!await launchUrl(url, mode: LaunchMode.inAppBrowserView)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open webpage"), backgroundColor: Colors.red));
                }
              }
            },
          ),*/
        ],
      ),
    );
  }
}
