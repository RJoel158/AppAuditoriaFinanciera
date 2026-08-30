import 'package:intl/intl.dart';
import '../../services/exchange_rate_service.dart';

class CurrencyFormatter {
  static double get defaultUsdRate => ExchangeRateService.currentRate;

  static final NumberFormat _bobFormat = NumberFormat.currency(
    locale: 'es_BO',
    symbol: 'Bs ',
    decimalDigits: 2,
  );

  static final NumberFormat _usdFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: 'USD ',
    decimalDigits: 2,
  );

  /// Formatear en Bolivianos (Moneda principal)
  static String format(double amount, {String currency = 'BOB'}) {
    if (currency == 'USD') {
      return _usdFormat.format(amount);
    }
    return _bobFormat.format(amount);
  }

  /// Formatear en formato compacto para cifras millonarias
  static String formatCompact(double amount, {String currency = 'BOB'}) {
    final symbol = currency == 'USD' ? 'USD' : 'Bs';
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';

    if (absAmount >= 1000000000) {
      return '$sign$symbol ${(absAmount / 1000000000).toStringAsFixed(2)}B';
    } else if (absAmount >= 1000000) {
      return '$sign$symbol ${(absAmount / 1000000).toStringAsFixed(2)}M';
    } else if (absAmount >= 100000) {
      return '$sign$symbol ${(absAmount / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, currency: currency);
  }

  /// Convertir USD a BOB
  static double usdToBob(double usdAmount, {double? rate}) {
    final actualRate = rate ?? ExchangeRateService.currentRate;
    return usdAmount * actualRate;
  }

  /// Convertir BOB a USD
  static double bobToUsd(double bobAmount, {double? rate}) {
    final actualRate = rate ?? ExchangeRateService.currentRate;
    return actualRate > 0 ? bobAmount / actualRate : 0.0;
  }
}
