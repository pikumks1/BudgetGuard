import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart' as tele;
import '../constants/app_constants.dart';
import 'database_service.dart';

@pragma('vm:entry-point')
void backgroundMessageHandler(tele.SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (message.body != null && message.date != null) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(message.date!);
    var expenseData = SmsParserService.parseMessage(message.body!, date, message.address ?? '');
    if (expenseData != null) {
      await DatabaseHelper.instance.insertExpense(expenseData);
    }
  }
}

class SmsParserService {
  static final List<String> _strictWords = ['vi', 'eat', 'sip', 'jio', 'ola', 'igl', 'mcg', 'srl', 'pvr', 'mall', 'fuel', 'toll', 'oyo', 'aha', 'vpf', 'epf', 'rto', 'mcd', 'ndmc', 'ccd', 'bata'];

  static String getFallbackCategory(String merchant) {
    String m = merchant.toLowerCase();
    for (var key in AppConstants.merchantCategoryMap.keys) {
      if (_strictWords.contains(key)) {
        if (RegExp(r'\b' + key + r'\b').hasMatch(m)) return AppConstants.merchantCategoryMap[key]!;
      } else {
        if (m.contains(key)) return AppConstants.merchantCategoryMap[key]!;
      }
    }
    return 'Other';
  }

  static Map<String, dynamic>? parseMessage(String message, DateTime date, String senderAddress) {
    String originalMsg = message;
    String lowerMsg = message.toLowerCase();

    // ---> 1. SENDER NAME CHECK <---
    String sender = senderAddress.toUpperCase();
    if (!(sender.endsWith('-S') || sender.endsWith('-T'))) {
      return null; // Agar -S ya -T par khatam nahi hota toh instantly reject
    }

    // Reminders or bill ko reject krne k list
    /* List<String> ignoreKeywords = ['due on', 'due date', 'due of', 'generated', 'reminder', 'intimation', 'scheduled', 'will be debited', 'will be deducted', 'auto-debited', 'outstanding', 'statement', 'emi of', 'for emi', 'to be paid', 'request received', 'is requested', 'payment of rs.', 'click here'];
    for (String word in ignoreKeywords) {
      if (lowerMsg.contains(word)) {
        return null; // Is message ko poori tarah ignore kardo
      }
    }*/

    /*List<String> ignoreKeywords = ['due', 'autopay', 'bill', 'generated', 'reminder', 'intimation', 'scheduled', 'will be debited', 'will be deducted', 'auto-debited', 'outstanding', 'statement', 'emi', 'emi of', 'to be paid', 'request received', 'is requested', 'payment of rs.', 'click here'];

    for (String word in ignoreKeywords) {
      // Exact word dhoondhne ke liye regex (Punctuation ignore karega)
      if (RegExp(r'\b' + RegExp.escape(word) + r'\b').hasMatch(lowerMsg)) {
        return null;
      }
    } */

    for (String word in AppConstants.ignoreKeywords) {
      // word boundary (\b) ensure karta hai ki 'emi' word mile toh 'premium' ignore na ho
      if (RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false).hasMatch(lowerMsg)) {
        return null; // Ignore keyword mila, SMS skip kar do
      }
    }

    if (lowerMsg.contains('otp') || lowerMsg.contains('one time password') || lowerMsg.contains('code is')) {
      return null; // Seedha reject kar do
    }

    //Amount nikalne ke liye regex, jo ki Rs. 500, INR 500, ₹500, Rs500, etc. formats ko handle karega
    double amount = 0.0;
    RegExp amountRegExp = RegExp(r"(?:rs[.:]?|inr[.:]?|₹[.:]?)\s*([0-9,]+(?:\.[0-9]+)?)");
    var amountMatch = amountRegExp.firstMatch(lowerMsg);
    if (amountMatch != null) amount = double.tryParse(amountMatch.group(1)!.replaceAll(',', '')) ?? 0.0;

    if (amount == 0.0) return null;

    // Transaction Type nikalne ke liye simple keywords check karenge
    String type = 'Unknown';
    if (lowerMsg.contains('credited') || lowerMsg.contains('received') || lowerMsg.contains('added') || lowerMsg.contains('refund') || lowerMsg.contains('reversal') || lowerMsg.contains('deposited') || lowerMsg.contains('transferred to')) {
      if ((lowerMsg.contains('credit card') || lowerMsg.contains('cc bill')) && (lowerMsg.contains('credited') || lowerMsg.contains('received'))) {
        type = 'Debit';
      } else {
        type = 'Credit';
      }
    } else if (lowerMsg.contains('debited') || lowerMsg.contains('deducted') || lowerMsg.contains('paid') || lowerMsg.contains('sent') || lowerMsg.contains('spent') || lowerMsg.contains('txn') || lowerMsg.contains('transaction') || lowerMsg.contains('payment') || lowerMsg.contains('purchase') || lowerMsg.contains('withdrawn') || lowerMsg.contains('used') || lowerMsg.contains('withdraw')) {
      type = 'Debit';
    }

    // bank name aur account info nikalne ke liye simple keyword matching karenge
    String bankName = 'Cash/Other';
    for (String bank in AppConstants.knownBanks) {
      // if (lowerMsg.contains(bank)) {
      if (RegExp(r'\b' + bank + r'\b').hasMatch(lowerMsg)) {
        // --> \b ensure karega ki sirf 'sbi' alag se likha ho tabhi match ho
        bankName = bank[0].toUpperCase() + bank.substring(1);
        if (bank == 'one card') bankName = 'One Card';
        break;
      }
    }

    String accountInfo = bankName;
    RegExp cardRegExp = RegExp(r"(?:ending|x|a/c|no|card|acct).{0,8}?([0-9]{4})\b");
    var accMatch = cardRegExp.firstMatch(lowerMsg);
    if (accMatch != null) accountInfo = "$bankName ${accMatch.group(1)}";

    // Merchant name nikalne ke liye thoda complex regex use karenge, jo ki "to", "at", "VPA", "Info", "paid to" jaise words ke baad aane wale text ko capture karega
    /* String merchant = 'Unknown';
    //RegExp merchantRegExp = RegExp(r"(?:to|at|VPA|Info|paid to)\s+([a-zA-Z0-9\s\.\@\-\_]+?)(?:\s+(?:on|via|Ref|UPI|from|by|card|balance))", caseSensitive: false);
    RegExp merchantRegExp = RegExp(r"(?:to|at|VPA|Info|paid to|towards)\s+([a-zA-Z0-9\s\@\-\_]+?)(?:\s+(?:on|via|Ref|UPI|from|by|card|balance)|\.|$)", caseSensitive: false);
    var merchantMatch = merchantRegExp.firstMatch(message);

    if (merchantMatch != null && merchantMatch.group(1) != null) {
      merchant = merchantMatch.group(1)!.trim();
    } else {
      merchant = 'General Expense';
    } */

    String merchant = 'Unknown';
    String lowerType = type.toLowerCase(); // 'debit' ya 'credit'

    if (lowerType == 'debit') {
      // Aapka purana Debit wala logic
      RegExp debitRegExp = RegExp(r"(?:to|at|VPA|Info|paid to|towards)\s+([a-zA-Z0-9\s\@\-\_]+?)(?:\s+(?:on|via|Ref|UPI|from|by|card|balance|\.|$))", caseSensitive: false);
      var match = debitRegExp.firstMatch(message);
      if (match != null && match.group(1) != null) {
        merchant = match.group(1)!.trim();
      }
    } else if (lowerType == 'credit') {
      // NAYA: Credit wala logic ("from" aur "by" ko pakdega)
      RegExp creditRegExp = RegExp(r"(?:from|by|received from|credited by)\s+(.+?)(?=\s+(?:on|via|Ref|UPI|to|Bal|balance)|\.|$)", caseSensitive: false);
      var match = creditRegExp.firstMatch(message);
      if (match != null && match.group(1) != null) {
        merchant = match.group(1)!.trim();
      }
    }

    // Agar koi naam nahi mila toh default set kar do
    if (merchant == 'Unknown' || merchant.isEmpty) {
      merchant = lowerType == 'credit' ? 'General Income' : 'General Expense';
    }

    // Faltu words (upi, imps, neft) aur slashes ko saaf karne ka logic
    if (merchant.length > 3) {
      merchant = merchant.replaceAll(RegExp(r'(upi|imps|neft|rtgs|/|-)', caseSensitive: false), " ").trim();

      // Agar multiple spaces aa gaye ho toh unhe single space bana do
      merchant = merchant.replaceAll(RegExp(r'\s+'), ' ');
    }

    // upi merchant name ko aur clean karne ke liye agar 'upi' word hai aur length 5 se zyada hai toh usko hata do
    if (merchant.toLowerCase().contains('upi') && merchant.length > 5) {
      merchant = merchant.replaceAll(RegExp(r'upi', caseSensitive: false), "").trim();
    }

    // category nikalne ke liye hum merchant name ko AppConstants ke merchantCategoryMap ke against check karenge
    // Remove UPI handles to prevent false positives like 'airtel' from '@mairtel.in'
    String cleanMsgForCategory = lowerMsg.replaceAll(RegExp(r'@[a-zA-Z0-9.-]+'), '');
    String category = 'Other';
    String? matchedKeyword;

    for (var key in AppConstants.merchantCategoryMap.keys) {
      if (_strictWords.contains(key)) {
        // Yahan cleanMsgForCategory use karein
        if (RegExp(r'\b' + key + r'\b').hasMatch(cleanMsgForCategory)) {
          category = AppConstants.merchantCategoryMap[key]!;
          matchedKeyword = key;
          break;
        }
      } else {
        // Yahan bhi cleanMsgForCategory use karein
        if (merchant.toLowerCase().contains(key) || cleanMsgForCategory.contains(key)) {
          category = AppConstants.merchantCategoryMap[key]!;
          matchedKeyword = key;
          break;
        }
      }
    }

    // Agar hume keyword mil gaya, toh hum merchant ka naam change kar denge
    // Aur usko Capitalize (Pehla letter bada) kar denge. (e.g. 'reliance fresh' -> 'Reliance Fresh')
    if (matchedKeyword != null) {
      merchant = matchedKeyword.split(' ').map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '').join(' ');
    }

    // REFERENCE / TXN NUMBER EXTRACTOR <---
    String refNumber = '';
    // Yeh regex Ref, Txn, ya UTR ke baad aane wale 6 ya usse zyada digits/alphanumeric ko pakdega
    RegExp refRegExp = RegExp(r"(?:ref(?:\.?\s*no\.?)?|txn(?:\.?\s*id)?|transaction(?:\s*id)?|trx|utr|upi\s*ref)[\s\:\-]*([0-9a-zA-Z]{6,})", caseSensitive: false);
    var refMatch = refRegExp.firstMatch(lowerMsg);

    if (refMatch != null && refMatch.group(1) != null) {
      refNumber = refMatch.group(1)!.trim();
    }

    //Payment mode nikalne ke liye simple keywords check karenge
    String payMode = 'Unknown';
    if (lowerMsg.contains('upi') || lowerMsg.contains('vpa') || lowerMsg.contains('@')) {
      payMode = 'UPI';
    } else if (lowerMsg.contains('card') || lowerMsg.contains('pos ')) {
      payMode = 'Card';
    } else if (lowerMsg.contains('netbanking') || lowerMsg.contains('net banking') || lowerMsg.contains('imps') || lowerMsg.contains('neft') || lowerMsg.contains('rtgs')) {
      payMode = 'NetBanking';
    } else if (lowerMsg.contains('mandate') || lowerMsg.contains('nach') || lowerMsg.contains('standing instruction') || lowerMsg.contains('auto debit')) {
      payMode = 'AutoDebit';
    } else {
      payMode = 'Other';
    }

    int isExpenseFlag = (type == 'Unknown') ? 0 : 1;

    if (lowerMsg.contains('standing instruction')) {
      category = 'Transfer';
      type = 'Unknown';
      merchant = 'Reminder: Payment Due';
      isExpenseFlag = 0;
    } else if (lowerMsg.contains('account transfer')) {
      category = 'Transfer';
      merchant = 'Account Transfer';
      isExpenseFlag = 0;
    }

    if (category == 'Other' && type == 'Credit') {
      category = 'Other Income';
      if (lowerMsg.contains('salary') || lowerMsg.contains('payroll') || lowerMsg.contains('ctc')) {
        category = 'Salary';
      } else if (lowerMsg.contains('bonus') || lowerMsg.contains('incentive')) {
        category = 'Bonus';
      } else if (lowerMsg.contains('refund') || lowerMsg.contains('rebate')) {
        category = 'Refund';
      } else if (lowerMsg.contains('gift') || lowerMsg.contains('donation')) {
        category = 'Gift';
      }
    }

    // Data Filteration rules:
    // Step 1: Mandatory Fields Check (Amount 0 hai ya Type pata nahi chala toh reject)
    if (amount <= 0.0 || type == 'Unknown' || type.isEmpty) {
      return null;
    }

    // Step 2: Entity Check (Kahan se paise kate/aaye aur kisko gaye - dono unknown nahi hone chahiye)
    bool isAccountUnknown = (accountInfo == 'Cash/Other' || accountInfo.toLowerCase().contains('unknown'));
    bool isMerchantUnknown = (merchant == 'Unknown' || merchant == 'General Expense' || merchant.isEmpty); // || merchant == 'General Income' excluded

    if (isAccountUnknown && isMerchantUnknown) {
      //return null; // Dono unknown hain, iska matlab garbage SMS hai, reject kar do
    }

    return {'amount': amount, 'type': type, 'merchant': merchant, 'date': date.toIso8601String(), 'body': originalMsg, 'category': category, 'account': accountInfo, 'payMode': payMode, 'is_expense': isExpenseFlag, 'is_edited': 0, 'ref_number': refNumber};
  }
}
