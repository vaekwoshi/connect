import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _TaxForm {
  final String name;
  final String desc;
  final List<String> targets;
  final String? assetPath; // null = 준비 중

  const _TaxForm({
    required this.name,
    required this.desc,
    required this.targets,
    this.assetPath, // ignore: unused_element_parameter
  });
}

const _allForms = [
  _TaxForm(
    name: '근로소득 원천징수영수증',
    desc: '연간 근로소득·공제·세액 확인서. 연말정산·5월 신고 모두 사용',
    targets: ['직장인', 'N잡러'],
  ),
  _TaxForm(
    name: '소득·세액공제신고서',
    desc: '연말정산 공제항목 신고. 연금·보험·카드·부양가족 등 기재',
    targets: ['직장인'],
  ),
  _TaxForm(
    name: '의료비지급명세서',
    desc: '연말정산 의료비 공제 근거 서류',
    targets: ['직장인'],
  ),
  _TaxForm(
    name: '기부금명세서',
    desc: '법정·지정기부금 세액공제 근거 서류',
    targets: ['직장인', 'N잡러', '프리랜서'],
  ),
  _TaxForm(
    name: '월세 세액공제 신청서',
    desc: '무주택 세입자 월세 세액공제 신청 (12~17%)',
    targets: ['직장인', 'N잡러'],
  ),
  _TaxForm(
    name: '주택자금 소득공제 명세서',
    desc: '장기주택저당차입금(주담대) 이자 소득공제',
    targets: ['직장인'],
  ),
  _TaxForm(
    name: '경정청구서',
    desc: '연말정산·종소세 환급 소급 신청. 5년 이내 가능',
    targets: ['직장인', 'N잡러', '프리랜서'],
  ),
  _TaxForm(
    name: '사업소득 원천징수영수증',
    desc: '3.3% 원천징수된 프리랜서 소득 확인서',
    targets: ['프리랜서', 'N잡러'],
  ),
  _TaxForm(
    name: '종합소득세 과세표준확정신고서',
    desc: '5월 종소세 신고 핵심 서식. 모든 소득 합산 신고',
    targets: ['프리랜서', 'N잡러'],
  ),
  _TaxForm(
    name: '사업장현황신고서',
    desc: '면세사업자(프리랜서) 연간 수입금액 신고',
    targets: ['프리랜서'],
  ),
  _TaxForm(
    name: '노란우산공제 소득공제 확인서',
    desc: '소기업·소상공인 노란우산공제 납입 확인서',
    targets: ['프리랜서', 'N잡러'],
  ),
  _TaxForm(
    name: '연금계좌(IRP·연금저축) 납입확인서',
    desc: '연금저축·IRP 납입액 세액공제 근거 서류',
    targets: ['직장인', 'N잡러', '프리랜서'],
  ),
  _TaxForm(
    name: '건강보험료 납부확인서',
    desc: '직장 외 소득 건보료 추가 납부 확인',
    targets: ['N잡러', '프리랜서'],
  ),
  _TaxForm(
    name: '임대차계약서 사본',
    desc: '월세 세액공제 필수 첨부 서류',
    targets: ['직장인', 'N잡러'],
  ),
];

/// 서식 목록 본문 — 홈 세무도구 아코디언과 양식탭 모두에서 공유.
/// shrinkWrap ListView 사용: 부모 ScrollView 안에 중첩 가능.
class TaxFormsBody extends StatefulWidget {
  final String userType;
  const TaxFormsBody({super.key, required this.userType});

  @override
  State<TaxFormsBody> createState() => _TaxFormsBodyState();
}

class _TaxFormsBodyState extends State<TaxFormsBody> {
  late String _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.userType;
  }

  @override
  void didUpdateWidget(TaxFormsBody old) {
    super.didUpdateWidget(old);
    if (old.userType != widget.userType) {
      setState(() => _filter = widget.userType);
    }
  }

  List<_TaxForm> get _filtered {
    if (_filter == '전체') return _allForms;
    return _allForms.where((f) => f.targets.contains(_filter)).toList();
  }

  void _onTap(_TaxForm form) {
    if (form.assetPath != null) {
      // PDF 공유 — share_plus 추가 후 구현
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('아직 PDF를 준비 중이에요.',
              style: AppTheme.sans(13, Colors.white)),
          backgroundColor: AppTheme.ink(context),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final forms = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFilterRow(),
        Divider(height: 1, thickness: 1, color: AppTheme.line(context)),
        if (forms.isEmpty)
          _buildEmpty()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: forms.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.line(context),
                indent: 16),
            itemBuilder: (_, i) => _buildItem(forms[i]),
          ),
      ],
    );
  }

  Widget _buildFilterRow() {
    const tabs = ['직장인', 'N잡러', '프리랜서', '전체'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: tabs.map((t) {
          final sel = _filter == t;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = t),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? AppTheme.ink(context) : Colors.transparent,
                  border: Border.all(
                      color: sel
                          ? AppTheme.ink(context)
                          : AppTheme.line(context)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  t,
                  style: AppTheme.sans(
                    13,
                    sel
                        ? AppTheme.backgroundColor(context)
                        : AppTheme.inkSecondary(context),
                    weight: sel ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItem(_TaxForm form) {
    final ready = form.assetPath != null;
    return GestureDetector(
      onTap: () => _onTap(form),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(form.name,
                      style: AppTheme.sans(15, AppTheme.ink(context),
                          weight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(form.desc,
                      style: AppTheme.sans(
                          12, AppTheme.inkSecondary(context),
                          height: 1.4)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    children: form.targets.map(_buildBadge).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (ready)
              Icon(Icons.share_outlined,
                  size: 18, color: AppTheme.accentColor(context))
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.line(context)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('준비 중',
                    style:
                        AppTheme.sans(11, AppTheme.inkTertiary(context))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surface(context),
        border: Border.all(color: AppTheme.line(context)),
        borderRadius: BorderRadius.circular(2),
      ),
      child:
          Text(label, style: AppTheme.sans(10, AppTheme.inkTertiary(context))),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.description_outlined,
                size: 36, color: AppTheme.inkTertiary(context)),
            const SizedBox(height: 12),
            Text('해당 유형의 양식이 없어요',
                style: AppTheme.sans(14, AppTheme.inkSecondary(context))),
          ],
        ),
      ),
    );
  }
}

/// 양식 탭 화면 — TaxFormsBody를 Scaffold + AppBar로 래핑.
class FormsScreen extends StatelessWidget {
  final String userType;
  const FormsScreen({super.key, required this.userType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppTheme.inkSecondary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 16,
        title: Text('양식',
            style: AppTheme.serif(17, AppTheme.ink(context),
                weight: FontWeight.w400, spacing: -0.5)),
      ),
      body: SingleChildScrollView(
        child: TaxFormsBody(userType: userType),
      ),
    );
  }
}
