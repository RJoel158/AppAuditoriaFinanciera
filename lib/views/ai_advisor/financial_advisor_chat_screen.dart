import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/chat_message.dart';
import '../../models/financial_record.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_ai_service.dart';

class FinancialAdvisorChatScreen extends StatefulWidget {
  const FinancialAdvisorChatScreen({super.key});

  @override
  State<FinancialAdvisorChatScreen> createState() => _FinancialAdvisorChatScreenState();
}

class _FinancialAdvisorChatScreenState extends State<FinancialAdvisorChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _initialized = false;
  bool _hasCustomApiKey = false;

  final List<String> _quickPrompts = [
    '💡 ¿Cómo podemos ahorrar más este mes?',
    '📊 ¿En qué se fue la mayor parte del dinero?',
    '🎯 ¿Cuál es el presupuesto semanal recomendado?',
    '🛒 ¿Cómo podemos recortar gastos de comida?',
    '🔍 ¿Nos alcanza para un gasto extra de Bs 200?',
  ];

  @override
  void initState() {
    super.initState();
    _checkApiKeyStatus();
  }

  Future<void> _checkApiKeyStatus() async {
    final key = await GeminiAiService.getApiKey();
    if (mounted) {
      setState(() {
        _hasCustomApiKey = key.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initWelcomeMessage(FamilyFinancialContext ctx) {
    if (_initialized) return;
    _initialized = true;

    final userName = _authService.currentUser?.displayName ?? 'Familiar';
    final balanceText = CurrencyFormatter.format(ctx.balance);

    _messages.add(
      ChatMessage(
        id: 'welcome',
        text: '¡Hola $userName! Soy tu Asesor Financiero Familiar.\n\n'
            'Tengo acceso al balance del hogar en tiempo real (Balance actual: **$balanceText**).\n\n'
            'Puedo analizar en qué gastan más, evaluar si les alcanza para una compra o darles un plan de ahorro. ¿En qué te oriento hoy?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  void _showApiKeyDialog() async {
    final currentKey = await GeminiAiService.getApiKey();
    final keyController = TextEditingController(text: currentKey);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Text('Clave Gemini AI (Opcional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Puedes ingresar tu API Key gratuita de Google AI Studio para activar respuestas ilimitadas y creativas en la nube con Gemini 1.5 Flash.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'API Key de Gemini',
                hintText: 'AIzaSy...',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Si no tienes una clave, la app continuará usando su motor analítico local en tiempo real sin costo.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
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
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final enteredKey = keyController.text.trim();
              await GeminiAiService.saveApiKey(enteredKey);
              nav.pop();
              if (mounted) {
                _checkApiKeyStatus();
                messenger.showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.primary,
                    content: Text(
                      enteredKey.isNotEmpty
                          ? 'Clave de Gemini guardada. Respuestas inteligentes activadas.'
                          : 'Modo local activo.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],

      ),
    );
  }

  Future<void> _sendMessage(String text, FamilyFinancialContext context) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _textController.clear();
    });

    _scrollToBottom();

    try {
      final response = await GeminiAiService.chatWithAdvisor(
        userMessage: text.trim(),
        history: _messages,
        context: context,
      );

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              text: response,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
              text: 'Ocurrió un inconveniente al procesar tu consulta. Intenta de nuevo.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  FamilyFinancialContext _buildContextFromRecords(List<FinancialRecord> records) {
    final now = DateTime.now();
    final currentMonthRecords = records.where(
      (r) => r.date.year == now.year && r.date.month == now.month,
    ).toList();

    double totalIncome = 0.0;
    double totalExpense = 0.0;
    final Map<String, double> categoryExpenses = {};

    for (final r in currentMonthRecords) {
      if (r.type == RecordType.income) {
        totalIncome += r.amount;
      } else {
        totalExpense += r.amount;
        categoryExpenses[r.category] = (categoryExpenses[r.category] ?? 0.0) + r.amount;
      }
    }

    final user = _authService.currentUser;

    return FamilyFinancialContext(
      userName: user?.displayName ?? 'Familiar',
      userRole: user?.role.label ?? 'Miembro',
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      balance: totalIncome - totalExpense,
      categoryExpenses: categoryExpenses,
      totalRecordsCount: currentMonthRecords.length,
      recentRecords: currentMonthRecords,
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FinancialRecord>>(
      stream: _firestoreService.getRecordsStream(limit: 500),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];
        final financialContext = _buildContextFromRecords(records);

        if (!_initialized && snapshot.hasData) {
          _initWelcomeMessage(financialContext);
        }

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Asesor Financiero IA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      Text(
                        _hasCustomApiKey ? 'Gemini 1.5 Flash • Nube' : 'Motor Analítico Local • Activo',
                        style: const TextStyle(fontSize: 10, color: AppColors.primary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.vpn_key_rounded,
                  color: _hasCustomApiKey ? AppColors.accent : AppColors.textMuted,
                  size: 20,
                ),
                tooltip: 'Configurar Gemini API Key',
                onPressed: _showApiKeyDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                tooltip: 'Reiniciar Chat',
                onPressed: () {
                  setState(() {
                    _messages.clear();
                    _initialized = false;
                    _initWelcomeMessage(financialContext);
                  });
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Badge Informativo Superior con Balance del Mes
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          'Balance Mes: ${CurrencyFormatter.format(financialContext.balance)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: financialContext.balance >= 0 ? AppColors.income : AppColors.expense,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${financialContext.totalRecordsCount} movimientos',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

              // 2. Lista de Mensajes
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg);
                  },
                ),
              ),

              // 3. Indicador de análisis del Asesor
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withAlpha(50)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            SizedBox(width: 8),
                            Text('El asesor está analizando sus finanzas...', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. Barra de Sugerencias Rápidas (Chips)
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _quickPrompts.length,
                  itemBuilder: (context, index) {
                    final prompt = _quickPrompts[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        backgroundColor: AppColors.surfaceLight.withAlpha(60),
                        side: const BorderSide(color: AppColors.border),
                        label: Text(prompt, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary)),
                        onPressed: _isLoading ? null : () => _sendMessage(prompt, financialContext),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // 5. Input de Mensaje
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border, width: 1)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (val) => _sendMessage(val, financialContext),
                          decoration: InputDecoration(
                            hintText: 'Pregúntale a tu asesor familiar...',
                            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            filled: true,
                            fillColor: AppColors.surfaceLight.withAlpha(40),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        onPressed: _isLoading
                            ? null
                            : () => _sendMessage(_textController.text, financialContext),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(6),
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 14),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
                border: Border.all(
                  color: isUser ? Colors.transparent : AppColors.border,
                ),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
