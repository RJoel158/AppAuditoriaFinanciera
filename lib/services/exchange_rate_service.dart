import 'dart:convert';
import 'package:http/http.dart' as http;

class ExchangeRateService {
  // Tasa de cambio por defecto en Bolivia (Mercado actual / Fallback)
  static const double fallbackRate = 10.50;
  static double _currentRate = fallbackRate;
  static DateTime? _lastUpdated;

  static double get currentRate => _currentRate;

  /// Obtener tasa de cambio actualizada (USD a BOB)
  static Future<double> fetchUsdToBobRate() async {
    // Si se actualizó hace menos de 1 hora, usar valor en caché
    if (_lastUpdated != null &&
        DateTime.now().difference(_lastUpdated!).inHours < 1) {
      return _currentRate;
    }

    try {
      final response = await http
          .get(Uri.parse('https://open.er-api.com/v6/latest/USD'))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['rates'] != null && data['rates']['BOB'] != null) {
          final officialBob = (data['rates']['BOB'] as num).toDouble();
          // Si la API devuelve la tasa oficial estática (6.85-6.96), usamos el mercado real (10.50)
          if (officialBob < 8.0) {
            _currentRate = fallbackRate;
          } else {
            _currentRate = officialBob;
          }
          _lastUpdated = DateTime.now();
          return _currentRate;
        }
      }
    } catch (_) {
      // Si no hay internet o falla la API, usar fallback seguro
    }

    _currentRate = fallbackRate;
    return _currentRate;
  }

  static void setCustomRate(double rate) {
    if (rate > 0) {
      _currentRate = rate;
      _lastUpdated = DateTime.now();
    }
  }
}
