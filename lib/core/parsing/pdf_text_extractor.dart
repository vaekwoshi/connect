import 'package:syncfusion_flutter_pdf/pdf.dart';

/// 1층 어댑터 — PDF 바이트에서 텍스트만 추출(순수 Dart, 온디바이스).
/// 추출된 텍스트는 2층(parseSimplifiedText / parseWithholdingText)이 처리한다.
/// 추출기를 바꿔도 이 함수만 교체하면 됨.
String extractPdfText(List<int> bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    // layoutText: 위치 기반 추출 — 표가 행 단위로 보존돼 파서와 맞물림.
    // (기본 추출은 셀 순서가 흐트러져 파싱 불가)
    return PdfTextExtractor(document).extractText(layoutText: true);
  } finally {
    document.dispose();
  }
}
