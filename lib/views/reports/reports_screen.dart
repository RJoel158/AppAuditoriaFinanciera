import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_categories.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/financial_record.dart';
import '../../services/firestore_service.dart';
import '../../services/gemini_ai_service.dart';
import '../../services/pdf_report_service.dart';
import '../ai_advisor/financial_advisor_chat_screen.dart';

enum DateRangeFilter {
  thisMonth('Este Mes'),
  last30Days('Últimos 30 Días'),
  thisYear('Este Año'),
  all('Todo el Historial');

  final String label;
  const DateRangeFilter(this.label);
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  DateRangeFilter _selectedDateRange = DateRangeFilter.thisMonth;
  RecordType? _selectedType;
  String? _selectedCategory;

  String? _aiDiagnosis;
  bool _isLoadingAi = false;
  bool _isExportingPdf = false;

  List<FinancialRecord> _filterRecords(List<FinancialRecord> allRecords) {
    final now = DateTime.now();

    return allRecords.where((record) {
      // 1. Filtro de Fechas
      switch (_selectedDateRange) {
        case DateRangeFilter.thisMonth:
          if (record.date.year != now.year || record.date.month != now.month) {
            return false;
          }
          break;
        case DateRangeFilter.last30Days:
          if (now.difference(record.date).inDays > 30) {
            return false;
          }
          break;
        case DateRangeFilter.thisYear:
          if (record.date.year != now.year) {
            return false;
          }
          break;
        case DateRangeFilter.all:
          break;
      }

      // 2. Filtro de Tipo
      if (_selectedType != null && record.type != _selectedType) {
        return false;
      }

      // 3. Filtro de Categoría
      if (_selectedCategory != null && record.category != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();
  }

  Future<void> _generateAiDiagnosis(
    double totalIncome,
    double totalExpense,
    Map<String, double> categoryExpenses,
    int count,
  ) async {
    setState(() {
      _isLoadingAi = true;
    });

    try {
      final diagnosis = await GeminiAiService.generateFinancialDiagnosis(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        categoryExpenses: categoryExpenses,
        totalTransactions: count,
      );

      if (mounted) {
        setState(() {
          _aiDiagnosis = diagnosis;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expense, content: Text('Error IA: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAi = false;
        });
      }
    }
  }

  Future<void> _exportPdf(
    List<FinancialRecord> filteredRecords,
    double totalIncome,
    double totalExpense,
  ) async {
    setState(() {
      _isExportingPdf = true;
    });

    try {
      await PdfReportService.generateAndExportPdf(
        records: filteredRecords,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        periodLabel: _selectedDateRange.label,
        aiDiagnosis: _aiDiagnosis,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.expense, content: Text('Error al exportar PDF: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes & Auditoría IA', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<FinancialRecord>>(
        stream: _firestoreService.getRecordsStream(limit: 500),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final allRecords = snapshot.data ?? [];
          final filteredRecords = _filterRecords(allRecords);

          double totalIncome = 0.0;
          double totalExpense = 0.0;
          final Map<String, double> categoryExpenses = {};

          for (final r in filteredRecords) {
            if (r.type == RecordType.income) {
              totalIncome += r.amount;
            } else {
              totalExpense += r.amount;
              categoryExpenses[r.category] = (categoryExpenses[r.category] ?? 0.0) + r.amount;
            }
          }

          final balance = totalIncome - totalExpense;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Selector de Rango de Fechas (Filtros en memoria Spark)
                _buildDateRangeSelector(),
                const SizedBox(height: 14),

                // 2. Tarjetas de Resumen Financiero
                _buildSummaryCards(totalIncome, totalExpense, balance),
                const SizedBox(height: 16),

                // 3. Tarjeta de Diagnóstico IA Gemini (Bajo demanda)
                _buildAiDiagnosisCard(totalIncome, totalExpense, categoryExpenses, filteredRecords.length),
                const SizedBox(height: 16),

                // 4. Gráfico de Distribución de Gastos (fl_chart)
                if (categoryExpenses.isNotEmpty) ...[
                  _buildExpenseChartSection(categoryExpenses, totalExpense),
                  const SizedBox(height: 16),
                ],

                // 5. Botón de Exportar a PDF
                _buildExportPdfButton(filteredRecords, totalIncome, totalExpense),
                const SizedBox(height: 16),

                // 6. Lista de Registros Filtrados
                _buildFilteredRecordsList(filteredRecords),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text('Periodo:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<DateRangeFilter>(
                value: _selectedDateRange,
                dropdownColor: AppColors.surface,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                items: DateRangeFilter.values.map((range) {
                  return DropdownMenuItem(
                    value: range,
                    child: Text(range.label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedDateRange = val;
                      _aiDiagnosis = null; // Reset diagnosis for new range
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double totalIncome, double totalExpense, double balance) {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Ingresos',
            amount: totalIncome,
            color: AppColors.income,
            icon: Icons.arrow_upward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            title: 'Egresos',
            amount: totalExpense,
            color: AppColors.expense,
            icon: Icons.arrow_downward_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            title: balance >= 0 ? 'Ahorro' : 'Déficit',
            amount: balance,
            color: balance >= 0 ? AppColors.accent : AppColors.expense,
            icon: balance >= 0 ? Icons.savings_rounded : Icons.warning_amber_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.format(amount),
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDiagnosisCard(
    double totalIncome,
    double totalExpense,
    Map<String, double> categoryExpenses,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(25),
            AppColors.accent.withAlpha(15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withAlpha(70), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Diagnóstico Financiero Gemini IA',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
              if (_aiDiagnosis != null)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                  tooltip: 'Actualizar Análisis',
                  onPressed: _isLoadingAi
                      ? null
                      : () => _generateAiDiagnosis(totalIncome, totalExpense, categoryExpenses, count),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isLoadingAi)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    SizedBox(height: 8),
                    Text('Analizando métricas con IA...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            )
          else if (_aiDiagnosis != null) ...[
            Text(
              _aiDiagnosis!,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FinancialAdvisorChatScreen()),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.primary),
              label: const Text('Preguntarle al Asesor IA sobre esto', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ] else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Obtén un análisis instantáneo con 2 recomendaciones prácticas de ahorro familiar basadas exclusivamente en los números de este periodo.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: count == 0
                          ? null
                          : () => _generateAiDiagnosis(totalIncome, totalExpense, categoryExpenses, count),
                      icon: const Icon(Icons.psychology_rounded, size: 18, color: Colors.white),
                      label: const Text('Generar Diagnóstico', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accent),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const FinancialAdvisorChatScreen()),
                        );
                      },
                      icon: const Icon(Icons.forum_outlined, size: 16, color: AppColors.accent),
                      label: const Text('Chat Asesor', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),

              ],
            ),
        ],
      ),
    );
  }

  Widget _buildExpenseChartSection(Map<String, double> categoryExpenses, double totalExpense) {
    final sorted = categoryExpenses.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sorted.take(5).toList();

    final colors = [
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFFEC4899),
      const Color(0xFFF59E0B),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribución de Gastos por Categoría',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 36,
                sections: topCategories.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  final color = colors[idx % colors.length];

                  return PieChartSectionData(
                    value: item.value,
                    color: color,
                    radius: 28,
                    showTitle: false,
                  );
                }).toList(),

              ),
            ),
          ),
          const SizedBox(height: 12),
          // Leyenda de categorías
          ...topCategories.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final cat = AppCategories.getCategoryById(item.key);
            final percent = totalExpense > 0 ? (item.value / totalExpense * 100).toStringAsFixed(1) : '0';
            final color = colors[idx % colors.length];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cat.name,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Bs ${item.value.toStringAsFixed(2)} ($percent%)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExportPdfButton(
    List<FinancialRecord> filteredRecords,
    double totalIncome,
    double totalExpense,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimary,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
      onPressed: _isExportingPdf || filteredRecords.isEmpty
          ? null
          : () => _exportPdf(filteredRecords, totalIncome, totalExpense),
      icon: _isExportingPdf
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : const Icon(Icons.share_rounded, color: AppColors.primary, size: 20),
      label: Text(
        _isExportingPdf ? 'Generando y abriendo opciones para compartir...' : 'Exportar y Compartir PDF (WhatsApp / Drive)',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),

    );
  }

  Widget _buildFilteredRecordsList(List<FinancialRecord> records) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Movimientos Filtrados', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${records.length} transacciones', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('No hay movimientos en este rango.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length > 20 ? 20 : records.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (ctx, i) {
                final r = records[i];
                final isIncome = r.type == RecordType.income;
                final cat = AppCategories.getCategoryById(r.category);

                return ListTile(
                  dense: true,
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isIncome ? AppColors.income.withAlpha(20) : AppColors.expense.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat.icon, size: 16, color: isIncome ? AppColors.income : AppColors.expense),
                  ),
                  title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${DateFormatter.formatShort(r.date)} • ${r.registeredBy}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  trailing: Text(
                    '${isIncome ? "+" : "-"}${CurrencyFormatter.format(r.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
