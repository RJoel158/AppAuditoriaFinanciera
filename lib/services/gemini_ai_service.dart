import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants/app_categories.dart';

class GeminiAiService {
  // Clave de API opcional (puede cargarse o usar fallback local inteligente sin costo)
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Genera un diagnóstico financiero familiar conciso y 100% acotado a los datos reales
  static Future<String> generateFinancialDiagnosis({
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> categoryExpenses,
    required int totalTransactions,
    String? customApiKey,
  }) async {
    final apiKey = customApiKey?.isNotEmpty == true ? customApiKey! : _defaultApiKey;

    final balance = totalIncome - totalExpense;
    final savingsRate = totalIncome > 0 ? ((balance / totalIncome) * 100).clamp(-100, 100) : 0.0;

    // Obtener las 3 categorías con mayor gasto
    final sortedCategories = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topExpenses = sortedCategories.take(3).map((e) {
      final cat = AppCategories.getCategoryById(e.key);
      final percent = totalExpense > 0 ? (e.value / totalExpense * 100).toStringAsFixed(1) : '0';
      return '- ${cat.name}: Bs ${e.value.toStringAsFixed(2)} ($percent%)';
    }).join('\n');

    final dataSummary = '''
Resumen Numérico Familiar:
- Ingresos Totales: Bs ${totalIncome.toStringAsFixed(2)}
- Egresos Totales: Bs ${totalExpense.toStringAsFixed(2)}
- Balance Neto: Bs ${balance.toStringAsFixed(2)}
- Tasa de Ahorro: ${savingsRate.toStringAsFixed(1)}%
- Total Transacciones Registradas: $totalTransactions
Principales Categorías de Gasto:
$topExpenses
''';

    if (apiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.2,
            maxOutputTokens: 250,
          ),
        );

        final prompt = '''
Eres un asesor financiero casero, cercano y amigable para una familia.
Analiza exclusivamente los siguientes datos numéricos de este reporte. No inventes información externa ni asumas datos no provistos.
Emite un diagnóstico breve (2-3 líneas) y exactamente 2 recomendaciones prácticas y concretas para el hogar.

$dataSummary
''';

        final response = await model.generateContent([Content.text(prompt)]);
        if (response.text != null && response.text!.trim().isNotEmpty) {
          return response.text!.trim();
        }
      } catch (_) {
        // Fallback a motor heurístico si falla la llamada
      }
    }

    // Motor Heurístico Inteligente Local (0 Costos, 100% Confiable Offline)
    return _generateLocalHeuristicDiagnosis(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: balance,
      savingsRate: savingsRate.toDouble(),
      sortedCategories: sortedCategories,
    );

  }

  static String _generateLocalHeuristicDiagnosis({
    required double totalIncome,
    required double totalExpense,
    required double balance,
    required double savingsRate,
    required List<MapEntry<String, double>> sortedCategories,
  }) {
    final topCatName = sortedCategories.isNotEmpty
        ? AppCategories.getCategoryById(sortedCategories.first.key).name
        : 'Gastos Generales';

    if (totalIncome == 0 && totalExpense == 0) {
      return 'No hay suficientes movimientos financieros registrados en el periodo seleccionado para generar un diagnóstico.';
    }

    final StringBuffer buffer = StringBuffer();

    if (balance >= 0) {
      buffer.writeln(
          'Diagnóstico: Salud financiera familiar favorable con un superávit de Bs ${balance.toStringAsFixed(2)} (Tasa de ahorro del ${savingsRate.toStringAsFixed(1)}%).');
      buffer.writeln('\nRecomendaciones Prácticas:');
      buffer.writeln(
          '1. Asignar al menos el 50% del saldo positivo actual (Bs ${(balance * 0.5).toStringAsFixed(2)}) a un fondo de emergencia familiar.');
      if (sortedCategories.isNotEmpty) {
        buffer.writeln(
            '2. Tu mayor concentración de gasto está en "$topCatName" (Bs ${sortedCategories.first.value.toStringAsFixed(2)}). Establecer un tope semanal ayudará a elevar el margen de ahorro.');
      } else {
        buffer.writeln(
            '2. Mantener la constancia en el registro de comprobantes diarios para no perder la trazabilidad de egresos.');
      }
    } else {
      buffer.writeln(
          'Diagnóstico: Alerta de déficit financiero familiar de Bs ${balance.abs().toStringAsFixed(2)}. Los egresos superan los ingresos en el periodo analizado.');
      buffer.writeln('\nRecomendaciones Prácticas:');
      if (sortedCategories.isNotEmpty) {
        buffer.writeln(
            '1. Revisar de inmediato las compras no esenciales en "$topCatName", reduciendo al menos un 15% para equilibrar el presupuesto.');
      } else {
        buffer.writeln('1. Pausar gastos prescindibles hasta estabilizar el balance del hogar.');
      }
      buffer.writeln(
          '2. Planificar un presupuesto familiar cerrado para la próxima semana con topes estrictos de consumo.');
    }

    return buffer.toString();
  }
}
