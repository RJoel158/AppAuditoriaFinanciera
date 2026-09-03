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
  String _processingStatus = 'Apunta la cámara al código QR de la factura';

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
      _processingStatus = 'Factura detectada. Parseando datos SIAT...';
    });

    HapticFeedback.mediumImpact();

    // 1. Parsear datos iniciales del QR
    final partialInvoice = _siatService.parseQrData(rawData);

    if (partialInvoice == null) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = 'No es un código QR válido de Facturación de Bolivia';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.expense,
            content: Text('El código QR no corresponde a una factura SIAT / Impuestos de Bolivia.'),
          ),
        );
      }
      return;
    }

    // 2. Consultar web SIAT para obtener Razón Social y enlace al PDF
    setState(() {
      _processingStatus = 'Consultando datos del comercio en el portal SIAT...';
    });

    final fullInvoice = await _siatService.fetchInvoiceDetails(partialInvoice);

    // 3. Descargar PDF si existe enlace
    if (fullInvoice.pdfUrl != null && fullInvoice.pdfUrl!.isNotEmpty) {
      setState(() {
        _processingStatus = 'Descargando comprobante PDF de la factura...';
      });

      final pdfFile = await _siatService.downloadInvoicePdf(
        pdfUrl: fullInvoice.pdfUrl!,
        invoiceNumber: fullInvoice.invoiceNumber,
      );

      if (mounted) {
        final finalInvoice = fullInvoice.copyWith(downloadedPdfPath: pdfFile?.path);
        Navigator.pop(context, finalInvoice);
        return;
      }
    }

    if (mounted) {
      Navigator.pop(context, fullInvoice);
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
    final scanSize = MediaQuery.of(context).size.width * 0.72;

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

          // 2. Máscara Oscura Alrededor del Visor
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(160),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanSize,
                    height: scanSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Marco Visual Cuadrado con Esquinas y Línea Animada
          Center(
            child: SizedBox(
              width: scanSize,
              height: scanSize,
              child: Stack(
                children: [
                  // Bordes / Esquinas
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primary, width: 2.5),
                    ),
                  ),

                  // Línea Verde Animada de Escaneo
                  if (!_isProcessing)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanAnimation.value * (scanSize - 20),
                          left: 12,
                          right: 12,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.transparent, AppColors.primary, Colors.transparent],
                              ),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(150),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Overlay de Carga si está procesando
                  if (_isProcessing)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Panel Inferior con Instrucciones y Botón Manual
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withAlpha(220),
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
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.surfaceLight.withAlpha(80),
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
