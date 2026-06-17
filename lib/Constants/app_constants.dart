import 'package:flutter/material.dart';

class AppConstants {
  static const Color primaryColor = Color(0xFF003366);
  static const Color accentColor = Color(0xFFDAA520);
  static const Color bgLight = Color(0xFFF7F9FB);

  static final List<String> categories = ['Food', 'Transport', 'Bills', 'Shopping', 'Health', 'Grocery', 'Fruits Vegies', 'Investment', 'Transfer', 'Other'];

  static final Map<String, Color> categoryColors = {'Food': const Color(0xFF4CAF50), 'Transport': const Color(0xFF2196F3), 'Bills': const Color(0xFF3F51B5), 'Shopping': const Color.fromARGB(255, 242, 192, 44), 'Health': const Color(0xFF009688), 'Grocery': const Color(0xFF673AB7), 'Fruits Vegies': const Color(0xFFE91E63), 'Investment': const Color(0xFF1565C0), 'Transfer': Colors.grey.shade600, 'Other': Colors.grey};

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case 'Food':
        return Icons.restaurant;
      case 'Transport':
        return Icons.directions_car;
      case 'Bills':
        return Icons.receipt_long;
      case 'Shopping':
        return Icons.shopping_bag;
      case 'Health':
        return Icons.medical_services;
      case 'Grocery':
        return Icons.shopping_basket;
      case 'Fruits Vegies':
        return Icons.eco;
      case 'Investment':
        return Icons.trending_up;
      case 'Transfer':
        return Icons.swap_horiz;
      default:
        return Icons.category;
    }
  }

  // Unified Regex/String Keyword Map (Ekdum clean aur readable)
  static final Map<String, String> merchantCategoryMap = {
    // Food
    'swiggy': 'Food',
    'zomato': 'Food',
    'mcdonalds': 'Food',
    'kfc': 'Food',
    'eat': 'Food',
    'restaurant': 'Food',

    // Grocery
    'blinkit': 'Grocery',
    'zepto': 'Grocery',
    'bbnow': 'Grocery',
    'bigbasket': 'Grocery',
    'big basket': 'Grocery',
    'dmart': 'Grocery',
    'reliance fresh': 'Grocery',
    'reliancefresh': 'Grocery',
    'supermarket': 'Grocery',
    'instamart': 'Grocery',
    'jiomart': 'Grocery',
    'jio mart': 'Grocery',

    // Shopping
    'amazon': 'Shopping',
    'flipkart': 'Shopping',
    'myntra': 'Shopping',
    'meesho': 'Shopping',
    'ajio': 'Shopping',
    'tanishq': 'Shopping',

    // Bills
    'airtel': 'Bills',
    'jio': 'Bills',
    'vi': 'Bills',
    'bescom': 'Bills',
    'cred': 'Bills',
    'recharge': 'Bills',
    'electricity': 'Bills',
    'dhbvn': 'Bills',

    // Investment
    'zerodha': 'Investment',
    'groww': 'Investment',
    'mutual fund': 'Investment',
    'sip': 'Investment',
    'etf': 'Investment',
    'nach': 'Investment',

    // Health
    'apollo': 'Health',
    'pharmeasy': 'Health',
    '1mg': 'Health',
    'pharmacy': 'Health',
    'hospital': 'Health',
    'clinic': 'Health',

    // Transport
    'uber': 'Transport',
    'ola': 'Transport',
    'irctc': 'Transport',
    'makemytrip': 'Transport',
    'gas agency': 'Transport',
    'rapido': 'Transport',
    'metro': 'Transport',
    'petrol': 'Transport',
    'fuel': 'Transport',

    // Fruits & Veggies
    'safal': 'Fruits Vegies',
    'vegetable': 'Fruits Vegies',
    'fruit': 'Fruits Vegies',
    'mandi': 'Fruits Vegies',
  };

  static final List<String> knownBanks = ['kotak', 'sbi', 'icici', 'axis', 'hdfc', 'indusind', 'yes bank', 'yesbank', 'pnb', 'onecard', 'one card', 'pluxee', 'paytm'];
}
