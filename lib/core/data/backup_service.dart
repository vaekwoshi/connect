import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'db_helper.dart';

/// 백업/복원 결과 — UI에서 메시지 분기용.
enum BackupResult { success, cancelled, invalidFile, error }

/// 오프라인 데이터 백업/복원 — 전 테이블을 JSON 파일 한 개로 내보내고/되돌린다.
/// 서버 없이 사용자가 직접 파일을 보관(클라우드·메일 등)하도록 한다.
class BackupService {
  /// 전체 데이터를 JSON으로 내보내 사용자가 고른 위치에 저장.
  Future<BackupResult> exportToFile() async {
    try {
      final data = await dbService.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = Uint8List.fromList(utf8.encode(jsonStr));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: '세끌 백업 저장',
        fileName: 'sekkeul_backup_${_stamp()}.json',
        bytes: bytes,
      );
      return path == null ? BackupResult.cancelled : BackupResult.success;
    } catch (_) {
      return BackupResult.error;
    }
  }

  /// 백업 파일을 골라 전체 데이터를 복원(기존 데이터 덮어씀).
  Future<BackupResult> importFromFile() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return BackupResult.cancelled;
      final bytes = picked.files.first.bytes;
      if (bytes == null) return BackupResult.error;
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map || decoded['app'] != 'sekkeul' || decoded['tables'] is! Map) {
        return BackupResult.invalidFile;
      }
      await dbService.importAllData(Map<String, dynamic>.from(decoded));
      return BackupResult.success;
    } catch (_) {
      return BackupResult.error;
    }
  }

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }
}

final backupService = BackupService();
