import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('budget_tracker.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 4, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL,
        merchant TEXT,
        date TEXT,
        type TEXT,
        body TEXT,
        category TEXT,
        is_expense INTEGER DEFAULT 1,
        is_edited INTEGER DEFAULT 0,
        account TEXT,
        payMode TEXT,
        ref_number TEXT,
        is_hidden INTEGER DEFAULT 0
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE expenses ADD COLUMN is_expense INTEGER DEFAULT 1;');
      await db.execute('ALTER TABLE expenses ADD COLUMN is_edited INTEGER DEFAULT 0;');
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE expenses ADD COLUMN account TEXT DEFAULT 'Cash/Other';");
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE expenses ADD COLUMN payMode TEXT DEFAULT 'Unknown';");
    }
  }

  Future<int> toggleExpenseStatus(int id, int isExpense) async {
    final db = await instance.database;
    return await db.update('expenses', {'is_expense': isExpense}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateTransactionDetails(int id, String merchant, String category, int isEdited) async {
    final db = await instance.database;
    return await db.update('expenses', {'merchant': merchant, 'category': category, 'is_edited': isEdited}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateExpenseCategory(int id, String category) async {
    final db = await instance.database;
    return await db.update('expenses', {'category': category}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateManualExpense(int id, double amount, String merchant, String category) async {
    final db = await instance.database;
    return await db.update('expenses', {'amount': amount, 'merchant': merchant, 'category': category}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> insertExpense(Map<String, dynamic> row) async {
    final db = await instance.database;
    Map<String, dynamic> insertRow = Map<String, dynamic>.from(row);

    // EXACT MATCH CHECK: Agar pura SMS (body) aur time same hai toh insert hi mat karo
    final List<Map<String, dynamic>> exactMatch = await db.query('expenses', where: 'body = ? AND date = ?', whereArgs: [insertRow['body'], insertRow['date']]);
    if (exactMatch.isNotEmpty) return 0;

    if (insertRow['date'] != null && insertRow['amount'] != null) {
      DateTime newDate = DateTime.parse(insertRow['date']);

      // Amount ko proper double mein convert karna
      double newAmt = (insertRow['amount'] is int) ? (insertRow['amount'] as int).toDouble() : insertRow['amount'] as double;

      // Aaj ka filter hata diya, ab sirf EXACT Amount dhoondhenge (Fast & Cross-day support)
      final List<Map<String, dynamic>> existing = await db.query('expenses', where: 'amount = ?', whereArgs: [newAmt]);

      bool isDuplicate = false;
      String newRef = (insertRow['ref_number'] ?? '').toString().trim();

      for (var oldExp in existing) {
        if (oldExp['type'] == insertRow['type']) {
          String oldRef = (oldExp['ref_number'] ?? '').toString().trim();

          // TIER 1: Reference Number Match (Sabse solid)
          if (newRef.isNotEmpty && oldRef.isNotEmpty) {
            if (newRef == oldRef) {
              isDuplicate = true;
              break;
            } else {
              continue; // Ref alag hai toh pakka alag kharcha hai
            }
          }

          // Dates compare karne ke liye gap nikalo
          DateTime oldDate = DateTime.parse(oldExp['date']);
          int diffMinutes = newDate.difference(oldDate).inMinutes.abs();
          int diffHours = newDate.difference(oldDate).inHours.abs();

          // TIER 2: Normal 5-Minute Rule (Chhote ya bade kisi bhi amount ke liye)
          if (diffMinutes <= 5) {
            isDuplicate = true;
            break;
          }

          // TIER 3: NAYA SMART DECIMAL LOGIC (Bade Bills ke liye)
          // newAmt % 1 != 0 ka matlab hai ki decimal ke baad kuch number hai (e.g. 1000.50 % 1 = 0.50)
          bool hasDecimal = (newAmt % 1 != 0);

          // Agar amount > 1000 hai, decimal hai, aur pichle 24 ghante ke andar same bill aaya hai
          if (newAmt > 1000 && hasDecimal && diffHours <= 24) {
            isDuplicate = true;
            break;
          }
        }
      }

      // Agar duplicate nikla toh is_expense = 0 kar do (Total mein nahi judega)
      if (isDuplicate) insertRow['is_expense'] = 0;

      // ---> NAYA LOGIC: DEFAULT UNHIDDEN INSERT <---
      // Agar row map mein is_hidden nahi aaya hai, toh by default 0 (visible) set kar do
      if (!insertRow.containsKey('is_hidden')) {
        insertRow['is_hidden'] = 0;
      }
      // ---------------------------------------------
    }

    return await db.insert('expenses', insertRow);
  }

  // Naya parameter {bool includeHidden = false} add kiya hai
  Future<List<Map<String, dynamic>>> getAllExpenses({bool includeHidden = false}) async {
    final db = await instance.database;

    if (includeHidden) {
      // Agar setting ON hai, toh saara data lao (hidden + unhidden)
      return await db.query('expenses', orderBy: 'date DESC');
    } else {
      // Warna sirf wahi lao jo hidden nahi hai (is_hidden = 0)
      return await db.query('expenses', where: 'is_hidden = 0 OR is_hidden IS NULL', orderBy: 'date DESC');
    }
  }

  // Hide/Unhide ka function (is_hidden ko toggle karega)
  Future<int> toggleHideExpense(int id, int isHiddenStatus) async {
    final db = await instance.database;
    return await db.update('expenses', {'is_hidden': isHiddenStatus}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('expenses');
  }

  Future<DateTime?> getLatestExpenseDate() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> result = await db.query('expenses', orderBy: 'date DESC', limit: 1);
    if (result.isNotEmpty && result.first['date'] != null) return DateTime.parse(result.first['date']);
    return null;
  }

  Future<void> updateBulkCategory(List<int> expenseIds, String newCategory) async {
    final db = await instance.database;
    if (expenseIds.isEmpty) return; // Safety check

    String placeholders = List.filled(expenseIds.length, '?').join(',');

    // ---> NAYA LOGIC: Agar Transfer hai toh is_expense 0, warna 1 <---
    int isExpenseFlag = (newCategory == 'Transfer') ? 0 : 1;

    await db.rawUpdate('UPDATE expenses SET category = ?, is_expense = ? WHERE id IN ($placeholders)', [newCategory, isExpenseFlag, ...expenseIds]);
  }
}
