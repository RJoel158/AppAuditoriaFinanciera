import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/constants/app_categories.dart';
import '../models/financial_record.dart';
import 'firestore_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isInitialized = false;
  StreamSubscription<List<FinancialRecord>>? _recordsSubscription;
  DateTime _listenerStartTime = DateTime.now();
  final Set<String> _notifiedRecordIds = {};

  static const String _channelId = 'famfinance_records_channel';
  static const String _channelName = 'Movimientos Familiares';
  static const String _channelDescription = 'Avisos en tiempo real de nuevos gastos e ingresos familiares con vista previa de imagen';

  /// Inicializa el motor de notificaciones locales y canales en Android
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('🔔 Notificación tocada con payload: ${details.payload}');
      },
    );

    // Crear canal de alta prioridad para Android
    const androidNotificationChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(androidNotificationChannel);
      await androidImplementation.requestNotificationsPermission();
    }

    _isInitialized = true;
    debugPrint('🔔 [NotificationService] Inicializado correctamente');
  }

  /// Escucha movimientos en tiempo real en Firestore creados por otros familiares
  void startFamilyListener({required String currentUserId}) {
    _recordsSubscription?.cancel();
    _listenerStartTime = DateTime.now().subtract(const Duration(seconds: 5));
    _notifiedRecordIds.clear();

    _recordsSubscription = _firestoreService.getRecordsStream(limit: 10).listen(
      (records) {
        for (final record in records) {
          // Si el registro es nuevo, pertenece a otro usuario y no ha sido notificado aún
          if (record.createdAt.isAfter(_listenerStartTime) &&
              record.memberId != currentUserId &&
              !_notifiedRecordIds.contains(record.id)) {
            _notifiedRecordIds.add(record.id);
            showRecordNotification(record: record, isSelf: false);
          }
        }
      },
      onError: (err) {
        debugPrint('⚠️ Error en listener de notificaciones familiares: $err');
      },
    );
  }

  /// Detiene el listener cuando se cierra sesión
  void stopFamilyListener() {
    _recordsSubscription?.cancel();
    _recordsSubscription = null;
    _notifiedRecordIds.clear();
  }

  /// Despliega la notificación enriquecida con datos y Preview de la imagen si existe
  Future<void> showRecordNotification({
    required FinancialRecord record,
    bool isSelf = false,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      final isIncome = record.isIncome;
      final typeEmoji = isIncome ? '💰' : '💸';
      final typeName = isIncome ? 'Ingreso' : 'Gasto';
      final author = isSelf ? 'Tú (${record.registeredBy})' : record.registeredBy;
      final categoryItem = AppCategories.getCategoryById(record.category);
      final categoryName = categoryItem.name;

      final title = '$typeEmoji Nuevo $typeName de $author';
      final formattedAmount = 'Bs ${record.amount.toStringAsFixed(2)}';
      final conceptPart = record.title.trim().isNotEmpty ? record.title.trim() : categoryName;
      final summary = '$conceptPart: $formattedAmount';

      StyleInformation styleInformation;
      AndroidBitmap<Object>? largeIconBitmap;

      // 1. Descargar imagen para BigPictureStyle si tiene foto de comprobante/recibo
      if (record.imageUrl != null && record.imageUrl!.trim().isNotEmpty) {
        try {
          final imageUrl = record.imageUrl!.trim();
          final response = await http.get(Uri.parse(imageUrl)).timeout(const Duration(seconds: 4));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            final tempDir = await getTemporaryDirectory();
            final filePath = '${tempDir.path}/notif_preview_${record.id.isNotEmpty ? record.id : DateTime.now().millisecondsSinceEpoch}.jpg';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            final bigPicture = FilePathAndroidBitmap(filePath);
            largeIconBitmap = bigPicture;

            styleInformation = BigPictureStyleInformation(
              bigPicture,
              largeIcon: largeIconBitmap,
              contentTitle: title,
              summaryText: '$summary • Recibo adjunto 📷',
              htmlFormatContentTitle: false,
              htmlFormatSummaryText: false,
              hideExpandedLargeIcon: true,
            );
          } else {
            styleInformation = _buildBigTextStyle(title, record, categoryName, formattedAmount);
          }
        } catch (e) {
          debugPrint('⚠️ No se pudo descargar preview de imagen para notificación: $e');
          styleInformation = _buildBigTextStyle(title, record, categoryName, formattedAmount);
        }
      } else {
        styleInformation = _buildBigTextStyle(title, record, categoryName, formattedAmount);
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: styleInformation,
        largeIcon: largeIconBitmap,
        ticker: title,
        color: isIncome ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        enableLights: true,
        enableVibration: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      final notificationId = record.id.isNotEmpty
          ? (record.id.hashCode & 0x7FFFFFFF)
          : DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notificationsPlugin.show(
        notificationId,
        title,
        summary,
        notificationDetails,
        payload: record.id,
      );

      debugPrint('🔔 [NotificationService] Notificación enviada con éxito: $title');
    } catch (e) {
      debugPrint('❌ Error mostrando notificación de registro: $e');
    }
  }

  BigTextStyleInformation _buildBigTextStyle(
    String title,
    FinancialRecord record,
    String categoryName,
    String formattedAmount,
  ) {
    final descPart = record.description.trim().isNotEmpty ? '\n📝 Detalle: ${record.description}' : '';
    final datePart = '📅 Fecha: ${record.date.day.toString().padLeft(2, '0')}/${record.date.month.toString().padLeft(2, '0')}/${record.date.year}';

    return BigTextStyleInformation(
      '🏷️ Categoría: $categoryName\n💵 Monto: $formattedAmount$descPart\n$datePart',
      contentTitle: title,
      summaryText: '$categoryName • $formattedAmount',
      htmlFormatBigText: false,
      htmlFormatContentTitle: false,
    );
  }
}
