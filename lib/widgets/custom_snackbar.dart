import 'package:flutter/material.dart';

class CustomSnackBar {
  static void show({required BuildContext context, required String message, bool isError = false, Color? backgroundColor}) {
    ScaffoldMessenger.of(context).clearSnackBars();

    final Color finalColor = backgroundColor ?? (isError ? const Color(0xFFE53935) : const Color(0xFF43A047));

    final IconData icon = isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
        backgroundColor: finalColor,

        // ---> EKDUM BOTTOM SE CHIPKANE KE LIYE FIXED <---
        behavior: SnackBarBehavior.fixed,

        // Box ko slim rakhne ke liye vertical padding kam rakhi hai
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

        // Fixed banner mein margin aur shape allowed nahi hote
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
