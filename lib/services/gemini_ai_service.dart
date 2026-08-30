import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
Contexto Financiero Familiar Auditado (${now.month}/${now.year}):
- Miembro que consulta: $userName ($userRole)
- Ingresos Totales del Mes: Bs ${totalIncome.toStringAsFixed(2)}
- Egresos Totales del Mes: Bs ${totalExpense.toStringAsFixed(2)}
- Balance Neto Actual: Bs ${balance.toStringAsFixed(2)} (Tasa de Ahorro: ${savingsRate.toStringAsFixed(1)}%)
- Gasto Promedio Diario: Bs ${dailyAvgExpense.toStringAsFixed(2)}/día (Día $currentDay de $daysInMonth)
- Proyección de Balance a Fin de Mes: Bs ${projectedBalance.toStringAsFixed(2)}
- Total Movimientos Registrados: $totalRecordsCount

Desglose de Gastos por Categorías:
${topExpenses.isNotEmpty ? topExpenses : "- No hay gastos registrados aún en el periodo."}

Últimos Movimientos Reales Registrados:
${recentRecordsText.isNotEmpty ? recentRecordsText : "- Sin transacciones recientes."}
''';
  }
}

class GeminiAiService {
  static const String _prefApiKey = 'custom_gemini_api_key';
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Obtener API Key guardada en SharedPreferences o por defecto
  static Future<String> getApiKey() async {
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
      try {
        final systemPrompt = '''
Eres el Asesor Financiero Familiar de cabecera de este hogar. Eres inteligente, empático, motivador y sumamente analítico.
Hablas con tono profesional pero amigable, accesible para cualquier integrante de la familia.

Tus directrices:
1. Responde de forma personalizada analizando las cifras reales del contexto provisto.
2. Si preguntan sobre un gasto, compara con el balance actual, la proyección de fin de mes y el gasto diario.
3. Si preguntan sobre ahorro o categorías, menciona nombres exactos de los movimientos y porcentajes de las categorías.
4. Varía tu lenguaje de forma natural. Ofrece sugerencias innovadoras y tácticas caseras viables.
5. Mantén respuestas estructuradas con párrafos breves o viñetas cuando sea apropiado.

$contextSummary
''';

        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.7, // Respuestas variadas, naturales y creativas
            maxOutputTokens: 500,
          ),
          systemInstruction: Content.system(systemPrompt),
        );

        // Construir historial multi-turno
        final contents = <Content>[];
        for (final msg in history.take(10)) {
          if (msg.isUser) {
            contents.add(Content.text('Usuario: ${msg.text}'));
          } else {
            contents.add(Content.model([TextPart(msg.text)]));
          }
        }
        contents.add(Content.text(userMessage));

        final response = await model.generateContent(contents);
        if (response.text != null && response.text!.trim().isNotEmpty) {
          return response.text!.trim();
        }
      } catch (e) {
        // Si falla la API por cuota o conexión, continuar al motor dinámico enriquecido
      }
    }

    // Motor Analítico Dinámico Enriquecido (Local sin API Key)
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
      userMessage: 'Genera un diagnóstico financiero detallado del periodo y 2 recomendaciones concretas de ahorro basadas en los datos.',
      history: [],
      context: context,
      customApiKey: customApiKey,
    );
  }

  /// Motor Analítico Local Dinámico (Cálculos reales avanzados)
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

    // 1. Consultas sobre Ahorro
    if (lower.contains('ahorrar') || lower.contains('ahorro') || lower.contains('guardar') || lower.contains('optimizar')) {
      final buffer = StringBuffer();
      if (balance > 0) {
        final targetReserve = balance * 0.45;
        buffer.writeln('📈 **Análisis de Ahorro Familiar:**');
        buffer.writeln('Actualmente tienen un superávit de **Bs ${balance.toStringAsFixed(2)}** (tasa de ahorro del **${savingsRate.toStringAsFixed(1)}%**).');
        buffer.writeln('\n💡 **Estrategias Recomendadas:**');
        buffer.writeln('1. **Fondo de Reserva:** Separen de inmediato **Bs ${targetReserve.toStringAsFixed(2)}** antes de incurrir en nuevos gastos variables.');
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

    // 2. Consultas sobre Categorías y Dónde se fue el dinero
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

    // 3. Consultas sobre si alcanza para un gasto extra
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

    // 4. Consultas sobre Presupuesto
    if (lower.contains('presupuesto') || lower.contains('semanal') || lower.contains('recomienda') || lower.contains('meta')) {
      final safeWeekly = totalIncome > 0 ? (totalIncome / 4.2) : 0.0;
      final buffer = StringBuffer();
      buffer.writeln('🎯 **Propuesta de Presupuesto Familiar Semanal:**');
      buffer.writeln('Con base en sus ingresos de Bs ${totalIncome.toStringAsFixed(2)}:');
      buffer.writeln('• **Límite Semanal Sugerido:** Bs ${safeWeekly.toStringAsFixed(2)}/semana.');
      buffer.writeln('• **Asignación para $topCatName:** Máximo Bs ${(safeWeekly * 0.45).toStringAsFixed(2)}/semana.');
      buffer.writeln('• **Meta de Ahorro:** Reservar Bs ${(safeWeekly * 0.2).toStringAsFixed(2)} semanales.');
      return buffer.toString();
    }

    // 5. Saludo general analítico
    return '¡Hola ${ctx.userName}! Como tu Asesor Familiar, he auditado las finanzas del mes:\n\n'
        '• **Ingresos:** Bs ${totalIncome.toStringAsFixed(2)}\n'
        '• **Egresos:** Bs ${totalExpense.toStringAsFixed(2)} (Promedio: Bs ${dailyAvgExpense.toStringAsFixed(2)}/día)\n'
        '• **Balance Actual:** Bs ${balance.toStringAsFixed(2)} (Proyección a fin de mes: Bs ${projectedBalance.toStringAsFixed(2)})\n\n'
        '¿Deseas evaluar si les alcanza para un gasto, optimizar una categoría o armar un presupuesto semanal?';
  }
}
