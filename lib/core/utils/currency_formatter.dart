import 'package:intl/intl.dart';

class CurrencyFormatter {
  // Tipo de cambio referencial USD a Bolivianos (BOB)
  static const double defaultUsdRate = 6.96;

  static final NumberFormat _bobFormat = NumberFormat.currency(
    locale: 'es_BO',
    symbol: 'Bs ',
    decimalDigits: 2,
  );

  static final NumberFormat _usdFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$ ',
    decimalDigits: 2,
  );

  /// Formatear en Bolivianos (Moneda principal)
  static String format(double amount, {String currency = 'BOB'}) {
    if (currency == 'USD') {
      return _usdFormat.format(amount);
    }
    return _bobFormat.format(amount);
  }

  /// Formatear en Bolivianos compacto (ej. Bs 1.5K, Bs 2.3M)
  static String formatCompact(double amount, {String currency = 'BOB'}) {
    final symbol = currency == 'USD' ? '\$' : 'Bs';
    if (amount >= 1000000) {
      return '$symbol ${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$symbol ${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$symbol ${amount.toStringAsFixed(2)}';
  }

  /// Convertir USD a BOB
  static double usdToBob(double usdAmount, {double rate = defaultUsdRate}) {
    return usdAmount * rate;
  }

  /// Convertir BOB a USD
  static double bobToUsd(double bobAmount, {double rate = defaultUsdRate}) {
    return rate > 0 ? bobAmount / rate : 0.0;
  }
}
