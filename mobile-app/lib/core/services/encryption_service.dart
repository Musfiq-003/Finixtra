import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

/// Service responsible for End-to-End Encryption of offline transactions
/// using AES-256-GCM as specified in the GetConnect methodology.
class EncryptionService {
  // In production, keys should be derived via ECDH. 
  // For demonstration, we use a fixed key derivation.
  static final Key _key = Key.fromUtf8('finixtra_enterprise_secure_32byt'); 
  
  /// Encrypts the transaction payload before broadcasting to the mesh.
  static String encryptPayload(Map<String, dynamic> payload) {
    try {
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
      
      final jsonPayload = jsonEncode(payload);
      final encrypted = encrypter.encrypt(jsonPayload, iv: iv);
      
      return jsonEncode({
        'iv': iv.base64,
        'data': encrypted.base64,
      });
    } catch (e) {
      throw Exception("Encryption failed: $e");
    }
  }

  /// Decrypts a payload if this node is the intended recipient.
  static Map<String, dynamic> decryptPayload(String encryptedJson) {
    try {
      final decoded = jsonDecode(encryptedJson);
      final iv = IV.fromBase64(decoded['iv']);
      final encryptedData = Encrypted.fromBase64(decoded['data']);
      
      final encrypter = Encrypter(AES(_key, mode: AESMode.gcm));
      final decrypted = encrypter.decrypt(encryptedData, iv: iv);
      
      return jsonDecode(decrypted);
    } catch (e) {
      throw Exception("Decryption failed: $e");
    }
  }

  /// Generates a cryptographic signature to prevent tampering by relay nodes.
  static String generateSignature(Map<String, dynamic> payload) {
    // A real implementation would use asymmetric keys (e.g., ECDSA)
    // Here we use HMAC-SHA256 for structural demonstration.
    final jsonPayload = jsonEncode(payload);
    var hmacSha256 = Hmac(sha256, _key.bytes);
    var digest = hmacSha256.convert(utf8.encode(jsonPayload));
    return digest.toString();
  }
}
