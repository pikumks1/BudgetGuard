import 'package:flutter/material.dart';

import 'constants/app_constants.dart';
import 'screens/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MaterialApp(
      title: 'Budget Guard',
      home: const BudgetDashboard(),
      debugShowCheckedModeBanner: false,
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
