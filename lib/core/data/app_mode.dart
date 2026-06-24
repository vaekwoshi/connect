import 'package:flutter/foundation.dart';

/// 특허 데이터 수집 모드 정의
/// - manual : 제1모드 오프라인 파싱부(111) — 수기 입력·OCR·문서 파싱 (완전 오프라인)
/// - linked : 제2모드 외부 금융망 실시간 연동부(112) — 실시간 자동 동기화 (목업)
enum AppMode { manual, linked }

extension AppModeX on AppMode {
  /// DB 저장용 문자열
  String get dbValue => this == AppMode.linked ? 'linked' : 'manual';

  /// 짧은 라벨 (뱃지용)
  String get label => this == AppMode.linked ? '자동 연동' : '수동 입력';

  /// 뱃지 이모지
  String get emoji => this == AppMode.linked ? '🔗' : '✍️';

  /// 설명 (설정 화면용)
  String get description => this == AppMode.linked
      ? '연동 계좌에서 결제 내역을 실시간으로 자동 수집해요.'
      : '카드 내역을 직접 등록해요. 외부 전송 없이 완전 비공개로 동작해요.';

  /// 특허 도면 부호
  String get patentRef => this == AppMode.linked ? '제2모드(112)' : '제1모드(111)';

  bool get isManual => this == AppMode.manual;
  bool get isLinked => this == AppMode.linked;
}

/// DB 문자열 → AppMode 복원 (미설정 시 기본값 = 제1모드 수동)
AppMode appModeFromDb(String? value) =>
    value == 'linked' ? AppMode.linked : AppMode.manual;

/// 앱 전역 모드 상태. 시작 시 DB에서 로드되고, 설정 변경 시 갱신된다.
/// (main.dart의 themeNotifier와 동일한 패턴)
final ValueNotifier<AppMode> appModeNotifier = ValueNotifier(AppMode.manual);
