import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:secul/core/parsing/simplified_data_parser.dart';

void main() {
  group('간소화 자료 파서 — 실제 추출 텍스트(골든)', () {
    late GansoDeductions d;

    setUpAll(() {
      final text = File('test/fixtures/ganso_sample.txt').readAsStringSync();
      d = parseSimplifiedText(text);
    });

    test('카드 3종 합계 정확 추출', () {
      expect(d.creditCard, 3712061, reason: '신용카드 집계 합계금액');
      expect(d.debitCard, 2842303, reason: '직불카드 등 합계금액');
      expect(d.cashReceipt, 2724031, reason: '현금영수증 집계 합계금액');
      expect(d.debitCash, 2842303 + 2724031, reason: '체크+현금');
    });

    test('4대보험 — 총합계/합계 패턴', () {
      expect(d.nationalPension, 1686420);
      expect(d.healthInsurance, 1782490);
      expect(d.employmentInsurance, 389280);
      expect(d.fourMajorInsurance, 1686420 + 1782490 + 389280);
    });

    test('보장성·의료비·실손 — 인별합계금액', () {
      expect(d.lifeInsurance, 2968840);
      expect(d.medical, 219400);
      expect(d.medicalReimbursed, 71000);
      expect(d.medicalNet, 148400, reason: '실손 차감 후 의료비');
    });

    test('없는 카테고리는 0', () {
      expect(d.education, 0);
      expect(d.donation, 0);
      expect(d.pensionSavings, 0);
      expect(d.mortgage, 0);
      expect(d.rent, 0);
    });
  });

  group('교육·기부·연금·월세 4카테고리 — 구조 합성 골든', () {
    // ※ 합계 라벨은 확정 패턴 기반 추정. 후속: 4카테고리 든 실파일 1부로 라벨 확인.
    late GansoDeductions d;
    setUpAll(() {
      d = parseSimplifiedText(File('test/fixtures/ganso_extra_sample.txt').readAsStringSync());
    });
    test('교육비 인별합계금액', () => expect(d.education, 1500000));
    test('기부금 인별합계금액', () => expect(d.donation, 600000));
    test('연금저축 납입금액계', () => expect(d.pensionSavings, 3000000));
    test('월세액 인별합계금액', () => expect(d.rent, 6000000));
  });

  group('합성 엣지케이스 (구조는 실파일 패턴, 값만 변형)', () {
    test('신용카드만 있는 최소 텍스트 → 나머지 0', () {
      const text = '''
2025년 귀속 소득 · 세액공제증명서류 : 기본(사용처별)내역
[ 신용카드 ]
■ 신용카드 등 사용금액 집계
일반 전통시장 대중교통 문화체육 합계금액
9,000,000 0 0 0 9,000,000
인별합계금액 9,000,000
''';
      final d = parseSimplifiedText(text);
      expect(d.creditCard, 9000000);
      expect(d.debitCard, 0);
      expect(d.healthInsurance, 0);
      expect(d.medical, 0);
    });

    test('교육비·기부금·연금저축 추가 시 인별합계금액 추출(best-effort)', () {
      const text = '''
2025년 귀속 소득 · 세액공제증명서류 : 기본(지출처별)내역 [교육비]
인별합계금액 1,200,000
2025년 귀속 소득 · 세액공제증명서류 [기부금]
인별합계금액 500,000
2025년 귀속 소득 · 세액공제증명서류 [연금저축]
인별합계금액 6,000,000
''';
      final d = parseSimplifiedText(text);
      expect(d.education, 1200000);
      expect(d.donation, 500000);
      expect(d.pensionSavings, 6000000);
    });

    test('난임시술비 인별합계금액 분리 추출', () {
      const text = '''
[의료비]
일반 120,000
난임시술비 인별합계금액 1,500,000
의료비 인별합계금액 1,620,000
인별합계금액 1,620,000
''';
      final d = parseSimplifiedText(text);
      expect(d.medical, 1620000);
      expect(d.medicalInfertility, 1500000);
    });

    test('의료비 노트의 난임은 오매칭 안 됨(인별합계금액 없음)', () {
      const text = '''
[의료비]
인별합계금액 200,000
본인ㆍ65세 이상 자ㆍ난임시술비(한도 없음) 그 외
''';
      final d = parseSimplifiedText(text);
      expect(d.medical, 200000);
      expect(d.medicalInfertility, 0);
    });

    test('의료비 > 실손 음수 방지', () {
      const text = '''
[의료비]
인별합계금액 100,000
[실손의료보험금]
인별합계금액 300,000
''';
      final d = parseSimplifiedText(text);
      expect(d.medicalNet, 0);
    });
  });
}
