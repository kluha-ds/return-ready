import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ReturnReadyApp());
}

class ReturnReadyApp extends StatelessWidget {
  const ReturnReadyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReturnReady',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A5AE0)),
        useMaterial3: true,
      ),
      home: const ReturnReadyHomePage(),
    );
  }
}

enum OrderStatus {
  tracked,
  mightReturn,
  returnStarted,
  waitingForRefund,
  refunded,
  deadlineMissed,
}

enum DeadlineConfidence { confirmed, estimated, unknown }

enum OrderSource { manual, gmail }

enum InboxFilter { all, actionNeeded, waitingForRefund, refunded }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.tracked => 'Tracked',
    OrderStatus.mightReturn => 'Might Return',
    OrderStatus.returnStarted => 'Return Started',
    OrderStatus.waitingForRefund => 'Waiting for Refund',
    OrderStatus.refunded => 'Refunded',
    OrderStatus.deadlineMissed => 'Deadline Missed',
  };
}

extension DeadlineConfidenceX on DeadlineConfidence {
  String get label => switch (this) {
    DeadlineConfidence.confirmed => 'Confirmed deadline',
    DeadlineConfidence.estimated => 'Estimated deadline',
    DeadlineConfidence.unknown => 'Unknown deadline',
  };
}

extension InboxFilterX on InboxFilter {
  String get label => switch (this) {
    InboxFilter.all => 'All',
    InboxFilter.actionNeeded => 'Action Needed',
    InboxFilter.waitingForRefund => 'Waiting for Refund',
    InboxFilter.refunded => 'Refunded',
  };
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.userId,
    required this.merchantName,
    required this.orderDate,
    required this.totalAmount,
    required this.currency,
    required this.source,
    required this.status,
    required this.returnDeadlineConfidence,
    required this.createdAt,
    required this.updatedAt,
    this.orderNumber,
    this.sourceMessageId,
    this.returnDeadlineDate,
    this.deadlineBasisNote,
    this.merchantReturnUrl,
    this.notes,
    this.expectedRefundAmount,
    this.actualRefundAmount,
    this.refundReceivedDate,
    this.startedAt,
    this.droppedOffAt,
    this.methodNote,
    this.proofAttachmentUrl,
    this.lastRefundReminderAt,
  });

  final String id;
  final String userId;
  final String merchantName;
  final String? orderNumber;
  final DateTime orderDate;
  final double totalAmount;
  final String currency;
  final OrderSource source;
  final String? sourceMessageId;
  final OrderStatus status;
  final DateTime? returnDeadlineDate;
  final DeadlineConfidence returnDeadlineConfidence;
  final String? deadlineBasisNote;
  final String? merchantReturnUrl;
  final String? notes;
  final double? expectedRefundAmount;
  final double? actualRefundAmount;
  final DateTime? refundReceivedDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startedAt;
  final DateTime? droppedOffAt;
  final String? methodNote;
  final String? proofAttachmentUrl;
  final DateTime? lastRefundReminderAt;

  OrderRecord copyWith({
    String? id,
    String? userId,
    String? merchantName,
    String? orderNumber,
    DateTime? orderDate,
    double? totalAmount,
    String? currency,
    OrderSource? source,
    String? sourceMessageId,
    OrderStatus? status,
    DateTime? returnDeadlineDate,
    bool clearDeadlineDate = false,
    DeadlineConfidence? returnDeadlineConfidence,
    String? deadlineBasisNote,
    bool clearDeadlineBasisNote = false,
    String? merchantReturnUrl,
    bool clearMerchantReturnUrl = false,
    String? notes,
    bool clearNotes = false,
    double? expectedRefundAmount,
    bool clearExpectedRefundAmount = false,
    double? actualRefundAmount,
    bool clearActualRefundAmount = false,
    DateTime? refundReceivedDate,
    bool clearRefundReceivedDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startedAt,
    bool clearStartedAt = false,
    DateTime? droppedOffAt,
    bool clearDroppedOffAt = false,
    String? methodNote,
    bool clearMethodNote = false,
    String? proofAttachmentUrl,
    bool clearProofAttachmentUrl = false,
    DateTime? lastRefundReminderAt,
    bool clearLastRefundReminderAt = false,
  }) {
    return OrderRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      merchantName: merchantName ?? this.merchantName,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      source: source ?? this.source,
      sourceMessageId: sourceMessageId ?? this.sourceMessageId,
      status: status ?? this.status,
      returnDeadlineDate: clearDeadlineDate
          ? null
          : returnDeadlineDate ?? this.returnDeadlineDate,
      returnDeadlineConfidence:
          returnDeadlineConfidence ?? this.returnDeadlineConfidence,
      deadlineBasisNote: clearDeadlineBasisNote
          ? null
          : deadlineBasisNote ?? this.deadlineBasisNote,
      merchantReturnUrl: clearMerchantReturnUrl
          ? null
          : merchantReturnUrl ?? this.merchantReturnUrl,
      notes: clearNotes ? null : notes ?? this.notes,
      expectedRefundAmount: clearExpectedRefundAmount
          ? null
          : expectedRefundAmount ?? this.expectedRefundAmount,
      actualRefundAmount: clearActualRefundAmount
          ? null
          : actualRefundAmount ?? this.actualRefundAmount,
      refundReceivedDate: clearRefundReceivedDate
          ? null
          : refundReceivedDate ?? this.refundReceivedDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
      droppedOffAt: clearDroppedOffAt
          ? null
          : droppedOffAt ?? this.droppedOffAt,
      methodNote: clearMethodNote ? null : methodNote ?? this.methodNote,
      proofAttachmentUrl: clearProofAttachmentUrl
          ? null
          : proofAttachmentUrl ?? this.proofAttachmentUrl,
      lastRefundReminderAt: clearLastRefundReminderAt
          ? null
          : lastRefundReminderAt ?? this.lastRefundReminderAt,
    );
  }

  bool get deadlineKnown =>
      returnDeadlineConfidence != DeadlineConfidence.unknown &&
      returnDeadlineDate != null;

  int? daysUntilDeadline(DateTime now) {
    if (!deadlineKnown) return null;
    final start = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(
      returnDeadlineDate!.year,
      returnDeadlineDate!.month,
      returnDeadlineDate!.day,
    );
    return deadline.difference(start).inDays;
  }

  String amountLabel([double? override]) {
    final value = override ?? totalAmount;
    return '$currency${value.toStringAsFixed(2)}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'merchantName': merchantName,
    'orderNumber': orderNumber,
    'orderDate': orderDate.toIso8601String(),
    'totalAmount': totalAmount,
    'currency': currency,
    'source': source.name,
    'sourceMessageId': sourceMessageId,
    'status': status.name,
    'returnDeadlineDate': returnDeadlineDate?.toIso8601String(),
    'returnDeadlineConfidence': returnDeadlineConfidence.name,
    'deadlineBasisNote': deadlineBasisNote,
    'merchantReturnUrl': merchantReturnUrl,
    'notes': notes,
    'expectedRefundAmount': expectedRefundAmount,
    'actualRefundAmount': actualRefundAmount,
    'refundReceivedDate': refundReceivedDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'droppedOffAt': droppedOffAt?.toIso8601String(),
    'methodNote': methodNote,
    'proofAttachmentUrl': proofAttachmentUrl,
    'lastRefundReminderAt': lastRefundReminderAt?.toIso8601String(),
  };

  factory OrderRecord.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) =>
        json[key] == null ? null : DateTime.parse(json[key] as String);

    return OrderRecord(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? 'local-user',
      merchantName: json['merchantName'] as String,
      orderNumber: json['orderNumber'] as String?,
      orderDate: DateTime.parse(json['orderDate'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      currency: json['currency'] as String? ?? '\$',
      source: OrderSource.values.byName(
        json['source'] as String? ?? OrderSource.manual.name,
      ),
      sourceMessageId: json['sourceMessageId'] as String?,
      status: OrderStatus.values.byName(
        json['status'] as String? ?? OrderStatus.tracked.name,
      ),
      returnDeadlineDate: parseDate('returnDeadlineDate'),
      returnDeadlineConfidence: DeadlineConfidence.values.byName(
        json['returnDeadlineConfidence'] as String? ??
            DeadlineConfidence.unknown.name,
      ),
      deadlineBasisNote: json['deadlineBasisNote'] as String?,
      merchantReturnUrl: json['merchantReturnUrl'] as String?,
      notes: json['notes'] as String?,
      expectedRefundAmount: (json['expectedRefundAmount'] as num?)?.toDouble(),
      actualRefundAmount: (json['actualRefundAmount'] as num?)?.toDouble(),
      refundReceivedDate: parseDate('refundReceivedDate'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      startedAt: parseDate('startedAt'),
      droppedOffAt: parseDate('droppedOffAt'),
      methodNote: json['methodNote'] as String?,
      proofAttachmentUrl: json['proofAttachmentUrl'] as String?,
      lastRefundReminderAt: parseDate('lastRefundReminderAt'),
    );
  }
}

class AppState {
  const AppState({
    required this.orders,
    required this.gmailConnected,
    required this.gmailImportSeeded,
    required this.userTimeZoneLabel,
    required this.quietHoursEnabled,
  });

  final List<OrderRecord> orders;
  final bool gmailConnected;
  final bool gmailImportSeeded;
  final String userTimeZoneLabel;
  final bool quietHoursEnabled;

  AppState copyWith({
    List<OrderRecord>? orders,
    bool? gmailConnected,
    bool? gmailImportSeeded,
    String? userTimeZoneLabel,
    bool? quietHoursEnabled,
  }) {
    return AppState(
      orders: orders ?? this.orders,
      gmailConnected: gmailConnected ?? this.gmailConnected,
      gmailImportSeeded: gmailImportSeeded ?? this.gmailImportSeeded,
      userTimeZoneLabel: userTimeZoneLabel ?? this.userTimeZoneLabel,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'orders': orders.map((e) => e.toJson()).toList(),
    'gmailConnected': gmailConnected,
    'gmailImportSeeded': gmailImportSeeded,
    'userTimeZoneLabel': userTimeZoneLabel,
    'quietHoursEnabled': quietHoursEnabled,
  };

  factory AppState.fromJson(Map<String, dynamic> json) {
    return AppState(
      orders: ((json['orders'] as List?) ?? const [])
          .map((e) => OrderRecord.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      gmailConnected: json['gmailConnected'] as bool? ?? false,
      gmailImportSeeded: json['gmailImportSeeded'] as bool? ?? false,
      userTimeZoneLabel:
          json['userTimeZoneLabel'] as String? ?? 'Local timezone',
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? true,
    );
  }

  static AppState seed() {
    final now = DateTime.now();
    return AppState(
      orders: [
        OrderRecord(
          id: 'seed-1',
          userId: 'local-user',
          merchantName: 'Everlane',
          orderNumber: 'EVR-19321',
          orderDate: now.subtract(const Duration(days: 12)),
          totalAmount: 128.00,
          currency: '\$',
          source: OrderSource.gmail,
          sourceMessageId: 'gmail-1',
          status: OrderStatus.mightReturn,
          returnDeadlineDate: now.add(const Duration(days: 3)),
          returnDeadlineConfidence: DeadlineConfidence.confirmed,
          deadlineBasisNote: 'Explicit date parsed from merchant email.',
          merchantReturnUrl: 'https://www.everlane.com/account/orders',
          notes: 'Sizing feels off.',
          expectedRefundAmount: 128.00,
          createdAt: now,
          updatedAt: now,
        ),
        OrderRecord(
          id: 'seed-2',
          userId: 'local-user',
          merchantName: 'Target',
          orderNumber: 'TG-28844',
          orderDate: now.subtract(const Duration(days: 21)),
          totalAmount: 62.49,
          currency: '\$',
          source: OrderSource.manual,
          status: OrderStatus.waitingForRefund,
          returnDeadlineDate: now.subtract(const Duration(days: 2)),
          returnDeadlineConfidence: DeadlineConfidence.estimated,
          deadlineBasisNote: 'Estimated from merchant policy and order date.',
          merchantReturnUrl: 'https://www.target.com/returns',
          expectedRefundAmount: 62.49,
          startedAt: now.subtract(const Duration(days: 9)),
          droppedOffAt: now.subtract(const Duration(days: 8)),
          methodNote: 'UPS Store drop-off',
          lastRefundReminderAt: now.subtract(const Duration(days: 1)),
          createdAt: now,
          updatedAt: now,
        ),
        OrderRecord(
          id: 'seed-3',
          userId: 'local-user',
          merchantName: 'Nordstrom Rack',
          orderDate: now.subtract(const Duration(days: 4)),
          totalAmount: 44.95,
          currency: '\$',
          source: OrderSource.gmail,
          sourceMessageId: 'gmail-2',
          status: OrderStatus.tracked,
          returnDeadlineConfidence: DeadlineConfidence.unknown,
          deadlineBasisNote: 'Need manual deadline confirmation.',
          expectedRefundAmount: 44.95,
          createdAt: now,
          updatedAt: now,
        ),
      ],
      gmailConnected: false,
      gmailImportSeeded: false,
      userTimeZoneLabel: 'Local timezone',
      quietHoursEnabled: true,
    );
  }
}

class ReturnReadyHomePage extends StatefulWidget {
  const ReturnReadyHomePage({super.key});

  @override
  State<ReturnReadyHomePage> createState() => _ReturnReadyHomePageState();
}

class _ReturnReadyHomePageState extends State<ReturnReadyHomePage> {
  static const _prefsKey = 'return_ready_state_v1';

  AppState _state = AppState.seed();
  bool _loading = true;
  int _tabIndex = 0;
  InboxFilter _filter = InboxFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _state = AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_state.toJson()));
  }

  Future<void> _saveState(AppState next) async {
    setState(() => _state = next);
    await _persist();
  }

  Future<void> _connectGmail() async {
    final now = DateTime.now();
    var next = _state.copyWith(gmailConnected: true);
    if (!_state.gmailImportSeeded) {
      final imports = [
        OrderRecord(
          id: 'gmail-${now.millisecondsSinceEpoch}',
          userId: 'local-user',
          merchantName: 'Madewell',
          orderNumber: 'MDW-1002',
          orderDate: now.subtract(const Duration(days: 9)),
          totalAmount: 86.50,
          currency: '\$',
          source: OrderSource.gmail,
          sourceMessageId: 'gmail-3',
          status: OrderStatus.tracked,
          returnDeadlineDate: now.add(const Duration(days: 6)),
          returnDeadlineConfidence: DeadlineConfidence.estimated,
          deadlineBasisNote: 'Estimated from merchant policy using order date.',
          merchantReturnUrl: 'https://www.madewell.com/orders',
          expectedRefundAmount: 86.50,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      next = next.copyWith(
        gmailImportSeeded: true,
        orders: [...imports, ...next.orders],
      );
    }
    await _saveState(next);
  }

  Future<void> _disconnectGmail() async {
    await _saveState(_state.copyWith(gmailConnected: false));
  }

  Future<void> _upsertOrder(OrderRecord order) async {
    final orders = [..._state.orders];
    final index = orders.indexWhere((candidate) => candidate.id == order.id);
    if (index >= 0) {
      orders[index] = order.copyWith(updatedAt: DateTime.now());
    } else {
      orders.insert(0, order);
    }
    await _saveState(_state.copyWith(orders: orders));
  }

  Future<void> _deleteOrder(OrderRecord order) async {
    await _saveState(
      _state.copyWith(
        orders: _state.orders
            .where((candidate) => candidate.id != order.id)
            .toList(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${order.merchantName} order.')),
    );
  }

  Future<void> _showOrderForm({OrderRecord? existing}) async {
    final result = await showModalBottomSheet<OrderRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => OrderFormSheet(existing: existing),
    );
    if (result == null) return;
    await _upsertOrder(result);
  }

  Future<void> _openOrderDetails(OrderRecord order) async {
    final action = await showModalBottomSheet<_OrderActionResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => OrderDetailSheet(order: order),
    );
    if (action == null) return;

    switch (action.type) {
      case _OrderActionType.save:
        await _upsertOrder(action.order!);
        break;
      case _OrderActionType.edit:
        await _showOrderForm(existing: order);
        break;
      case _OrderActionType.delete:
        await _deleteOrder(order);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filteredOrders = _applyFilter(_state.orders, _filter);
    final layout = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final dashboard = DashboardTab(
          state: _state,
          onConnectGmail: _connectGmail,
          onDisconnectGmail: _disconnectGmail,
          onAddOrder: () => _showOrderForm(),
          onOpenOrder: _openOrderDetails,
        );
        final inbox = OrdersInboxTab(
          orders: filteredOrders,
          selectedFilter: _filter,
          onFilterChanged: (value) => setState(() => _filter = value),
          onAddOrder: () => _showOrderForm(),
          onOpenOrder: _openOrderDetails,
        );
        final setup = SetupTab(
          state: _state,
          onConnectGmail: _connectGmail,
          onDisconnectGmail: _disconnectGmail,
          onAddOrder: () => _showOrderForm(),
        );

        final pages = [dashboard, inbox, setup];
        if (!wide) return pages[_tabIndex];

        return Row(
          children: [
            NavigationRail(
              selectedIndex: _tabIndex,
              onDestinationSelected: (value) =>
                  setState(() => _tabIndex = value),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inbox_outlined),
                  selectedIcon: Icon(Icons.inbox),
                  label: Text('Inbox'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Setup'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages[_tabIndex]),
          ],
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('ReturnReady'),
        actions: [
          IconButton(
            tooltip: 'Add order',
            onPressed: () => _showOrderForm(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      body: layout,
      bottomNavigationBar: MediaQuery.of(context).size.width < 1000
          ? NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (value) =>
                  setState(() => _tabIndex = value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.space_dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Setup',
                ),
              ],
            )
          : null,
    );
  }
}

List<OrderRecord> _applyFilter(List<OrderRecord> orders, InboxFilter filter) {
  final now = DateTime.now();
  final sorted = [...orders]
    ..sort((a, b) {
      final aUrgency = _urgencyScore(a, now);
      final bUrgency = _urgencyScore(b, now);
      if (aUrgency != bUrgency) return bUrgency.compareTo(aUrgency);
      return b.updatedAt.compareTo(a.updatedAt);
    });

  return sorted.where((order) {
    switch (filter) {
      case InboxFilter.all:
        return true;
      case InboxFilter.actionNeeded:
        final days = order.daysUntilDeadline(now);
        return order.status == OrderStatus.mightReturn ||
            order.status == OrderStatus.tracked ||
            (days != null && days <= 3) ||
            order.returnDeadlineConfidence == DeadlineConfidence.unknown;
      case InboxFilter.waitingForRefund:
        return order.status == OrderStatus.waitingForRefund;
      case InboxFilter.refunded:
        return order.status == OrderStatus.refunded;
    }
  }).toList();
}

int _urgencyScore(OrderRecord order, DateTime now) {
  if (order.status == OrderStatus.waitingForRefund) return 90;
  if (order.status == OrderStatus.mightReturn) return 80;
  final days = order.daysUntilDeadline(now);
  if (days != null && days <= 1) return 100;
  if (days != null && days <= 3) return 95;
  if (order.returnDeadlineConfidence == DeadlineConfidence.unknown) return 70;
  if (order.status == OrderStatus.refunded) return 10;
  return 50;
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({
    super.key,
    required this.state,
    required this.onConnectGmail,
    required this.onDisconnectGmail,
    required this.onAddOrder,
    required this.onOpenOrder,
  });

  final AppState state;
  final Future<void> Function() onConnectGmail;
  final Future<void> Function() onDisconnectGmail;
  final VoidCallback onAddOrder;
  final Future<void> Function(OrderRecord order) onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final orders = [...state.orders];
    orders.sort(
      (a, b) => _urgencyScore(b, now).compareTo(_urgencyScore(a, now)),
    );

    final nearDeadline = orders.where((order) {
      final days = order.daysUntilDeadline(now);
      return days != null && days <= 3 && order.status != OrderStatus.refunded;
    }).toList();
    final waitingRefund = orders
        .where((order) => order.status == OrderStatus.waitingForRefund)
        .toList();
    final atRiskAmount = moneyAtRisk(orders, now);
    final knownDeadlineCount = orders
        .where((order) => order.deadlineKnown)
        .length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                title: 'Money at risk',
                value: '\$${atRiskAmount.toStringAsFixed(2)}',
                detail: 'Might Return + Waiting for Refund',
                icon: Icons.attach_money,
              ),
              _MetricCard(
                title: 'Deadlines within 3 days',
                value: '${nearDeadline.length}',
                detail: 'Highest-priority action surface',
                icon: Icons.timer_outlined,
              ),
              _MetricCard(
                title: 'Waiting for refund',
                value: '${waitingRefund.length}',
                detail: 'Follow up after 7 and 14 days',
                icon: Icons.refresh,
              ),
              _MetricCard(
                title: 'Known deadlines',
                value: '$knownDeadlineCount / ${orders.length}',
                detail: 'Unknown deadlines prompt manual follow-up',
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Launch wedge',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Never miss a return window, and do not forget unfinished refunds.',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: onAddOrder,
                      icon: const Icon(Icons.add),
                      label: const Text('Add order manually'),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.gmailConnected
                          ? onDisconnectGmail
                          : onConnectGmail,
                      icon: Icon(
                        state.gmailConnected
                            ? Icons.link_off
                            : Icons.mail_outline,
                      ),
                      label: Text(
                        state.gmailConnected
                            ? 'Disconnect Gmail'
                            : 'Connect Gmail',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Action queue',
            child: Column(
              children: [
                if (orders.isEmpty)
                  const ListTile(
                    title: Text('No orders yet'),
                    subtitle: Text(
                      'Add a manual order or connect Gmail to get started.',
                    ),
                  ),
                for (final order in orders.take(6))
                  OrderTile(order: order, onTap: () => onOpenOrder(order)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Reminder rules',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('• Deadline reminders: 7, 3, and 1 day before deadline.'),
                Text(
                  '• Same-day reminders only for orders marked Might Return.',
                ),
                Text('• Unknown deadlines trigger “Add return deadline”.'),
                Text(
                  '• Refund follow-up: 7 days after drop-off, then 14 days if unresolved.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double moneyAtRisk(List<OrderRecord> orders, DateTime now) {
  double total = 0;
  for (final order in orders) {
    final days = order.daysUntilDeadline(now);
    final notExpired = days == null || days >= 0;
    if (order.status == OrderStatus.mightReturn &&
        order.deadlineKnown &&
        notExpired) {
      total += order.totalAmount;
    }
    if (order.status == OrderStatus.waitingForRefund) {
      total += order.expectedRefundAmount ?? order.totalAmount;
    }
  }
  return total;
}

class OrdersInboxTab extends StatelessWidget {
  const OrdersInboxTab({
    super.key,
    required this.orders,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onAddOrder,
    required this.onOpenOrder,
  });

  final List<OrderRecord> orders;
  final InboxFilter selectedFilter;
  final ValueChanged<InboxFilter> onFilterChanged;
  final VoidCallback onAddOrder;
  final Future<void> Function(OrderRecord order) onOpenOrder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: InboxFilter.values
                .map(
                  (filter) => ChoiceChip(
                    label: Text(filter.label),
                    selected: filter == selectedFilter,
                    onSelected: (_) => onFilterChanged(filter),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Tracked orders',
            child: Column(
              children: [
                if (orders.isEmpty)
                  ListTile(
                    title: const Text('No orders match this filter'),
                    subtitle: const Text(
                      'Try a different inbox filter or add your first order.',
                    ),
                    trailing: FilledButton(
                      onPressed: onAddOrder,
                      child: const Text('Add order'),
                    ),
                  ),
                for (final order in orders)
                  OrderTile(order: order, onTap: () => onOpenOrder(order)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SetupTab extends StatelessWidget {
  const SetupTab({
    super.key,
    required this.state,
    required this.onConnectGmail,
    required this.onDisconnectGmail,
    required this.onAddOrder,
  });

  final AppState state;
  final Future<void> Function() onConnectGmail;
  final Future<void> Function() onDisconnectGmail;
  final VoidCallback onAddOrder;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Setup flow',
            child: Column(
              children: [
                _StepTile(
                  index: 1,
                  title: 'Create an account',
                  subtitle:
                      'Use the mobile app or the lightweight responsive web app.',
                ),
                _StepTile(
                  index: 2,
                  title: 'Choose a capture path',
                  subtitle: state.gmailConnected
                      ? 'Gmail connected for order import.'
                      : 'Connect Gmail or start with manual order entry.',
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: state.gmailConnected
                            ? onDisconnectGmail
                            : onConnectGmail,
                        child: Text(
                          state.gmailConnected
                              ? 'Disconnect Gmail'
                              : 'Connect Gmail',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: onAddOrder,
                        child: const Text('Manual entry'),
                      ),
                    ],
                  ),
                ),
                _StepTile(
                  index: 3,
                  title: 'Understand trust levels',
                  subtitle:
                      'Confirmed deadlines are explicit. Estimated deadlines use merchant policy. Unknown deadlines stay manual.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Privacy and trust',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('• Gmail access is used to find order-related emails.'),
                Text(
                  '• Non-order emails are not surfaced as user-facing records.',
                ),
                Text('• Users can disconnect Gmail at any time.'),
                Text('• Imported orders and proof attachments can be deleted.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'What is in MVP',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('• Orders inbox with action-focused filters'),
                Text('• Manual order entry'),
                Text('• Gmail import simulation path for onboarding'),
                Text('• Order-level lifecycle from Tracked to Refunded'),
                Text('• Refund follow-up reminders and optional proof storage'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({super.key, required this.order, required this.onTap});

  final OrderRecord order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final deadlineText = _deadlineSummary(order, now);
    final badgeColor = _deadlineColor(order, now, context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        onTap: onTap,
        title: Text(order.merchantName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${_formatDate(order.orderDate)} • ${order.amountLabel()} • ${order.status.label}',
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text(deadlineText), backgroundColor: badgeColor),
                Chip(label: Text(order.returnDeadlineConfidence.label)),
                if (order.source == OrderSource.gmail)
                  const Chip(label: Text('Gmail import')),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

String _deadlineSummary(OrderRecord order, DateTime now) {
  final days = order.daysUntilDeadline(now);
  if (order.returnDeadlineConfidence == DeadlineConfidence.unknown ||
      order.returnDeadlineDate == null) {
    return 'Add return deadline';
  }
  if (days! < 0) return 'Deadline passed';
  if (days == 0) return 'Deadline today';
  return '$days day${days == 1 ? '' : 's'} left';
}

Color _deadlineColor(OrderRecord order, DateTime now, BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final days = order.daysUntilDeadline(now);
  if (order.returnDeadlineConfidence == DeadlineConfidence.unknown ||
      days == null) {
    return scheme.surfaceContainerHighest;
  }
  if (days <= 1) return scheme.errorContainer;
  if (days <= 3) return scheme.tertiaryContainer;
  return scheme.secondaryContainer;
}

class OrderFormSheet extends StatefulWidget {
  const OrderFormSheet({super.key, this.existing});

  final OrderRecord? existing;

  @override
  State<OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends State<OrderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _orderNumberController;
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late final TextEditingController _returnUrlController;
  late final TextEditingController _notesController;
  late final TextEditingController _basisNoteController;
  late final TextEditingController _expectedRefundController;
  late DateTime _orderDate;
  DateTime? _deadlineDate;
  late DeadlineConfidence _confidence;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _merchantController = TextEditingController(
      text: existing?.merchantName ?? '',
    );
    _orderNumberController = TextEditingController(
      text: existing?.orderNumber ?? '',
    );
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.totalAmount.toStringAsFixed(2),
    );
    _currencyController = TextEditingController(
      text: existing?.currency ?? '\$',
    );
    _returnUrlController = TextEditingController(
      text: existing?.merchantReturnUrl ?? '',
    );
    _notesController = TextEditingController(text: existing?.notes ?? '');
    _basisNoteController = TextEditingController(
      text: existing?.deadlineBasisNote ?? '',
    );
    _expectedRefundController = TextEditingController(
      text: existing?.expectedRefundAmount == null
          ? ''
          : existing!.expectedRefundAmount!.toStringAsFixed(2),
    );
    _orderDate = existing?.orderDate ?? DateTime.now();
    _deadlineDate = existing?.returnDeadlineDate;
    _confidence =
        existing?.returnDeadlineConfidence ?? DeadlineConfidence.unknown;
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _orderNumberController.dispose();
    _amountController.dispose();
    _currencyController.dispose();
    _returnUrlController.dispose();
    _notesController.dispose();
    _basisNoteController.dispose();
    _expectedRefundController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (selected != null) onPicked(selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final existing = widget.existing;
    final amount = double.parse(_amountController.text.trim());
    final expectedRefund = _expectedRefundController.text.trim().isEmpty
        ? amount
        : double.tryParse(_expectedRefundController.text.trim()) ?? amount;

    final order = OrderRecord(
      id:
          existing?.id ??
          'manual-${now.microsecondsSinceEpoch}-${Random().nextInt(9999)}',
      userId: 'local-user',
      merchantName: _merchantController.text.trim(),
      orderNumber: _emptyToNull(_orderNumberController.text),
      orderDate: _orderDate,
      totalAmount: amount,
      currency: _currencyController.text.trim().isEmpty
          ? '\$'
          : _currencyController.text.trim(),
      source: existing?.source ?? OrderSource.manual,
      sourceMessageId: existing?.sourceMessageId,
      status: existing?.status ?? OrderStatus.tracked,
      returnDeadlineDate: _confidence == DeadlineConfidence.unknown
          ? null
          : _deadlineDate,
      returnDeadlineConfidence: _confidence,
      deadlineBasisNote: _emptyToNull(_basisNoteController.text),
      merchantReturnUrl: _emptyToNull(_returnUrlController.text),
      notes: _emptyToNull(_notesController.text),
      expectedRefundAmount: expectedRefund,
      actualRefundAmount: existing?.actualRefundAmount,
      refundReceivedDate: existing?.refundReceivedDate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
      startedAt: existing?.startedAt,
      droppedOffAt: existing?.droppedOffAt,
      methodNote: existing?.methodNote,
      proofAttachmentUrl: existing?.proofAttachmentUrl,
      lastRefundReminderAt: existing?.lastRefundReminderAt,
    );

    Navigator.of(context).pop(order);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.existing == null ? 'Add order' : 'Edit order',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _merchantController,
                  decoration: const InputDecoration(labelText: 'Merchant name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Total amount',
                        ),
                        validator: (value) =>
                            double.tryParse(value ?? '') == null
                            ? 'Enter a valid amount'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: _currencyController,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _orderNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Order number (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Order date'),
                  subtitle: Text(_formatDate(_orderDate)),
                  trailing: OutlinedButton(
                    onPressed: () => _pickDate(
                      initial: _orderDate,
                      onPicked: (value) => setState(() => _orderDate = value),
                    ),
                    child: const Text('Choose'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DeadlineConfidence>(
                  initialValue: _confidence,
                  decoration: const InputDecoration(
                    labelText: 'Deadline status',
                  ),
                  items: DeadlineConfidence.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _confidence = value ?? DeadlineConfidence.unknown,
                  ),
                ),
                if (_confidence != DeadlineConfidence.unknown) ...[
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Return deadline'),
                    subtitle: Text(
                      _deadlineDate == null
                          ? 'Pick a date'
                          : _formatDate(_deadlineDate!),
                    ),
                    trailing: OutlinedButton(
                      onPressed: () => _pickDate(
                        initial: _deadlineDate ?? _orderDate,
                        onPicked: (value) =>
                            setState(() => _deadlineDate = value),
                      ),
                      child: const Text('Choose'),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _basisNoteController,
                  decoration: const InputDecoration(
                    labelText: 'Deadline basis note (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _returnUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant return URL (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _expectedRefundController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Expected refund amount (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  child: Text(
                    widget.existing == null ? 'Save order' : 'Save changes',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OrderDetailSheet extends StatefulWidget {
  const OrderDetailSheet({super.key, required this.order});

  final OrderRecord order;

  @override
  State<OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<OrderDetailSheet> {
  late OrderRecord _order;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  void _save() {
    Navigator.of(
      context,
    ).pop(_OrderActionResult.save(_order.copyWith(updatedAt: DateTime.now())));
  }

  Future<void> _pickProof() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null) return;
    setState(() {
      _order = _order.copyWith(proofAttachmentUrl: file.path);
    });
  }

  void _markMightReturn() {
    setState(() {
      _order = _order.copyWith(
        status: OrderStatus.mightReturn,
        expectedRefundAmount: _order.expectedRefundAmount ?? _order.totalAmount,
      );
    });
  }

  void _markReturnStarted() {
    final now = DateTime.now();
    setState(() {
      _order = _order.copyWith(
        status: OrderStatus.returnStarted,
        startedAt: _order.startedAt ?? now,
      );
    });
  }

  void _markDroppedOff() {
    final now = DateTime.now();
    setState(() {
      _order = _order.copyWith(
        status: OrderStatus.waitingForRefund,
        droppedOffAt: _order.droppedOffAt ?? now,
        expectedRefundAmount: _order.expectedRefundAmount ?? _order.totalAmount,
        lastRefundReminderAt: now.add(const Duration(days: 7)),
      );
    });
  }

  Future<void> _markRefundReceived() async {
    final controller = TextEditingController(
      text:
          (_order.actualRefundAmount ??
                  _order.expectedRefundAmount ??
                  _order.totalAmount)
              .toStringAsFixed(2),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark refund received'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Actual refund amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              double.tryParse(controller.text.trim()) ?? _order.totalAmount,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() {
      _order = _order.copyWith(
        status: OrderStatus.refunded,
        actualRefundAmount: result,
        refundReceivedDate: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final now = DateTime.now();
    final deadlineText = _deadlineSummary(_order, now);
    final refundReminderText = _refundReminderText(_order, now);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _order.merchantName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatDate(_order.orderDate)} • ${_order.amountLabel()}',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(_order.status.label)),
                  Chip(label: Text(deadlineText)),
                  Chip(label: Text(_order.returnDeadlineConfidence.label)),
                ],
              ),
              const SizedBox(height: 16),
              _DetailRow(
                label: 'Order number',
                value: _order.orderNumber ?? 'Not saved',
              ),
              _DetailRow(
                label: 'Source',
                value: _order.source == OrderSource.gmail
                    ? 'Gmail import'
                    : 'Manual entry',
              ),
              _DetailRow(
                label: 'Deadline basis',
                value:
                    _order.deadlineBasisNote ??
                    'Unknown, manual fallback available',
              ),
              _DetailRow(
                label: 'Return URL',
                value: _order.merchantReturnUrl ?? 'Not available yet',
              ),
              _DetailRow(
                label: 'Expected refund',
                value: _order.amountLabel(
                  _order.expectedRefundAmount ?? _order.totalAmount,
                ),
              ),
              _DetailRow(label: 'Refund follow-up', value: refundReminderText),
              _DetailRow(label: 'Notes', value: _order.notes ?? 'No notes'),
              _DetailRow(
                label: 'Proof attachment',
                value: _order.proofAttachmentUrl ?? 'No proof attached',
              ),
              const SizedBox(height: 16),
              Text(
                'Next actions',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _markMightReturn,
                    child: const Text('Mark Might Return'),
                  ),
                  OutlinedButton(
                    onPressed: _markReturnStarted,
                    child: const Text('Mark return started'),
                  ),
                  OutlinedButton(
                    onPressed: _markDroppedOff,
                    child: const Text('Mark drop-off / shipment'),
                  ),
                  FilledButton(
                    onPressed: _markRefundReceived,
                    child: const Text('Mark refund received'),
                  ),
                  OutlinedButton(
                    onPressed: _pickProof,
                    child: const Text('Attach proof'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save),
                    label: const Text('Save updates'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _OrderActionResult.edit()),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit fields'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const _OrderActionResult.delete()),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _refundReminderText(OrderRecord order, DateTime now) {
  if (order.status != OrderStatus.waitingForRefund) {
    return 'Refund reminders only fire in Waiting for Refund.';
  }
  if (order.droppedOffAt == null) {
    return 'Add a drop-off or shipment date.';
  }
  final first = order.droppedOffAt!.add(const Duration(days: 7));
  final second = order.droppedOffAt!.add(const Duration(days: 14));
  if (now.isBefore(first)) {
    return 'First reminder scheduled for ${_formatDate(first)}.';
  }
  if (now.isBefore(second)) {
    return 'Second reminder scheduled for ${_formatDate(second)} if unresolved.';
  }
  return 'Reminder cadence reached, user confirmation still needed.';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String value;
  final String detail;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 12),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(detail),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final int index;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Text('$index')),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final month = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][date.month - 1];
  return '$month ${date.day}, ${date.year}';
}

String? _emptyToNull(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? null : trimmed;
}

enum _OrderActionType { save, edit, delete }

class _OrderActionResult {
  const _OrderActionResult.save(this.order) : type = _OrderActionType.save;
  const _OrderActionResult.edit() : type = _OrderActionType.edit, order = null;
  const _OrderActionResult.delete()
    : type = _OrderActionType.delete,
      order = null;

  final _OrderActionType type;
  final OrderRecord? order;
}
