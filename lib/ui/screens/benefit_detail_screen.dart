import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class BenefitDetailScreen extends StatelessWidget {
  final String name;
  final String amount;
  final String desc;
  final WidgetBuilder? calcBuilder;
  final List<(String, String)>? links;
  final WidgetBuilder? eligibilityBuilder;

  const BenefitDetailScreen({
    super.key,
    required this.name,
    required this.amount,
    required this.desc,
    this.calcBuilder,
    this.links,
    this.eligibilityBuilder,
  });

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = AppTheme.ink(context);
    final sub = AppTheme.inkSecondary(context);
    final accent = AppTheme.accentColor(context);
    final line = AppTheme.line(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: ink),
        title: Text(name,
            style: AppTheme.serif(16, ink,
                weight: FontWeight.w400, spacing: -0.3)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                style: AppTheme.sans(22, ink, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(amount,
                style: AppTheme.sans(14, accent, weight: FontWeight.w600)),
            if (eligibilityBuilder != null) ...[
              const SizedBox(height: 12),
              Builder(builder: eligibilityBuilder!),
            ],
            const SizedBox(height: 20),
            Divider(height: 1, thickness: 1, color: line),
            const SizedBox(height: 20),
            Text(desc, style: AppTheme.sans(14, sub, height: 1.7)),
            const SizedBox(height: 36),
            if (calcBuilder != null) ...[
              _btn(
                context,
                label: '계산해보기',
                color: ink,
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: calcBuilder!)),
              ),
              const SizedBox(height: 12),
            ],
            if (links != null && links!.isNotEmpty) ...[
              Text('관련 공식 사이트',
                  style: AppTheme.sans(12, sub, weight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final (label, url) in links!) ...[
                _btn(context,
                    label: label,
                    color: accent,
                    onTap: () => _openUrl(url)),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext context,
      {required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.line(context)),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: AppTheme.sans(14, color, weight: FontWeight.w600)),
      ),
    );
  }
}
