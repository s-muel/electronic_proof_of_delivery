import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String cloudName = 'bajfreight';
  static const String uploadPreset = 'epod_unsigned';

  static Future<String?> uploadSignature({
    required Uint8List signatureBytes,
    required String fileName,
  }) async {
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );

      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'e_pod_signatures';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          signatureBytes,
          filename: '$fileName.png',
        ),
      );

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final secureUrl = data['secure_url'] as String?;

        if (secureUrl == null || secureUrl.isEmpty) {
          throw Exception('Cloudinary response did not contain secure_url');
        }

        return secureUrl;
      } else {
        final error = data['error'];
        final message = error is Map ? error['message'] : responseBody;
        print('Cloudinary upload failed: ${response.statusCode} $message');
        return null;
      }
    } catch (e) {
      print('Cloudinary upload error: $e');
      return null;
    }
  }
}
