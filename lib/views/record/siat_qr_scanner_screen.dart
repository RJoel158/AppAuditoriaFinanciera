import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../services/siat_invoice_service.dart';


class SiatQrScannerScreen extends StatefulWidget {
  const SiatQrScannerScreen({super.key});

  @override
  State<SiatQrScannerScreen> createState() => _SiatQrScannerScreenState();
}

class _SiatQrScannerScreenState extends State<SiatQrScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final SiatInvoiceService _siatService = SiatInvoiceService();
  bool _isProcessing = false;
  bool _isTorchOn = false;
  String _processingStatus = 'Enfoca el código QR de la factura';

  late AnimationController _animController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleQrDetection(String rawData) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _processingStatus = 'Factura detectada. Extrayendo datos del SIAT...';
    });

    HapticFeedback.mediumImpact();

    // 1. Parsear datos iniciales del QR
    final partialInvoice = _siatService.parseQrData(rawData);

    if (partialInvoice == null) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'Código no reconocido. Intenta enfocar nuevamente.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.expense,
            content: Text('El código QR no corresponde a una factura SIAT de Bolivia.'),
          ),
        );
      }
      return;
    }

    // 2. Consultar web SIAT y enriquecer con Gemini AI
    setState(() {
      _processingStatus = 'Identificando comercio y montos con IA...';
    });

    final fullInvoice = await _siatService.fetchInvoiceDetails(partialInvoice);

    // 3. Descargar PDF del SIAT o Generar Comprobante Oficial Digital
    setState(() {
      _processingStatus = 'Adjuntando comprobante oficial de la factura...';
    });

    final pdfFile = await _siatService.downloadOrGenerateInvoicePdf(
      invoice: fullInvoice,
    );

    if (mounted) {
      final finalInvoice = fullInvoice.copyWith(downloadedPdfPath: pdfFile?.path);
      Navigator.pop(context, finalInvoice);
    }
  }

  void _showManualLinkDialog() {
    final linkController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Pegar Enlace SIAT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pega la URL del QR de Impuestos Nacionales de Bolivia:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: linkController,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'https://siat.impuestos.gob.bo/consulta/QR?...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              final text = linkController.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                _handleQrDetection(text);
              }
            },
            child: const Text('Procesar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanBoxSize = screenSize.width * 0.72;
    final scanWindow = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height * 0.42),
      width: scanBoxSize,
      height: scanBoxSize,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha(200),
        title: const Text('Escanear Factura QR (SIAT)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? Colors.amber : Colors.white,
            ),
            tooltip: 'Linterna',
            onPressed: () {
              setState(() => _isTorchOn = !_isTorchOn);
              _scannerController.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            tooltip: 'Cambiar Cámara',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Visor de Cámara MobileScanner
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _handleQrDetection(rawValue);
                  break;
                }
              }
            },
          ),

          // 2. Máscara Oscura 100% Transparente en el Centro (CustomPainter)
          CustomPaint(
            painter: _ScannerHolePainter(
              scanWindow: scanWindow,
              borderRadius: 20,
            ),
          ),

          // 3. Marco Visual con Esquinas Verdes y Línea Láser Animada
          Positioned(
            left: scanWindow.left,
            top: scanWindow.top,
            width: scanWindow.width,
            height: scanWindow.height,
            child: Stack(
              children: [
                // Borde Verde Neón
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary, width: 2.5),
                  ),
                ),

                // Línea Láser de Escaneo
                if (!_isProcessing)
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanAnimation.value * (scanBoxSize - 16),
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                            ),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(200),
                                blurRadius: 10,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                // Overlay de Carga durante consulta
                if (_isProcessing)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(200),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ),
              ],
            ),
          ),

          // 4. Panel Inferior con Estado y Botón de Enlace Manual
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withAlpha(230),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _processingStatus,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight.withAlpha(90),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showManualLinkDialog,
                  icon: const Icon(Icons.link_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Pegar Enlace SIAT / Ingresar URL',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter que oscurece toda la pantalla EXCEPTO el rectángulo central que queda 100% transparente
class _ScannerHolePainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;

  _ScannerHolePainter({required this.scanWindow, this.borderRadius = 20});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withAlpha(160)
      ..style = PaintingStyle.fill;

    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)));

    final overlayPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    canvas.drawPath(overlayPath, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
