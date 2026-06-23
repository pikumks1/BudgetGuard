import 'package:flutter/material.dart';

import 'constants/app_constants.dart';
import 'screens/dashboard_screen.dart';
// ---> NAYA IMPORT YAHAN HAI <---
import 'services/remote_config_service.dart';
import 'widgets/app_lock_wrapper.dart'; // Nayi file import karein

// ---> main() ko async banaya <---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ---> APP START HOTE HI DATA FETCH HOGA <---
  await RemoteConfigService.fetchAndCacheConstants();

  // ---> YEH 2 LINES ADD KAREIN TEST KE LIYE <---
  debugPrint("Total Categories: ${AppConstants.categories.length}");
  debugPrint("Is Zepto mapped?: ${AppConstants.merchantCategoryMap['zepto']}");
  debugPrint("Is Categories?: ${AppConstants.categories}");
  debugPrint("Is Icons?: ${AppConstants.dynamicIcons}");
  debugPrint("Is Colours?: ${AppConstants.dynamicColors}");

  runApp(
    MaterialApp(
      title: 'Budget Guard',
      //home: const BudgetDashboard(),
      home: const AppLockWrapper(
        child: BudgetDashboard(), // Dashboard ko wrapper ke andar daal diya
      ),
      debugShowCheckedModeBanner: false,

      // ---> YEH NAYA BUILDER ADD KAREIN <---
      builder: (context, child) {
        // Yeh line text ko 1.1x se zyada scale hone se rok degi
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
              minScaleFactor: 0.8, // Sabse chhota font
              maxScaleFactor: 1.1, // Sabse bada font (1.1 means 10% bigger max)
            ),
          ),
          child: child!,
        );
      },
      // ------------------------------------
      theme: ThemeData(
        scaffoldBackgroundColor: AppConstants.bgLight,
        primaryColor: AppConstants.primaryColor,
        appBarTheme: const AppBarTheme(backgroundColor: AppConstants.primaryColor, foregroundColor: Colors.white, centerTitle: false, elevation: 0),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: AppConstants.primaryColor, foregroundColor: AppConstants.accentColor),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ),
    ),
  );
}
