import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class FlowDb {
  FlowDb._();
  static final FlowDb instance = FlowDb._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'flowpilot_offline.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            balance REAL NOT NULL DEFAULT 0,
            currency TEXT NOT NULL DEFAULT 'TZS'
          )
        ''');
        await db.execute('''
          CREATE TABLE categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            type TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER NOT NULL,
            category_id INTEGER,
            type TEXT NOT NULL,
            amount REAL NOT NULL,
            description TEXT,
            transaction_date TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');

        await db.insert('accounts', {
          'name': 'Cash drawer',
          'type': 'cash',
          'balance': 0,
          'currency': 'TZS',
        });
        await db.insert('accounts', {
          'name': 'M-Pesa',
          'type': 'mpesa',
          'balance': 0,
          'currency': 'TZS',
        });

        const income = [
          'Shop / walk-in sales',
          'Services rendered',
          'Customer paid via M-Pesa / Airtel',
          'Bank deposit from a customer',
          'Loan or capital in',
          'Other money in',
        ];
        const expense = [
          'Stock & supplies',
          'Transport, boda, fuel',
          'Rent & premises',
          'Staff wages',
          'Power, water, airtime',
          'Food & meals',
          'Mobile money / bank fees',
          'TRA, license, tax',
          'Marketing & promotions',
          'Equipment & repairs',
          'Owner drawings',
          'Other money out',
        ];
        for (final name in income) {
          await db.insert('categories', {'name': name, 'type': 'income'});
        }
        for (final name in expense) {
          await db.insert('categories', {'name': name, 'type': 'expense'});
        }
      },
    );
    return _db!;
  }

  Future<List<Map<String, dynamic>>> accounts() async {
    final db = await database;
    return db.query('accounts', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> categories(String type) async {
    final db = await database;
    return db.query('categories', where: 'type = ?', whereArgs: [type], orderBy: 'name');
  }

  Future<void> addAccount(String name, String type, double opening) async {
    final db = await database;
    await db.insert('accounts', {
      'name': name,
      'type': type,
      'balance': opening,
      'currency': 'TZS',
    });
  }

  Future<List<Map<String, dynamic>>> transactions() async {
    final db = await database;
    return db.rawQuery('''
      SELECT t.*, a.name AS account_name, c.name AS category_name
      FROM transactions t
      LEFT JOIN accounts a ON a.id = t.account_id
      LEFT JOIN categories c ON c.id = t.category_id
      ORDER BY t.transaction_date DESC, t.id DESC
    ''');
  }

  Future<String?> addTransaction({
    required int accountId,
    int? categoryId,
    required String type,
    required double amount,
    String? description,
    required DateTime date,
  }) async {
    final db = await database;
    return db.transaction((txn) async {
      final rows = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId]);
      if (rows.isEmpty) return 'Account not found.';
      final balance = (rows.first['balance'] as num).toDouble();
      if (type == 'expense' && amount > balance) {
        return 'Not enough balance.';
      }
      final delta = type == 'income' ? amount : -amount;
      await txn.insert('transactions', {
        'account_id': accountId,
        'category_id': categoryId,
        'type': type,
        'amount': amount,
        'description': description,
        'transaction_date': date.toIso8601String().substring(0, 10),
        'created_at': DateTime.now().toIso8601String(),
      });
      await txn.update(
        'accounts',
        {'balance': balance + delta},
        where: 'id = ?',
        whereArgs: [accountId],
      );
      return null;
    });
  }

  Future<void> rollback(int transactionId) async {
    final db = await database;
    await db.transaction((txn) async {
      final rows = await txn.query('transactions', where: 'id = ?', whereArgs: [transactionId]);
      if (rows.isEmpty) return;
      final t = rows.first;
      final amount = (t['amount'] as num).toDouble();
      final accountId = t['account_id'] as int;
      final type = t['type'] as String;
      final acc = await txn.query('accounts', where: 'id = ?', whereArgs: [accountId]);
      if (acc.isNotEmpty) {
        final balance = (acc.first['balance'] as num).toDouble();
        final delta = type == 'income' ? -amount : amount;
        await txn.update(
          'accounts',
          {'balance': balance + delta},
          where: 'id = ?',
          whereArgs: [accountId],
        );
      }
      await txn.delete('transactions', where: 'id = ?', whereArgs: [transactionId]);
    });
  }

  Future<Map<String, double>> dashboard() async {
    final db = await database;
    final acc = await db.rawQuery('SELECT SUM(balance) AS total FROM accounts');
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
    final cashOut = await db.rawQuery(
      "SELECT SUM(amount) AS total FROM transactions WHERE type = 'expense' AND transaction_date >= ?",
      [monthStart],
    );
    final cashIn = await db.rawQuery(
      "SELECT SUM(amount) AS total FROM transactions WHERE type = 'income' AND transaction_date >= ?",
      [monthStart],
    );
    final inAmt = (cashIn.first['total'] as num?)?.toDouble() ?? 0;
    final outAmt = (cashOut.first['total'] as num?)?.toDouble() ?? 0;
    return {
      'balance': (acc.first['total'] as num?)?.toDouble() ?? 0,
      'cashOut': outAmt,
      'net': inAmt - outAmt,
    };
  }
}
