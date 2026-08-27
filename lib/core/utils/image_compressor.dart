import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class CompressionResult {
  final File file;
  final int originalBytes;
  final int compressedBytes;

  CompressionResult({
    required this.file,
    required this.originalBytes,
    required this.compressedBytes,
  });

  double get savedPercentage =>
      originalBytes > 0 ? (1 - (compressedBytes / originalBytes)) * 100 : 0;

  String get originalSizeFormatted => _formatBytes(originalBytes);
  String get compressedSizeFormatted => _formatBytes(compressedBytes);

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }
}

class ImageCompressorUtil {
  /// Comprime una imagen a JPEG con calidad configurable (por defecto 70%) y resolución máxima
  static Future<CompressionResult?> compressImage(
    File file, {
    int quality = 70,
    int minWidth = 1280,
    int minHeight = 1280,
  }) async {
    try {
      final originalSize = await file.length();
      final tempDir = await getTemporaryDirectory();
      final targetPath = p.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile == null) {
        return null;
      }

      final compressedFile = File(compressedXFile.path);
      final compressedSize = await compressedFile.length();

      debugPrint(
        'Compresión completada: Original ($originalSize B) -> Comprimido ($compressedSize B)',
      );

      return CompressionResult(
        file: compressedFile,
        originalBytes: originalSize,
        compressedBytes: compressedSize,
      );
    } catch (e) {
      debugPrint('Error al comprimir imagen: $e');
      // En caso de fallo en compresión, devolvemos el archivo original
      final originalSize = await file.length();
      return CompressionResult(
        file: file,
        originalBytes: originalSize,
        compressedBytes: originalSize,
      );
    }
  }
}
