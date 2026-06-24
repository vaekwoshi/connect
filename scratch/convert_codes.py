import json
import os

json_path = '지식_변환/JSON/2025년 귀속 경비율.json'
dart_dir = 'lib/core/data'
dart_path = os.path.join(dart_dir, 'occupation_data.dart')

if not os.path.exists(dart_dir):
    os.makedirs(dart_dir)

with open(json_path, 'r', encoding='utf-8') as f:
    data = json.load(f)

rows = data.get('데이터', [])

dart_content = """/// 2025년 귀속 경비율 고시 기준 업종코드 매핑 데이터
class OccupationData {
  static const Map<String, OccupationInfo> occupations = {
"""

# 첫 두 행은 헤더이므로 인덱스 2부터 처리
for row in rows[2:]:
    if len(row) < 3:
        continue
    code = row[0].strip()
    name = row[1].strip()
    
    # 단순경비율 기본율
    simple_base_str = row[2].strip() if row[2] else '0.0'
    try:
        simple_base = float(simple_base_str) if simple_base_str else 0.0
    except ValueError:
        simple_base = 0.0
        
    # 단순경비율 초과율 (인덱스 3이 존재하고 값이 있는 경우)
    simple_excess_str = ''
    if len(row) > 3:
        simple_excess_str = row[3].strip()
    try:
        simple_excess = float(simple_excess_str) if simple_excess_str else 0.0
    except ValueError:
        simple_excess = 0.0
        
    # 기준경비율 (인덱스 4가 존재하고 값이 있는 경우)
    standard_str = '0.0'
    if len(row) > 4:
        standard_str = row[4].strip() if row[4] else '0.0'
    try:
        standard = float(standard_str) if standard_str else 0.0
    except ValueError:
        standard = 0.0
        
    # Escape single quotes in name for Dart string
    name_escaped = name.replace("'", "\\'")
    
    dart_content += f"    '{code}': const OccupationInfo(code: '{code}', name: '{name_escaped}', simpleBaseRate: {simple_base}, simpleExcessRate: {simple_excess}, standardRate: {standard}),\n"

dart_content += """  };
}

class OccupationInfo {
  final String code;
  final String name;
  final double simpleBaseRate;
  final double simpleExcessRate;
  final double standardRate;

  const OccupationInfo({
    required this.code,
    required this.name,
    required this.simpleBaseRate,
    required this.simpleExcessRate,
    required this.standardRate,
  });
}
"""

with open(dart_path, 'w', encoding='utf-8') as f:
    f.write(dart_content)

print("Dart 파일 생성 완료!")
