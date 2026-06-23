import 'package:flutter/material.dart';

class AppConstants {
  static const Color primaryColor = Color(0xFF003366);
  static const Color accentColor = Color(0xFFDAA520);
  static const Color bgLight = Color(0xFFF7F9FB);

  // 'final' aur 'const' hata diya taki JSON inko update kar sake
  static List<String> categories = ['Food', 'Transport', 'Bills', 'Shopping', 'Health', 'Grocery', 'Fruits Vegies', 'Investment', 'Transfer', 'Other'];
  static List<String> incomeCategories = ['Salary', 'Gift', 'Refund', 'Bonus', 'Other Income'];

  // ---> YEH NAYE MAPS HAIN JO JSON SE BHARENGE <---
  static Map<String, String> dynamicColors = {};
  static Map<String, String> dynamicIcons = {};

  // ---> ICON DICTIONARY (Future icons ke liye jo JSON se aayenge) <---
  static final Map<String, IconData> availableIcons = {'pets': Icons.pets, 'fitness_center': Icons.fitness_center, 'flight': Icons.flight, 'local_movies': Icons.local_movies, 'school': Icons.school, 'work': Icons.work};

  // ---> UPDATE: Dono cases (Capital & Small) add kiye hain taki color kabhi grey na ho <---
  static final Map<String, Color> categoryColors = {
    'Food': const Color(0xFF4CAF50), 'food': const Color(0xFF4CAF50),
    'Transport': const Color(0xFF2196F3), 'transport': const Color(0xFF2196F3),
    'Bills': const Color(0xFF3F51B5), 'bills': const Color(0xFF3F51B5),
    'Shopping': const Color.fromARGB(255, 242, 192, 44), 'shopping': const Color.fromARGB(255, 242, 192, 44),
    'Health': const Color(0xFF009688), 'health': const Color(0xFF009688),
    'Grocery': const Color(0xFF673AB7), 'grocery': const Color(0xFF673AB7),
    'Fruits Vegies': const Color(0xFFE91E63), 'fruits vegies': const Color(0xFFE91E63),
    'Investment': const Color(0xFF1565C0), 'investment': const Color(0xFF1565C0),
    'Transfer': Colors.grey.shade600, 'transfer': Colors.grey.shade600,
    'Other': Colors.grey, 'other': Colors.grey,

    // Income Colors
    'Salary': Colors.green, 'salary': Colors.green,
    'Gift': Colors.pink, 'gift': Colors.pink,
    'Refund': Colors.orange, 'refund': Colors.orange,
    'Bonus': Colors.purple, 'bonus': Colors.purple,
    'Other Income': Colors.blueGrey, 'other income': Colors.blueGrey,
  };

  // ---> UPDATE: toLowerCase() lagaya hai taki case ka jhanjhat khatam ho <---
  static IconData getCategoryIcon(String category) {
    String cleanCategory = category.toLowerCase();

    // Check 1: App kis naam se icon dhoondh rahi hai?
    debugPrint("🔍 DEBUG 2: App icon dhoondh rahi hai for category -> '$cleanCategory'");

    if (dynamicIcons.containsKey(cleanCategory)) {
      String iconName = dynamicIcons[cleanCategory]!;
      // Check 2: JSON mein category mil gayi!
      debugPrint("✅ DEBUG 3: '$cleanCategory' JSON map mein mil gayi! Icon mapped as -> '$iconName'");

      if (availableIcons.containsKey(iconName)) {
        // Check 3: Icon availableIcons dictionary mein bhi hai
        debugPrint("🎯 DEBUG 4: Icon '$iconName' availableIcons me mil gaya. PERFECT MATCH!");
        return availableIcons[iconName]!;
      } else {
        // Check 4: ERROR - JSON mein naam toh hai, par availableIcons map mein define karna bhool gaye
        debugPrint("⚠️ DEBUG ERROR: '$iconName' JSON me toh hai, par AppConstants.availableIcons me define nahi hai!");
      }
    } else {
      // Check 5: JSON mein nahi mila, ab switch case me jayega
      debugPrint("📉 DEBUG 5: '$cleanCategory' dynamic JSON me nahi mila, default fallback chalega.");
    }

    switch (cleanCategory) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'bills':
        return Icons.receipt_long;
      case 'shopping':
        return Icons.shopping_bag;
      case 'health':
        return Icons.medical_services;
      case 'grocery':
        return Icons.shopping_basket;
      case 'fruits vegies':
        return Icons.eco;
      case 'investment':
        return Icons.trending_up;
      case 'transfer':
        return Icons.swap_horiz;
      case 'selfcare':
        return Icons.person;
      case 'other':
        return Icons.widgets;
      // INCOME CATEGORY
      case 'salary': //payment
        return Icons.payment;
      case 'gift':
        return Icons.redeem;
      case 'refund':
        return Icons.replay;
      case 'bonus':
        return Icons.card_giftcard;
      case 'other income':
        return Icons.currency_rupee;
      case 'roi':
        return Icons.analytics;
      default:
        return Icons.category;
    }
  }

  // Unified Regex/String Keyword Map (Ekdum clean aur readable)
  // 'final' hata diya taki JSON se naye merchants add ho sakein
  static Map<String, String> merchantCategoryMap = {
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

  // 'final' hata diya
  static List<String> knownBanks = ['kotak', 'sbi', 'icici', 'axis', 'hdfc', 'indusind', 'yes bank', 'yesbank', 'pnb', 'onecard', 'one card', 'pluxee', 'paytm'];

  // ---> NAYA: Ignore keywords list <---
  static List<String> ignoreKeywords = ['due', 'autopay', 'bill', 'generated', 'reminder', 'intimation', 'scheduled', 'will be debited', 'will be deducted', 'auto-debited', 'outstanding', 'statement', 'emi', 'emi of', 'to be paid', 'request received', 'is requested', 'payment of rs.', 'click here'];

  // ---> COLOR FETCH KARNE KA MASTER FUNCTION <---
  static Color getCategoryColor(String? category) {
    if (category == null || category.trim().isEmpty) return Colors.grey;

    String cleanCategory = category.trim();

    // Naya logic: Pehle JSON wala color check karo
    if (dynamicColors.containsKey(cleanCategory.toLowerCase())) {
      return Color(int.parse(dynamicColors[cleanCategory.toLowerCase()]!));
    }

    // 1. Direct match check karo
    if (categoryColors.containsKey(cleanCategory)) {
      return categoryColors[cleanCategory]!;
    }

    // 2. Small letter karke check karo
    if (categoryColors.containsKey(cleanCategory.toLowerCase())) {
      return categoryColors[cleanCategory.toLowerCase()]!;
    }

    // 3. Agar fir bhi na mile, toh grey de do
    return Colors.grey;
  }
}
