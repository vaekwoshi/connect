import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../components/reminder_card.dart';
import '../../main.dart';

import 'freelancer_book_screen.dart';
import 'onboarding_screen.dart';
import 'profile_input_screen.dart';
import 'year_end_tax_screen.dart';
import 'tax_simulator_screen.dart';
import 'tax_persona_question_screen.dart';
import 'financial_income_screen.dart';
import 'expense_calendar_screen.dart';
import 'tax_tools_screen.dart';
import 'settings_screen.dart';
import '../../core/data/tax_tips.dart';
import '../../core/data/db_helper.dart';
import '../../core/tax_engine/employee_tax.dart';
import '../../core/security/notification_helper.dart';
import '../../core/notifications/reminder_scheduler.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userType = '직장인'; 
  int _currentIndex = 0;

  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _savingGoalController = TextEditingController();
  final TextEditingController _monthlyRentController = TextEditingController();

  // 신용카드/체크+현금 당월 누계 (표시용)
  double _creditCardTotal = 0.0;
  double _debitCashTotal = 0.0;

  // 신용카드/체크+현금 입력용 (더하기 버튼 전 임시값)
  final TextEditingController _creditCardInputController = TextEditingController();
  final TextEditingController _debitCashInputController = TextEditingController();
  

  final TextEditingController _freelancerIncomeController = TextEditingController();
  final TextEditingController _monthsController = TextEditingController(text: '12');
  final TextEditingController _yellowUmbrellaController = TextEditingController();

  // 절세 프로필 상태 변수
  int _dependentCount = 1;
  bool _isMonthlyRent = false;
  bool _isTypeIdentified = false;   // 유형 파악 완료 여부 (온보딩 1단계)
  bool _isProfileCompleted = false; // 프로필 완성 여부 (온보딩 2단계)
  double _decidedTax = 0.0; // 결정세액 (연말정산 진단 데이터)
  double _grossIncome = 0.0; // 연소득(연봉) (연말정산 진단 데이터)
  double _laborIncome = 0.0; // 이번 달 근로소득(급여) — N잡러 수입 분리
  double _otherIncome = 0.0; // 이번 달 기타 수익(프리랜서·부수입 등) — N잡러 수입 분리
  double _expenseTarget = 0.0; // 이번 달 지출 목표
  int _payDay = 25; // 직장인·N잡 월급여일 (1~31, 알림 넛지 기준)
  bool _notificationsEnabled = true; // 세금·가계부 알림 마스터 on/off (reminder_settings 'master'에 영속)
  bool _thresholdNotified = false; // 공제 문턱 도달 알림 중복 방지(세션 내)
  bool _thresholdNearNotified = false; // 공제 문턱 80% 임박 알림 중복 방지(세션 내)

  // 세무 도구 — '빠르게 계산' 서랍(드롭다운) 펼침
  bool _calcDrawerOpen = false;

  // 홈 인라인 연봉 입력
  bool _showSalaryInput = false;
  final TextEditingController _grossIncomeInlineCtrl = TextEditingController();

  // 홈 인라인 지출 목표 입력
  bool _showExpenseInput = false;
  final TextEditingController _expenseTargetInlineCtrl = TextEditingController();

  bool get _isEmployee => _userType == '직장인' || _userType == 'N잡러';

  final _numberFormat = NumberFormat('#,###');

  // 홈 상단 회전 배너 (광고·알림 카드) — 6초마다 페이드 전환, 유형별 카드 세트
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  // '이달의 절세' 카드 — 상단 배너와 동일 형식의 페이드 회전(별도 인덱스, 같은 타이머)
  int _tipIndex = 0;

  @override
  void initState() {
    super.initState();
    notificationHelper.requestPermissions();
    _salaryController.addListener(_calculateTax);
    _monthlyRentController.addListener(_calculateTax);
    _freelancerIncomeController.addListener(_calculateTax);
    _monthsController.addListener(_calculateTax);
    _yellowUmbrellaController.addListener(_calculateTax);
    _savingGoalController.addListener(_onExpenseTargetChanged);
    _loadDataFromDB();
    _startBannerRotation();
  }

  /// 상단 배너 + 이달의 절세 카드 6초 자동 회전(페이드). 각자 2장 이상일 때만 전환.
  void _startBannerRotation() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      final bn = _bannerCards().length;
      final tn = _currentTips().length;
      if (bn <= 1 && tn <= 1) return;
      setState(() {
        if (bn > 1) _bannerIndex = (_bannerIndex + 1) % bn;
        if (tn > 1) _tipIndex = (_tipIndex + 1) % tn;
      });
    });
  }

  /// 이번 달·유형에 맞는 절세 팁(회전용 최대 5장).
  List<TaxTip> _currentTips() => taxTipsFor(_userType, DateTime.now().month, limit: 5);

  Future<void> _loadDataFromDB() async {
    try {
      final profile = await dbService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          _userType = profile['user_type'] ?? '직장인';
          
          double monthlyIncome = 0.0;
          try {
            monthlyIncome = profile['monthly_income'] as double? ?? 0.0;
          } catch (_) {}

          if (monthlyIncome > 0) {
            _salaryController.text = _numberFormat.format(monthlyIncome.toInt());
          }
          
          _dependentCount = profile['dependents'] as int? ?? 1;
          _isMonthlyRent = profile['is_monthly_rent'] == true;
          
          final monthlyRent = profile['monthly_rent'] as double? ?? 0.0;
          if (monthlyRent > 0) {
            _monthlyRentController.text = _numberFormat.format(monthlyRent.toInt());
          }

          final yellowUmbrella = profile['yellow_umbrella'] as double? ?? 0.0;
          if (yellowUmbrella > 0) {
            _yellowUmbrellaController.text = _numberFormat.format(yellowUmbrella.toInt());
          }

          final expenseTarget = profile['expense_target'] as double? ?? 0.0;
          if (expenseTarget > 0) {
            _expenseTarget = expenseTarget;
            _savingGoalController.text = _numberFormat.format(expenseTarget.toInt());
          }

          _decidedTax = profile['decided_tax'] as double? ?? 0.0;
          _grossIncome = profile['gross_income'] as double? ?? 0.0;
          _payDay = (profile['pay_day'] as int? ?? 25).clamp(1, 31);
          _isTypeIdentified = profile['type_identified'] == true;
          _isProfileCompleted = true;
          // 기존 사용자 호환: 프로필이 있으면 유형 파악 완료로 처리
          if (!_isTypeIdentified) _isTypeIdentified = true;
        });
      }
    } catch (e) {
      // 핫 리로드 과도기 중 DB 필드 불일치 에러 방어
    }

    // 마스터 알림 토글 — reminder_settings 'master'(없으면 ON)에서 복원.
    try {
      final rs = await dbService.getReminderSettings();
      if (mounted) setState(() => _notificationsEnabled = rs['master'] ?? true);
    } catch (_) {}

    await _loadMonthlyExpenses();
    await _loadCurrentMonthIncome();
    _calculateTax();
    _refreshReminders();
  }

  /// 알림 켜짐 상태면 시즌·월간 리마인더를 (재)예약. 웹은 미지원.
  Future<void> _refreshReminders() async {
    if (kIsWeb) return;
    if (_notificationsEnabled) {
      await ReminderScheduler.scheduleAll(payDay: _payDay, userType: _userType);
    } else {
      await ReminderScheduler.cancelAll();
    }
  }

  /// 설정 알림 토글 — 영속화(reminder_settings 'master') + 즉시 예약/해제.
  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    await dbService.setReminderSetting('master', enabled);
    if (kIsWeb) return;
    if (enabled) {
      await notificationHelper.requestPermissions();
      await ReminderScheduler.scheduleAll(payDay: _payDay, userType: _userType);
    } else {
      await ReminderScheduler.cancelAll();
    }
  }

  /// 홈 소득 카드가 사용하는 컨트롤러 (직장인/N잡러 → 급여, 프리랜서 → 수입)
  TextEditingController get _activeIncomeController =>
      _isEmployee ? _salaryController : _freelancerIncomeController;

  /// 소득 달력의 이번 달 기록을 홈 카드에 반영 (기록이 source of truth)
  Future<void> _loadCurrentMonthIncome() async {
    final now = DateTime.now();
    final incomes = await dbService.getMonthlyIncomesForYear(now.year);
    final amount = incomes[now.month];
    if (amount != null && amount > 0 && mounted) {
      setState(() {
        _activeIncomeController.text = _numberFormat.format(amount.toInt());
      });
    }
    // 근로소득(급여) / 기타 수익 분리 — N잡러 수입 카드용 (income_entries = SSOT)
    final entries = await dbService.getIncomeEntriesForMonth(now.year, now.month);
    double labor = 0, other = 0;
    for (final e in entries) {
      if (e.incomeType == '급여') {
        labor += e.amount;
      } else {
        other += e.amount;
      }
    }
    if (mounted) {
      setState(() {
        _laborIncome = labor;
        _otherIncome = other;
      });
    }
  }

  Future<void> _loadMonthlyExpenses() async {
    final now = DateTime.now();
    final firstOfMonth = DateTime(now.year, now.month, 1);
    final nextMonth = now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final lastOfMonth = nextMonth.subtract(const Duration(days: 1));

    final all = await dbService.getExpenses();
    double credit = 0.0;
    double debit = 0.0;
    for (final e in all) {
      final eStart = DateTime(e.date.year, e.date.month, e.date.day);
      final eEnd = e.endDate != null
          ? DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day)
          : eStart;
      // 이번 달과 겹치는 항목 포함
      if (!eEnd.isBefore(firstOfMonth) && !eStart.isAfter(lastOfMonth)) {
        if (e.category == '신용카드') {
          credit += e.amount;
        } else {
          debit += e.amount;
        }
      }
    }
    if (mounted) {
      setState(() {
        _creditCardTotal = credit;
        _debitCashTotal = debit;
      });
      _checkCardThreshold();
    }
  }

  /// 신용카드 누계가 공제 문턱(연봉 25%)의 80%·100%에 처음 닿으면 각각 1회 알림.
  void _checkCardThreshold() {
    if (kIsWeb || !_notificationsEnabled || !_isEmployee) return;
    final monthlyIncome = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final annualSalary = _grossIncome > 0 ? _grossIncome : monthlyIncome * 12;
    if (annualSalary <= 0) return;
    final threshold = annualSalary * 0.25;
    if (_creditCardTotal >= threshold) {
      if (!_thresholdNotified) {
        _thresholdNotified = true;
        ReminderScheduler.showThresholdReached();
      }
    } else {
      _thresholdNotified = false; // 문턱 아래로 내려가면 리셋
      // 80% 임박 — 문턱 넘기 전에 한 번만.
      if (_creditCardTotal >= threshold * 0.8) {
        if (!_thresholdNearNotified) {
          _thresholdNearNotified = true;
          ReminderScheduler.showThresholdNear();
        }
      } else {
        _thresholdNearNotified = false;
      }
    }
  }

  Future<void> _saveProfileToDB() async {
    final monthlyIncome = double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;
    final monthlyRent = double.tryParse(_monthlyRentController.text.replaceAll(',', '')) ?? 0.0;
    final yellowUmbrella = double.tryParse(_yellowUmbrellaController.text.replaceAll(',', '')) ?? 0.0;
    final expenseTarget = double.tryParse(_savingGoalController.text.replaceAll(',', '')) ?? 0.0;

    // 기존 프로필을 읽어 위저드에서 설정한 공제 항목(혼인·자녀·경로우대 등)을 보존(merge)
    final existing = await dbService.getProfile() ?? <String, dynamic>{};
    final profile = {
      ...existing,
      'user_type': _userType,
      'gross_income': _grossIncome,
      'dependents': _dependentCount,
      'is_monthly_rent': _isMonthlyRent,
      'monthly_rent': monthlyRent,
      'decided_tax': _decidedTax,
      'yellow_umbrella': yellowUmbrella,
      'monthly_income': monthlyIncome,
      'expense_target': expenseTarget,
      'pay_day': _payDay,
      'type_identified': _isTypeIdentified,
    };
    await dbService.saveProfile(profile);
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _savingGoalController.dispose();
    _monthlyRentController.dispose();
    _creditCardInputController.dispose();
    _debitCashInputController.dispose();
    _freelancerIncomeController.dispose();
    _monthsController.dispose();
    _yellowUmbrellaController.dispose();
    _grossIncomeInlineCtrl.dispose();
    _expenseTargetInlineCtrl.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  /// 설정 풀스크린 진입 (구 설정 바텀시트 대체).
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          notificationsEnabled: _notificationsEnabled,
          onNotificationsChanged: _setNotificationsEnabled,
          onDestroyData: _showDestroyConfirmDialog,
        ),
      ),
    );
  }

  void _showDestroyConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('데이터 파기 확인', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontWeight: FontWeight.bold)),
          content: Text(
            '모든 프로필 및 지출 데이터가 기기에서 영구적으로 파기됩니다.\n이 작업은 되돌릴 수 없어요. 정말 파기하시겠습니까?',
            style: TextStyle(color: Theme.of(context).textTheme.labelMedium!.color!),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('취소', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await dbService.destroyAllData();
                setState(() {
                  _salaryController.clear();
                  _savingGoalController.clear();
                  _creditCardInputController.clear();
                  _debitCashInputController.clear();
                  _creditCardTotal = 0.0;
                  _debitCashTotal = 0.0;
                  _monthlyRentController.clear();
                  _freelancerIncomeController.clear();
                  _monthsController.text = '12';
                  _yellowUmbrellaController.clear();
                  _isProfileCompleted = false;
                  _isTypeIdentified = false;
                  _userType = '직장인';
                  _decidedTax = 0.0;
                  _grossIncome = 0.0;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('특허 기술을 통해 로컬 세무 정보가 복구 불가능하게 완전 파기되었습니다.'),
                      backgroundColor: Color(0xFFFF4D4D),
                    ),
                  );
                }
              },
              child: const Text('파기', style: TextStyle(color: Color(0xFFFF4D4D), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _setUserType(String type) {
    setState(() {
      _userType = type;
      _bannerIndex = 0;
      _tipIndex = 0;
      _calculateTax();
    });
    _startBannerRotation();
    _saveProfileToDB();
    _refreshReminders(); // 유형별 시즌 알림 재예약
  }

  void _calculateTax() {
    // 세전 급여 또는 지출 목표 변경 시 세액 계산 필요 시 추후 확장 가능
  }

  void _onExpenseTargetChanged() {
    setState(() {
      _expenseTarget = double.tryParse(_savingGoalController.text.replaceAll(',', '')) ?? 0.0;
    });
    _saveProfileToDB();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.ink(context), width: 1),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('세끌',
                  style: AppTheme.serif(18, AppTheme.ink(context), weight: FontWeight.w400, spacing: -0.5)),
            ),
            const Spacer(),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, currentMode, child) {
                final isDark = currentMode == ThemeMode.dark;
                return IconButton(
                  icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: AppTheme.inkSecondary(context), size: 24),
                  onPressed: () {
                    themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
                  },
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.settings_rounded, color: AppTheme.inkSecondary(context), size: 24),
              onPressed: _openSettings,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _buildHomeContent(),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// 원 단위 표기 ("36,000,000원")
  String _toWon(double won) {
    if (won <= 0) return '0원';
    return '${_numberFormat.format(won.toInt())}원';
  }

  /// 만원 단위 표기 ("3,800만원")
  String _toWanWon(double won) {
    final man = (won / 10000).round();
    return '${_numberFormat.format(man)}만원';
  }

  /// 한국 소득세 한계세율 (2024년 기준)
  int _marginalRate(double annualIncome) {
    if (annualIncome <= 12000000) return 6;
    if (annualIncome <= 46000000) return 15;
    if (annualIncome <= 88000000) return 24;
    if (annualIncome <= 150000000) return 35;
    if (annualIncome <= 300000000) return 38;
    if (annualIncome <= 500000000) return 40;
    if (annualIncome <= 1000000000) return 42;
    return 45;
  }

  /// 소득 + 지출 통합 카드
  /// 이번 달 현황 — 수입 + 지출 통합 (에디토리얼: 카드 없이 선과 여백)
  Widget _buildStatusSection() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final now = DateTime.now();

    final incomeCtrl = _isEmployee ? _salaryController : _freelancerIncomeController;
    final monthlyIncome = double.tryParse(incomeCtrl.text.replaceAll(',', '')) ?? 0.0;

    final double baseMonthly = _grossIncome > 0 ? _grossIncome / 12 : monthlyIncome;
    InsuranceBreakdown? insurance;
    double monthlyIncomeTax = 0.0;
    if (_isEmployee && baseMonthly > 0) {
      insurance = EmployeeTaxCalculator.calculateMonthlyInsurance(baseMonthly);
      // 세후 = 4대보험 + 소득세(간이세액 추정) 차감. 부양가족 수 반영.
      monthlyIncomeTax = EmployeeTaxCalculator.estimateMonthlyIncomeTax(
        grossAnnual: baseMonthly * 12,
        dependentsIncludingSelf: 1 + _dependentCount,
      );
    }
    final double? netEstimate =
        insurance != null ? baseMonthly - insurance.total - monthlyIncomeTax : null;

    final budget = _expenseTarget;
    final totalSpent = _creditCardTotal + _debitCashTotal;
    final hasBudget = budget > 0;
    final budgetProgress = hasBudget ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    final overBudget = hasBudget && totalSpent > budget;
    final underBudget = hasBudget && totalSpent <= budget;

    final annualSalary = _grossIncome > 0 ? _grossIncome : monthlyIncome * 12;
    final deductionThreshold = annualSalary * 0.25;
    final hasThreshold = annualSalary > 0;
    final thresholdProgress = hasThreshold ? (_creditCardTotal / deductionThreshold).clamp(0.0, 1.0) : 0.0;
    final overThreshold = hasThreshold && _creditCardTotal >= deductionThreshold;
    final monthlyCardPace = deductionThreshold / 12;
    final onPace = _creditCardTotal >= monthlyCardPace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 헤더: 라벨 + 기록하기 ──
        Row(children: [
          _sectionLabel('${now.month}월 현황'),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseCalendarScreen()));
              await _loadCurrentMonthIncome();
              await _loadMonthlyExpenses();
              setState(() {});
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.chevron_right_rounded, size: 16, color: accent),
              Text('가계부', style: AppTheme.sans(13, accent, weight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),

        // ── 수입 — 금액 위, 라벨 아래 (우측 정렬) ──
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (monthlyIncome > 0)
                Text(_toWon(monthlyIncome), style: AppTheme.serif(44, ink, spacing: -1.5, height: 1.0))
              else
                Text('기록 없음', style: AppTheme.serif(30, tert, spacing: -0.5, height: 1.0)),
              const SizedBox(height: 4),
              Text(_isEmployee ? '이번 달 수령액 (세전)' : '이번 달 수입 (세전)',
                  style: AppTheme.sans(12.5, tert)),
            ],
          ),
        ),

        // ── N잡러: 근로소득 / 기타 수익 분리 (합산세율·건보료 판단 기준) ──
        if (_userType == 'N잡러' && (_laborIncome + _otherIncome) > 0) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _spendChip('근로소득', _laborIncome),
            const SizedBox(width: 8),
            _spendChip('기타 수익', _otherIncome),
          ]),
        ]
        // N잡러인데 분리 기록이 없으면 0원 칩을 항상 노출 + 나눠 기록 동선.
        else if (_userType == 'N잡러' && monthlyIncome > 0) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _spendChip('근로소득', _laborIncome),
            const SizedBox(width: 8),
            _spendChip('기타 수익', _otherIncome),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseCalendarScreen()));
                await _loadCurrentMonthIncome();
                if (mounted) setState(() {});
              },
              behavior: HitTestBehavior.opaque,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.call_split_rounded, size: 14, color: accent),
                const SizedBox(width: 6),
                Text('근로·기타로 나눠 기록하기', style: AppTheme.sans(12.5, accent, weight: FontWeight.w600)),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 14),

        // ── 예상 연봉 / 실수령 정보 or 프롬프트 ──
        if (_grossIncome > 0 && netEstimate != null && !_showSalaryInput) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('예상 연봉(세전)', style: AppTheme.sans(13, sub)),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  _grossIncomeInlineCtrl.text = _numberFormat.format(_grossIncome.toInt());
                  setState(() => _showSalaryInput = true);
                },
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.edit_outlined, size: 14, color: sub),
              ),
            ]),
            Text(_toWon(_grossIncome), style: AppTheme.sans(14, ink, weight: FontWeight.w600)),
          ]),
          const SizedBox(height: 7),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text('예상 연봉(세후)', style: AppTheme.sans(13, sub)),
              const SizedBox(width: 6),
              Text('4대보험·소득세 반영', style: AppTheme.sans(10.5, tert)),
            ]),
            Text('약 ${_toWon(netEstimate * 12)}', style: AppTheme.sans(14, accent, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
        ] else if (_isEmployee) ...[
          _buildSalaryPromptOrInput(ink, sub, accent),
          const SizedBox(height: 14),
        ],

        const SizedBox(height: 14),

        // ── 지출 — 금액 위, 라벨 아래 (우측 정렬) ──
        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_toWon(totalSpent),
                  style: AppTheme.serif(34, ink, weight: FontWeight.w700, spacing: -1.0, height: 1.0)),
              const SizedBox(height: 4),
              Text('이번 달 지출', style: AppTheme.sans(12.5, tert)),
            ],
          ),
        ),
        if (totalSpent > 0) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _spendChip('신용카드', _creditCardTotal),
            const SizedBox(width: 8),
            _spendChip('체크·현금', _debitCashTotal),
          ]),
        ],

        // ── 지출 목표 진행 + 수정 ──
        if (hasBudget && !_showExpenseInput) ...[
          const SizedBox(height: 14),
          _progressBlock(
            '지출 목표 ${_toWon(budget)}',
            '${(budgetProgress * 100).toStringAsFixed(0)}%',
            budgetProgress,
            overBudget ? AppTheme.colorDanger : accent,
            overBudget
                ? '이번 달 지출이 목표를 넘었어요. 남은 날 조금만 줄여봐요.'
                : underBudget && totalSpent > 0
                    ? '목표 대비 ${_toWon(budget - totalSpent)} 절약 중이에요.'
                    : '지출을 추가해보세요.',
            onEdit: () {
              _expenseTargetInlineCtrl.text = _numberFormat.format(_expenseTarget.toInt());
              setState(() => _showExpenseInput = true);
            },
          ),
        ],
        // ── 지출 목표 설정 프롬프트 (목표 없음) 또는 인라인 수정 ──
        if (!hasBudget || _showExpenseInput) ...[
          const SizedBox(height: 12),
          _buildExpensePromptOrInput(ink, sub, accent),
        ],

        // ── 신용카드 공제 문턱 ──
        if (hasThreshold) ...[
          const SizedBox(height: 14),
          _progressBlock(
            '신용카드 공제 문턱 (연봉의 25%)',
            overThreshold ? '돌파' : '${_toWon(deductionThreshold - _creditCardTotal)} 남음',
            thresholdProgress,
            overThreshold ? AppTheme.colorSuccess : accent,
            overThreshold
                ? '지금부터는 체크·현금이 공제율 2배(30%)예요.'
                : onPace
                    ? '월 권장 페이스(${_toWon(monthlyCardPace)}) 이상 쓰고 있어요. 연내 문턱 도달 가능.'
                    : '월 ${_toWon(monthlyCardPace)}씩 쓰면 연내 문턱을 넘겨요.',
          ),
        ],

      ],
    );
  }

  /// 예상 연봉 프롬프트 → 탭 시 인라인 입력 전환 (높이 고정)
  Widget _buildSalaryPromptOrInput(Color ink, Color sub, Color accent) {
    return _inlinePrompt(
      expanded: _showSalaryInput,
      promptText: '예상 연봉을 설정하면 절세 기준을 잡아드려요',
      hintText: '예상 연봉 입력',
      controller: _grossIncomeInlineCtrl,
      ink: ink, sub: sub, accent: accent,
      onTapBanner: () {
        _grossIncomeInlineCtrl.text =
            _grossIncome > 0 ? _numberFormat.format(_grossIncome.toInt()) : '';
        setState(() => _showSalaryInput = true);
      },
      onApply: () async {
        final val = double.tryParse(_grossIncomeInlineCtrl.text.replaceAll(',', '')) ?? 0.0;
        if (val > 0) {
          setState(() { _grossIncome = val; _showSalaryInput = false; });
          await _saveProfileToDB();
          _calculateTax();
        } else {
          setState(() => _showSalaryInput = false);
        }
      },
    );
  }

  /// 지출 목표 프롬프트 → 탭 시 인라인 입력 전환 (높이 고정)
  Widget _buildExpensePromptOrInput(Color ink, Color sub, Color accent) {
    return _inlinePrompt(
      expanded: _showExpenseInput,
      promptText: '이번 달 지출 목표액을 설정하면 공제 기준을 잡아드려요',
      hintText: '이번 달 지출 목표',
      controller: _expenseTargetInlineCtrl,
      ink: ink, sub: sub, accent: accent,
      onTapBanner: () {
        _expenseTargetInlineCtrl.text =
            _expenseTarget > 0 ? _numberFormat.format(_expenseTarget.toInt()) : '';
        setState(() => _showExpenseInput = true);
      },
      onApply: () async {
        final val = double.tryParse(_expenseTargetInlineCtrl.text.replaceAll(',', '')) ?? 0.0;
        if (val > 0) {
          setState(() {
            _expenseTarget = val;
            _savingGoalController.text = _numberFormat.format(val.toInt());
            _showExpenseInput = false;
          });
          await _saveProfileToDB();
        } else {
          setState(() => _showExpenseInput = false);
        }
      },
    );
  }

  /// 홈 인라인 프롬프트 공통 위젯 — 도면(에디토리얼) 스타일
  /// 안내 배너 ↔ 입력 행 페이드 전환, 양쪽 동일 높이로 스크롤 흔들림 방지
  Widget _inlinePrompt({
    required bool expanded,
    required String promptText,
    required String hintText,
    required TextEditingController controller,
    required VoidCallback onTapBanner,
    required Future<void> Function() onApply,
    required Color ink,
    required Color sub,
    required Color accent,
  }) {
    const h = 48.0;

    // ── 안내 배너: 표면색 + 헤어라인 + 좌측 도면 액센트 바 + 화살표 ──
    final banner = GestureDetector(
      onTap: onTapBanner,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: AppTheme.surface(context),
          border: Border.all(color: AppTheme.line(context), width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(children: [
          Container(width: 3, height: h, color: accent),
          const SizedBox(width: 12),
          Expanded(child: Text(
            promptText,
            style: AppTheme.sans(12.5, AppTheme.inkSecondary(context), weight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, color: accent, size: 15),
          const SizedBox(width: 14),
        ]),
      ),
    );

    // ── 입력 행: 헤어라인 필드 + 잉크 적용 버튼 ──
    final inputRow = SizedBox(
      height: h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              expands: true,
              maxLines: null,
              minLines: null,
              style: AppTheme.sans(14, ink, weight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTheme.sans(13.5, AppTheme.inkTertiary(context)),
                suffixText: '원',
                suffixStyle: AppTheme.sans(13, sub),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: AppTheme.surface(context),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.line(context))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: accent, width: 1.5)),
              ),
              onChanged: (v) {
                final n = v.replaceAll(RegExp(r'[^0-9]'), '');
                final f = n.isEmpty ? '' : _numberFormat.format(int.parse(n));
                controller.value = TextEditingValue(
                  text: f, selection: TextSelection.collapsed(offset: f.length));
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onApply,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(4)),
              child: Text('적용', style: AppTheme.sans(13.5, AppTheme.backgroundColor(context), weight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );

    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 220),
      crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstCurve: Curves.easeIn,
      secondCurve: Curves.easeOut,
      firstChild: banner,
      secondChild: inputRow,
    );
  }

  Widget _spendChip(String label, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line(context), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text('$label ${_toWon(amount)}', style: AppTheme.sans(12, AppTheme.inkSecondary(context), weight: FontWeight.w500)),
    );
  }

  /// 진행 막대 블록 (라벨 + 값 + 1px 트랙 + 설명)
  Widget _progressBlock(String label, String value, double progress, Color color, String note, {VoidCallback? onEdit}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: AppTheme.sans(12.5, AppTheme.inkSecondary(context), weight: FontWeight.w500)),
            if (onEdit != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                  child: Icon(Icons.edit_outlined, size: 13, color: AppTheme.inkTertiary(context)),
                ),
              ),
            ],
          ]),
          Text(value, style: AppTheme.sans(12.5, color, weight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 3,
          backgroundColor: AppTheme.line(context),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
        Text(note, style: AppTheme.sans(12, color, weight: FontWeight.w500, height: 1.4)),
      ],
    );
  }


  /// 직장인/N잡러/프리랜서별 세무 도구 카드
  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  /// 이달의 절세 — 이번 달·유형에 맞는 "득 되는 정보"(일정·2026 혜택·꿀팁).
  /// 상단 배너와 동일한 형식으로 6초 페이드 회전. 팁 없으면 빈 위젯.
  Widget _buildTaxTipsCard() {
    final now = DateTime.now();
    final tips = _currentTips();
    if (tips.isEmpty) return const SizedBox.shrink();
    final idx = _tipIndex % tips.length;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('이달의 절세 · ${now.month}월'),
        const SizedBox(height: 10),
        SizedBox(
          height: 98,
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: reduce ? 0 : 500),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey('tip$idx'),
              child: _tipCardView(tips[idx]),
            ),
          ),
        ),
        if (tips.length > 1) ...[
          const SizedBox(height: 10),
          _tipTicks(tips.length, idx),
        ],
        const SizedBox(height: 14),
        AppTheme.hairline(context),
        const SizedBox(height: 14),
      ],
    );
  }

  /// 단일 절세 팁 카드 — 상단 배너 카드와 같은 레이아웃(라벨·세리프 헤드라인·글리프 박스).
  /// action이 있으면 탭 가능(부연 줄에 화살표), 없으면 정보성.
  Widget _tipCardView(TaxTip t) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final glyph = _tipGlyph(t.label);
    final tappable = t.action != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tappable ? () => _tipNavigate(t.action!) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.label.toUpperCase(), style: AppTheme.label(context)),
                const SizedBox(height: 8),
                Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.serif(23, ink, spacing: -0.5, height: 1.2)),
                const SizedBox(height: 6),
                Row(children: [
                  Flexible(
                    child: Text(t.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.sans(12.5, sub, height: 1.4)),
                  ),
                  if (tappable) ...[
                    const SizedBox(width: 5),
                    Icon(Icons.arrow_forward, size: 13, color: sub),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.lineStrong(context), width: 1),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.center,
            child: Text(glyph, style: AppTheme.serif(glyph.length > 1 ? 22 : 30, ink, spacing: 0, height: 1.0)),
          ),
        ],
      ),
    );
  }

  /// 절세 팁 액션 키 → 화면 이동.
  void _tipNavigate(String key) {
    switch (key) {
      case 'record':
        _go(taxRecordEntryFor(_userType).build(_userType));
        break;
      case 'book':
        _go(const FreelancerBookScreen());
        break;
      case 'simulator':
      default:
        _go(TaxSimulatorScreen(userType: _userType));
    }
  }

  /// 팁 분류 라벨 → 글리프 박스 1글자.
  String _tipGlyph(String label) {
    switch (label) {
      case '2026 혜택':
        return '혜';
      case '꿀팁':
        return '팁';
      case '5월 신고':
        return '5';
      case '장려금':
        return '장';
      case '연말정산':
        return '정';
      case '소득파악':
        return '파';
      case '지급명세서':
        return '명';
      case '부가세':
        return '부';
      case '중간예납':
        return '예';
      default:
        return '세';
    }
  }

  /// 절세 팁 위치 틱 — 배너 틱과 동일 형식, 탭 시 해당 팁으로.
  Widget _tipTicks(int count, int active) {
    final ink = AppTheme.ink(context);
    return Row(
      children: List.generate(count, (i) {
        final on = i == active;
        return GestureDetector(
          onTap: () {
            setState(() => _tipIndex = i);
            _startBannerRotation();
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: on ? 18 : 10,
              height: 2,
              color: on ? ink : AppTheme.line(context),
            ),
          ),
        );
      }),
    );
  }

  /// 세무 도구 카드 — 별도 메뉴 4행:
  /// ① 기록하기(입력 토대) ② 종합소득세 신고 준비하기(핵심·강조 + 3단계 스테퍼)
  /// ③ 경정청구 준비하기(직장인·N잡러) ④ 빠르게 계산.
  Widget _buildTaxToolsCard() {
    final record = taxRecordEntryFor(_userType);
    final stages = taxPipelineFor(_userType);
    final amended = taxAmendedEntryFor(_userType);
    final quick = taxQuickCalcsFor(_userType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(taxToolsLabel()),
        const SizedBox(height: 4),
        AppTheme.hairline(context),
        // 행1 — 연말정산/사업소득 기록하기
        _taxToolRow(
          title: record.title,
          subtitle: record.subtitle,
          onTap: () => _go(record.build(_userType)),
        ),
        AppTheme.hairline(context),
        // 행2 — 종합소득세 신고 준비하기 (핵심) + 3단계 스테퍼
        if (stages.isNotEmpty) ...[
          _taxToolRow(
            title: '종합소득세 신고 준비하기',
            subtitle: _flowSubtitle(),
            badge: stages.last.badge,
            onTap: () => _go(stages.first.build(_userType)),
            emphasized: true,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 17, bottom: 18),
            child: _taxFlowStepper(),
          ),
        ],
        AppTheme.hairline(context),
        // 행3 — 경정청구 준비하기 (직장인·N잡러)
        if (amended != null) ...[
          _taxToolRow(
            title: amended.title,
            subtitle: amended.subtitle,
            onTap: () => _go(amended.build(_userType)),
          ),
          AppTheme.hairline(context),
        ],
        // 행4 — 빠르게 계산
        _quickCalcDrawer(quick),
      ],
    );
  }

  /// 종합소득세 신고 준비 진입점 서브타이틀 — 유형별 한 줄 요약.
  String _flowSubtitle() => _userType == '직장인'
      ? '연말정산 기록을 토대로 빠진 공제 찾아 5월 직접 신고'
      : _userType == 'N잡러'
          ? '근로+사업 합산으로 5월 종합소득세 신고'
          : '사업소득 5월 종합소득세 신고';

  /// 3단계 미니 스테퍼 — 신고 준비 흐름(진단 → 신고서 → 가이드)을
  /// 카드에서 한눈에 보여준다. 1단계만 accent로 현재 시작점 표시.
  Widget _taxFlowStepper() {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    const labels = ['진단', '신고서', '가이드'];
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 1,
                color: AppTheme.line(context),
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: i == 0 ? accent : tert, width: 1.2),
              ),
              child: Text('${i + 1}',
                  style: AppTheme.sans(10, i == 0 ? accent : sub, weight: FontWeight.w700)),
            ),
            const SizedBox(width: 5),
            Text(labels[i],
                style: AppTheme.sans(11.5, i == 0 ? ink : sub, weight: FontWeight.w600)),
          ]),
        ],
      ],
    );
  }

  /// '빠르게 계산' 공구 서랍 — 접힘 시 내용 미리보기, 펼치면 좌측 룰로 묶인
  /// 계산기 목록(각 행 → 화면). FAQ 드롭다운과 같은 패턴.
  Widget _quickCalcDrawer(List<TaxItem> quick) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    final preview = quick.map((c) => c.title.split(' ').first).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _calcDrawerOpen = !_calcDrawerOpen),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('빠르게 계산', style: AppTheme.sans(16, ink, weight: FontWeight.w700, spacing: -0.2)),
                      const SizedBox(height: 5),
                      Text(preview,
                          style: AppTheme.sans(13, sub, height: 1.45),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _calcDrawerOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(Icons.expand_more_rounded, color: _calcDrawerOpen ? accent : tert, size: 22),
                ),
              ],
            ),
          ),
        ),
        // 서랍 펼침 — 좌측 세로 룰이 도구들을 묶는다(서랍 모서리)
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _calcDrawerOpen
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(left: BorderSide(color: AppTheme.lineStrong(context), width: 1.4)),
                    ),
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      children: [
                        for (int i = 0; i < quick.length; i++) ...[
                          if (i > 0) AppTheme.hairline(context),
                          _drawerCalcRow(quick[i]),
                        ],
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _drawerCalcRow(TaxItem c) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    return GestureDetector(
      onTap: () => _go(c.build(_userType)),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: AppTheme.sans(15, ink, weight: FontWeight.w700, spacing: -0.2)),
                  const SizedBox(height: 3),
                  Text(c.subtitle, style: AppTheme.sans(12.5, sub, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: tert, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _taxToolRow({
    required String title,
    required String subtitle,
    String? badge,
    required VoidCallback onTap,
    bool emphasized = false,
    bool chevronOnly = false,
  }) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (emphasized) ...[
              Container(width: 3, height: 38, color: accent),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(title,
                          style: AppTheme.sans(emphasized ? 17 : (chevronOnly ? 15 : 16), ink,
                              weight: chevronOnly ? FontWeight.w600 : FontWeight.w700, spacing: -0.2)),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      AppTheme.blueprintBadge(context, badge),
                    ],
                  ]),
                  if (!chevronOnly) ...[
                    const SizedBox(height: 5),
                    Text(subtitle, style: AppTheme.sans(13, sub, height: 1.45)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: tert, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTypeSelector(),
          const SizedBox(height: 10),
          AppTheme.hairline(context),
          const SizedBox(height: 12),
          _buildRotatingBanner(),
          const SizedBox(height: 12),
          AppTheme.hairline(context),
          const SizedBox(height: 12),
          _buildStatusSection(),
          const SizedBox(height: 12),
          AppTheme.hairline(context),
          const SizedBox(height: 12),
          // 지출 카드와 절세 카드 사이 — 사용자 맞춤 리마인더(핵심 기능).
          ReminderCard(userType: _userType),
          const SizedBox(height: 12),
          AppTheme.hairline(context),
          const SizedBox(height: 12),
          _buildTaxTipsCard(),
          _buildTaxToolsCard(),
          const SizedBox(height: 12),
          AppTheme.hairline(context),
          const SizedBox(height: 8),
          _buildFaqCard(),
        ],
      ),
    );
  }

  /// 도면 주석 라벨 — 극소형 + 자간 극대 (섹션 머리표)
  Widget _sectionLabel(String text) =>
      Text(text.toUpperCase(), style: AppTheme.label(context));


  /// 월 기준 계절 배너 콘텐츠 — 라벨/헤드라인/액션/글리프를 시즌별로 분기.
  ({String label, String headline, String action, String glyph}) _seasonalBanner() {
    final m = DateTime.now().month;
    if (m >= 1 && m <= 3) {
      // 연초: 연말정산 결과·경정청구
      return (
        label: '연말정산 시즌',
        headline: '올해 연말정산,\n돌려받을 게 더 있을까?',
        action: '내 절세 유형 찾기',
        glyph: '결',
      );
    } else if (m == 4 || m == 5) {
      // 종합소득세 신고철
      return (
        label: '종합소득세 신고',
        headline: '5월 종합소득세,\n나도 환급 대상일까?',
        action: '내 절세 유형 찾기',
        glyph: '신',
      );
    } else {
      // 평시: 절세 준비
      return (
        label: '절세 준비',
        headline: '미리 챙기는 공제,\n내년 환급을 바꿔요',
        action: '내 절세 유형 찾기',
        glyph: 'S',
      );
    }
  }

  /// 절세 유형 찾기(페르소나 질문) 진입 — 결과로 유형 변경 시 반영.
  Future<void> _openPersona() async {
    final newUserType = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TaxPersonaQuestionScreen(initialUserType: _userType)),
    );
    if (newUserType != null && newUserType is String && newUserType != _userType) {
      _setUserType(newUserType);
    }
  }

  /// 유형 파악 온보딩 진입 — 결과로 user_type + type_identified 저장.
  Future<void> _openOnboarding() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OnboardingScreen(returnResult: true)),
    );
    if (result is String && mounted) {
      setState(() {
        _userType = result;
        _isTypeIdentified = true;
        _bannerIndex = 0;
      });
      await _saveProfileToDB();
      _startBannerRotation();
    }
  }

  /// 프로필 작성 진입 — 완료 시 홈 데이터 재동기화.
  Future<void> _openProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileInputScreen(userType: _userType)),
    );
    if (result == true && mounted) {
      setState(() {
        _isProfileCompleted = true;
        _bannerIndex = 0;
      });
      _loadDataFromDB();
    }
  }

  /// 유형별 회전 배너 카드 세트 — 온보딩 단계에 따라 4가지 상태 분기.
  ///
  /// A: 유형 미파악 → [유형 파악 카드] 단 1장
  /// B: 유형 OK + 프로필 미완성 → [프로필 작성] + [유형 소개]
  /// C: 완료 + 소득 미설정 → [연봉 설정 촉구] + 유형별 도구 + 시즌
  /// D: 완료 + 소득 설정됨 → [개인화 데이터 카드] + 유형별 도구 + 시즌
  List<_BannerCard> _bannerCards() {
    final s = _seasonalBanner();

    // ── 상태 A: 유형 미파악 (완전 신규) ──
    if (!_isTypeIdentified) {
      return [
        _BannerCard(
          label: '시작',
          headline: '내가 어떤 납세자인지\n먼저 확인해봐요',
          action: '유형 파악하기',
          glyph: '유',
          onTap: _openOnboarding,
        ),
      ];
    }

    // ── 상태 B: 유형 파악 완료, 프로필 미완성 ──
    if (!_isProfileCompleted) {
      final typeIntro = _userType == '직장인'
          ? '연말정산에서\n놓친 공제가 있을 수 있어요'
          : _userType == 'N잡러'
              ? '합산 소득세율이\n예상보다 높을 수 있어요'
              : '3.3% 원천징수 후에도\n5월 신고가 따로 필요해요';
      final typeGlyph = _userType == '직장인' ? '결' : _userType == 'N잡러' ? '합' : '신';
      return [
        _BannerCard(
          label: '프로필',
          headline: '$_userType 절세 기준을\n잡으려면 프로필이 필요해요',
          action: '기초 프로필 작성',
          glyph: '1',
          onTap: _openProfile,
        ),
        _BannerCard(
          label: _userType,
          headline: typeIntro,
          action: '자세히 보기',
          glyph: typeGlyph,
          onTap: () => _go(TaxSimulatorScreen(userType: _userType)),
        ),
      ];
    }

    final cards = <_BannerCard>[];

    // ── 상태 C: 완료 + 소득 미설정 ──
    if (_grossIncome == 0) {
      cards.add(_BannerCard(
        label: '다음 단계',
        headline: '예상 연봉을 입력하면\n공제 기준이 잡혀요',
        action: '연봉 설정하기',
        glyph: '₩',
        onTap: () => setState(() => _showSalaryInput = true),
      ));
    } else {
      // ── 상태 D: 완료 + 소득 설정됨 — 개인화 카드 ──
      if (_userType == '직장인') {
        final remaining = _grossIncome * 0.25 - _creditCardTotal;
        cards.add(remaining > 0
            ? _BannerCard(
                label: '신카 공제',
                headline: '공제 문턱까지\n${_toWanWon(remaining)} 남았어요',
                action: '신용카드 공제 확인',
                glyph: '카',
                onTap: () => _go(YearEndTaxScreen(userType: _userType)),
              )
            : _BannerCard(
                label: '신카 공제',
                headline: '공제 문턱 돌파!\n체크카드로 2배 공제예요',
                action: '연말정산 진단',
                glyph: '↑',
                onTap: () => _go(YearEndTaxScreen(userType: _userType)),
              ));
      } else if (_userType == 'N잡러') {
        final rate = _marginalRate(_grossIncome);
        cards.add(_BannerCard(
          label: 'N잡 세율',
          headline: '직장 소득 기준\n한계세율 $rate% 구간이에요',
          action: '합산소득세 확인',
          glyph: '율',
          onTap: () => _go(TaxSimulatorScreen(userType: _userType)),
        ));
      } else {
        cards.add(_BannerCard(
          label: '5월 신고',
          headline: '연 ${_toWanWon(_grossIncome)} 기준\n종합소득세 신고 대상이에요',
          action: '종합소득세 계산',
          glyph: '신',
          onTap: () => _go(TaxSimulatorScreen(userType: _userType)),
        ));
      }
    }

    // 유형별 도구 카드
    if (_userType == '직장인') {
      cards.addAll([
        _BannerCard(label: '종합소득세', headline: '회사에 안 알리고\n5월에 직접 환급받기', action: '5월 신고 시작', glyph: '소', onTap: () => _go(taxRecordEntryFor(_userType).build(_userType))),
        _BannerCard(label: '경정청구', headline: '작년에 놓친 공제도\n5년 안엔 돌려받아요', action: '환급액 계산하기', glyph: '환', onTap: () => _go(TaxSimulatorScreen(userType: _userType))),
      ]);
    } else if (_userType == 'N잡러') {
      cards.addAll([
        _BannerCard(label: 'N잡 합산', headline: '근로+부업 합치면\n세율이 올라가요', action: '합산소득세 보기', glyph: '합', onTap: () => _go(TaxSimulatorScreen(userType: _userType))),
        _BannerCard(label: '건강보험', headline: '부업 2,000만 넘으면\n건보료가 따라와요', action: '기준 확인하기', glyph: '보', onTap: () => _go(const FinancialIncomeScreen())),
      ]);
    } else {
      cards.addAll([
        _BannerCard(label: '경비율', headline: '장부를 쓰면 경비\n인정 폭이 넓어져요', action: '간편장부 열기', glyph: '장', onTap: () => _go(const FreelancerBookScreen())),
      ]);
    }

    cards.add(_BannerCard(
      label: s.label, headline: s.headline, action: s.action, glyph: s.glyph, onTap: _openPersona,
    ));
    return cards;
  }

  /// 상단 회전 배너 — 6초마다 페이드 전환, 하단에 위치 틱.
  Widget _buildRotatingBanner() {
    final cards = _bannerCards();
    if (cards.isEmpty) return const SizedBox.shrink();
    final idx = _bannerIndex % cards.length;
    final reduce = MediaQuery.of(context).disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 84,
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: reduce ? 0 : 500),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey(idx),
              child: _bannerCardView(cards[idx]),
            ),
          ),
        ),
        if (cards.length > 1) ...[
          const SizedBox(height: 12),
          _bannerTicks(cards.length, idx),
        ],
      ],
    );
  }

  /// 단일 배너 카드 — 라벨 + 세리프 헤드라인 + 액션 + 글리프 박스.
  /// 색상은 유형 무관 기본 ink/sub 사용 — accent 블루 없음.
  Widget _bannerCardView(_BannerCard c) {
    final ink = AppTheme.ink(context);
    // 페이드 회전 카드 — 라벨 + 헤드라인만(액션 줄 제거). 카드 전체가 탭 영역.
    // 가로 꽉 채워 좌측 정렬(AnimatedSwitcher의 가운데 정렬 방지).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: c.onTap,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.label.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 8),
            Text(c.headline, style: AppTheme.serif(24, ink, spacing: -0.5, height: 1.22)),
          ],
        ),
      ),
    );
  }

  /// 배너 위치 틱 — 현재 카드는 ink 긴 막대, 나머지는 헤어라인. 탭하면 이동.
  Widget _bannerTicks(int count, int active) {
    final ink = AppTheme.ink(context);
    return Row(
      children: List.generate(count, (i) {
        final on = i == active;
        return GestureDetector(
          onTap: () {
            setState(() => _bannerIndex = i);
            _startBannerRotation();
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: on ? 18 : 10,
              height: 2,
              color: on ? ink : AppTheme.line(context),
            ),
          ),
        );
      }),
    );
  }

  /// 유형 선택 — 텍스트 탭(선택 시 굵게 + 하단 라인) + 프로필 링크
  Widget _buildTypeSelector() {
    final ink = AppTheme.ink(context);
    final tert = AppTheme.inkTertiary(context);
    final accent = AppTheme.accentColor(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ...['직장인', 'N잡러', '프리랜서'].map((type) {
          final selected = _userType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: GestureDetector(
              onTap: () => _setUserType(type),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(type, style: AppTheme.sans(16, selected ? ink : tert, weight: selected ? FontWeight.w700 : FontWeight.w500, spacing: -0.2)),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 2,
                    width: selected ? 20 : 0,
                    color: ink,
                  ),
                ],
              ),
            ),
          );
        }),
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileInputScreen(userType: _userType)));
            if (result == true) {
              setState(() => _isProfileCompleted = true);
              _loadDataFromDB();
            }
          },
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_isProfileCompleted ? Icons.check_circle_outline : Icons.add, size: 15, color: accent),
            const SizedBox(width: 5),
            Text(_isProfileCompleted ? '프로필 수정' : '프로필 작성', style: AppTheme.sans(13, accent, weight: FontWeight.w600)),
          ]),
        ),
      ],
    );
  }

  /// FAQ 카드 (최하단)
  Widget _buildFaqCard() {
    final List<Map<String, String>> faqs;

    if (_userType == '직장인') {
      faqs = [
        {'q': '연말정산에서 놓친 공제, 5월에 다시 받을 수 있나요?', 'a': '네, 가능합니다. 5월 종합소득세 신고(경정청구)를 통해 연말정산에서 누락된 공제를 추가로 신청할 수 있습니다. 최대 5년 이내의 공제까지 소급 신청 가능합니다.'},
        {'q': '회사에 알리기 싫은 의료비, 따로 공제받는 방법은?', 'a': '연말정산 때 해당 항목을 빼고, 5월에 개인적으로 종합소득세 신고를 하면 됩니다. 홈택스에서 직접 신고하면 회사에는 해당 내역이 전달되지 않습니다.'},
        {'q': '언제부터 체크카드를 써야 유리한가요?', 'a': '총급여의 25%를 신용카드로 채운 뒤, 그 이후부터는 체크카드·현금을 사용하는 것이 유리합니다. 체크카드는 공제율이 30%로 신용카드(15%)의 두 배입니다.'},
        {'q': '중도 퇴사자 연말정산은 어떻게 하나요?', 'a': '퇴사 시 회사에서 기본 연말정산을 해줍니다. 이후 다른 회사에 입사하면 전 직장 원천징수영수증을 제출하고, 미취업 상태라면 다음 해 5월에 직접 종합소득세를 신고합니다.'},
        {'q': '부양가족 공제, 형제자매도 가능한가요?', 'a': '가능합니다. 만 20세 이하 또는 만 60세 이상의 형제자매가 연 소득 100만원 이하이고 다른 가족이 공제받지 않는 경우, 기본공제 대상에 포함됩니다.'},
      ];
    } else if (_userType == '프리랜서') {
      faqs = [
        {'q': '3.3% 떼고 받았는데 5월에 세금을 또 내야 하나요?', 'a': '3.3%는 원천징수(미리 떼는 세금)일 뿐, 실제 세금과 다를 수 있습니다. 5월 종소세 신고 시 실제 세액을 계산하여, 더 냈으면 환급받고 덜 냈으면 추가 납부합니다.'},
        {'q': '단순경비율과 기준경비율, 어떤 게 유리한가요?', 'a': '일반적으로 수입이 적으면 단순경비율이, 수입이 많으면 간편장부가 유리합니다. 기준경비율은 주요경비를 증빙해야 하므로, 증빙 서류가 부족하면 불리할 수 있습니다.'},
        {'q': '식대, 교통비도 경비로 인정받을 수 있나요?', 'a': '업무와 직접 관련된 식대·교통비는 경비로 인정됩니다. 다만 간편장부나 복식부기로 신고하는 경우에만 개별 경비로 반영 가능하며, 추계신고(경비율) 시에는 이미 경비율에 포함되어 있습니다.'},
        {'q': '종소세 신고를 안 하면 가산세가 얼마나 붙나요?', 'a': '무신고 가산세 20%, 납부지연 가산세 연 8.03%가 부과됩니다. 부정 무신고의 경우 40%까지 올라갑니다. 환급 대상인데도 신고하지 않으면 환급을 받지 못합니다.'},
        {'q': '프리랜서도 부가세 신고를 해야 하나요?', 'a': '인적용역(프리랜서)은 부가가치세 면세 대상입니다. 별도의 부가세 신고가 필요 없습니다. 단, 사업자등록을 내고 물건을 판매하는 경우에는 부가세 신고가 필요합니다.'},
      ];
    } else {
      faqs = [
        {'q': '부업 수입이 생기면 회사에 자동으로 통보되나요?', 'a': '소득 자체가 통보되지는 않지만, 부업 소득으로 건강보험료가 오르면 회사에 간접적으로 알려질 수 있습니다. 종소세 신고 시 건보료 납부 방법을 "개인별 고지"로 선택하면 이를 방지할 수 있습니다.'},
        {'q': '직장 연말정산 끝냈는데 5월 종소세도 해야 하나요?', 'a': '네, 반드시 해야 합니다. 직장 외 소득(부업 등)이 있으면 모든 소득을 합산하여 5월에 종합소득세를 신고해야 합니다. 이때 연말정산에서 이미 낸 세금은 기납부세액으로 차감됩니다.'},
        {'q': '신용카드 공제와 부업 경비를 중복 처리할 수 있나요?', 'a': '불가능합니다. 하나의 지출은 근로소득 카드공제 또는 사업소득 필요경비 중 하나로만 적용해야 합니다. 업무용 지출은 경비로, 개인 소비는 카드공제로 분리하는 것이 유리합니다.'},
        {'q': '부업 수입 얼마부터 건보료가 오르나요?', 'a': '직장가입자의 경우, 근로 외 소득(이자·배당·사업·기타소득 합산)이 연 2,000만원을 초과하면 초과분에 대해 건강보험료가 추가 부과됩니다.'},
        {'q': '사업자등록 없이 프리랜서 소득 신고가 되나요?', 'a': '가능합니다. 사업자등록 없이도 종합소득세 신고 시 사업소득(프리랜서 소득)으로 신고할 수 있습니다. 다만 연 매출이 일정 규모 이상이면 사업자등록 의무가 생길 수 있습니다.'},
      ];
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        iconColor: AppTheme.inkTertiary(context),
        collapsedIconColor: AppTheme.inkTertiary(context),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 16),
        title: Text('자주 묻는 질문', style: AppTheme.sans(15, AppTheme.ink(context), weight: FontWeight.w700, spacing: -0.2)),
        children: faqs.map((faq) => _buildFaqItem(faq['q']!, faq['a']!)).toList(),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        iconColor: AppTheme.inkTertiary(context),
        collapsedIconColor: AppTheme.inkTertiary(context),
        title: Text('Q. $question', style: AppTheme.sans(13, AppTheme.ink(context), weight: FontWeight.w600, height: 1.4)),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: AppTheme.accentColor(context), width: 2)),
            ),
            child: Text(answer, style: AppTheme.sans(13, AppTheme.inkSecondary(context), height: 1.55)),
          ),
        ],
      ),
    );
  }

  /// 하단 탭 라우팅 — 홈은 베이스, 나머지는 해당 화면으로 진입 후 복귀 시 동기화.
  Future<void> _onNavTap(int index) async {
    if (index == 0) {
      setState(() => _currentIndex = 0);
      return;
    }
    switch (index) {
      case 1: // 소득
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ExpenseCalendarScreen(initialFocus: 'income')));
        break;
      case 2: // 지출
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const ExpenseCalendarScreen(initialFocus: 'expense')));
        break;
      case 3: // 세무
        await Navigator.push(context, MaterialPageRoute(
            builder: (_) => TaxToolsScreen(userType: _userType)));
        break;
      case 4: // 내정보
        final result = await Navigator.push(context, MaterialPageRoute(
            builder: (_) => ProfileInputScreen(userType: _userType)));
        if (result == true && mounted) setState(() => _isProfileCompleted = true);
        break;
    }
    // 가계부·프로필에서 돌아오면 홈 데이터 재동기화
    await _loadDataFromDB();
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.line(context), width: 1)),
      ),
      child: BottomNavigationBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: _onNavTap,
        selectedItemColor: AppTheme.ink(context),
        unselectedItemColor: AppTheme.inkTertiary(context),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.square_outlined, size: 20), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.north_east_rounded, size: 20), label: '소득'),
          BottomNavigationBarItem(icon: Icon(Icons.south_east_rounded, size: 20), label: '지출'),
          BottomNavigationBarItem(icon: Icon(Icons.change_history_outlined, size: 20), label: '세무'),
          BottomNavigationBarItem(icon: Icon(Icons.circle_outlined, size: 20), label: '내정보'),
        ],
      ),
    );
  }
}

/// 홈 상단 회전 배너의 단일 카드 모델 (광고·알림·안내).
class _BannerCard {
  final String label;
  final String headline;
  final String action;
  final String glyph;
  final VoidCallback onTap;

  const _BannerCard({
    required this.label,
    required this.headline,
    required this.action,
    required this.glyph,
    required this.onTap,
  });

  /// 닫기 영구 저장용 안정 키 — 라벨+헤드라인 기반.
  String get id => '$label::$headline';
}
