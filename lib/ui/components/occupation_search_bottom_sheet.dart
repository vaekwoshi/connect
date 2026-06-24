import 'package:flutter/material.dart';
import '../../core/data/occupation_data.dart';

class OccupationSearchBottomSheet extends StatefulWidget {
  const OccupationSearchBottomSheet({super.key});

  static Future<OccupationInfo?> show(BuildContext context) {
    return showModalBottomSheet<OccupationInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: const OccupationSearchBottomSheet(),
      ),
    );
  }

  @override
  State<OccupationSearchBottomSheet> createState() => _OccupationSearchBottomSheetState();
}

class _OccupationSearchBottomSheetState extends State<OccupationSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<OccupationInfo> _filteredList = [];

  @override
  void initState() {
    super.initState();
    _filteredList = OccupationData.occupations.values.take(50).toList();
  }

  /// 구어체 → 경비율 고시 공식 용어 동의어. 사용자가 흔히 치는 말이
  /// 공식 분류명과 달라(예: '카페'→고시엔 '커피숍') 검색이 빗나가는 걸 메운다.
  static const Map<String, List<String>> _synonyms = {
    '카페': ['커피', '커피숍'],
    '까페': ['커피', '커피숍'],
    '커피숍': ['커피'],
    '치킨': ['닭', '호프', '튀김'],
    '분식': ['김밥', '떡볶이', '음식점'],
    '식당': ['음식점', '한식'],
    '밥집': ['음식점', '한식'],
    '고깃집': ['육류', '구이', '음식점'],
    '술집': ['주점', '호프', '맥주'],
    '호프': ['주점', '맥주'],
    '피시방': ['컴퓨터게임', '게임'],
    'pc방': ['컴퓨터게임', '게임'],
    '노래방': ['노래연습장'],
    '헬스장': ['체력단련', '스포츠'],
    '헬스': ['체력단련'],
    '미용실': ['미용', '이용'],
    '네일': ['미용'],
    '옷가게': ['의류', '의복'],
    '편의점': ['종합소매', '체인화편의점'],
    '학원': ['교습', '강사'],
    '과외': ['교습', '강사'],
    '유튜버': ['미디어콘텐츠', '1인미디어', '크리에이터'],
    '유튜브': ['미디어콘텐츠', '1인미디어'],
    '쇼핑몰': ['전자상거래', '통신판매'],
    '스마트스토어': ['전자상거래', '통신판매'],
    '온라인판매': ['전자상거래', '통신판매'],
    '배달': ['배달', '퀵서비스'],
    '택배': ['배달', '화물', '퀵서비스'],
    '프리랜서': ['인적용역'],
    '개발자': ['소프트웨어', '프로그래'],
    '프로그래머': ['소프트웨어', '프로그래'],
    '디자이너': ['디자인'],
    '사진작가': ['사진', '촬영'],
    '블로거': ['미디어콘텐츠', '1인미디어'],
    '인플루언서': ['미디어콘텐츠', '1인미디어'],
  };

  /// 관련도 점수 — 이름 일치 > 부분일치 > 키워드 > 코드. 0이면 제외.
  int _score(OccupationInfo info, String t) {
    if (t.isEmpty) return 0;
    final name = info.name.toLowerCase().replaceAll(' ', '');
    final kw = info.keywords.toLowerCase().replaceAll(' ', '');
    if (name == t) return 100;
    if (name.startsWith(t)) return 85;
    if (name.contains(t)) return 70;
    if (info.code.startsWith(t)) return 50;
    if (kw.contains(t)) return 40;
    return 0;
  }

  void _onSearch(String keyword) {
    final q = keyword.trim().toLowerCase().replaceAll(' ', '');
    if (q.isEmpty) {
      setState(() => _filteredList = OccupationData.occupations.values.take(50).toList());
      return;
    }
    // term → 보너스. 원 검색어는 보너스 0, 동의어는 +20을 줘서 구어체 검색이
    // 우연한 부분일치(예: '카페'→'카페트')보다 위로 올라오게 한다.
    final terms = <String, double>{q: 0};
    _synonyms.forEach((k, syns) {
      if (q == k || q.contains(k)) {
        for (final s in syns) terms[s] = 20;
      }
    });

    final scored = <MapEntry<OccupationInfo, double>>[];
    for (final info in OccupationData.occupations.values) {
      double best = 0;
      terms.forEach((t, bonus) {
        final base = _score(info, t).toDouble();
        if (base > 0) {
          final s = (base + bonus).clamp(0, 100).toDouble();
          if (s > best) best = s;
        }
      });
      if (best > 0) scored.add(MapEntry(info, best));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    setState(() => _filteredList = scored.take(60).map((e) => e.key).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor, // 앱 배경색
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '업종코드 검색',
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!),
              decoration: InputDecoration(
                hintText: '업종명(예: 프리랜서, 카페) 또는 6자리 코드',
                hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.3), fontSize: 14),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodyLarge!.color!),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: _filteredList.length,
              separatorBuilder: (context, index) => Divider(color: Theme.of(context).cardColor, height: 1),
              itemBuilder: (context, index) {
                final item = _filteredList[index];
                final nameParts = item.name.split(' / ');
                final category = nameParts.length > 1 ? nameParts[0] : '';
                final detailName = nameParts.length > 1 ? nameParts[1] : item.name;

                return InkWell(
                  onTap: () => Navigator.pop(context, item),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (category.isNotEmpty)
                                Text(
                                  category,
                                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                detailName,
                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.code,
                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
