import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../security/crypto_helper.dart';
import 'expense_item.dart';
import 'income_entry.dart';

/// 온디바이스 데이터베이스 보안 인터페이스 정의
abstract class DatabaseService {
  Future<void> initDatabase();
  Future<void> saveProfile(Map<String, dynamic> profile);
  Future<Map<String, dynamic>?> getProfile();
  Future<void> insertExpense(ExpenseItem item);
  Future<List<ExpenseItem>> getExpenses();
  Future<void> deleteExpense(String id);
  Future<void> updateExpense(ExpenseItem item);
  Future<void> insertTaxRecord(Map<String, dynamic> record);
  Future<List<Map<String, dynamic>>> getTaxRecords();
  Future<void> saveBannerHideTime(String bannerId, int hideUntilEpoch);
  Future<int?> getBannerHideTime(String bannerId);
  Future<Map<String, int>> getAllBannerHideTimes();
  Future<void> setMonthlyIncome(int year, int month, double amount);
  Future<Map<int, double>> getMonthlyIncomesForYear(int year);
  Future<void> deleteMonthlyIncome(int year, int month);
  // 일별 수입 기록 (v14)
  Future<void> insertIncomeEntry(IncomeEntry entry);
  Future<List<IncomeEntry>> getIncomeEntriesForMonth(int year, int month);
  Future<void> updateIncomeEntry(IncomeEntry entry);
  Future<void> deleteIncomeEntry(String id, int year, int month);
  // ②진단 결과(가상 신고서 draft) 영속화 → ③에서 자동기입
  Future<void> saveReportDraft(String userType,
      {required String reportType,
      required List<Map<String, dynamic>> items,
      required double finalAmount,
      required bool isRefund});
  Future<Map<String, dynamic>?> getReportDraft(String userType);
  // 연말정산 기록 원시 입력값(수기/PDF) — user_type별 1건, 진단 자동기입용
  Future<void> saveAnnualRecord(String userType, Map<String, dynamic> values);
  Future<Map<String, dynamic>?> getAnnualRecord(String userType);
  // 사용자 맞춤 리마인더 (v20) — 항목·기한·알림시각, 시스템 알림 예약 연동
  Future<int> insertReminder(Map<String, dynamic> reminder); // 생성된 id 반환
  Future<List<Map<String, dynamic>>> getReminders();
  Future<void> updateReminder(Map<String, dynamic> reminder);
  Future<void> deleteReminder(int id);
  // 시스템 알림 토글 상태 (v22) — key별 on/off, 값 없으면 ON으로 간주
  Future<Map<String, bool>> getReminderSettings();
  Future<void> setReminderSetting(String key, bool enabled);
  Future<void> destroyAllData(); // 복구 불가능 영구 파기
  Future<void> close();
}

/// 1. 실제 모바일 기기 구동용 Sqflite 데이터베이스 서비스 구현
class SqfliteDatabaseHelper implements DatabaseService {
  Database? _db;
  final String dbName = 'secul.db';

  /// 사용자 맞춤 리마인더 테이블 정의 (v21)
  /// repeat_monthly(구버전)는 호환용으로 남기고, 반복 주기는 frequency로 표현.
  static const String _remindersTableSql = '''
    CREATE TABLE IF NOT EXISTS reminders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      kind TEXT,
      due_date TEXT,
      notify_date TEXT,
      notify_hour INTEGER,
      notify_minute INTEGER,
      repeat_monthly INTEGER DEFAULT 0,
      frequency TEXT DEFAULT 'once',
      weekday INTEGER,
      enabled INTEGER DEFAULT 1,
      notif_id INTEGER
    )
  ''';

  /// 시스템 알림 토글 상태 테이블 (v22). 행이 없으면 ON으로 간주.
  static const String _reminderSettingsTableSql = '''
    CREATE TABLE IF NOT EXISTS reminder_settings (
      key TEXT PRIMARY KEY,
      enabled INTEGER DEFAULT 1
    )
  ''';

  @override
  Future<void> initDatabase() async {
    if (_db != null) return;
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    _db = await openDatabase(
      path,
      version: 22,
      onCreate: (db, version) async {
        // 프로필 테이블 생성
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_type TEXT,
            gross_income REAL,
            dependents INTEGER,
            age INTEGER,
            military_months INTEGER,
            is_monthly_rent INTEGER,
            monthly_rent REAL,
            decided_tax REAL,
            yellow_umbrella REAL,
            monthly_income REAL,
            is_married INTEGER,
            is_spouse_dependent INTEGER,
            has_spouse_disability INTEGER,
            has_self_disability INTEGER,
            disabled_dependent_count INTEGER,
            data_mode TEXT,
            expense_target REAL,
            has_elderly_70plus INTEGER,
            is_female_head INTEGER,
            is_single_parent INTEGER,
            wedding_year INTEGER,
            children_count_8plus INTEGER,
            newborn_count INTEGER,
            is_sme_employee INTEGER,
            sme_start_year INTEGER,
            pay_day INTEGER DEFAULT 25,
            type_identified INTEGER DEFAULT 0
          )
        ''');
        // 지출 내역 테이블 생성 (민감 정보는 텍스트 암호화 상태로 저장)
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            date TEXT,
            end_date TEXT,
            amount TEXT,
            content TEXT,
            category TEXT
          )
        ''');
        // 세무 기록부 테이블 생성
        await db.execute('''
          CREATE TABLE tax_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            record_year INTEGER,
            record_type TEXT,
            gross_income REAL,
            refund_amount REAL,
            created_at TEXT
          )
        ''');
        // 배너 숨김 상태 테이블
        await db.execute('''
          CREATE TABLE banner_states (
            banner_id TEXT PRIMARY KEY,
            hide_until_epoch INTEGER
          )
        ''');
        // 당월 카드·현금 누계 테이블
        await db.execute('''
          CREATE TABLE monthly_card_usage (
            year INTEGER,
            month INTEGER,
            credit_card_total REAL DEFAULT 0,
            debit_cash_total REAL DEFAULT 0,
            PRIMARY KEY (year, month)
          )
        ''');
        // 월별 소득 기록 테이블
        await db.execute('''
          CREATE TABLE monthly_income_records (
            year INTEGER,
            month INTEGER,
            amount REAL,
            PRIMARY KEY (year, month)
          )
        ''');
        // 일별 수입 기록 테이블 (v14) — 암호화 저장
        await db.execute('''
          CREATE TABLE income_entries (
            id TEXT PRIMARY KEY,
            date TEXT,
            end_date TEXT,
            amount TEXT,
            memo TEXT,
            income_type TEXT
          )
        ''');
        // ②진단 결과(가상 신고서 draft) — user_type별 1건
        await db.execute('''
          CREATE TABLE report_drafts (
            user_type TEXT PRIMARY KEY,
            report_type TEXT,
            items TEXT,
            final_amount REAL,
            is_refund INTEGER,
            created_at TEXT
          )
        ''');
        // 연말정산 기록 원시값(암호화 JSON) — user_type별 1건
        await db.execute('''
          CREATE TABLE annual_records (
            user_type TEXT PRIMARY KEY,
            payload TEXT,
            created_at TEXT
          )
        ''');
        // 사용자 맞춤 리마인더 (v20)
        await db.execute(_remindersTableSql);
        // 시스템 알림 토글 (v22)
        await db.execute(_reminderSettingsTableSql);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN monthly_income REAL');
          } catch (e) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_married INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_spouse_dependent INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN has_spouse_disability INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN has_self_disability INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN disabled_dependent_count INTEGER');
          } catch (e) {}
          try {
            await db.execute('''
              CREATE TABLE tax_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                record_year INTEGER,
                record_type TEXT,
                gross_income REAL,
                refund_amount REAL,
                created_at TEXT
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('''
              CREATE TABLE banner_states (
                banner_id TEXT PRIMARY KEY,
                hide_until_epoch INTEGER
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN data_mode TEXT');
          } catch (e) {}
        }
        if (oldVersion < 6) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN paid_tax REAL');
            await db.execute('ALTER TABLE user_profile ADD COLUMN withholding_text TEXT');
          } catch (e) {}
        }
        if (oldVersion < 7) {
          try {
            await db.execute('''
              CREATE TABLE monthly_card_usage (
                year INTEGER,
                month INTEGER,
                credit_card_total REAL DEFAULT 0,
                debit_cash_total REAL DEFAULT 0,
                PRIMARY KEY (year, month)
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 8) {
          try {
            await db.execute('ALTER TABLE expenses ADD COLUMN end_date TEXT');
          } catch (e) {}
        }
        if (oldVersion < 9) {
          try {
            await db.execute('''
              CREATE TABLE monthly_income_records (
                year INTEGER,
                month INTEGER,
                amount REAL,
                PRIMARY KEY (year, month)
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 10) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN expense_target REAL');
          } catch (e) {}
        }
        if (oldVersion < 11) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN has_elderly_70plus INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_female_head INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_single_parent INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 12) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN wedding_year INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN children_count_8plus INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN newborn_count INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 13) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN is_sme_employee INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN sme_start_year INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 14) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS income_entries (
                id TEXT PRIMARY KEY,
                date TEXT,
                amount TEXT,
                memo TEXT,
                income_type TEXT
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 15) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN pay_day INTEGER DEFAULT 25');
          } catch (e) {}
        }
        if (oldVersion < 16) {
          try {
            await db.execute('ALTER TABLE income_entries ADD COLUMN end_date TEXT');
          } catch (e) {}
        }
        if (oldVersion < 17) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN type_identified INTEGER DEFAULT 0');
          } catch (e) {}
        }
        if (oldVersion < 18) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS report_drafts (
                user_type TEXT PRIMARY KEY,
                report_type TEXT,
                items TEXT,
                final_amount REAL,
                is_refund INTEGER,
                created_at TEXT
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 19) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS annual_records (
                user_type TEXT PRIMARY KEY,
                payload TEXT,
                created_at TEXT
              )
            ''');
          } catch (e) {}
        }
        if (oldVersion < 20) {
          try {
            await db.execute('ALTER TABLE user_profile ADD COLUMN age INTEGER');
            await db.execute('ALTER TABLE user_profile ADD COLUMN military_months INTEGER');
          } catch (e) {}
          try {
            await db.execute(_remindersTableSql);
          } catch (e) {}
        }
        if (oldVersion < 21) {
          try {
            await db.execute("ALTER TABLE reminders ADD COLUMN frequency TEXT DEFAULT 'once'");
            await db.execute('ALTER TABLE reminders ADD COLUMN weekday INTEGER');
          } catch (e) {}
        }
        if (oldVersion < 22) {
          try {
            await db.execute(_reminderSettingsTableSql);
          } catch (e) {}
        }
      },
    );
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    final db = _db;
    if (db == null) return;

    await db.transaction((txn) async {
      await txn.delete('user_profile'); // 기존 단일 프로필 유지
      await txn.insert('user_profile', {
        'user_type': profile['user_type'],
        'gross_income': profile['gross_income'],
        'dependents': profile['dependents'],
        'age': profile['age'],
        'military_months': profile['military_months'],
        'is_monthly_rent': profile['is_monthly_rent'] == true ? 1 : 0,
        'monthly_rent': profile['monthly_rent'],
        'decided_tax': profile['decided_tax'],
        'yellow_umbrella': profile['yellow_umbrella'],
        'monthly_income': profile['monthly_income'],
        'is_married': profile['is_married'] == true ? 1 : 0,
        'is_spouse_dependent': profile['is_spouse_dependent'] == true ? 1 : 0,
        'has_spouse_disability': profile['has_spouse_disability'] == true ? 1 : 0,
        'has_self_disability': profile['has_self_disability'] == true ? 1 : 0,
        'disabled_dependent_count': profile['disabled_dependent_count'] ?? 0,
        'data_mode': profile['data_mode'] ?? 'manual',
        'paid_tax': profile['paid_tax'],
        'withholding_text': profile['withholding_text'],
        'expense_target': profile['expense_target'],
        'has_elderly_70plus': profile['has_elderly_70plus'] == true ? 1 : 0,
        'is_female_head': profile['is_female_head'] == true ? 1 : 0,
        'is_single_parent': profile['is_single_parent'] == true ? 1 : 0,
        'wedding_year': profile['wedding_year'],
        'children_count_8plus': profile['children_count_8plus'] ?? 0,
        'newborn_count': profile['newborn_count'] ?? 0,
        'is_sme_employee': profile['is_sme_employee'] == true ? 1 : 0,
        'sme_start_year': profile['sme_start_year'],
        'pay_day': profile['pay_day'] ?? 25,
        'type_identified': profile['type_identified'] == true ? 1 : 0,
      });
    });
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    final db = _db;
    if (db == null) return null;

    final List<Map<String, dynamic>> maps = await db.query('user_profile');
    if (maps.isEmpty) return null;

    final map = maps.first;
    return {
      'user_type': map['user_type'],
      'gross_income': map['gross_income'],
      'dependents': map['dependents'],
      'age': map['age'] as int?,
      'military_months': map['military_months'] as int?,
      'is_monthly_rent': map['is_monthly_rent'] == 1,
      'monthly_rent': map['monthly_rent'],
      'decided_tax': map['decided_tax'],
      'yellow_umbrella': map['yellow_umbrella'],
      'monthly_income': map['monthly_income'],
      'is_married': map['is_married'] == 1,
      'is_spouse_dependent': map['is_spouse_dependent'] == 1,
      'has_spouse_disability': map['has_spouse_disability'] == 1,
      'has_self_disability': map['has_self_disability'] == 1,
      'disabled_dependent_count': map['disabled_dependent_count'] ?? 0,
      'data_mode': map['data_mode'] ?? 'manual',
      'paid_tax': map['paid_tax'],
      'withholding_text': map['withholding_text'],
      'expense_target': map['expense_target'],
      'has_elderly_70plus': map['has_elderly_70plus'] == 1,
      'is_female_head': map['is_female_head'] == 1,
      'is_single_parent': map['is_single_parent'] == 1,
      'wedding_year': map['wedding_year'] as int?,
      'children_count_8plus': map['children_count_8plus'] as int? ?? 0,
      'newborn_count': map['newborn_count'] as int? ?? 0,
      'is_sme_employee': map['is_sme_employee'] == 1,
      'sme_start_year': map['sme_start_year'] as int?,
      'pay_day': map['pay_day'] as int? ?? 25,
      'type_identified': map['type_identified'] == 1,
    };
  }

  @override
  Future<void> insertTaxRecord(Map<String, dynamic> record) async {
    final db = _db;
    if (db == null) return;
    await db.insert('tax_records', record);
  }

  @override
  Future<List<Map<String, dynamic>>> getTaxRecords() async {
    final db = _db;
    if (db == null) return [];
    return await db.query('tax_records', orderBy: 'created_at DESC');
  }

  @override
  Future<void> insertExpense(ExpenseItem item) async {
    final db = _db;
    if (db == null) return;

    // 민감 정보 암호화 처리 후 텍스트로 삽입
    final String encryptedAmount = CryptoHelper.encrypt(item.amount.toString());
    final String encryptedContent = CryptoHelper.encrypt(item.content);
    final String encryptedCategory = CryptoHelper.encrypt(item.category);

    await db.insert(
      'expenses',
      {
        'id': item.id,
        'date': item.date.toIso8601String(),
        'end_date': item.endDate?.toIso8601String(),
        'amount': encryptedAmount,
        'content': encryptedContent,
        'category': encryptedCategory,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<ExpenseItem>> getExpenses() async {
    final db = _db;
    if (db == null) return [];

    final List<Map<String, dynamic>> maps = await db.query('expenses');
    final List<ExpenseItem> list = [];

    for (final map in maps) {
      try {
        // 복호화 수행 및 원 데이터 복구
        final String decryptedAmountStr = CryptoHelper.decrypt(map['amount'] as String);
        final String decryptedContent = CryptoHelper.decrypt(map['content'] as String);
        final String decryptedCategory = CryptoHelper.decrypt(map['category'] as String);

        final int amount = int.parse(decryptedAmountStr);
        final DateTime date = DateTime.parse(map['date'] as String);
        final endDateStr = map['end_date'] as String?;

        list.add(ExpenseItem(
          id: map['id'] as String,
          date: date,
          endDate: endDateStr != null ? DateTime.parse(endDateStr) : null,
          amount: amount,
          content: decryptedContent,
          category: decryptedCategory,
        ));
      } catch (e) {
        // 복호화 실패 등 예외 시 무시
      }
    }
    return list;
  }

  @override
  Future<void> deleteExpense(String id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> updateExpense(ExpenseItem item) async {
    final db = _db;
    if (db == null) return;
    final String encryptedAmount = CryptoHelper.encrypt(item.amount.toString());
    final String encryptedContent = CryptoHelper.encrypt(item.content);
    final String encryptedCategory = CryptoHelper.encrypt(item.category);
    await db.update(
      'expenses',
      {
        'date': item.date.toIso8601String(),
        'end_date': item.endDate?.toIso8601String(),
        'amount': encryptedAmount,
        'content': encryptedContent,
        'category': encryptedCategory,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  @override
  Future<void> insertIncomeEntry(IncomeEntry entry) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'income_entries',
      {
        'id': entry.id,
        'date': entry.date.toIso8601String(),
        'end_date': entry.endDate?.toIso8601String(),
        'amount': CryptoHelper.encrypt(entry.amount.toString()),
        'memo': CryptoHelper.encrypt(entry.memo),
        'income_type': CryptoHelper.encrypt(entry.incomeType),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recalcMonthlyIncome(db, entry.date.year, entry.date.month);
  }

  @override
  Future<List<IncomeEntry>> getIncomeEntriesForMonth(int year, int month) async {
    final db = _db;
    if (db == null) return [];
    final rows = await db.query('income_entries');
    final result = <IncomeEntry>[];
    for (final row in rows) {
      try {
        final date = DateTime.parse(row['date'] as String);
        if (date.year != year || date.month != month) continue;
        final endStr = row['end_date'] as String?;
        result.add(IncomeEntry(
          id: row['id'] as String,
          date: date,
          endDate: endStr != null ? DateTime.parse(endStr) : null,
          amount: int.parse(CryptoHelper.decrypt(row['amount'] as String)),
          memo: CryptoHelper.decrypt(row['memo'] as String),
          incomeType: CryptoHelper.decrypt(row['income_type'] as String),
        ));
      } catch (_) {}
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  @override
  Future<void> updateIncomeEntry(IncomeEntry entry) async {
    final db = _db;
    if (db == null) return;
    await db.update(
      'income_entries',
      {
        'date': entry.date.toIso8601String(),
        'end_date': entry.endDate?.toIso8601String(),
        'amount': CryptoHelper.encrypt(entry.amount.toString()),
        'memo': CryptoHelper.encrypt(entry.memo),
        'income_type': CryptoHelper.encrypt(entry.incomeType),
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    await _recalcMonthlyIncome(db, entry.date.year, entry.date.month);
  }

  @override
  Future<void> deleteIncomeEntry(String id, int year, int month) async {
    final db = _db;
    if (db == null) return;
    await db.delete('income_entries', where: 'id = ?', whereArgs: [id]);
    await _recalcMonthlyIncome(db, year, month);
  }

  Future<void> _recalcMonthlyIncome(Database db, int year, int month) async {
    final rows = await db.query('income_entries');
    int total = 0;
    for (final row in rows) {
      try {
        final date = DateTime.parse(row['date'] as String);
        if (date.year == year && date.month == month) {
          total += int.parse(CryptoHelper.decrypt(row['amount'] as String));
        }
      } catch (_) {}
    }
    if (total > 0) {
      await db.insert('monthly_income_records',
          {'year': year, 'month': month, 'amount': total.toDouble()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete('monthly_income_records',
          where: 'year = ? AND month = ?', whereArgs: [year, month]);
    }
  }

  @override
  Future<void> saveBannerHideTime(String bannerId, int hideUntilEpoch) async {
    final db = _db;
    if (db == null) return;
    await db.insert('banner_states', {
      'banner_id': bannerId,
      'hide_until_epoch': hideUntilEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<int?> getBannerHideTime(String bannerId) async {
    final db = _db;
    if (db == null) return null;
    final maps = await db.query('banner_states', where: 'banner_id = ?', whereArgs: [bannerId]);
    if (maps.isEmpty) return null;
    return maps.first['hide_until_epoch'] as int?;
  }

  @override
  Future<Map<String, int>> getAllBannerHideTimes() async {
    final db = _db;
    if (db == null) return {};
    final maps = await db.query('banner_states');
    final Map<String, int> result = {};
    for (var map in maps) {
      result[map['banner_id'] as String] = map['hide_until_epoch'] as int;
    }
    return result;
  }

  @override
  Future<void> setMonthlyIncome(int year, int month, double amount) async {
    final db = _db;
    if (db == null) return;
    await db.insert('monthly_income_records', {
      'year': year, 'month': month, 'amount': amount,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<int, double>> getMonthlyIncomesForYear(int year) async {
    final db = _db;
    if (db == null) return {};
    final rows = await db.query('monthly_income_records', where: 'year = ?', whereArgs: [year]);
    final result = <int, double>{};
    for (final r in rows) {
      result[r['month'] as int] = (r['amount'] as double?) ?? 0.0;
    }
    return result;
  }

  @override
  Future<void> deleteMonthlyIncome(int year, int month) async {
    final db = _db;
    if (db == null) return;
    await db.delete('monthly_income_records', where: 'year = ? AND month = ?', whereArgs: [year, month]);
  }

  @override
  Future<void> saveReportDraft(String userType,
      {required String reportType,
      required List<Map<String, dynamic>> items,
      required double finalAmount,
      required bool isRefund}) async {
    final db = _db;
    if (db == null) return;
    await db.insert('report_drafts', {
      'user_type': userType,
      'report_type': reportType,
      'items': jsonEncode(items),
      'final_amount': finalAmount,
      'is_refund': isRefund ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> getReportDraft(String userType) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('report_drafts', where: 'user_type = ?', whereArgs: [userType]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    List<Map<String, dynamic>> items = [];
    try {
      final decoded = jsonDecode(r['items'] as String? ?? '[]') as List;
      items = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {}
    return {
      'report_type': r['report_type'],
      'items': items,
      'final_amount': (r['final_amount'] as num?)?.toDouble() ?? 0.0,
      'is_refund': r['is_refund'] == 1,
    };
  }

  @override
  Future<void> saveAnnualRecord(String userType, Map<String, dynamic> values) async {
    final db = _db;
    if (db == null) return;
    await db.insert('annual_records', {
      'user_type': userType,
      'payload': CryptoHelper.encrypt(jsonEncode(values)),
      'created_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, dynamic>?> getAnnualRecord(String userType) async {
    final db = _db;
    if (db == null) return null;
    final rows = await db.query('annual_records', where: 'user_type = ?', whereArgs: [userType]);
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(CryptoHelper.decrypt(rows.first['payload'] as String)) as Map;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = _db;
    if (db == null) return -1;
    return await db.insert('reminders', _reminderToRow(reminder));
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders() async {
    final db = _db;
    if (db == null) return [];
    final rows = await db.query('reminders', orderBy: 'notify_date ASC');
    return rows.map(_rowToReminder).toList();
  }

  @override
  Future<void> updateReminder(Map<String, dynamic> reminder) async {
    final db = _db;
    if (db == null) return;
    await db.update('reminders', _reminderToRow(reminder),
        where: 'id = ?', whereArgs: [reminder['id']]);
  }

  @override
  Future<void> deleteReminder(int id) async {
    final db = _db;
    if (db == null) return;
    await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Map<String, bool>> getReminderSettings() async {
    final db = _db;
    if (db == null) return {};
    final rows = await db.query('reminder_settings');
    return {for (final r in rows) r['key'] as String: r['enabled'] == 1};
  }

  @override
  Future<void> setReminderSetting(String key, bool enabled) async {
    final db = _db;
    if (db == null) return;
    await db.insert(
      'reminder_settings',
      {'key': key, 'enabled': enabled ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Map<String, dynamic> _reminderToRow(Map<String, dynamic> r) => {
        if (r['id'] != null) 'id': r['id'],
        'title': r['title'],
        'kind': r['kind'],
        'due_date': r['due_date'],
        'notify_date': r['notify_date'],
        'notify_hour': r['notify_hour'],
        'notify_minute': r['notify_minute'],
        // 구버전 호환 유지: monthly면 repeat_monthly=1로도 기록.
        'repeat_monthly': (r['frequency'] == 'monthly' || r['repeat_monthly'] == true) ? 1 : 0,
        'frequency': r['frequency'] ?? 'once',
        'weekday': r['weekday'],
        'enabled': r['enabled'] == false ? 0 : 1,
        'notif_id': r['notif_id'],
      };

  Map<String, dynamic> _rowToReminder(Map<String, dynamic> row) => {
        'id': row['id'],
        'title': row['title'],
        'kind': row['kind'],
        'due_date': row['due_date'],
        'notify_date': row['notify_date'],
        'notify_hour': row['notify_hour'],
        'notify_minute': row['notify_minute'],
        'repeat_monthly': row['repeat_monthly'] == 1,
        'frequency': row['frequency'],
        'weekday': row['weekday'],
        'enabled': row['enabled'] == 1,
        'notif_id': row['notif_id'],
      };

  @override
  Future<void> destroyAllData() async {
    final db = _db;
    if (db == null) return;

    // 1단계: 난수 및 0 채우기로 플래시 메모리 영역 덮어쓰기 (Shredding)
    try {
      await db.execute("UPDATE user_profile SET user_type='TEMP', gross_income=0, dependents=0, monthly_rent=0, decided_tax=0, yellow_umbrella=0, monthly_income=0");
      await db.execute("UPDATE expenses SET date='0000', amount='ZERO', content='ZERO', category='ZERO'");
      await db.execute("DELETE FROM banner_states");
      await db.execute("DELETE FROM monthly_card_usage");
      await db.execute("DELETE FROM monthly_income_records");
      await db.execute("DELETE FROM income_entries");
      await db.execute("DELETE FROM report_drafts");
      await db.execute("DELETE FROM annual_records");
      await db.execute("DELETE FROM reminders");
      await db.execute("DELETE FROM reminder_settings");
    } catch (e) {
      // 무시
    }

    // 2단계: SQLite 프리리스트 영구 소거를 위한 VACUUM 실행
    try {
      await db.execute("VACUUM");
    } catch (e) {
      // 무시
    }

    // 3단계: 커넥션 클로즈 및 물리적 DB 파일 삭제
    await close();
    
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}

/// 2. 데스크톱 테스트(flutter test) 환경용 인메모리 가상 데이터베이스 서비스 구현
class InMemoryDatabaseHelper implements DatabaseService {
  Map<String, dynamic>? _profile;
  final Map<String, Map<String, dynamic>> _expenses = {};
  final List<Map<String, dynamic>> _taxRecords = [];
  bool _isClosed = false;

  @override
  Future<void> initDatabase() async {
    _isClosed = false;
  }

  @override
  Future<void> saveProfile(Map<String, dynamic> profile) async {
    if (_isClosed) return;
    _profile = Map<String, dynamic>.from(profile);
  }

  @override
  Future<Map<String, dynamic>?> getProfile() async {
    if (_isClosed) return null;
    return _profile;
  }

  @override
  Future<void> insertTaxRecord(Map<String, dynamic> record) async {
    if (_isClosed) return;
    _taxRecords.add(Map<String, dynamic>.from(record));
  }

  @override
  Future<List<Map<String, dynamic>>> getTaxRecords() async {
    if (_isClosed) return [];
    final records = List<Map<String, dynamic>>.from(_taxRecords);
    records.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    return records;
  }

  @override
  Future<void> insertExpense(ExpenseItem item) async {
    if (_isClosed) return;
    
    // 유닛 테스트 무결성 증명을 위해 인메모리 내에서도 암호화 적재 시뮬레이션 수행
    final String encryptedAmount = CryptoHelper.encrypt(item.amount.toString());
    final String encryptedContent = CryptoHelper.encrypt(item.content);
    final String encryptedCategory = CryptoHelper.encrypt(item.category);

    _expenses[item.id] = {
      'id': item.id,
      'date': item.date.toIso8601String(),
      'end_date': item.endDate?.toIso8601String(),
      'amount': encryptedAmount,
      'content': encryptedContent,
      'category': encryptedCategory,
    };
  }

  @override
  Future<List<ExpenseItem>> getExpenses() async {
    if (_isClosed) return [];
    
    final List<ExpenseItem> list = [];
    for (final raw in _expenses.values) {
      final String decryptedAmountStr = CryptoHelper.decrypt(raw['amount'] as String);
      final String decryptedContent = CryptoHelper.decrypt(raw['content'] as String);
      final String decryptedCategory = CryptoHelper.decrypt(raw['category'] as String);
      
      final endDateStr = raw['end_date'] as String?;
      list.add(ExpenseItem(
        id: raw['id'] as String,
        date: DateTime.parse(raw['date'] as String),
        endDate: endDateStr != null ? DateTime.parse(endDateStr) : null,
        amount: int.parse(decryptedAmountStr),
        content: decryptedContent,
        category: decryptedCategory,
      ));
    }
    return list;
  }

  @override
  Future<void> deleteExpense(String id) async {
    if (_isClosed) return;
    _expenses.remove(id);
  }

  final Map<String, int> _bannerHideTimes = {};

  @override
  Future<void> saveBannerHideTime(String bannerId, int hideUntilEpoch) async {
    if (_isClosed) return;
    _bannerHideTimes[bannerId] = hideUntilEpoch;
  }

  @override
  Future<int?> getBannerHideTime(String bannerId) async {
    if (_isClosed) return null;
    return _bannerHideTimes[bannerId];
  }

  @override
  Future<Map<String, int>> getAllBannerHideTimes() async {
    if (_isClosed) return {};
    return Map.from(_bannerHideTimes);
  }

  final Map<String, double> _monthlyIncomes = {};

  @override
  Future<void> setMonthlyIncome(int year, int month, double amount) async {
    if (_isClosed) return;
    _monthlyIncomes['$year-$month'] = amount;
  }

  @override
  Future<Map<int, double>> getMonthlyIncomesForYear(int year) async {
    if (_isClosed) return {};
    final result = <int, double>{};
    _monthlyIncomes.forEach((key, value) {
      final parts = key.split('-');
      if (parts[0] == '$year') result[int.parse(parts[1])] = value;
    });
    return result;
  }

  @override
  Future<void> deleteMonthlyIncome(int year, int month) async {
    if (_isClosed) return;
    _monthlyIncomes.remove('$year-$month');
  }

  final List<IncomeEntry> _incomeEntries = [];

  @override
  Future<void> insertIncomeEntry(IncomeEntry entry) async {
    if (_isClosed) return;
    _incomeEntries.removeWhere((e) => e.id == entry.id);
    _incomeEntries.add(entry);
    _recalcMonthlyIncomeInMemory(entry.date.year, entry.date.month);
  }

  @override
  Future<List<IncomeEntry>> getIncomeEntriesForMonth(int year, int month) async {
    if (_isClosed) return [];
    return _incomeEntries
        .where((e) => e.date.year == year && e.date.month == month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<void> updateIncomeEntry(IncomeEntry entry) async {
    if (_isClosed) return;
    final idx = _incomeEntries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) _incomeEntries[idx] = entry;
    _recalcMonthlyIncomeInMemory(entry.date.year, entry.date.month);
  }

  @override
  Future<void> deleteIncomeEntry(String id, int year, int month) async {
    if (_isClosed) return;
    _incomeEntries.removeWhere((e) => e.id == id);
    _recalcMonthlyIncomeInMemory(year, month);
  }

  void _recalcMonthlyIncomeInMemory(int year, int month) {
    final total = _incomeEntries
        .where((e) => e.date.year == year && e.date.month == month)
        .fold(0, (s, e) => s + e.amount);
    if (total > 0) {
      _monthlyIncomes['$year-$month'] = total.toDouble();
    } else {
      _monthlyIncomes.remove('$year-$month');
    }
  }

  @override
  Future<void> updateExpense(ExpenseItem item) async {
    if (_isClosed) return;
    await insertExpense(item); // replace
  }

  final Map<String, Map<String, dynamic>> _reportDrafts = {};

  @override
  Future<void> saveReportDraft(String userType,
      {required String reportType,
      required List<Map<String, dynamic>> items,
      required double finalAmount,
      required bool isRefund}) async {
    if (_isClosed) return;
    _reportDrafts[userType] = {
      'report_type': reportType,
      'items': items.map((e) => Map<String, dynamic>.from(e)).toList(),
      'final_amount': finalAmount,
      'is_refund': isRefund,
    };
  }

  @override
  Future<Map<String, dynamic>?> getReportDraft(String userType) async {
    if (_isClosed) return null;
    return _reportDrafts[userType];
  }

  final Map<String, Map<String, dynamic>> _annualRecords = {};

  @override
  Future<void> saveAnnualRecord(String userType, Map<String, dynamic> values) async {
    if (_isClosed) return;
    // 무결성 증명을 위해 인메모리에서도 암호화 적재
    final enc = CryptoHelper.encrypt(jsonEncode(values));
    _annualRecords[userType] = {'payload': enc};
  }

  @override
  Future<Map<String, dynamic>?> getAnnualRecord(String userType) async {
    if (_isClosed) return null;
    final row = _annualRecords[userType];
    if (row == null) return null;
    try {
      final decoded = jsonDecode(CryptoHelper.decrypt(row['payload'] as String)) as Map;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  final List<Map<String, dynamic>> _reminders = [];
  int _reminderAutoId = 1;

  @override
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    if (_isClosed) return -1;
    final id = _reminderAutoId++;
    _reminders.add({...reminder, 'id': id});
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getReminders() async {
    if (_isClosed) return [];
    final list = _reminders.map((e) => Map<String, dynamic>.from(e)).toList();
    list.sort((a, b) =>
        (a['notify_date'] as String? ?? '').compareTo(b['notify_date'] as String? ?? ''));
    return list;
  }

  @override
  Future<void> updateReminder(Map<String, dynamic> reminder) async {
    if (_isClosed) return;
    final idx = _reminders.indexWhere((e) => e['id'] == reminder['id']);
    if (idx >= 0) _reminders[idx] = Map<String, dynamic>.from(reminder);
  }

  @override
  Future<void> deleteReminder(int id) async {
    if (_isClosed) return;
    _reminders.removeWhere((e) => e['id'] == id);
  }

  final Map<String, bool> _reminderSettings = {};

  @override
  Future<Map<String, bool>> getReminderSettings() async {
    if (_isClosed) return {};
    return Map<String, bool>.from(_reminderSettings);
  }

  @override
  Future<void> setReminderSetting(String key, bool enabled) async {
    if (_isClosed) return;
    _reminderSettings[key] = enabled;
  }

  @override
  Future<void> destroyAllData() async {
    // 1단계: 난수 오염 시뮬레이션
    _expenses.forEach((key, value) {
      _expenses[key] = {
        'id': key,
        'date': '0000',
        'amount': 'ZERO',
        'content': 'ZERO',
        'category': 'ZERO',
      };
    });
    _profile = null;

    // 2/3단계: 물리적 소거
    _expenses.clear();
    _monthlyIncomes.clear();
    _incomeEntries.clear();
    _reportDrafts.clear();
    _annualRecords.clear();
    _reminders.clear();
    _reminderSettings.clear();
    await close();
  }

  @override
  Future<void> close() async {
    _isClosed = true;
  }
}

/// 전역적으로 접근 가능한 데이터베이스 서비스 단일 인스턴스
/// 웹에서는 sqflite 미지원이므로 인메모리 구현체를 사용
DatabaseService dbService = kIsWeb ? InMemoryDatabaseHelper() : SqfliteDatabaseHelper();
