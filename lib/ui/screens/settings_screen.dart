import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../../core/data/app_mode.dart';
import '../../core/data/backup_service.dart';
import '../../main.dart';
import 'data_mode_screen.dart';

/// 설정 — 홈 우상단 톱니에서 진입.
/// 알림 · 다크모드 · 데이터 수집방식 · 백업/복원 · 개인정보처리방침 · 파기 · 버전.
class SettingsScreen extends StatefulWidget {
  final bool notificationsEnabled;
  final Future<void> Function(bool) onNotificationsChanged;
  final VoidCallback onDestroyData;

  const SettingsScreen({
    super.key,
    required this.notificationsEnabled,
    required this.onNotificationsChanged,
    required this.onDestroyData,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notificationsEnabled = widget.notificationsEnabled;

  @override
  void didUpdateWidget(SettingsScreen old) {
    super.didUpdateWidget(old);
    if (old.notificationsEnabled != widget.notificationsEnabled) {
      setState(() => _notificationsEnabled = widget.notificationsEnabled);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _exportBackup() async {
    final r = await backupService.exportToFile();
    switch (r) {
      case BackupResult.success:
        _snack('백업 파일을 저장했어요. 안전한 곳에 보관하세요.');
      case BackupResult.cancelled:
        break;
      default:
        _snack('백업에 실패했어요. 다시 시도해주세요.');
    }
  }

  Future<void> _importBackup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('백업에서 복원할까요?',
            style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: Text('지금 기기에 있는 데이터는 백업 내용으로 덮어써져요.',
            style: AppTheme.sans(14, AppTheme.inkSecondary(ctx), height: 1.45)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('취소', style: AppTheme.sans(14, AppTheme.inkSecondary(ctx)))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('복원',
                  style: AppTheme.sans(14, AppTheme.accentColor(ctx), weight: FontWeight.w700))),
        ],
      ),
    );
    if (ok != true) return;
    final r = await backupService.importFromFile();
    switch (r) {
      case BackupResult.success:
        _snack('복원했어요. 앱을 완전히 종료한 뒤 다시 열면 모두 반영돼요.');
      case BackupResult.cancelled:
        break;
      case BackupResult.invalidFile:
        _snack('세끌 백업 파일이 아니에요. 파일을 확인해주세요.');
      default:
        _snack('복원에 실패했어요. 파일이 손상됐을 수 있어요.');
    }
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('개인정보처리방침',
            style: AppTheme.sans(15, AppTheme.ink(ctx), weight: FontWeight.w700)),
        content: Text(
          '세끌은 제1모드(완전 오프라인)로 운영됩니다.\n\n'
          '모든 납세자 정보·가계부·리마인더 데이터는 이 기기의 저장소에만 보관되며, '
          '외부 서버 전송·제3자 제공·광고 추적이 전혀 없습니다.\n\n'
          '데이터는 "개인 세무 데이터 영구 파기"로 언제든 완전히 삭제할 수 있습니다.',
          style: AppTheme.sans(13, AppTheme.inkSecondary(ctx), height: 1.55),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('닫기',
                  style: AppTheme.sans(14, AppTheme.accentColor(ctx), weight: FontWeight.w700))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('설정', style: AppTheme.serif(22, ink, weight: FontWeight.w400, spacing: -0.3)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            const SizedBox(height: 8),
            Text('일반'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            AppTheme.hairline(context),
            _notifRow(),
            AppTheme.hairline(context),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) {
                final isDark = mode == ThemeMode.dark;
                return _row(
                  icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  title: '다크 모드',
                  subtitle: isDark ? '어두운 화면 켜짐' : '밝은 화면 켜짐',
                  trailing: Switch(
                    value: isDark,
                    activeColor: AppTheme.accentColor(context),
                    onChanged: (v) {
                      themeNotifier.value = v ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                  onTap: () {
                    themeNotifier.value =
                        themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
                  },
                );
              },
            ),
            AppTheme.hairline(context),
            ValueListenableBuilder<AppMode>(
              valueListenable: appModeNotifier,
              builder: (context, mode, _) => _row(
                icon: mode.isLinked ? Icons.sync_rounded : Icons.edit_note_rounded,
                title: '데이터 수집 방식',
                subtitle: '현재: ${mode.label} · 탭하여 변경',
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const DataModeScreen())),
              ),
            ),
            AppTheme.hairline(context),
            if (!kIsWeb) ...[
              const SizedBox(height: 24),
              Text('데이터'.toUpperCase(), style: AppTheme.label(context)),
              const SizedBox(height: 6),
              AppTheme.hairline(context),
              _row(
                icon: Icons.ios_share_rounded,
                title: '데이터 백업 (내보내기)',
                subtitle: '모든 데이터를 파일 하나로 저장 — 기기 변경·재설치 대비',
                onTap: _exportBackup,
              ),
              AppTheme.hairline(context),
              _row(
                icon: Icons.settings_backup_restore_rounded,
                title: '데이터 복원 (가져오기)',
                subtitle: '백업 파일에서 되돌리기 — 지금 데이터는 덮어써져요',
                onTap: _importBackup,
              ),
              AppTheme.hairline(context),
            ],
            const SizedBox(height: 24),
            Text('법적 고지'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            AppTheme.hairline(context),
            _row(
              icon: Icons.privacy_tip_outlined,
              title: '개인정보처리방침',
              subtitle: '제1모드: 완전 오프라인 · 수집·전송 없음',
              onTap: _showPrivacyPolicy,
            ),
            AppTheme.hairline(context),
            _row(
              icon: Icons.delete_outline_rounded,
              title: '개인 세무 데이터 영구 파기',
              subtitle: '기기에 저장된 모든 데이터를 복구 불가능하게 파기',
              danger: true,
              onTap: widget.onDestroyData,
            ),
            AppTheme.hairline(context),
            const SizedBox(height: 24),
            Text('앱 정보'.toUpperCase(), style: AppTheme.label(context)),
            const SizedBox(height: 6),
            AppTheme.hairline(context),
            _row(
              icon: Icons.info_outline_rounded,
              title: '앱 버전',
              subtitle: '세끌 1.0.0 (1)',
              onTap: () {},
              noChevron: true,
            ),
            AppTheme.hairline(context),
          ],
        ),
      ),
    );
  }

  Widget _notifRow() {
    return _row(
      icon: _notificationsEnabled
          ? Icons.notifications_active_outlined
          : Icons.notifications_off_outlined,
      title: '세금·가계부 알림',
      subtitle: _notificationsEnabled
          ? '시즌 신고일·월 기록 넛지·공제 문턱 알림 켜짐'
          : '알림이 꺼져 있어요',
      trailing: Switch(
        value: _notificationsEnabled,
        activeColor: AppTheme.accentColor(context),
        onChanged: (v) async {
          setState(() => _notificationsEnabled = v);
          await widget.onNotificationsChanged(v);
        },
      ),
      onTap: () async {
        final v = !_notificationsEnabled;
        setState(() => _notificationsEnabled = v);
        await widget.onNotificationsChanged(v);
      },
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
    bool noChevron = false,
    Widget? trailing,
  }) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final tert = AppTheme.inkTertiary(context);
    final titleColor = danger ? AppTheme.colorDanger : ink;
    final iconColor = danger ? AppTheme.colorDanger : sub;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: AppTheme.sans(15, titleColor, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTheme.sans(12, sub, height: 1.4)),
            ]),
          ),
          if (trailing != null)
            trailing
          else if (!danger && !noChevron)
            Icon(Icons.chevron_right_rounded, size: 20, color: tert),
        ]),
      ),
    );
  }
}
