import 'package:flutter/material.dart';
import '../../core/data/app_mode.dart';
import '../../core/data/db_helper.dart';

/// 데이터 수집 방식(제1모드/제2모드) 선택 화면
/// 특허: 데이터 수집부(110)의 투트랙 인터페이스 — 사용자 세무 프로필 설정부(113)에 의해 활성화
class DataModeScreen extends StatefulWidget {
  const DataModeScreen({super.key});

  @override
  State<DataModeScreen> createState() => _DataModeScreenState();
}

class _DataModeScreenState extends State<DataModeScreen> {
  AppMode _selected = appModeNotifier.value;

  Future<void> _persist(AppMode mode) async {
    // 기존 프로필을 읽어 data_mode만 갱신 후 저장 (없으면 기본 프로필 생성)
    final existing = await dbService.getProfile() ?? <String, dynamic>{};
    final merged = Map<String, dynamic>.from(existing);
    merged['data_mode'] = mode.dbValue;
    merged['user_type'] = existing['user_type'] ?? '직장인';
    await dbService.saveProfile(merged);
    appModeNotifier.value = mode;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('데이터 수집 방식', style: TextStyle(color: textColor, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(
                '카드·소득 데이터를 어떻게 모을지 선택해요.\n언제든 바꿀 수 있어요.',
                style: TextStyle(color: subColor, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              _buildModeCard(AppMode.manual),
              const SizedBox(height: 16),
              _buildModeCard(AppMode.linked),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(AppMode mode) {
    final textColor = Theme.of(context).textTheme.bodyLarge!.color!;
    final subColor = Theme.of(context).textTheme.labelMedium!.color!;
    final primary = Theme.of(context).primaryColor;
    final isSelected = _selected == mode;

    return GestureDetector(
      onTap: () async {
        setState(() => _selected = mode);
        await _persist(mode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${mode.emoji} ${mode.label} 모드로 전환했어요.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.12) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? primary : Colors.transparent, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(mode.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Text(mode.label, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (isSelected) Icon(Icons.check_circle_rounded, color: primary, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Text(mode.description, style: TextStyle(color: subColor, fontSize: 14, height: 1.5)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                mode.patentRef,
                style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
