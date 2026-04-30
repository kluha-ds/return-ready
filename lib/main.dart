import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AiLifeAdminApp());
}

enum ProcessingState { received, processing, needsReview, completed, failed, duplicate }
enum WorkflowState { newItem, reviewed, actioned, waiting, done, archived }
enum ItemCategory { billPayment, bookingAppointment, receiptReturn, formNotice, other }
enum ConfidenceLevel { high, medium, low }
enum ActionType { reminder, task }
enum IntakeChannel { upload, emailForward }

class ExtractedField {
  const ExtractedField({
    required this.label,
    required this.value,
    required this.confidence,
    required this.source,
    this.unresolved = false,
  });

  final String label;
  final String value;
  final ConfidenceLevel confidence;
  final String source;
  final bool unresolved;

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'confidence': confidence.name,
        'source': source,
        'unresolved': unresolved,
      };

  factory ExtractedField.fromJson(Map<String, dynamic> json) => ExtractedField(
        label: json['label'] as String,
        value: json['value'] as String,
        confidence: ConfidenceLevel.values.byName(json['confidence'] as String),
        source: json['source'] as String,
        unresolved: json['unresolved'] as bool? ?? false,
      );
}

class AdminAction {
  const AdminAction({
    required this.id,
    required this.type,
    required this.title,
    required this.dueAt,
    required this.status,
  });

  final String id;
  final ActionType type;
  final String title;
  final DateTime? dueAt;
  final String status;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'dueAt': dueAt?.toIso8601String(),
        'status': status,
      };

  factory AdminAction.fromJson(Map<String, dynamic> json) => AdminAction(
        id: json['id'] as String,
        type: ActionType.values.byName(json['type'] as String),
        title: json['title'] as String,
        dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
        status: json['status'] as String,
      );
}

class InboxItem {
  const InboxItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.processingState,
    required this.workflowState,
    required this.channel,
    required this.receivedAt,
    required this.suggestedNextStep,
    required this.rawPreview,
    required this.stageNotes,
    required this.fields,
    required this.actions,
    this.failureReason,
    this.duplicateOf,
  });

  final String id;
  final String title;
  final String summary;
  final ItemCategory category;
  final ProcessingState processingState;
  final WorkflowState workflowState;
  final IntakeChannel channel;
  final DateTime receivedAt;
  final String suggestedNextStep;
  final String rawPreview;
  final List<String> stageNotes;
  final List<ExtractedField> fields;
  final List<AdminAction> actions;
  final String? failureReason;
  final String? duplicateOf;

  InboxItem copyWith({
    ProcessingState? processingState,
    WorkflowState? workflowState,
    List<AdminAction>? actions,
  }) => InboxItem(
        id: id,
        title: title,
        summary: summary,
        category: category,
        processingState: processingState ?? this.processingState,
        workflowState: workflowState ?? this.workflowState,
        channel: channel,
        receivedAt: receivedAt,
        suggestedNextStep: suggestedNextStep,
        rawPreview: rawPreview,
        stageNotes: stageNotes,
        fields: fields,
        actions: actions ?? this.actions,
        failureReason: failureReason,
        duplicateOf: duplicateOf,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'summary': summary,
        'category': category.name,
        'processingState': processingState.name,
        'workflowState': workflowState.name,
        'channel': channel.name,
        'receivedAt': receivedAt.toIso8601String(),
        'suggestedNextStep': suggestedNextStep,
        'rawPreview': rawPreview,
        'stageNotes': stageNotes,
        'fields': fields.map((f) => f.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'failureReason': failureReason,
        'duplicateOf': duplicateOf,
      };

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
        id: json['id'] as String,
        title: json['title'] as String,
        summary: json['summary'] as String,
        category: ItemCategory.values.byName(json['category'] as String),
        processingState: ProcessingState.values.byName(json['processingState'] as String),
        workflowState: WorkflowState.values.byName(json['workflowState'] as String),
        channel: IntakeChannel.values.byName(json['channel'] as String),
        receivedAt: DateTime.parse(json['receivedAt'] as String),
        suggestedNextStep: json['suggestedNextStep'] as String,
        rawPreview: json['rawPreview'] as String,
        stageNotes: (json['stageNotes'] as List).cast<String>(),
        fields: (json['fields'] as List)
            .map((item) => ExtractedField.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        actions: (json['actions'] as List)
            .map((item) => AdminAction.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        failureReason: json['failureReason'] as String?,
        duplicateOf: json['duplicateOf'] as String?,
      );
}

class AppStore {
  static const _key = 'ai_life_admin_v1';

  Future<List<InboxItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return seedItems();
    return (jsonDecode(raw) as List)
        .map((item) => InboxItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> save(List<InboxItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class AiLifeAdminApp extends StatelessWidget {
  const AiLifeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Life Admin Inbox',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4263EB)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = AppStore();
  bool _loading = true;
  int _tab = 0;
  String _query = '';
  List<InboxItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _store.load();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _save() => _store.save(_items);

  Future<void> _reset() async {
    await _store.clear();
    final items = seedItems();
    setState(() => _items = items);
    await _save();
  }

  Future<void> _export() async {
    final payload = const JsonEncoder.withIndent('  ')
        .convert(_items.map((e) => e.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export copied to clipboard.')),
    );
  }

  Future<void> _ingestSample(IntakeChannel channel) async {
    final sample = generatedSample(channel, _items);
    setState(() => _items = [sample, ..._items]);
    await _save();
  }

  Future<void> _updateItem(InboxItem item) async {
    setState(() {
      _items = _items.map((e) => e.id == item.id ? item : e).toList();
    });
    await _save();
  }

  List<InboxItem> get _activeInbox => _items
      .where((item) => item.workflowState != WorkflowState.archived)
      .where((item) => item.workflowState != WorkflowState.done)
      .toList();

  List<InboxItem> get _upcoming => _items
      .where((item) => item.actions.any((a) => a.dueAt != null && a.status != 'done'))
      .toList();

  List<InboxItem> get _history {
    final q = _query.trim().toLowerCase();
    final source = _items.where((item) => item.workflowState == WorkflowState.archived || item.workflowState == WorkflowState.done || item.processingState == ProcessingState.failed || item.processingState == ProcessingState.duplicate);
    if (q.isEmpty) return source.toList();
    return source.where((item) {
      final haystack = [
        item.title,
        item.summary,
        item.rawPreview,
        item.suggestedNextStep,
        ...item.fields.map((f) => '${f.label} ${f.value} ${f.source}'),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final body = switch (_tab) {
      0 => InboxView(items: _activeInbox, onOpen: _openItem, onIngest: _ingestSample),
      1 => UpcomingView(items: _upcoming, onOpen: _openItem),
      2 => SearchView(items: _history, query: _query, onChanged: (v) => setState(() => _query = v), onOpen: _openItem),
      _ => SettingsView(onExport: _export, onReset: _reset),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('AI Life Admin Inbox')),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Upcoming'),
          NavigationDestination(icon: Icon(Icons.search), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  Future<void> _openItem(InboxItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ItemSheet(item: item, onChanged: _updateItem),
    );
  }
}

class InboxView extends StatelessWidget {
  const InboxView({super.key, required this.items, required this.onOpen, required this.onIngest});

  final List<InboxItem> items;
  final Future<void> Function(InboxItem) onOpen;
  final Future<void> Function(IntakeChannel) onIngest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Forward or upload life-admin clutter', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('v1 supports uploads and a forwarding address. This prototype simulates each path with staged extraction, duplicate handling, and safe review before actions.'),
              const SizedBox(height: 12),
              const SelectableText('Forwarding address: inbox-demo@ailifeadmin.app'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(onPressed: () => onIngest(IntakeChannel.upload), icon: const Icon(Icons.upload_file_outlined), label: const Text('Simulate upload')),
                OutlinedButton.icon(onPressed: () => onIngest(IntakeChannel.emailForward), icon: const Icon(Icons.forward_to_inbox_outlined), label: const Text('Simulate forwarded email')),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => ItemCard(item: item, onTap: () => onOpen(item))),
      ],
    );
  }
}

class UpcomingView extends StatelessWidget {
  const UpcomingView({super.key, required this.items, required this.onOpen});
  final List<InboxItem> items;
  final Future<void> Function(InboxItem) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
          ? [const EmptyState(message: 'No reminders or tasks yet.')]
          : items.map((item) => ItemCard(item: item, onTap: () => onOpen(item))).toList(),
    );
  }
}

class SearchView extends StatelessWidget {
  const SearchView({super.key, required this.items, required this.query, required this.onChanged, required this.onOpen});
  final List<InboxItem> items;
  final String query;
  final ValueChanged<String> onChanged;
  final Future<void> Function(InboxItem) onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          onChanged: onChanged,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search summaries, fields, OCR text, archived items'),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => ItemCard(item: item, onTap: () => onOpen(item))),
        if (items.isEmpty) const EmptyState(message: 'No matching archived, done, failed, or duplicate items.'),
      ],
    );
  }
}

class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.onExport, required this.onReset});
  final Future<void> Function() onExport;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Trust and privacy controls', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Important fields stay editable, low-confidence date and amount values stay unresolved, and no external side effects happen without approval.'),
              const SizedBox(height: 12),
              const Text('Suggested prototype retention policy:'),
              const Text('• raw files: 30 days'),
              const Text('• OCR text and extracted fields: until user deletes or exports'),
              const Text('• model providers: use zero-retention mode before launch'),
              const Text('• deletion must clear storage, indexes, and pending queues'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: onExport, child: const Text('Export data')),
                TextButton(onPressed: onReset, child: const Text('Delete local data')),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.onTap});
  final InboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final due = item.fields.where((f) => f.label.contains('date')).toList();
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)), StatusChip(label: item.processingState.name)]),
            const SizedBox(height: 8),
            Text(item.summary),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusChip(label: item.category.name),
              StatusChip(label: item.workflowState.name),
              if (due.isNotEmpty) StatusChip(label: due.first.value),
            ]),
          ]),
        ),
      ),
    );
  }
}

class ItemSheet extends StatelessWidget {
  const ItemSheet({super.key, required this.item, required this.onChanged});
  final InboxItem item;
  final Future<void> Function(InboxItem) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(item.summary),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            StatusChip(label: 'processing: ${item.processingState.name}'),
            StatusChip(label: 'workflow: ${item.workflowState.name}'),
            StatusChip(label: 'channel: ${item.channel.name}'),
          ]),
          const SizedBox(height: 16),
          Text('Suggested next step', style: Theme.of(context).textTheme.titleMedium),
          Text(item.suggestedNextStep),
          const SizedBox(height: 16),
          Text('Extracted fields', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...item.fields.map((field) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${field.label}: ${field.value}'),
                subtitle: Text('${field.confidence.name} confidence • ${field.source}'),
                trailing: field.unresolved ? const Icon(Icons.warning_amber_rounded) : null,
              )),
          const SizedBox(height: 12),
          Text('Pipeline stages', style: Theme.of(context).textTheme.titleMedium),
          ...item.stageNotes.map((note) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $note'),
              )),
          if (item.failureReason != null) ...[
            const SizedBox(height: 12),
            Text('Failure handling', style: Theme.of(context).textTheme.titleMedium),
            Text(item.failureReason!),
          ],
          if (item.duplicateOf != null) ...[
            const SizedBox(height: 12),
            Text('Duplicate handling', style: Theme.of(context).textTheme.titleMedium),
            Text('Linked to ${item.duplicateOf}. No duplicate reminder or task was created.'),
          ],
          const SizedBox(height: 12),
          Text('Source preview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF1F3F8), borderRadius: BorderRadius.circular(12)),
            child: Text(item.rawPreview),
          ),
          const SizedBox(height: 16),
          Text('Internal actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...item.actions.map((action) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(action.title),
                subtitle: Text('${action.type.name} • ${action.dueAt?.toLocal() ?? 'No date'} • ${action.status}'),
              )),
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: () => _apply(context, item.copyWith(workflowState: WorkflowState.actioned, actions: [...item.actions, AdminAction(id: '${item.id}-r', type: ActionType.reminder, title: item.suggestedNextStep, dueAt: _extractDueDate(item), status: 'scheduled')])), child: const Text('Create reminder')),
            OutlinedButton(onPressed: () => _apply(context, item.copyWith(workflowState: WorkflowState.actioned, actions: [...item.actions, AdminAction(id: '${item.id}-t', type: ActionType.task, title: item.suggestedNextStep, dueAt: null, status: 'open')])), child: const Text('Create task')),
            OutlinedButton(onPressed: () => _apply(context, item.copyWith(workflowState: WorkflowState.done, processingState: ProcessingState.completed)), child: const Text('Mark done')),
            OutlinedButton(onPressed: () => _apply(context, item.copyWith(workflowState: WorkflowState.archived)), child: const Text('Archive')),
            TextButton(onPressed: () => _apply(context, item.copyWith(workflowState: WorkflowState.reviewed)), child: const Text('Reviewed')),
          ]),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  DateTime? _extractDueDate(InboxItem item) {
    final value = item.fields.where((f) => f.label == 'due date' || f.label == 'event date').map((f) => f.value).firstWhere((_) => true, orElse: () => '');
    return DateTime.tryParse(value);
  }

  Future<void> _apply(BuildContext context, InboxItem next) async {
    await onChanged(next);
    if (context.mounted) Navigator.pop(context);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0xFFD7DCEA))),
      child: Text(label),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Text(message)));
  }
}

List<InboxItem> seedItems() {
  return [
    _billItem(),
    _bookingItem(),
    _receiptItem(),
    _failedItem(),
    _duplicateItem(),
  ];
}

InboxItem generatedSample(IntakeChannel channel, List<InboxItem> existing) {
  final generated = _formItem(channel: channel);
  final duplicate = existing.any((item) => item.title == generated.title);
  if (!duplicate) return generated;
  return generated.copyWith(processingState: ProcessingState.duplicate).copyWith(workflowState: WorkflowState.reviewed);
}

InboxItem _billItem() {
  final now = DateTime.now();
  return InboxItem(
    id: 'bill-1',
    title: 'EnergyHub autopay notice',
    summary: 'Utility bill due soon. The amount and due date were extracted with source snippets for review.',
    category: ItemCategory.billPayment,
    processingState: ProcessingState.needsReview,
    workflowState: WorkflowState.newItem,
    channel: IntakeChannel.emailForward,
    receivedAt: now.subtract(const Duration(hours: 5)),
    suggestedNextStep: 'Create a reminder 2 days before the due date.',
    rawPreview: 'Your payment of \$84.12 is due on 2026-05-03. Please keep autopay details current.',
    stageNotes: const [
      'received',
      'normalized forwarded email and attachment metadata',
      'OCR/text extraction succeeded',
      'classified as Bill / Payment',
      'field extraction found due date, amount, provider, reference id',
      'confidence scoring marked amount and due date high confidence',
      'review-ready item created',
    ],
    fields: const [
      ExtractedField(label: 'due date', value: '2026-05-03', confidence: ConfidenceLevel.high, source: '"due on 2026-05-03"'),
      ExtractedField(label: 'amount', value: '\$84.12', confidence: ConfidenceLevel.high, source: '"payment of \$84.12"'),
      ExtractedField(label: 'provider', value: 'EnergyHub', confidence: ConfidenceLevel.high, source: 'sender line'),
      ExtractedField(label: 'reference id', value: 'EH-44021', confidence: ConfidenceLevel.medium, source: 'invoice footer'),
    ],
    actions: const [],
  );
}

InboxItem _bookingItem() {
  final now = DateTime.now();
  return InboxItem(
    id: 'booking-1',
    title: 'CityCare dental appointment',
    summary: 'Appointment confirmed. Event date is clear, but the check-in time is low confidence and left unresolved.',
    category: ItemCategory.bookingAppointment,
    processingState: ProcessingState.needsReview,
    workflowState: WorkflowState.reviewed,
    channel: IntakeChannel.upload,
    receivedAt: now.subtract(const Duration(days: 1)),
    suggestedNextStep: 'Create an internal reminder for the appointment.',
    rawPreview: 'Appointment on May 8. Arrive at 8 or 9 AM depending on office confirmation.',
    stageNotes: const [
      'received',
      'file normalization completed',
      'OCR extracted readable text from uploaded photo',
      'classified as Booking / Appointment',
      'field extraction found event date and provider',
      'confidence scoring flagged check-in time as low confidence',
      'review-ready item created with unresolved field',
    ],
    fields: const [
      ExtractedField(label: 'event date', value: '2026-05-08', confidence: ConfidenceLevel.high, source: '"Appointment on May 8"'),
      ExtractedField(label: 'provider', value: 'CityCare Dental', confidence: ConfidenceLevel.high, source: 'header text'),
      ExtractedField(label: 'amount', value: 'Not present', confidence: ConfidenceLevel.low, source: 'no amount found', unresolved: true),
      ExtractedField(label: 'booking id', value: 'CC-APT-208', confidence: ConfidenceLevel.medium, source: 'confirmation block'),
    ],
    actions: const [AdminAction(id: 'booking-1-r', type: ActionType.reminder, title: 'Dental appointment reminder', dueAt: null, status: 'draft')],
  );
}

InboxItem _receiptItem() {
  final now = DateTime.now();
  return InboxItem(
    id: 'receipt-1',
    title: 'LoopMart return window',
    summary: 'Receipt processed with a likely return-by date and merchant. Suggest a task if you still want to return the item.',
    category: ItemCategory.receiptReturn,
    processingState: ProcessingState.needsReview,
    workflowState: WorkflowState.waiting,
    channel: IntakeChannel.upload,
    receivedAt: now.subtract(const Duration(days: 2)),
    suggestedNextStep: 'Create a task to decide on the return before the window closes.',
    rawPreview: 'Purchased on Apr 25. Returns accepted within 14 days with receipt.',
    stageNotes: const [
      'received',
      'file normalization completed',
      'text extraction succeeded',
      'classified as Receipt / Return',
      'field extraction inferred return deadline from policy text',
      'confidence scoring marked merchant high and date medium confidence',
      'review-ready item created',
    ],
    fields: const [
      ExtractedField(label: 'due date', value: '2026-05-09', confidence: ConfidenceLevel.medium, source: '"within 14 days"'),
      ExtractedField(label: 'merchant', value: 'LoopMart', confidence: ConfidenceLevel.high, source: 'receipt header'),
      ExtractedField(label: 'amount', value: '\$42.55', confidence: ConfidenceLevel.high, source: 'total line'),
    ],
    actions: const [],
  );
}

InboxItem _formItem({IntakeChannel channel = IntakeChannel.upload}) {
  final now = DateTime.now();
  return InboxItem(
    id: 'form-${now.microsecondsSinceEpoch}',
    title: 'Parking permit renewal form',
    summary: 'A new notice was ingested and summarized into one safe next step.',
    category: ItemCategory.formNotice,
    processingState: ProcessingState.needsReview,
    workflowState: WorkflowState.newItem,
    channel: channel,
    receivedAt: now,
    suggestedNextStep: 'Create a task to submit the renewal form this week.',
    rawPreview: 'Renew by May 12 to avoid permit expiration. Fee due: \$15.',
    stageNotes: const [
      'received',
      'normalization completed',
      'OCR/text extraction succeeded',
      'classified as Form / Notice',
      'field extraction found due date and amount',
      'confidence scoring marked due date high confidence',
      'review-ready item created',
    ],
    fields: const [
      ExtractedField(label: 'due date', value: '2026-05-12', confidence: ConfidenceLevel.high, source: '"Renew by May 12"'),
      ExtractedField(label: 'amount', value: '\$15.00', confidence: ConfidenceLevel.high, source: '"Fee due: \$15"'),
      ExtractedField(label: 'provider', value: 'City Parking', confidence: ConfidenceLevel.medium, source: 'header stamp'),
    ],
    actions: const [],
  );
}

InboxItem _failedItem() {
  return InboxItem(
    id: 'failed-1',
    title: 'Password-protected PDF',
    summary: 'The file was preserved but could not be processed automatically.',
    category: ItemCategory.other,
    processingState: ProcessingState.failed,
    workflowState: WorkflowState.archived,
    channel: IntakeChannel.upload,
    receivedAt: DateTime.now().subtract(const Duration(days: 3)),
    suggestedNextStep: 'Unlock the file and re-upload it.',
    rawPreview: 'Encrypted document detected.',
    stageNotes: const [
      'received',
      'normalization failed during PDF text extraction',
      'safe fallback preserved the original item',
    ],
    fields: const [],
    actions: const [],
    failureReason: 'Password-protected PDFs, oversized files, unreadable images, and unsupported types should fail safely with clear user guidance.',
  );
}

InboxItem _duplicateItem() {
  return InboxItem(
    id: 'dup-1',
    title: 'EnergyHub autopay notice',
    summary: 'This item matched an earlier submission and was marked duplicate.',
    category: ItemCategory.billPayment,
    processingState: ProcessingState.duplicate,
    workflowState: WorkflowState.archived,
    channel: IntakeChannel.emailForward,
    receivedAt: DateTime.now().subtract(const Duration(days: 4)),
    suggestedNextStep: 'Review the original item instead of creating a second reminder.',
    rawPreview: 'Duplicate forwarded email detected.',
    stageNotes: const [
      'received',
      'normalized email metadata',
      'duplicate heuristics matched title, amount, and due date',
      'duplicate item created without extra actions',
    ],
    fields: const [],
    actions: const [],
    duplicateOf: 'bill-1',
  );
}
