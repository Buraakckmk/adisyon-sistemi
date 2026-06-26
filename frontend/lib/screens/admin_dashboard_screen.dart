import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";

import "../services/api_client.dart";
import "../services/socket_service.dart";
import "../widgets/x_report_preview_dialog.dart";
import "../models/payment_models.dart";
import "../models/dashboard_models.dart";
import "admin_menu_management_screen.dart";
import "waiter_tables_screen.dart";
import "admin_transactions_screen.dart";
import "admin_expenses_screen.dart";

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const String _adminDeletePin = "2323";

  late Future<DailySummary> _summaryFuture;
  late Future<AdminStats> _statsFuture;
  late Future<List<Expense>> _expensesFuture;
  late Future<List<PaymentTransaction>> _transactionsFuture;
  late Future<List<TableItem>> _customTablesFuture;
  late Future<List<dynamic>> _combinedFuture;

  bool _isGeneratingZReport = false;
  bool _isFetchingXReport = false;

  @override
  void initState() {
    super.initState();
    _initFutures();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    final socket = SocketService().socket;
    if (socket != null) {
      socket.on("orders:refresh", (_) => _refreshData());
      socket.on("tables:refresh", (_) => _refreshData());
      socket.on("payment:completed", (_) => _refreshData());
    }
  }

  @override
  void dispose() {
    final socket = SocketService().socket;
    if (socket != null) {
      socket.off("orders:refresh");
      socket.off("tables:refresh");
      socket.off("payment:completed");
    }
    super.dispose();
  }

  void _initFutures() {
    _summaryFuture = _fetchDailySummary();
    _statsFuture = _fetchStats();
    _expensesFuture = _fetchExpenses();
    _transactionsFuture = _fetchTransactions();
    _customTablesFuture = _fetchCustomTables();
    _combinedFuture = Future.wait([
      _summaryFuture,
      _statsFuture,
      _expensesFuture,
      _transactionsFuture,
      _customTablesFuture,
    ]);
  }

  void _refreshData() {
    setState(() {
      _initFutures();
    });
  }

  Future<DailySummary> _fetchDailySummary() async {
    try {
      final response = await ApiClient.dio.get("/admin/daily-summary");
      final data = response.data as Map<String, dynamic>;
      final summaryData = data["data"] as Map<String, dynamic>?;
      if (summaryData == null) throw Exception("Veri bulunamadı");
      return DailySummary.fromJson(summaryData);
    } catch (e) {
      throw Exception("Günlük özet alınamadı: $e");
    }
  }

  Future<AdminStats> _fetchStats() async {
    try {
      final response = await ApiClient.dio.get("/admin/stats");
      final data = response.data as Map<String, dynamic>;
      final statsData = data["data"] as Map<String, dynamic>?;
      if (statsData == null) throw Exception("Veri bulunamadı");
      return AdminStats.fromJson(statsData);
    } catch (e) {
      throw Exception("İstatistikler alınamadı: $e");
    }
  }

  Future<List<Expense>> _fetchExpenses() async {
    try {
      final response = await ApiClient.dio.get(
        "/admin/expenses?currentPeriodOnly=true",
      );
      final data = response.data as Map<String, dynamic>;
      final expenseData = data["data"] as Map<String, dynamic>?;
      final list = expenseData?["expenses"] as List? ?? [];
      return list.map((e) => Expense.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Giderler alınamadı: $e");
    }
  }

  Future<List<PaymentTransaction>> _fetchTransactions() async {
    try {
      final response = await ApiClient.dio.get("/admin/paid-transactions");
      final data = response.data as Map<String, dynamic>;
      final transactionData = data["data"] as Map<String, dynamic>?;
      final list = transactionData?["transactions"] as List? ?? [];
      return list.map((e) => PaymentTransaction.fromJson(e)).toList();
    } catch (e) {
      throw Exception("Tahsilatlar alınamadı: $e");
    }
  }

  Future<List<TableItem>> _fetchCustomTables() async {
    try {
      final response = await ApiClient.dio.get("/waiter/tables");
      final data = response.data as Map<String, dynamic>;
      final rawTables = (data["tables"] as List<dynamic>? ?? []);
      final tables = rawTables
          .whereType<Map<String, dynamic>>()
          .map(TableItem.fromJson)
          .toList();
      final custom = tables.where((t) => t.isCustom).toList();
      custom.sort((a, b) => a.label.compareTo(b.label));
      return custom;
    } catch (e) {
      throw Exception("Özel masalar alınamadı: $e");
    }
  }

  Future<List<DailyHistoryItem>> _fetchDailyHistory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await ApiClient.dio.get(
        "/admin/daily-history",
        queryParameters: {
          "startDate": startDate.toIso8601String().split("T")[0],
          "endDate": endDate.toIso8601String().split("T")[0],
        },
      );
      final data = response.data as Map<String, dynamic>;
      final rows = data["data"] as List<dynamic>? ?? [];
      return rows
          .map(
            (item) => DailyHistoryItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      throw Exception("Günlük geçmiş alınamadı: $e");
    }
  }

  Future<void> _showDailyHistoryDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          DailyHistoryDialog(fetchHistory: _fetchDailyHistory),
    );
  }

  Future<void> _deleteCustomTable(TableItem table) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Özel Masa Sil"),
        content: Text(
          "${table.label} masasını silmek istiyor musunuz?\n\nAktif adisyon varsa silinmez.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deletePinVerified = await _verifyDeletePin();
    if (deletePinVerified != true) return;

    try {
      await ApiClient.dio.delete("/waiter/tables/custom/${table.id}");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Özel masa silindi."),
          backgroundColor: Color(0xFF166534),
        ),
      );
      _refreshData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Silme başarısız: $e"),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  Future<void> _updatePaymentMethod(int paymentId, String newMethod) async {
    try {
      await ApiClient.dio.patch(
        "/admin/payments/$paymentId/method",
        data: {"paymentMethod": newMethod},
      );
      _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ödeme yöntemi güncellenemedi: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _deleteExpense(int expenseId) async {
    try {
      await ApiClient.dio.delete("/admin/expenses/$expenseId");
      _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gider silinemedi: $e"),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<bool?> _verifyDeletePin() async {
    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Silme Şifresi"),
        content: TextField(
          controller: pinController,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(hintText: "Silme şifresini girin"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () {
              final isValid = pinController.text.trim() == _adminDeletePin;
              Navigator.of(ctx).pop(isValid);
            },
            child: const Text("Doğrula"),
          ),
        ],
      ),
    );

    if (result != true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Silme şifresi hatalı."),
          backgroundColor: Color(0xFFB91C1C),
        ),
      );
    }

    return result;
  }

  Future<void> _showAddExpenseDialog() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: "1");
    final priceController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Gider Ekle"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Ürün/Hizmet Adı"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Miktar"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Birim Fiyat (TL)",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: "Not (Opsiyonel)"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || priceController.text.isEmpty) {
                return;
              }
              try {
                await ApiClient.dio.post(
                  "/admin/expenses",
                  data: {
                    "item_name": nameController.text,
                    "quantity": double.tryParse(quantityController.text) ?? 1,
                    "unit_price": double.tryParse(priceController.text) ?? 0,
                    "note": noteController.text,
                  },
                );
                if (context.mounted) Navigator.pop(context, true);
              } catch (e) {
                // error handled by interceptor
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _fetchXReport() async {
    setState(() => _isFetchingXReport = true);
    try {
      final response = await ApiClient.dio.get("/admin/x-report");
      final data = response.data as Map<String, dynamic>;
      final xReportData = XReportData.fromJson(
        data["data"] as Map<String, dynamic>,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => XReportPreviewDialog(data: xReportData),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("X Raporu alınamadı: ${e.toString()}"),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingXReport = false);
      }
    }
  }

  Future<void> _generateZReport() async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Günü Kapat"),
        content: const Text(
          "Gün sonu raporu oluşturulacak ve Excel'e kaydedilecek. Devam etmek istiyor musunuz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Vazgeç"),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Onayla"),
          ),
        ],
      ),
    );

    if (approved != true || !mounted) {
      return;
    }

    setState(() {
      _isGeneratingZReport = true;
    });

    try {
      await ApiClient.dio.post("/admin/z-report");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Z Raporu başarıyla oluşturuldu!"),
            backgroundColor: Color(0xFF166534),
          ),
        );
        // Veriyi yenile
        _refreshData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Z Raporu oluşturulamadı: ${e.toString()}"),
            backgroundColor: Color(0xFFB91C1C),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingZReport = false;
        });
      }
    }
  }

  bool _isCompactViewport(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width <= 1280 || size.height <= 820;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final compactViewport = _isCompactViewport(context);
    final isWideDesktop = screenWidth >= 1280 && screenHeight >= 700;
    final compactHeaderActions = screenWidth < 1500 || compactViewport;
    final pagePadding = compactViewport ? 12.0 : 16.0;
    final sectionGap = compactViewport ? 14.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Yönetici Paneli",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        toolbarHeight: compactViewport ? 56 : kToolbarHeight,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: _buildResponsiveAppBarActions(
          screenWidth,
          compactHeaderActions,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
        },
        child: FutureBuilder<List<dynamic>>(
          future: _combinedFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error);
            }

            final summary = snapshot.data![0] as DailySummary;
            final stats = snapshot.data![1] as AdminStats;
            final expenses = snapshot.data![2] as List<Expense>;
            final transactions = snapshot.data![3] as List<PaymentTransaction>;
            final customTables = snapshot.data![4] as List<TableItem>;

            final summaryGrid = LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final tightCards = width < 980;
                final spacing = compactViewport ? 8.0 : 12.0;
                final cardExtent = width >= 1450
                    ? 320.0
                    : width >= 1200
                    ? 260.0
                    : width >= 900
                    ? 220.0
                    : 180.0;
                final ratio = width >= 1200
                    ? 2.7
                    : width >= 900
                    ? 2.15
                    : 1.6;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: cardExtent,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: ratio,
                  ),
                  itemBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return _buildCompactSummaryCard(
                          "Günlük Ciro",
                          "${summary.totalRevenue.toStringAsFixed(0)} ₺",
                          Icons.payments_rounded,
                          const Color(0xFF10B981),
                          tight: tightCards || compactViewport,
                        );
                      case 1:
                        return _buildCompactSummaryCard(
                          "Adisyon",
                          "${summary.totalOrders} Adet",
                          Icons.receipt_long_rounded,
                          const Color(0xFF3B82F6),
                          tight: tightCards || compactViewport,
                        );
                      case 2:
                        return _buildCompactSummaryCard(
                          "Nakit",
                          "${summary.cashTotal.toStringAsFixed(0)} ₺",
                          Icons.money_rounded,
                          const Color(0xFFF59E0B),
                          tight: tightCards || compactViewport,
                        );
                      default:
                        return _buildCompactSummaryCard(
                          "Kredi Kartı",
                          "${summary.cardTotal.toStringAsFixed(0)} ₺",
                          Icons.credit_card_rounded,
                          const Color(0xFF8B5CF6),
                          tight: tightCards || compactViewport,
                        );
                    }
                  },
                );
              },
            );

            final desktopContent = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildWeeklyRevenueChart(
                              stats.weeklyRevenue,
                            ),
                          ),
                          SizedBox(width: compactViewport ? 12 : 16),
                          Expanded(
                            child: _buildCategorySalesChart(
                              stats.categorySales,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTopProductsChart(stats.topProducts),
                    ],
                  ),
                ),
                SizedBox(width: compactViewport ? 14 : 20),
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildSectionHeaderWithActions(
                        "Son Tahsilatlar",
                        onSeeAll: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminTransactionsScreen(),
                          ),
                        ),
                      ),
                      _buildTransactionsCard(transactions),
                      SizedBox(height: sectionGap),
                      _buildSectionHeaderWithActions(
                        "Son Giderler",
                        onAdd: _showAddExpenseDialog,
                        onSeeAll: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminExpensesScreen(),
                          ),
                        ),
                      ),
                      _buildExpensesCard(expenses),
                      SizedBox(height: sectionGap),
                      _buildSectionHeader("Özel Masalar"),
                      _buildCustomTablesCard(customTables),
                    ],
                  ),
                ),
              ],
            );

            final lowHeightDesktop =
                isWideDesktop && compactViewport && screenHeight <= 820;

            if (lowHeightDesktop) {
              return Padding(
                padding: EdgeInsets.all(pagePadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    summaryGrid,
                    SizedBox(height: compactViewport ? 10 : sectionGap),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildWeeklyRevenueChart(
                                          stats.weeklyRevenue,
                                        ),
                                      ),
                                      SizedBox(
                                        width: compactViewport ? 10 : 12,
                                      ),
                                      Expanded(
                                        child: _buildCategorySalesChart(
                                          stats.categorySales,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  flex: 2,
                                  child: _buildTopProductsChart(
                                    stats.topProducts,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: compactViewport ? 12 : 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildSectionHeaderWithActions(
                                  "Son Tahsilatlar",
                                  onSeeAll: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminTransactionsScreen(),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _buildTransactionsCard(transactions),
                                ),
                                SizedBox(height: compactViewport ? 8 : 10),
                                _buildSectionHeaderWithActions(
                                  "Son Giderler",
                                  onAdd: _showAddExpenseDialog,
                                  onSeeAll: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminExpensesScreen(),
                                    ),
                                  ),
                                ),
                                Expanded(child: _buildExpensesCard(expenses)),
                                SizedBox(height: compactViewport ? 8 : 10),
                                _buildSectionHeader("Özel Masalar"),
                                Expanded(
                                  child: _buildCustomTablesCard(customTables),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.all(pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  summaryGrid,

                  SizedBox(height: sectionGap),

                  if (isWideDesktop)
                    desktopContent
                  else
                    Column(
                      children: [
                        _buildWeeklyRevenueChart(stats.weeklyRevenue),
                        SizedBox(height: sectionGap),
                        _buildCategorySalesChart(stats.categorySales),
                        SizedBox(height: sectionGap),
                        _buildTopProductsChart(stats.topProducts),
                        SizedBox(height: sectionGap),
                        _buildSectionHeaderWithActions(
                          "Son Tahsilatlar",
                          onSeeAll: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminTransactionsScreen(),
                            ),
                          ),
                        ),
                        _buildTransactionsCard(transactions),
                        SizedBox(height: sectionGap),
                        _buildSectionHeaderWithActions(
                          "Son Giderler",
                          onAdd: _showAddExpenseDialog,
                          onSeeAll: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminExpensesScreen(),
                            ),
                          ),
                        ),
                        _buildExpensesCard(expenses),
                        SizedBox(height: sectionGap),
                        _buildSectionHeader("Özel Masalar"),
                        _buildCustomTablesCard(customTables),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildResponsiveAppBarActions(
    double screenWidth,
    bool compactHeaderActions,
  ) {
    final actions = <Widget>[];

    final quickActions = <Widget>[
      _buildHeaderAction(
        onPressed: _showDailyHistoryDialog,
        icon: Icons.calendar_month_rounded,
        label: "Günlük Liste",
        color: const Color(0xFF6366F1),
        compact: compactHeaderActions,
      ),
      const SizedBox(width: 6),
      _buildHeaderAction(
        onPressed: _isFetchingXReport ? null : _fetchXReport,
        icon: Icons.print_rounded,
        label: "X Raporu",
        color: const Color(0xFF10B981),
        isLoading: _isFetchingXReport,
        compact: compactHeaderActions,
      ),
      const SizedBox(width: 6),
      _buildHeaderAction(
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WaiterTablesScreen()));
        },
        icon: Icons.table_restaurant_rounded,
        label: "Masalar",
        color: const Color(0xFF3B82F6),
        compact: compactHeaderActions,
      ),
      const SizedBox(width: 6),
    ];

    if (screenWidth >= 1400 && !compactHeaderActions) {
      actions.addAll([
        _buildHeaderAction(
          onPressed: _showAddExpenseDialog,
          icon: Icons.add_shopping_cart_rounded,
          label: "Gider Ekle",
          color: const Color(0xFF6366F1),
          compact: compactHeaderActions,
        ),
        const SizedBox(width: 6),
        _buildHeaderAction(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AdminMenuManagementScreen(),
              ),
            );
          },
          icon: Icons.inventory_2_rounded,
          label: "Ürün Yönetimi",
          color: const Color(0xFF0EA5E9),
          compact: compactHeaderActions,
        ),
        const SizedBox(width: 6),
        _buildHeaderAction(
          onPressed: _isGeneratingZReport ? null : _generateZReport,
          icon: Icons.power_settings_new_rounded,
          label: "Günü Kapat",
          color: const Color(0xFFEF4444),
          isLoading: _isGeneratingZReport,
          compact: compactHeaderActions,
        ),
        const SizedBox(width: 6),
      ]);
    }

    actions.addAll(quickActions);

    actions.add(
      PopupMenuButton<String>(
        tooltip: "Daha Fazla",
        icon: const Icon(Icons.more_horiz_rounded),
        onSelected: _handleHeaderMenuAction,
        itemBuilder: (context) => const [
          PopupMenuItem(value: "expense", child: Text("Gider Ekle")),
          PopupMenuItem(value: "menu", child: Text("Ürün Yönetimi")),
          PopupMenuItem(value: "z", child: Text("Günü Kapat (Z Raporu)")),
          PopupMenuItem(value: "x", child: Text("X Raporu")),
          PopupMenuItem(value: "tables", child: Text("Masalar")),
        ],
      ),
    );
    actions.add(const SizedBox(width: 8));

    return actions;
  }

  void _handleHeaderMenuAction(String value) {
    switch (value) {
      case "expense":
        _showAddExpenseDialog();
        break;
      case "menu":
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminMenuManagementScreen()),
        );
        break;
      case "z":
        if (!_isGeneratingZReport) {
          _generateZReport();
        }
        break;
      case "x":
        if (!_isFetchingXReport) {
          _fetchXReport();
        }
        break;
      case "tables":
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const WaiterTablesScreen()));
        break;
    }
  }

  Widget _buildHeaderAction({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
    bool isLoading = false,
    bool compact = false,
  }) {
    if (compact) {
      return IconButton(
        onPressed: onPressed,
        tooltip: label,
        icon: isLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              )
            : Icon(icon, size: 18, color: color),
        style: IconButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.08),
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(40, 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            )
          : Icon(icon, size: 18, color: color),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSectionHeaderWithActions(
    String title, {
    VoidCallback? onAdd,
    VoidCallback? onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: _buildSectionHeader(title)),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              "Tümünü Gör",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        if (onAdd != null)
          TextButton(
            onPressed: onAdd,
            child: const Text(
              "Yeni Ekle",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomTablesCard(List<TableItem> tables) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: tables.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Aktif özel masa yok.",
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final bounded = constraints.hasBoundedHeight;
                final list = ListView.separated(
                  primary: false,
                  shrinkWrap: !bounded,
                  physics: bounded
                      ? const BouncingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  itemCount: tables.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  itemBuilder: (context, index) {
                    final table = tables[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        table.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        "${table.zone} • ${table.status == "OCCUPIED" ? "DOLU" : "BOŞ"}",
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                      trailing: IconButton(
                        tooltip: "Sil",
                        onPressed: () => _deleteCustomTable(table),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    );
                  },
                );

                if (bounded) return list;

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: list,
                );
              },
            ),
    );
  }

  Widget _buildCompactSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool tight = false,
  }) {
    return Container(
      padding: EdgeInsets.all(tight ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(tight ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: tight ? 16 : 18),
              ),
            ],
          ),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF64748B),
              fontSize: tight ? 11 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: tight ? 17 : 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 16),
            const Text(
              "Veriler Yüklenemedi",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Tekrar Dene"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsCard(List<PaymentTransaction> data) {
    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          "Henüz tahsilat yapılmadı.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight;
          final list = ListView.separated(
            primary: false,
            shrinkWrap: !bounded,
            physics: bounded
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: data.length > 10 ? 10 : data.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = data[index];
              final isCash = item.paymentMethod == "CASH";

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      (isCash
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF8B5CF6))
                          .withValues(alpha: 0.1),
                  child: Icon(
                    isCash ? Icons.money : Icons.credit_card,
                    color: isCash
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF8B5CF6),
                    size: 20,
                  ),
                ),
                title: Text(
                  "${item.tableName} - #${item.orderId}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${item.cashierName} • ${item.paidAt.substring(11, 16)}",
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${item.amount.toStringAsFixed(2)} TL",
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (newMethod) =>
                          _updatePaymentMethod(item.id, newMethod),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: isCash ? "CARD" : "CASH",
                          child: Text(isCash ? "Kredi Kartı Yap" : "Nakit Yap"),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );

          if (bounded) return list;

          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 350),
            child: list,
          );
        },
      ),
    );
  }

  Widget _buildExpensesCard(List<Expense> data) {
    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          "Kayıtlı gider bulunamadı.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight;
          final list = ListView.separated(
            primary: false,
            shrinkWrap: !bounded,
            physics: bounded
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: data.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = data[index];
              return ListTile(
                title: Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${item.quantity} x ${item.unitPrice.toStringAsFixed(2)} TL",
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "-${item.totalAmount.toStringAsFixed(2)} TL",
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text("Gideri Sil"),
                            content: const Text(
                              "Bu gider kaydını silmek istediğinize emin misiniz?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Vazgeç"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  "Sil",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final deletePinVerified = await _verifyDeletePin();
                          if (deletePinVerified == true) {
                            _deleteExpense(item.id);
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          );

          if (bounded) return list;

          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 350),
            child: list,
          );
        },
      ),
    );
  }

  Widget _buildWeeklyRevenueChart(List<WeeklyRevenue> data) {
    final compact = _isCompactViewport(context);
    if (data.isEmpty) {
      return Container(
        height: compact ? 250 : 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text("Haftalık veri bulunamadı.")),
      );
    }

    final maxRevenue = data
        .map((d) => d.revenue)
        .reduce((a, b) => a > b ? a : b);
    final displayMax = maxRevenue > 0 ? maxRevenue : 1000.0;

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Haftalık Ciro",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 12 : 24),
          SizedBox(
            height: compact ? 165 : 200,
            child: BarChart(
              BarChartData(
                maxY: displayMax * 1.2,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            data[index].dayName,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "${value.toInt()}",
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: data.toList().asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.revenue,
                        color: const Color(0xFF10B981),
                        width: 16,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsChart(List<TopProduct> data) {
    final compact = _isCompactViewport(context);
    if (data.isEmpty) {
      return Container(
        height: compact ? 250 : 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text("Satış verisi bulunamadı.")),
      );
    }

    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "En Çok Satan Ürünler",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          SizedBox(
            height: compact ? 160 : 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: true),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: data.toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: product.quantity > 0 ? product.quantity : 0.1,
                    title: "${product.quantity.toInt()}",
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...data.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final product = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      product.name,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "${product.quantity.toInt()}",
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCategorySalesChart(List<CategorySales> data) {
    final compact = _isCompactViewport(context);
    if (data.isEmpty) {
      return Container(
        height: compact ? 250 : 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(child: Text("Kategori verisi bulunamadı.")),
      );
    }

    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFFF97316),
      const Color(0xFF14B8A6),
      const Color(0xFF8B5CF6),
    ];

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Kategori Bazlı Satışlar",
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          SizedBox(
            height: compact ? 160 : 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(enabled: true),
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: data.toList().asMap().entries.map((entry) {
                  final index = entry.key;
                  final category = entry.value;
                  return PieChartSectionData(
                    color: colors[index % colors.length],
                    value: category.revenue > 0 ? category.revenue : 0.1,
                    title: "",
                    radius: 50,
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...data.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "${category.revenue.toStringAsFixed(0)} ₺",
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class DailyHistoryDialog extends StatefulWidget {
  final Future<List<DailyHistoryItem>> Function({
    required DateTime startDate,
    required DateTime endDate,
  })
  fetchHistory;

  const DailyHistoryDialog({super.key, required this.fetchHistory});

  @override
  State<DailyHistoryDialog> createState() => _DailyHistoryDialogState();
}

class _DailyHistoryDialogState extends State<DailyHistoryDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  late Future<List<DailyHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _endDate = DateTime(today.year, today.month, today.day);
    _startDate = _endDate.subtract(const Duration(days: 29));
    _loadHistory();
  }

  void _loadHistory() {
    setState(() {
      _historyFuture = widget.fetchHistory(
        startDate: _startDate,
        endDate: _endDate,
      );
    });
  }

  Future<void> _pickDate(bool start) async {
    final initialDate = start ? _startDate : _endDate;
    final firstDate = DateTime.now().subtract(const Duration(days: 365));
    final lastDate = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
      }
    });
    _loadHistory();
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
  }

  Widget _buildSummaryChip(String label, double value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "${value.toStringAsFixed(0)} ₺",
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _formatHistoryDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    return '$day.$month.$year';
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 900;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: compact ? double.infinity : 860,
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Günlük Geçmiş",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  tooltip: "Kapat",
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text("Başlangıç: ${_formatDate(_startDate)}"),
                ),
                OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text("Bitiş: ${_formatDate(_endDate)}"),
                ),
                FilledButton(
                  onPressed: _loadHistory,
                  child: const Text("Filtrele"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<DailyHistoryItem>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Geçmiş alınamadı: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(
                      child: Text("Bu tarih aralığında veri bulunamadı."),
                    );
                  }

                  final totalCash = items.fold<double>(
                    0.0,
                    (sum, item) => sum + item.cashTotal,
                  );
                  final totalCard = items.fold<double>(
                    0.0,
                    (sum, item) => sum + item.cardTotal,
                  );
                  final totalRevenue = items.fold<double>(
                    0.0,
                    (sum, item) => sum + item.totalRevenue,
                  );
                  final totalExpense = items.fold<double>(
                    0.0,
                    (sum, item) => sum + item.totalExpense,
                  );

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Tarih: ${_formatDate(_startDate)} - ${_formatDate(_endDate)}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _buildSummaryChip("Nakit", totalCash),
                                  _buildSummaryChip("Kart", totalCard),
                                  _buildSummaryChip("Toplam", totalRevenue),
                                  _buildSummaryChip("Gider", totalExpense),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC),
                              ),
                              columns: const [
                                DataColumn(label: Text("Tarih")),
                                DataColumn(label: Text("Nakit")),
                                DataColumn(label: Text("Kart")),
                                DataColumn(label: Text("Toplam")),
                                DataColumn(label: Text("Gider")),
                              ],
                              rows: items.map((item) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(_formatHistoryDate(item.date)),
                                    ),
                                    DataCell(
                                      Text(
                                        "${item.cashTotal.toStringAsFixed(0)} ₺",
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "${item.cardTotal.toStringAsFixed(0)} ₺",
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "${item.totalRevenue.toStringAsFixed(0)} ₺",
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        "${item.totalExpense.toStringAsFixed(0)} ₺",
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
