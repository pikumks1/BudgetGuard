import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

// ---> NAYA FIX: 'with WidgetsBindingObserver' hata diya <---
class _AppLockWrapperState extends State<AppLockWrapper> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isLocked = false;

  @override
  void initState() {
    super.initState();
    // App start hote hi sirf ek baar check karega
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool isLockEnabledInSettings = prefs.getBool('app_lock_enabled') ?? false;

    if (isLockEnabledInSettings) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLocked = true;
    });

    try {
      bool authenticated = await auth.authenticate(localizedReason: 'Please authenticate to access BudgetGuard');

      if (authenticated) {
        setState(() => _isLocked = false);
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield_rounded, size: 80, color: AppConstants.primaryColor),
              const SizedBox(height: 20),
              const Text("App is Locked", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint),
                label: const Text("Unlock Now"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
