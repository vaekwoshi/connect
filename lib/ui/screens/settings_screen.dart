import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../core/data/app_mode.dart';
import 'data_mode_screen.dart';

/// 설정 — 구 설정 바텀시트를 풀스크린으로 승격.
/// 알림 토글·데이터 파기는 홈 상태와 연동되어야 하므로 콜백으로 위임.
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
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: sub),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          children: [
            Text('설정', style: AppTheme.serif(28, ink, spacing: -0.5)),
            const SizedBox(height: 24),
            AppTheme.hairline(context),
            _row(
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
            ),
            AppTheme.hairline(context),
            ValueListenableBuilder<AppMode>(
              valueListenable: appModeNotifier,
              builder: (context, mode, _) => _row(
                icon: mode.isLinked ? Icons.sync_rounded : Icons.edit_note_rounded,
                title: '데이터 수집 방식',
                subtitle: '현재: ${mode.label} · 탭하여 변경',
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const DataModeScreen())),
              ),
            ),
            AppTheme.hairline(context),
            _row(
              icon: Icons.delete_outline_rounded,
              title: '개인 세무 데이터 영구 파기',
              subtitle: '기기에 저장된 모든 데이터를 복구 불가능하게 파기',
              danger: true,
              onTap: () {
                Navigator.pop(context);
                widget.onDestroyData();
              },
            ),
            AppTheme.hairline(context),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
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
              Text(title, style: AppTheme.sans(15, titleColor, weight: FontWeight.w700, spacing: -0.2)),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTheme.sans(12.5, sub, height: 1.4)),
            ]),
          ),
          if (trailing != null) trailing
          else if (!danger) Icon(Icons.chevron_right_rounded, size: 20, color: tert),
        ]),
      ),
    );
  }
}
