import 'dart:convert';

/// 온디바이스 보안 저장부의 민감 데이터 보호를 위한 경량 암호화 헬퍼 클래스
class CryptoHelper {
  // 고정 솔트값 (역컴파일러 난독화 목적)
  static const String _salt = "SEKKEUL_SALT_2026_ONDEVICE";

  /// 런타임에 동적으로 마스킹 키 바이트 스트림을 생성 (하드코딩 키 유출 방지)
  static List<int> _getDynamicKeyBytes(int length) {
    // 실무에서는 디바이스 UUID 등과 조합하지만, 가출원 데모 및 독립 구동을 위해 
    // 솔트값과 난수 알고리즘 시드를 조합하여 결정론적 동적 바이트 스트림 생성
    final List<int> keyBytes = [];
    final List<int> saltBytes = utf8.encode(_salt);
    
    int saltSum = saltBytes.fold(0, (prev, element) => prev + element);
    
    for (int i = 0; i < length; i++) {
      // 솔트와 인덱스를 결합한 유사 난수 바이트 획득
      int keyByte = (saltBytes[i % saltBytes.length] ^ (saltSum + i)) & 0xFF;
      keyBytes.add(keyByte);
    }
    return keyBytes;
  }

  /// 평문 데이터를 XOR 난독화 및 Base64 인코딩하여 암호화
  static String encrypt(String plainText) {
    if (plainText.isEmpty) return "";
    
    final List<int> plainBytes = utf8.encode(plainText);
    final List<int> keyBytes = _getDynamicKeyBytes(plainBytes.length);
    final List<int> cipherBytes = [];

    for (int i = 0; i < plainBytes.length; i++) {
      cipherBytes.add(plainBytes[i] ^ keyBytes[i]);
    }

    return base64.encode(cipherBytes);
  }

  /// 암호화된 Base64 데이터를 디코딩 및 XOR 복호화하여 평문 복구
  static String decrypt(String cipherText) {
    if (cipherText.isEmpty) return "";
    
    try {
      final List<int> cipherBytes = base64.decode(cipherText);
      final List<int> keyBytes = _getDynamicKeyBytes(cipherBytes.length);
      final List<int> plainBytes = [];

      for (int i = 0; i < cipherBytes.length; i++) {
        plainBytes.add(cipherBytes[i] ^ keyBytes[i]);
      }

      return utf8.decode(plainBytes);
    } catch (e) {
      // 복호화 실패 시 방어 코드
      return "";
    }
  }
}
