import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:expense_manager/models/transaction_model.dart';
import 'package:expense_manager/models/category_model.dart';
import 'package:expense_manager/services/transaction_service.dart';
import 'package:expense_manager/services/category_service.dart';
import 'package:expense_manager/theme/app_theme.dart';
import 'package:expense_manager/utils/category_icon_utils.dart';

class GraphicsScreen extends StatefulWidget {
  const GraphicsScreen({super.key});

  @override
  State<GraphicsScreen> createState() => _GraphicsScreenState();
}

class _GraphicsScreenState extends State<GraphicsScreen> {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  
  String selectedPeriod = "Mois";
  bool isLoading = true;
  
  Map<String, Category> categories = {};
  double totalIncome = 0;
  double totalExpense = 0;
  double balance = 0;
  
  DateTime periodStart = DateTime.now();
  DateTime periodEnd = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initializePeriod();
    _loadData();
  }

  void _initializePeriod() {
    DateTime now = DateTime.now();
    
    switch (selectedPeriod) {
      case "Jour":
        periodStart = DateTime(now.year, now.month, now.day);
        periodEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case "Semaine":
        int weekday = now.weekday;
        periodStart = now.subtract(Duration(days: weekday - 1));
        periodStart = DateTime(periodStart.year, periodStart.month, periodStart.day);
        periodEnd = periodStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case "Mois":
        periodStart = DateTime(now.year, now.month, 1);
        periodEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case "Année":
        periodStart = DateTime(now.year, 1, 1);
        periodEnd = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
    }
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    try {
      final cats = await _categoryService.getAllCategories();
      categories = {for (var cat in cats) cat.id: cat};

      final incomes = await _transactionService.getTransactionsByTypeAndPeriod(
        type: TransactionType.income,
        start: periodStart,
        end: periodEnd,
      );
      
      final expenses = await _transactionService.getTransactionsByTypeAndPeriod(
        type: TransactionType.expense,
        start: periodStart,
        end: periodEnd,
      );

      double income = incomes.fold(0.0, (sum, t) => sum + t.amount);
      double expense = expenses.fold(0.0, (sum, t) => sum + t.amount);

      setState(() {
        totalIncome = income;
        totalExpense = expense;
        balance = income - expense;
        isLoading = false;
      });
    } catch (e) {
      print('Erreur: $e');
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, double>> _loadCategoryDetails(TransactionType type) async {
    try {
      List<TransactionModel> transactions = await _transactionService.getTransactionsByTypeAndPeriod(
        type: type,
        start: periodStart,
        end: periodEnd,
      );

      Map<String, double> categoryData = {};
      for (var t in transactions) {
        categoryData[t.categoryId] = (categoryData[t.categoryId] ?? 0) + t.amount;
      }

      var sortedEntries = categoryData.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      
      return Map.fromEntries(sortedEntries);
    } catch (e) {
      return {};
    }
  }

  void _showCategoryDetails(String title, TransactionType type, Color color) async {
    Map<String, double> categoryData = await _loadCategoryDetails(type);
    double total = type == TransactionType.income ? totalIncome : totalExpense;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.mediumGrey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${total.toStringAsFixed(2)} د.ت',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'Répartition par catégorie',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: categoryData.isEmpty
                        ? const Center(child: Text('Aucune donnée'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: categoryData.length,
                            itemBuilder: (context, index) {
                              var entry = categoryData.entries.elementAt(index);
                              Category? cat = categories[entry.key];
                              if (cat == null) return const SizedBox.shrink();
                              
                              double percent = (entry.value / total) * 100;
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          CategoryIconUtils.getColor(cat.color).withOpacity(0.7),
                                          CategoryIconUtils.getColor(cat.color),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      CategoryIconUtils.getIcon(cat.icon),
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  title: Text(
                                    cat.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text('${percent.toStringAsFixed(1)}%'),
                                  trailing: Text(
                                    '${entry.value.toStringAsFixed(2)} د.ت',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatPeriod() {
    switch (selectedPeriod) {
      case "Jour":
        return "${periodStart.day}/${periodStart.month}/${periodStart.year}";
      case "Semaine":
        return "${periodStart.day}/${periodStart.month} - ${periodEnd.day}/${periodEnd.month}";
      case "Mois":
        const months = ["", "Janvier", "Février", "Mars", "Avril", "Mai", "Juin", 
                       "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"];
        return "${months[periodStart.month]} ${periodStart.year}";
      case "Année":
        return "${periodStart.year}";
      default:
        return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Graphiques'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 20),
                  _buildBalanceCard(),
                  const SizedBox(height: 20),
                  _buildBarChart(),
                  const SizedBox(height: 20),
                  _buildSummaryCards(),
                ],
              ),
            ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          DropdownButton<String>(
            value: selectedPeriod,
            isExpanded: true,
            underline: Container(),
            items: ["Jour", "Semaine", "Mois", "Année"]
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                        p,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedPeriod = value;
                  _initializePeriod();
                });
                _loadData();
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            _formatPeriod(),
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: balance >= 0 ? AppTheme.incomeGradient : AppTheme.expenseGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (balance >= 0 ? AppTheme.incomeColor : AppTheme.expenseColor).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Solde',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(2)} د.ت',
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  balance >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  balance >= 0 ? 'Profit' : 'Perte',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vue d\'ensemble',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: [totalIncome, totalExpense, balance.abs()].reduce((a, b) => a > b ? a : b) * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (event is FlTapUpEvent && barTouchResponse != null && barTouchResponse.spot != null) {
                      int touchedIndex = barTouchResponse.spot!.touchedBarGroupIndex;
                      if (touchedIndex == 0) {
                        _showCategoryDetails('Revenus', TransactionType.income, AppTheme.incomeColor);
                      } else if (touchedIndex == 1) {
                        _showCategoryDetails('Dépenses', TransactionType.expense, AppTheme.expenseColor);
                      }
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const style = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
                        switch (value.toInt()) {
                          case 0:
                            return const Text('Revenus', style: style);
                          case 1:
                            return const Text('Dépenses', style: style);
                          case 2:
                            return Text(balance >= 0 ? 'Profit' : 'Perte', style: style);
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: AppTheme.lightGrey,
                      strokeWidth: 1,
                    );
                  },
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: totalIncome == 0 ? 0.1 : totalIncome,
                        gradient: AppTheme.incomeGradient,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: totalExpense == 0 ? 0.1 : totalExpense,
                        gradient: AppTheme.expenseGradient,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: balance.abs() == 0 ? 0.1 : balance.abs(),
                        color: balance >= 0 ? AppTheme.primaryColor : Colors.orange,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      children: [
        _buildSummaryCard(
          'Revenus',
          totalIncome,
          Icons.arrow_upward,
          AppTheme.incomeGradient,
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(
          'Dépenses',
          totalExpense,
          Icons.arrow_downward,
          AppTheme.expenseGradient,
        ),
        const SizedBox(height: 12),
        _buildSummaryCard(
          balance >= 0 ? 'Profit' : 'Perte',
          balance.abs(),
          balance >= 0 ? Icons.trending_up : Icons.trending_down,
          balance >= 0 
              ? const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF9B59B6)])
              : const LinearGradient(colors: [Colors.orange, Colors.deepOrange]),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, double value, IconData icon, Gradient gradient) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${value.toStringAsFixed(2)} د.ت',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}