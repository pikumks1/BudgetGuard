import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Dhyaan dein: Agar aapki app_constants.dart kisi dusre folder mein hai,
// toh is path ko apne hisaab se theek kar lijiye.
import '../constants/app_constants.dart';

class RemoteConfigService {
  static Future<void> fetchAndCacheConstants() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Agar phone mein pehle se internet wala data save hai, toh use turant load karo
    String? cachedData = prefs.getString('remote_constants');
    if (cachedData != null) {
      try {
        _updateAppConstants(json.decode(cachedData));
      } catch (e) {
        debugPrint("Error parsing cached config: $e");
      }
    }

    // 2. Background mein internet se naya data laao
    try {
      // ---> YAHAN APNE GITHUB GIST KA 'RAW' URL DAALIYE <---
      final url = Uri.parse('https://gist.githubusercontent.com/pikumks1/ea13d45a1dbb4dd665bef3b7924681d5/raw/constants.json');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Data memory mein update karo
        _updateAppConstants(data);

        // Agli baar ke liye phone storage me save kar lo
        prefs.setString('remote_constants', response.body);
        debugPrint("Remote constants successfully updated from Gist!");
      } else {
        debugPrint("Failed to fetch constants. Status code: ${response.statusCode}");
      }
    } catch (e) {
      // Agar net band hoga toh yeh catch me aayega, aur app bina crash hue purane data pe chalegi
      debugPrint("Offline mode: Using cached or default AppConstants. Error: $e");
    }
  }

  // Yeh helper function JSON data ko AppConstants mein set karta hai
  static void _updateAppConstants(Map<String, dynamic> data) {
    if (data.containsKey('categories')) {
      AppConstants.categories = List<String>.from(data['categories']);
    }

    if (data.containsKey('incomeCategories')) {
      AppConstants.incomeCategories = List<String>.from(data['incomeCategories']);
    }

    if (data.containsKey('knownBanks')) {
      AppConstants.knownBanks = List<String>.from(data['knownBanks']);
    }

    if (data.containsKey('merchantCategoryMap')) {
      AppConstants.merchantCategoryMap = Map<String, String>.from(data['merchantCategoryMap']);
    }

    if (data.containsKey('dynamicColors')) {
      AppConstants.dynamicColors = Map<String, String>.from(data['dynamicColors']);
    }

    if (data.containsKey('dynamicIcons')) {
      AppConstants.dynamicIcons = Map<String, String>.from(data['dynamicIcons']);
    }

    // Naye ignore keywords ko internet se fetch karo
    if (data.containsKey('ignoreKeywords')) {
      AppConstants.ignoreKeywords = List<String>.from(data['ignoreKeywords']);
    }
  }
}
