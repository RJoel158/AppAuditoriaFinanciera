import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/app_config.dart';
import '../core/utils/image_compressor.dart';

class UploadResult {
  final String downloadUrl;
  final String storagePath;
  final CompressionResult compressionStats;

  UploadResult({
    required this.downloadUrl,
    required this.storagePath,
    required this.compressionStats,
  });
}

class StorageService {
  /// Sube la imagen comprimida a la nube gratuita (Cloudinary) sin requerir tarjeta
  Future<UploadResult> uploadReceiptImage({
    required File imageFile,
    Function(double progress)? onProgress,
  }) async {
    final isPdf = imageFile.path.toLowerCase().endsWith('.pdf');

    // 1. Comprimir si es imagen (no aplica para PDF)
    CompressionResult? compression;
    if (!isPdf) {
      compression = await ImageCompressorUtil.compressImage(
        imageFile,
        quality: 70,
        minWidth: 1280,
        minHeight: 1280,
      );
    }

    final fileToUpload = compression?.file ?? imageFile;
    final fileLength = await imageFile.length();
    final fileStats = compression ??
        CompressionResult(
          file: imageFile,
          originalBytes: fileLength,
          compressedBytes: fileLength,
        );

    final cloudName = AppConfig.cloudinaryCloudName;
    final uploadPreset = AppConfig.cloudinaryUploadPreset;

    // 2. Si no se ha configurado Cloudinary aún, guardamos como Data URL Base64 optimizada
    if (cloudName == 'demo' || cloudName.isEmpty) {
      debugPrint('Usando modo local/base64 temporal optimizado.');
      final bytes = await fileToUpload.readAsBytes();
      final base64String = base64Encode(bytes);
      final mime = isPdf ? 'application/pdf' : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,$base64String';

      return UploadResult(
        downloadUrl: dataUrl,
        storagePath: 'local_base64_${DateTime.now().millisecondsSinceEpoch}',
        compressionStats: fileStats,
      );
    }


    // 3. Subir a Cloudinary (Plan Gratuito Permanente)
    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = 'comprobantes_familia'
        ..files.add(await http.MultipartFile.fromPath('file', fileToUpload.path));

      onProgress?.call(0.5);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final secureUrl = data['secure_url'] as String;
        final publicId = data['public_id'] as String;

        onProgress?.call(1.0);
        debugPrint('Comprobante subido exitosamente a Cloudinary: $secureUrl');

        return UploadResult(
          downloadUrl: secureUrl,
          storagePath: publicId,
          compressionStats: fileStats,
        );
      } else {
        debugPrint('Error en respuesta de Cloudinary: ${response.body}');
        throw Exception('Error al subir comprobante (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      debugPrint('Fallo en subida a Cloudinary, usando respaldo Base64: $e');
      final bytes = await fileToUpload.readAsBytes();
      final base64String = base64Encode(bytes);
      return UploadResult(
        downloadUrl: 'data:image/jpeg;base64,$base64String',
        storagePath: 'fallback_${DateTime.now().millisecondsSinceEpoch}',
        compressionStats: fileStats,
      );
    }
  }

  /// Eliminar comprobante
  Future<void> deleteImage(String storagePath) async {
    debugPrint('Eliminar referencia de imagen: $storagePath');
  }
}
