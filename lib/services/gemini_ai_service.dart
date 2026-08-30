import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/constants/app_categories.dart';
import '../models/chat_message.dart';

class FamilyFinancialContext {
  final String userName;
  final String userRole;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final Map<String, double> categoryExpenses;
  final int totalRecordsCount;

  const FamilyFinancialContext({
    required this.userName,
    required this.userRole,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.categoryExpenses,
    required this.totalRecordsCount,
  });

  String toFormattedSummary() {
    final savingsRate = totalIncome > 0 ? ((balance / totalIncome) * 100).clamp(-100, 100) : 0.0;

    final sortedCategories = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topExpenses = sortedCategories.take(4).map((e) {
      final cat = AppCategories.getCategoryById(e.key);
      final percent = totalExpense > 0 ? (e.value / totalExpense * 100).toStringAsFixed(1) : '0';
      return '- ${cat.name}: Bs ${e.value.toStringAsFixed(2)} ($percent%)';
    }).join('\n');

    return '''
Contexto Financiero Familiar Actual:
- Usuario que consulta: $userName ($userRole)
- Ingresos del Mes: Bs ${totalIncome.toStringAsFixed(2)}
- Egresos del Mes: Bs ${totalExpense.toStringAsFixed(2)}
- Balance / Ahorro Actual: Bs ${balance.toStringAsFixed(2)}
- Tasa de Ahorro: ${savingsRate.toStringAsFixed(1)}%
- Total Transacciones Registradas: $totalRecordsCount
Principales Categorías de Gasto:
${topExpenses.isNotEmpty ? topExpenses : "- No hay gastos registrados aún."}
''';
  }
}

class GeminiAiService {
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Conversación fluida con el Asesor Financiero Familiar IA
  static Future<String> chatWithAdvisor({
    required String userMessage,
    required List<ChatMessage> history,
    required FamilyFinancialContext context,
    String? customApiKey,
  }) async {
    final apiKey = customApiKey?.isNotEmpty == true ? customApiKey! : _defaultApiKey;
    final contextSummary = context.toFormattedSummary();

    if (apiKey.isNotEmpty) {
      try {
        final systemPrompt = '''
Eres el Asesor Financiero Familiar oficial del hogar. Eres cercano, empático, claro y pedagógico.
Tu misión es ayudar a la familia a tomar mejores decisiones de ahorro y control de gastos sin usar tecnicismos complejos.

Reglas estrictas:
1. Responde de forma concisa (máximo 2 a 4 párrafos cortos o viñetas).
2. Basa tus cálculos y consejos estrictamente en los datos numéricos provistos a continuación.
3. Si el usuario pregunta si les alcanza para un gasto extra, evalúa su balance actual y recomienda montos prudentes.
4. Si sugieres metas, hazlas amigables y alcanzables para el hogar.

$contextSummary
''';

        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: apiKey,
          generationConfig: GenerationConfig(
            temperature: 0.3,
            maxOutputTokens: 350,
          ),
          systemInstruction: Content.system(systemPrompt),
        );

        // Construir historial de conversación
        final contents = <Content>[];
        for (final msg in history.take(8)) {
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
      } catch (_) {}
    }

    // Fallback Inteligente Local en caso de no tener API Key activa o estar offline
    return _generateLocalChatbotResponse(userMessage, context);
  }

  /// Diagnóstico estático de reporte
  static Future<String> generateFinancialDiagnosis({
    required double totalIncome,
    required double totalExpense,
    required Map<String, double> categoryExpenses,
    required int totalTransactions,
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
    );

    return chatWithAdvisor(
      userMessage: 'Genera un diagnóstico general breve del mes y exactamente 2 recomendaciones de ahorro para el hogar.',
      history: [],
      context: context,
      customApiKey: customApiKey,
    );
  }

  /// Motor de respuestas locales offline para el Chatbot
  static String _generateLocalChatbotResponse(String message, FamilyFinancialContext ctx) {
    final lower = message.toLowerCase();
    final balance = ctx.balance;
    final sortedCategories = ctx.categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCatName = sortedCategories.isNotEmpty
        ? AppCategories.getCategoryById(sortedCategories.first.key).name
        : 'Gastos Generales';
    final topCatAmount = sortedCategories.isNotEmpty ? sortedCategories.first.value : 0.0;

    if (lower.contains('ahorrar') || lower.contains('ahorro') || lower.contains('guardar')) {
      if (balance > 0) {
        return 'Actualmente tienen un saldo a favor de Bs ${balance.toStringAsFixed(2)}. Les recomiendo separar el 40% de este remanente (Bs ${(balance * 0.4).toStringAsFixed(2)}) a un fondo de reserva antes de que termine el mes.';
      } else {
        return 'En este momento los egresos superan a los ingresos por Bs ${balance.abs().toStringAsFixed(2)}. La mejor forma de recuperar el ahorro es pausar compras secundarias y fijar un límite estricto para "$topCatName".';
      }
    }

    if (lower.contains('gastamos') || lower.contains('mayor') || lower.contains('mas') || lower.contains('más') || lower.contains('categoria') || lower.contains('categoría')) {
      if (sortedCategories.isNotEmpty) {
        final percent = ctx.totalExpense > 0 ? (topCatAmount / ctx.totalExpense * 100).toStringAsFixed(1) : '0';
        return 'La categoría con mayor consumo es **$topCatName** con **Bs ${topCatAmount.toStringAsFixed(2)}** (representa el $percent% del total de egresos). Planificar las compras de esta categoría semanalmente les ahorrará dinero.';
      } else {
        return 'Aún no tienen suficientes gastos registrados este mes para identificar la categoría principal.';
      }
    }

    if (lower.contains('alcanza') || lower.contains('comprar') || lower.contains('gastar') || lower.contains('salir')) {
      if (balance > 200) {
        return 'Tienen un margen disponible de Bs ${balance.toStringAsFixed(2)}. Sí les alcanza para un gasto moderado, pero les sugiero no destinar más de Bs ${(balance * 0.3).toStringAsFixed(2)} para mantener su colchón de seguridad.';
      } else {
        return 'El balance actual es ajustado (Bs ${balance.toStringAsFixed(2)}). Les recomiendo posponer gastos no urgentes hasta el próximo ingreso.';
      }
    }

    if (lower.contains('presupuesto') || lower.contains('semanal') || lower.contains('recomienda')) {
      final safeWeekly = ctx.totalIncome > 0 ? (ctx.totalIncome / 4) : 0.0;
      return 'Para mantener estabilidad, el presupuesto semanal sugerido para todo el hogar es de aproximadamente **Bs ${safeWeekly.toStringAsFixed(2)}**, priorizando alimentación y servicios básicos.';
    }

    // Respuesta general de saludo / ayuda
    return '¡Hola ${ctx.userName}! Analizando sus registros, este mes llevan un total de **Bs ${ctx.totalIncome.toStringAsFixed(2)}** en ingresos y **Bs ${ctx.totalExpense.toStringAsFixed(2)}** en egresos (Balance: **Bs ${balance.toStringAsFixed(2)}**).\n\nPuedes preguntarme sobre cómo optimizar una categoría, sugerir un presupuesto o consultar si les alcanza para un gasto.';
  }
}
