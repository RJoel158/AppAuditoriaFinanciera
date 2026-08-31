import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/gemini_config.dart';
import '../core/constants/app_categories.dart';
import '../models/chat_message.dart';
import '../models/financial_record.dart';

class FamilyFinancialContext {
  final String userName;
  final String userRole;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final Map<String, double> categoryExpenses;
  final int totalRecordsCount;
  final List<FinancialRecord> recentRecords;

  const FamilyFinancialContext({
    required this.userName,
    required this.userRole,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.categoryExpenses,
    required this.totalRecordsCount,
    this.recentRecords = const [],
  });

  String toFormattedSummary() {
    final savingsRate = totalIncome > 0 ? ((balance / totalIncome) * 100).clamp(-100, 100) : 0.0;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;
    final daysRemaining = (daysInMonth - currentDay).clamp(0, 31);
    final dailyAvgExpense = currentDay > 0 ? totalExpense / currentDay : 0.0;
    final projectedMonthExpense = totalExpense + (dailyAvgExpense * daysRemaining);
    final projectedBalance = totalIncome - projectedMonthExpense;

    final sortedCategories = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topExpenses = sortedCategories.take(5).map((e) {
      final cat = AppCategories.getCategoryById(e.key);
      final percent = totalExpense > 0 ? (e.value / totalExpense * 100).toStringAsFixed(1) : '0';
      return '- ${cat.name}: Bs ${e.value.toStringAsFixed(2)} ($percent% del total)';
    }).join('\n');

    final recentRecordsText = recentRecords.take(8).map((r) {
      final sign = r.type == RecordType.income ? '+' : '-';
      final cat = AppCategories.getCategoryById(r.category).name;
      return '- ${r.date.day}/${r.date.month}: "${r.title}" ($cat) $sign Bs ${r.amount.toStringAsFixed(2)} por ${r.registeredBy}';
    }).join('\n');

    return '''
Contexto Financiero Auditado del Hogar (${now.month}/${now.year}):
- País / Moneda: Bolivia (Bolivianos - Bs / BOB)
- Miembro que consulta: $userName ($userRole)
- Ingresos Totales del Mes: Bs ${totalIncome.toStringAsFixed(2)}
- Egresos Totales del Mes: Bs ${totalExpense.toStringAsFixed(2)}
- Balance Neto Actual: Bs ${balance.toStringAsFixed(2)} (Tasa de Ahorro: ${savingsRate.toStringAsFixed(1)}%)
- Gasto Promedio Diario: Bs ${dailyAvgExpense.toStringAsFixed(2)}/día (Día $currentDay de $daysInMonth)
- Proyección de Balance al Cierre del Mes: Bs ${projectedBalance.toStringAsFixed(2)}
- Total Transacciones Registradas en App: $totalRecordsCount

Desglose de Gastos por Categorías:
${topExpenses.isNotEmpty ? topExpenses : "- No hay gastos registrados aún en el periodo."}

Últimos Movimientos Reales Registrados en la App:
${recentRecordsText.isNotEmpty ? recentRecordsText : "- Sin transacciones recientes."}
''';
  }
}

class GeminiAiService {
  static const String _prefApiKey = 'custom_gemini_api_key';
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Obtener API Key global del proyecto o guardada en SharedPreferences
  static Future<String> getApiKey() async {
    if (GeminiConfig.apiKey.trim().isNotEmpty) {
      return GeminiConfig.apiKey.trim();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefApiKey);
      if (saved != null && saved.trim().isNotEmpty) {
        return saved.trim();
      }
    } catch (_) {}
    return _defaultApiKey;
  }

  /// Guardar API Key personalizada
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    if (apiKey.trim().isEmpty) {
      await prefs.remove(_prefApiKey);
    } else {
      await prefs.setString(_prefApiKey, apiKey.trim());
    }
  }

  /// Conversación profunda y variada con el Asesor Financiero Familiar IA
  static Future<String> chatWithAdvisor({
    required String userMessage,
    required List<ChatMessage> history,
    required FamilyFinancialContext context,
    String? customApiKey,
  }) async {
    final apiKey = customApiKey?.isNotEmpty == true ? customApiKey! : await getApiKey();
    final contextSummary = context.toFormattedSummary();

    if (apiKey.isNotEmpty) {
      final systemPrompt = '''
Eres "FamFinance Advisor", el Asesor Financiero Familiar experto en economía doméstica en Bolivia.
Eres sumamente analítico, directo, empático y práctico.
Tu objetivo es dar recomendaciones concretas, presupuestos detallados y estrategias de ahorro reales en Bolivianos (Bs / BOB).

DIRECTRICES OBLIGATORIAS:
1. SI TE PIDEN UN PRESUPUESTO (ej. para familia de 3, 4, 5 personas o general):
   - NUNCA respondas con frases vacías como "Oh muy bien papá".
   - ENTREGA INMEDIATAMENTE una estructura de presupuesto completa con porcentajes y montos estimados en Bs (Alimentación/Mercado, Vivienda/Servicios, Educación/Salud, Transporte, Imprevistos/Ahorro).
   - Compara el presupuesto teórico con los gastos que la familia YA tiene registrados en la app.
2. SI PREGUNTAN SI ALCANZA PARA UNA COMPRA O GASTO EXTRA:
   - Analiza el balance actual (Bs ${context.balance.toStringAsFixed(2)}), el ritmo de gasto diario y la proyección de fin de mes.
   - Da un veredicto claro: Recomendable / Ajustado / No recomendable, con un monto tope seguro.
3. ADAPTACIÓN A BOLIVIA:
   - Considera la realidad boliviana: compras en mercados populares vs supermercados, colegios, servicios básicos (luz, agua, gas/garrafas), transporte (micros/trufis/combustible).
4. TONO:
   - Profesional pero familiar y motivador. Usa viñetas claras y cifras en negrita.

$contextSummary
''';

      // Intentar primero con gemini-flash-latest, luego con gemini-1.5-pro si hay alta demanda
      final modelCandidates = ['gemini-flash-latest', 'gemini-1.5-pro'];

      for (final modelName in modelCandidates) {
        try {
          final model = GenerativeModel(
            model: modelName,
            apiKey: apiKey,
            generationConfig: GenerationConfig(
              temperature: 0.6,
              maxOutputTokens: 2048,
            ),
            systemInstruction: Content.system(systemPrompt),
          );

          // Construir historial multi-turno
          final contents = <Content>[];
          for (final msg in history.take(8)) {
            if (msg.isUser) {
              contents.add(Content.text('Usuario: ${msg.text}'));
            } else {
              contents.add(Content.model([TextPart(msg.text)]));
            }
          }
          contents.add(Content.text(userMessage));

          final response = await model.generateContent(contents).timeout(
            const Duration(seconds: 25),
          );


          if (response.text != null && response.text!.trim().isNotEmpty) {
            return response.text!.trim();
          }
        } catch (_) {
          // Si falla o agota el tiempo de espera, probar el siguiente modelo o ir al motor enriquecido
        }
      }
    }

    // Motor Analítico Dinámico Enriquecido (Offline o Contingencia)
    return _generateEnrichedLocalResponse(userMessage, context);
  }

  /// Diagnóstico estático de reporte
  static Future<String> generateFinancialDiagnosis({
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> categoryExpenses,
    required int totalTransactions,
    List<FinancialRecord> recentRecords = const [],
    String? customApiKey,
  }) async {
    final context = FamilyFinancialContext(
      userName: 'Familia',
      userRole: 'Hogar',
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      categoryExpenses: categoryExpenses,
      totalRecordsCount: totalTransactions,
      recentRecords: recentRecords,
    );

    return chatWithAdvisor(
      userMessage: 'Genera un diagnóstico financiero detallado del periodo y 2 recomendaciones concretas de ahorro familiar en Bolivia basadas en estos números.',
      history: [],
      context: context,
      customApiKey: customApiKey,
    );
  }

  /// Motor Analítico Local Dinámico (Cálculos reales avanzados para Bolivia)
  static String _generateEnrichedLocalResponse(String message, FamilyFinancialContext ctx) {
    final lower = message.toLowerCase();
    final balance = ctx.balance;
    final totalIncome = ctx.totalIncome;
    final totalExpense = ctx.totalExpense;
    final savingsRate = totalIncome > 0 ? ((balance / totalIncome) * 100).clamp(-100, 100) : 0.0;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDay = now.day;
    final daysRemaining = (daysInMonth - currentDay).clamp(0, 31);
    final dailyAvgExpense = currentDay > 0 ? totalExpense / currentDay : 0.0;
    final projectedMonthExpense = totalExpense + (dailyAvgExpense * daysRemaining);
    final projectedBalance = totalIncome - projectedMonthExpense;

    final sortedCategories = ctx.categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCat = sortedCategories.isNotEmpty ? sortedCategories.first : null;
    final topCatName = topCat != null ? AppCategories.getCategoryById(topCat.key).name : 'Gastos Generales';
    final topCatAmount = topCat?.value ?? 0.0;
    final topCatPercent = totalExpense > 0 ? (topCatAmount / totalExpense * 100).toStringAsFixed(1) : '0';

    final secondCat = sortedCategories.length > 1 ? sortedCategories[1] : null;
    final secondCatName = secondCat != null ? AppCategories.getCategoryById(secondCat.key).name : '';
    final secondCatAmount = secondCat?.value ?? 0.0;

    // 1. Consultas sobre Presupuesto Familiar (ej. familia de 5, presupuesto general)
    if (lower.contains('presupuesto') || lower.contains('familia') || lower.contains('bolivia') || lower.contains('distribuir') || lower.contains('cuanto')) {
      final baseIncome = totalIncome > 0 ? totalIncome : (totalExpense > 0 ? totalExpense * 1.2 : 4500.0);
      final isFamily5 = lower.contains('5') || lower.contains('cinco');

      final foodPct = isFamily5 ? 0.38 : 0.35;
      final housePct = isFamily5 ? 0.22 : 0.25;
      final eduHealthPct = isFamily5 ? 0.18 : 0.15;
      final transportPct = 0.10;
      final savingsPct = 0.12;

      final buffer = StringBuffer();
      buffer.writeln('📋 **Plan de Presupuesto Familiar en Bolivia${isFamily5 ? ' (5 Integrantes)' : ''}:**\n');
      buffer.writeln('Tomando como base sus ingresos de **Bs ${baseIncome.toStringAsFixed(2)}**, la distribución financiera recomendada es:\n');
      buffer.writeln('1. **🛒 Alimentación y Mercado (${(foodPct * 100).toInt()}%):** Bs ${(baseIncome * foodPct).toStringAsFixed(2)}/mes (~Bs ${((baseIncome * foodPct) / 4.2).toStringAsFixed(2)}/semana).');
      buffer.writeln('   - *Tip:* Priorizar compras mayoristas de abarrotes y verduras en mercado central.');
      buffer.writeln('2. **🏠 Vivienda y Servicios (${(housePct * 100).toInt()}%):** Bs ${(baseIncome * housePct).toStringAsFixed(2)}/mes.');
      buffer.writeln('   - Cubre alquiler/mantenimiento, luz, agua, gas e internet.');
      buffer.writeln('3. **📚 Educación, Colegios y Salud (${(eduHealthPct * 100).toInt()}%):** Bs ${(baseIncome * eduHealthPct).toStringAsFixed(2)}/mes.');
      buffer.writeln('   - Mensualidades escolares, fotocopias, medicinas y emergencias médicas.');
      buffer.writeln('4. **🚌 Transporte y Movilidad (${(transportPct * 100).toInt()}%):** Bs ${(baseIncome * transportPct).toStringAsFixed(2)}/mes.');
      buffer.writeln('   - Pasajes diarios en micros/trufis o gasolina.');
      buffer.writeln('5. **💰 Fondo de Ahorro y Reserva (${(savingsPct * 100).toInt()}%):** Bs ${(baseIncome * savingsPct).toStringAsFixed(2)}/mes.');

      if (totalExpense > 0) {
        buffer.writeln('\n🔍 **Comparativa con sus Registros en la App:**');
        buffer.writeln('• Llevan gastados **Bs ${totalExpense.toStringAsFixed(2)}** en el mes.');
        buffer.writeln('• Su mayor gasto es en **$topCatName** (Bs ${topCatAmount.toStringAsFixed(2)}, $topCatPercent% del total).');
      }

      return buffer.toString();
    }

    // 2. Consultas sobre Ahorro
    if (lower.contains('ahorrar') || lower.contains('ahorro') || lower.contains('guardar') || lower.contains('optimizar')) {
      final buffer = StringBuffer();
      if (balance > 0) {
        final targetReserve = balance * 0.45;
        buffer.writeln('📈 **Análisis de Ahorro Familiar:**');
        buffer.writeln('Actualmente tienen un superávit de **Bs ${balance.toStringAsFixed(2)}** (tasa de ahorro del **${savingsRate.toStringAsFixed(1)}%**).');
        buffer.writeln('\n💡 **Estrategias Recomendadas:**');
        buffer.writeln('1. **Fondo de Reserva:** Separen de inmediato **Bs ${targetReserve.toStringAsFixed(2)}** en una cuenta aparte antes de compras variables.');
        if (topCat != null) {
          final potentialSavings = topCatAmount * 0.15;
          buffer.writeln('2. **Optimización en "$topCatName":** Al representar el $topCatPercent% de sus egresos (Bs ${topCatAmount.toStringAsFixed(2)}), una reducción del 15% liberaría **Bs ${potentialSavings.toStringAsFixed(2)}** adicionales.');
        }
      } else {
        buffer.writeln('⚠️ **Alerta de Ahorro:**');
        buffer.writeln('En este momento registran un déficit de **Bs ${balance.abs().toStringAsFixed(2)}**. Los egresos (Bs ${totalExpense.toStringAsFixed(2)}) han rebasado los ingresos.');
        buffer.writeln('\n🎯 **Plan de Choque:**');
        buffer.writeln('1. Frenar compras no esenciales en "$topCatName" durante los próximos $daysRemaining días.');
        buffer.writeln('2. Limitar el gasto diario general a un máximo de **Bs ${(totalIncome > totalExpense ? (balance / daysRemaining) : 0).toStringAsFixed(2)}/día** para cerrar el mes en equilibrio.');
      }
      return buffer.toString();
    }

    // 3. Consultas sobre Categorías y Dónde se fue el dinero
    if (lower.contains('gastamos') || lower.contains('mayor') || lower.contains('mas') || lower.contains('más') || lower.contains('categoria') || lower.contains('categoría') || lower.contains('donde')) {
      final buffer = StringBuffer();
      buffer.writeln('📊 **Radiografía de Gastos del Mes:**');
      if (sortedCategories.isNotEmpty) {
        buffer.writeln('• **1° $topCatName:** Bs ${topCatAmount.toStringAsFixed(2)} ($topCatPercent% del presupuesto).');
        if (secondCat != null) {
          final secondPercent = totalExpense > 0 ? (secondCatAmount / totalExpense * 100).toStringAsFixed(1) : '0';
          buffer.writeln('• **2° $secondCatName:** Bs ${secondCatAmount.toStringAsFixed(2)} ($secondPercent%).');
        }
        buffer.writeln('\n🔍 **Diagnóstico:** El $topCatPercent% de su liquidez se concentró en "$topCatName". Establecer un tope semanal para esta categoría es la clave para evitar desbalances.');
      } else {
        buffer.writeln('No hay gastos suficientes registrados en el mes para desglosar el consumo.');
      }
      return buffer.toString();
    }

    // 4. Consultas sobre si alcanza para un gasto extra
    if (lower.contains('alcanza') || lower.contains('comprar') || lower.contains('gastar') || lower.contains('salir') || lower.contains('extra') || lower.contains('puedo')) {
      final buffer = StringBuffer();
      buffer.writeln('🔍 **Evaluación de Factibilidad de Gasto:**');
      buffer.writeln('• Balance disponible hoy: **Bs ${balance.toStringAsFixed(2)}**');
      buffer.writeln('• Ritmo de gasto actual: **Bs ${dailyAvgExpense.toStringAsFixed(2)}/día**');
      buffer.writeln('• Proyección a fin de mes: **Bs ${projectedBalance.toStringAsFixed(2)}**');

      if (balance > 350 && projectedBalance > 0) {
        final safeLimit = balance * 0.35;
        buffer.writeln('\n✅ **Veredicto:** Sí es viable realizar un gasto extra, pero les sugiero mantenerlo por debajo de **Bs ${safeLimit.toStringAsFixed(2)}** para no comprometer el colchón de seguridad.');
      } else if (balance > 0) {
        buffer.writeln('\n⚠️ **Veredicto:** El balance es positivo pero ajustado. Si realizan un gasto extra, procuren que no supere **Bs ${(balance * 0.2).toStringAsFixed(2)}** o compensen reduciendo en "$topCatName".');
      } else {
        buffer.writeln('\n❌ **Veredicto:** No es recomendable realizar gastos discrecionales ahora. Se proyecta un cierre de mes en déficit si se mantiene el ritmo actual.');
      }
      return buffer.toString();
    }

    // 5. Saludo general analítico
    return '¡Hola ${ctx.userName}! Como tu Asesor Familiar en Bolivia, he auditado las finanzas del mes:\n\n'
        '• **Ingresos Registrados:** Bs ${totalIncome.toStringAsFixed(2)}\n'
        '• **Egresos Registrados:** Bs ${totalExpense.toStringAsFixed(2)} (Promedio: Bs ${dailyAvgExpense.toStringAsFixed(2)}/día)\n'
        '• **Balance Actual:** Bs ${balance.toStringAsFixed(2)} (Proyección a fin de mes: Bs ${projectedBalance.toStringAsFixed(2)})\n\n'
        'Puedes consultarme sobre armar un presupuesto para tu familia, analizar un gasto específico o recomendaciones para recortar compras.';
  }
}
