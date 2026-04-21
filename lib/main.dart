import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AiLifeAdminApp());
}

enum CaptureSourceType { share, upload, scan, forwardedEmail }
enum ItemState { newItem, needsReview, inbox, scheduled, waiting, archived, done }
enum TopicCategory { healthcare, school, money, travel, subscriptions, home, other }
enum ActionKind { confirmReminder, followUpReminder, archiveRecord, markDone, manualReview }
enum ConfidenceLevel { high, low, undetermined }

class EvidenceSnippet {
  EvidenceSnippet({required this.label, required this.text});

  final String label;
  final String text;

  Map<String, dynamic> toJson() => {'label': label, 'text': text};

  factory EvidenceSnippet.fromJson(Map<String, dynamic> json) => EvidenceSnippet(
    label: json['label'] as String,
    text: json['text'] as String,
  );
}

class ExtractedFact {
  ExtractedFact({
    required this.label,
    required this.value,
    required this.confidence,
    this.evidence,
    this.isCritical = false,
    this.confirmed = false,
  });

  String label;
  String value;
  ConfidenceLevel confidence;
  EvidenceSnippet? evidence;
  bool isCritical;
  bool confirmed;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'confidence': confidence.name,
    'evidence': evidence?.toJson(),
    'isCritical': isCritical,
    'confirmed': confirmed,
  };

  factory ExtractedFact.fromJson(Map<String, dynamic> json) => ExtractedFact(
    label: json['label'] as String,
    value: json['value'] as String,
    confidence: ConfidenceLevel.values.byName(json['confidence'] as String),
    evidence: json['evidence'] == null ? null : EvidenceSnippet.fromJson(Map<String, dynamic>.from(json['evidence'] as Map)),
    isCritical: json['isCritical'] as bool? ?? false,
    confirmed: json['confirmed'] as bool? ?? false,
  );
}

class TimelineEvent {
  TimelineEvent({required this.label, required this.at});

  final String label;
  final DateTime at;

  Map<String, dynamic> toJson() => {'label': label, 'at': at.toIso8601String()};

  factory TimelineEvent.fromJson(Map<String, dynamic> json) => TimelineEvent(
    label: json['label'] as String,
    at: DateTime.parse(json['at'] as String),
  );
}

class InboxItem {
  InboxItem({
    required this.id,
    required this.sourceType,
    required this.sourceTitle,
    required this.sourceText,
    required this.summary,
    required this.plainLanguageExplanation,
    required this.recommendedNextStep,
    required this.state,
    required this.category,
    required this.facts,
    required this.createdAt,
    this.sourcePath,
    this.documentType = 'general notice',
    this.eventDate,
    this.dueDate,
    this.amount,
    this.provider,
    this.contact,
    this.referenceNumber,
    this.urgent = false,
    this.overdueNudges = false,
    this.reminderLabel,
    this.history = const [],
  });

  String id;
  CaptureSourceType sourceType;
  String sourceTitle;
  String sourceText;
  String summary;
  String plainLanguageExplanation;
  String recommendedNextStep;
  ItemState state;
  TopicCategory category;
  List<ExtractedFact> facts;
  DateTime createdAt;
  String documentType;
  DateTime? eventDate;
  DateTime? dueDate;
  String? amount;
  String? provider;
  String? contact;
  String? referenceNumber;
  String? sourcePath;
  bool urgent;
  bool overdueNudges;
  String? reminderLabel;
  List<TimelineEvent> history;

  Map<String, dynamic> toJson() => {
    'id': id,
    'sourceType': sourceType.name,
    'sourceTitle': sourceTitle,
    'sourceText': sourceText,
    'summary': summary,
    'plainLanguageExplanation': plainLanguageExplanation,
    'recommendedNextStep': recommendedNextStep,
    'state': state.name,
    'category': category.name,
    'facts': facts.map((fact) => fact.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'documentType': documentType,
    'eventDate': eventDate?.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'amount': amount,
    'provider': provider,
    'contact': contact,
    'referenceNumber': referenceNumber,
    'sourcePath': sourcePath,
    'urgent': urgent,
    'overdueNudges': overdueNudges,
    'reminderLabel': reminderLabel,
    'history': history.map((event) => event.toJson()).toList(),
  };

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
    id: json['id'] as String,
    sourceType: CaptureSourceType.values.byName(json['sourceType'] as String),
    sourceTitle: json['sourceTitle'] as String,
    sourceText: json['sourceText'] as String,
    summary: json['summary'] as String,
    plainLanguageExplanation: json['plainLanguageExplanation'] as String,
    recommendedNextStep: json['recommendedNextStep'] as String,
    state: ItemState.values.byName(json['state'] as String),
    category: TopicCategory.values.byName(json['category'] as String),
    facts: ((json['facts'] as List?) ?? [])
        .map((fact) => ExtractedFact.fromJson(Map<String, dynamic>.from(fact as Map)))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    documentType: json['documentType'] as String? ?? 'general notice',
    eventDate: json['eventDate'] == null ? null : DateTime.parse(json['eventDate'] as String),
    dueDate: json['dueDate'] == null ? null : DateTime.parse(json['dueDate'] as String),
    amount: json['amount'] as String?,
    provider: json['provider'] as String?,
    contact: json['contact'] as String?,
    referenceNumber: json['referenceNumber'] as String?,
    sourcePath: json['sourcePath'] as String?,
    urgent: json['urgent'] as bool? ?? false,
    overdueNudges: json['overdueNudges'] as bool? ?? false,
    reminderLabel: json['reminderLabel'] as String?,
    history: ((json['history'] as List?) ?? [])
        .map((event) => TimelineEvent.fromJson(Map<String, dynamic>.from(event as Map)))
        .toList(),
  );
}

class AppStorage {
  static const _itemsKey = 'items_v2';
  static const _signedInKey = 'signed_in';
  static const _quietHoursKey = 'quiet_hours';

  Future<List<InboxItem>> loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_itemsKey);
      if (raw == null || raw.isEmpty) return _seedItems();
      return (jsonDecode(raw) as List<dynamic>)
          .map((item) => InboxItem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } on MissingPluginException {
      return _seedItems();
    }
  }

  Future<void> saveItems(List<InboxItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_itemsKey, jsonEncode(items.map((item) => item.toJson()).toList()));
    } on MissingPluginException {
      return;
    }
  }

  Future<bool> loadSignedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_signedInKey) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> saveSignedIn(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_signedInKey, value);
    } on MissingPluginException {
      return;
    }
  }

  Future<bool> loadQuietHours() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_quietHoursKey) ?? true;
    } on MissingPluginException {
      return true;
    }
  }

  Future<void> saveQuietHours(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_quietHoursKey, value);
    } on MissingPluginException {
      return;
    }
  }

  Future<String> exportItems(List<InboxItem> items) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ai_life_admin_export.json');
    await file.writeAsString(jsonEncode({'items': items.map((item) => item.toJson()).toList()}));
    return file.path;
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_itemsKey);
    await prefs.remove(_signedInKey);
    await prefs.remove(_quietHoursKey);
  }
}

class AiLifeAdminApp extends StatelessWidget {
  const AiLifeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Life Admin',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51F7)),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = AppStorage();
  final _picker = ImagePicker();
  final _searchController = TextEditingController();
  final _pasteController = TextEditingController();
  List<InboxItem> _items = [];
  bool _loading = true;
  bool _signedIn = false;
  bool _quietHours = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _storage.loadItems();
    final signedIn = await _storage.loadSignedIn();
    final quietHours = await _storage.loadQuietHours();
    if (!mounted) return;
    setState(() {
      _items = items;
      _signedIn = signedIn;
      _quietHours = quietHours;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _storage.saveItems(_items);
    await _storage.saveSignedIn(_signedIn);
    await _storage.saveQuietHours(_quietHours);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final archive = _items.where((item) => item.state == ItemState.archived || item.state == ItemState.done).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('AI Life Admin')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCaptureSheet,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Capture'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.search_outlined), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _tab,
          children: [
            _buildInboxView(),
            _buildSearchView(archive),
            _buildSettingsView(),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxView() {
    final needsReview = _items.where((item) => item.state == ItemState.needsReview).toList();
    final inbox = _items.where((item) => item.state == ItemState.inbox).toList();
    final urgent = _items.where((item) => item.urgent && item.state != ItemState.archived && item.state != ItemState.done).toList();
    final upcoming = _items.where((item) => item.state == ItemState.scheduled).toList();
    final waiting = _items.where((item) => item.state == ItemState.waiting).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What needs my attention now?', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(_signedIn
                    ? 'Capture screenshots, PDFs, scans, or forwarded emails. Review extracted facts, confirm anything important, then schedule or archive with confidence.'
                    : 'Sign in to try the mobile-first capture and triage flow for life-admin paperwork.'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(onPressed: _signedIn ? _showCaptureSheet : _signIn, child: Text(_signedIn ? 'Capture item' : 'Sign in')),
                    OutlinedButton(onPressed: _loadExample, child: const Text('Load example')),
                    Chip(label: Text('Needs review ${needsReview.length}')),
                    Chip(label: Text('Urgent ${urgent.length}')),
                    Chip(label: Text('Upcoming ${upcoming.length}')),
                  ],
                ),
              ],
            ),
          ),
        ),
        _section('Needs review', needsReview),
        _section('Inbox', inbox),
        _section('Urgent', urgent),
        _section('Upcoming', upcoming),
        _section('Waiting', waiting),
      ],
    );
  }

  Widget _buildSearchView(List<InboxItem> archive) {
    final query = _searchController.text.toLowerCase();
    final filtered = archive.where((item) {
      if (query.isEmpty) return true;
      return item.summary.toLowerCase().contains(query) ||
          item.sourceText.toLowerCase().contains(query) ||
          item.sourceTitle.toLowerCase().contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search archived records',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Archived records', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ...filtered.map(_itemCard),
        if (filtered.isEmpty) const Card(child: ListTile(title: Text('No archived matches'))),
      ],
    );
  }

  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Desktop/web MVP support', style: Theme.of(context).textTheme.titleLarge),
        const Card(
          child: ListTile(
            title: Text('Supportive review experience'),
            subtitle: Text('This prototype focuses on mobile capture and triage, while preserving searchable records and item detail for later review.'),
          ),
        ),
        SwitchListTile(
          value: _quietHours,
          onChanged: (value) async {
            setState(() => _quietHours = value);
            await _persist();
          },
          title: const Text('Quiet hours'),
          subtitle: const Text('Keep reminders calmer by default.'),
        ),
        ListTile(
          title: const Text('Export item data and source info'),
          trailing: FilledButton(
            onPressed: () async {
              final path = await _storage.exportItems(_items);
              if (!mounted) return;
              _message('Exported to $path');
            },
            child: const Text('Export'),
          ),
        ),
        ListTile(
          title: const Text('Delete source files only'),
          trailing: OutlinedButton(
            onPressed: () async {
              setState(() {
                for (final item in _items) {
                  item.sourcePath = null;
                }
              });
              await _persist();
              _message('Removed stored source paths.');
            },
            child: const Text('Delete sources'),
          ),
        ),
        ListTile(
          title: const Text('Reset local data'),
          trailing: OutlinedButton(
            onPressed: () async {
              await _storage.reset();
              setState(() {
                _signedIn = false;
                _items = _seedItems();
              });
            },
            child: const Text('Reset'),
          ),
        ),
      ],
    );
  }

  Widget _section(String title, List<InboxItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (items.isEmpty) Card(child: ListTile(title: Text('Nothing in $title'))),
        ...items.map(_itemCard),
      ],
    );
  }

  Widget _itemCard(InboxItem item) {
    return Card(
      child: ListTile(
        title: Text(item.summary),
        subtitle: Text('${_stateLabel(item.state)} • ${item.recommendedNextStep}'),
        trailing: item.dueDate == null ? null : Text(_dateLabel(item.dueDate!)),
        onTap: () => _openItemDetail(item),
      ),
    );
  }

  Future<void> _signIn() async {
    setState(() => _signedIn = true);
    await _persist();
    _message('Signed in. You can start capturing items.');
  }

  Future<void> _showCaptureSheet() async {
    if (!_signedIn) {
      await _signIn();
    }
    if (!mounted) return;
    _pasteController.clear();
    // ignore: use_build_context_synchronously
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capture a life-admin item', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: _pickUpload, icon: const Icon(Icons.upload_file_outlined), label: const Text('Upload PDF/image')),
                OutlinedButton.icon(onPressed: _scanDoc, icon: const Icon(Icons.document_scanner_outlined), label: const Text('Scan paper doc')),
                OutlinedButton.icon(onPressed: () { Navigator.pop(context); _captureForwardedEmail(); }, icon: const Icon(Icons.forward_to_inbox_outlined), label: const Text('Forwarded email')),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pasteController,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Or paste a screenshot transcription, email body, or notice text'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                final text = _pasteController.text.trim();
                if (text.isEmpty) {
                  _message('Paste or import something first.');
                  return;
                }
                _reviewCapture(text, CaptureSourceType.share, 'Pasted capture');
              },
              child: const Text('Review capture'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickUpload() async {
    Navigator.of(context).pop();
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf', 'txt']);
    final file = result?.files.single;
    if (file == null) return;
    final text = file.extension == 'txt' && file.path != null
        ? await File(file.path!).readAsString()
        : 'Uploaded ${file.name}. Paste the visible text here before saving.';
    await _reviewCapture(text, CaptureSourceType.upload, file.name, sourcePath: file.path);
  }

  Future<void> _scanDoc() async {
    Navigator.of(context).pop();
    final photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    await _reviewCapture('Scanned paper mail. Paste or edit the extracted text.', CaptureSourceType.scan, photo.name, sourcePath: photo.path);
  }

  Future<void> _captureForwardedEmail() async {
    final controller = TextEditingController(text: 'Fwd: Subscription renewal\nMerchant: StreamBox\nRenews May 4, 2026\nAmount: \$12.99\nPlease review before your card is charged.');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forwarded email'),
        content: TextField(controller: controller, minLines: 6, maxLines: 10, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _reviewCapture(controller.text.trim(), CaptureSourceType.forwardedEmail, 'Forwarded email');
            },
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewCapture(String text, CaptureSourceType sourceType, String sourceTitle, {String? sourcePath}) async {
    final draft = _parse(text, sourceType, sourceTitle, sourcePath: sourcePath);
    final decision = await showModalBottomSheet<InboxItem>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReviewSheet(draft: draft),
    );
    if (decision == null) return;
    setState(() => _items.insert(0, decision));
    await _persist();
    _message('Saved to ${_stateLabel(decision.state)}.');
  }

  InboxItem _parse(String text, CaptureSourceType sourceType, String sourceTitle, {String? sourcePath}) {
    final lower = text.toLowerCase();
    final date = _extractDate(text);
    final amountMatch = RegExp(r'\$\s?(\d+[\d,.]*)').firstMatch(text);
    final amount = amountMatch == null ? null : '\$${amountMatch.group(1)}';
    final provider = RegExp(r'(?:provider|merchant|school|airline|hotel|from)[: ]+([A-Za-z0-9 &.-]+)', caseSensitive: false).firstMatch(text)?.group(1)?.trim();
    final ref = RegExp(r'(?:account|policy|reference|confirmation|claim)[#:\s-]*([A-Z0-9-]{3,})', caseSensitive: false).firstMatch(text)?.group(1);
    final dueLikely = lower.contains('due') || lower.contains('renew') || lower.contains('payment');
    final infoOnly = lower.contains('no action required') || lower.contains('for your records') || lower.contains('eob') || lower.contains('explanation of benefits');
    final waiting = lower.contains('waiting') || lower.contains('follow up');
    final school = lower.contains('school') || lower.contains('teacher');
    final travel = lower.contains('flight') || lower.contains('hotel') || lower.contains('airline');
    final subscription = lower.contains('subscription') || lower.contains('renewal');
    final healthcare = lower.contains('insurance') || lower.contains('medical') || lower.contains('claim') || lower.contains('eob');
    final category = healthcare
        ? TopicCategory.healthcare
        : school
            ? TopicCategory.school
            : travel
                ? TopicCategory.travel
                : subscription
                    ? TopicCategory.subscriptions
                    : amount != null
                        ? TopicCategory.money
                        : TopicCategory.other;

    final facts = <ExtractedFact>[
      ExtractedFact(
        label: dueLikely || subscription ? 'Due date' : travel ? 'Event date' : 'Date',
        value: date == null ? 'Could not determine' : _dateLabel(date),
        confidence: date == null ? ConfidenceLevel.undetermined : (dueLikely ? ConfidenceLevel.high : ConfidenceLevel.low),
        isCritical: dueLikely || subscription,
        evidence: EvidenceSnippet(label: 'Source snippet', text: _snippet(text, date == null ? 'date' : _dateLabel(date))),
      ),
      if (amount != null)
        ExtractedFact(
          label: 'Amount',
          value: amount,
          confidence: ConfidenceLevel.high,
          isCritical: true,
          evidence: EvidenceSnippet(label: 'Source snippet', text: _snippet(text, amount)),
        ),
      if (provider != null)
        ExtractedFact(
          label: 'Provider',
          value: provider,
          confidence: ConfidenceLevel.low,
          evidence: EvidenceSnippet(label: 'Source snippet', text: _snippet(text, provider)),
        ),
      if (ref != null)
        ExtractedFact(
          label: 'Reference number',
          value: ref,
          confidence: ConfidenceLevel.low,
          evidence: EvidenceSnippet(label: 'Source snippet', text: _snippet(text, ref)),
        ),
    ];

    final needsReview = facts.any((fact) => fact.isCritical && fact.confidence != ConfidenceLevel.high);
    final urgent = date != null && date.difference(DateTime.now()).inDays <= 2 && !infoOnly;
    final state = infoOnly
        ? ItemState.archived
        : waiting
            ? ItemState.waiting
            : needsReview
                ? ItemState.needsReview
                : dueLikely && date != null
                    ? ItemState.scheduled
                    : ItemState.inbox;

    return InboxItem(
      id: 'item-${DateTime.now().microsecondsSinceEpoch}',
      sourceType: sourceType,
      sourceTitle: sourceTitle,
      sourceText: text,
      sourcePath: sourcePath,
      summary: infoOnly
          ? 'Informational record captured and ready to archive.'
          : waiting
              ? 'Possible follow-up item captured. Decide when to check back.'
              : dueLikely
                  ? 'Time-sensitive admin item extracted from your capture.'
                  : 'Captured item ready for triage.',
      plainLanguageExplanation: infoOnly
          ? 'This looks like a record, not a task, so archive is the safest default.'
          : dueLikely
              ? 'This appears to include a deadline or renewal, so the app suggests a reminder only after you confirm the date.'
              : 'I found some useful facts, but you should decide the next step.',
      recommendedNextStep: infoOnly
          ? 'Archive as record'
          : waiting
              ? 'Create follow-up reminder'
              : dueLikely
                  ? 'Confirm due date and reminder'
                  : 'Review and decide',
      state: state,
      category: category,
      facts: facts,
      createdAt: DateTime.now(),
      documentType: infoOnly ? 'record' : subscription ? 'subscription renewal' : travel ? 'travel confirmation' : school ? 'school notice' : healthcare ? 'insurance notice' : dueLikely ? 'bill or deadline notice' : 'general capture',
      dueDate: dueLikely ? date : null,
      eventDate: travel ? date : null,
      amount: amount,
      provider: provider,
      referenceNumber: ref,
      urgent: urgent,
      reminderLabel: state == ItemState.scheduled ? 'User confirmation required before sending' : null,
      history: [TimelineEvent(label: 'Captured', at: DateTime.now())],
    );
  }

  DateTime? _extractDate(String text) {
    final now = DateTime.now();
    final numeric = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(text);
    if (numeric != null) {
      final year = int.parse(numeric.group(3)!);
      return DateTime(year < 100 ? 2000 + year : year, int.parse(numeric.group(1)!), int.parse(numeric.group(2)!));
    }
    final monthName = RegExp(r'(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{1,2})(?:,\s*(\d{4}))?', caseSensitive: false).firstMatch(text);
    if (monthName != null) {
      const months = {
        'january': 1,
        'february': 2,
        'march': 3,
        'april': 4,
        'may': 5,
        'june': 6,
        'july': 7,
        'august': 8,
        'september': 9,
        'october': 10,
        'november': 11,
        'december': 12,
      };
      return DateTime(
        monthName.group(3) == null ? now.year : int.parse(monthName.group(3)!),
        months[monthName.group(1)!.toLowerCase()]!,
        int.parse(monthName.group(2)!),
      );
    }
    return null;
  }

  String _snippet(String text, String needle) {
    final lower = text.toLowerCase();
    final matchIndex = lower.indexOf(needle.toLowerCase());
    if (matchIndex < 0) return text.substring(0, min(text.length, 80));
    final start = max(0, matchIndex - 24);
    final end = min(text.length, matchIndex + needle.length + 24);
    return text.substring(start, end).trim();
  }

  Future<void> _openItemDetail(InboxItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.summary, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(item.plainLanguageExplanation),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text(_stateLabel(item.state))),
                  Chip(label: Text(item.documentType)),
                  Chip(label: Text(item.category.name)),
                  if (item.urgent) const Chip(label: Text('Urgent')),
                ]),
                const SizedBox(height: 16),
                Text('Extracted facts', style: Theme.of(context).textTheme.titleMedium),
                ...item.facts.map((fact) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${fact.label}: ${fact.value}'),
                      subtitle: Text('Confidence: ${fact.confidence.name} ${fact.evidence == null ? '' : '• ${fact.evidence!.text}'}'),
                    )),
                const SizedBox(height: 8),
                Text('Source preview', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
                  child: Text(item.sourceText),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: () async {
                        setState(() {
                          item.state = ItemState.scheduled;
                          item.history = [...item.history, TimelineEvent(label: 'Reminder confirmed', at: DateTime.now())];
                        });
                        setSheetState(() {});
                        await _persist();
                      },
                      child: const Text('Confirm reminder'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        setState(() {
                          item.state = ItemState.waiting;
                          item.history = [...item.history, TimelineEvent(label: 'Follow-up reminder set', at: DateTime.now())];
                        });
                        setSheetState(() {});
                        await _persist();
                      },
                      child: const Text('Follow up later'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        setState(() {
                          item.state = ItemState.archived;
                          item.history = [...item.history, TimelineEvent(label: 'Archived', at: DateTime.now())];
                        });
                        setSheetState(() {});
                        await _persist();
                      },
                      child: const Text('Archive'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        setState(() {
                          item.state = ItemState.done;
                          item.history = [...item.history, TimelineEvent(label: 'Marked done', at: DateTime.now())];
                        });
                        setSheetState(() {});
                        await _persist();
                      },
                      child: const Text('Mark done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadExample() async {
    final item = _parse(
      'School form reminder for Ava. Please return by 04/25/2026. Teacher: Ms. Chen. No payment needed.',
      CaptureSourceType.share,
      'Example school reminder',
    );
    setState(() => _items.insert(0, item));
    await _persist();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _stateLabel(ItemState state) => switch (state) {
        ItemState.newItem => 'New',
        ItemState.needsReview => 'Needs review',
        ItemState.inbox => 'Inbox',
        ItemState.scheduled => 'Upcoming',
        ItemState.waiting => 'Waiting',
        ItemState.archived => 'Archived',
        ItemState.done => 'Done',
      };

  String _dateLabel(DateTime date) => '${date.month}/${date.day}/${date.year}';
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.draft});

  final InboxItem draft;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _summaryController;
  late final TextEditingController _explanationController;
  late final TextEditingController _stepController;

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController(text: widget.draft.summary);
    _explanationController = TextEditingController(text: widget.draft.plainLanguageExplanation);
    _stepController = TextEditingController(text: widget.draft.recommendedNextStep);
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _explanationController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  bool get _canSave {
    final criticalFacts = widget.draft.facts.where((fact) => fact.isCritical);
    return criticalFacts.every((fact) => !fact.isCritical || fact.confirmed || fact.confidence != ConfidenceLevel.high);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Review before saving', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(controller: _summaryController, decoration: const InputDecoration(labelText: 'Summary', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _explanationController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Plain-language explanation', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _stepController, decoration: const InputDecoration(labelText: 'Recommended next step', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            ...widget.draft.facts.map((fact) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${fact.label}: ${fact.value}'),
                        const SizedBox(height: 4),
                        Text('Confidence: ${fact.confidence.name}'),
                        if (fact.evidence != null) Text(fact.evidence!.text),
                        if (fact.isCritical)
                          CheckboxListTile(
                            value: fact.confirmed,
                            onChanged: fact.confidence == ConfidenceLevel.high ? (value) => setState(() => fact.confirmed = value ?? false) : null,
                            contentPadding: EdgeInsets.zero,
                            title: Text(fact.confidence == ConfidenceLevel.high ? 'I confirm this critical field' : 'Needs review before auto-reminding'),
                          ),
                      ],
                    ),
                  ),
                )),
            if (!_canSave)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('Confirm critical high-confidence fields before saving a reminder'),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: () {
                    widget.draft.summary = _summaryController.text.trim();
                    widget.draft.plainLanguageExplanation = _explanationController.text.trim();
                    widget.draft.recommendedNextStep = _stepController.text.trim();
                    Navigator.pop(context, widget.draft);
                  },
                  child: const Text('Save item'),
                ),
                OutlinedButton(
                  onPressed: () {
                    widget.draft.state = ItemState.archived;
                    widget.draft.recommendedNextStep = 'Archive as record';
                    Navigator.pop(context, widget.draft);
                  },
                  child: const Text('Archive instead'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<InboxItem> _seedItems() {
  final now = DateTime.now();
  return [
    InboxItem(
      id: 'seed-1',
      sourceType: CaptureSourceType.share,
      sourceTitle: 'Electric bill screenshot',
      sourceText: 'City Power. Amount due \$84.20 by 04/24/2026. Account 5519.',
      summary: 'Utility bill captured and ready for confirmation.',
      plainLanguageExplanation: 'This appears to be a bill with a clear amount and due date. Confirm the details before scheduling a reminder.',
      recommendedNextStep: 'Confirm due date and reminder',
      state: ItemState.scheduled,
      category: TopicCategory.money,
      createdAt: now.subtract(const Duration(hours: 3)),
      dueDate: DateTime(2026, 4, 24),
      amount: '\$84.20',
      provider: 'City Power',
      referenceNumber: '5519',
      urgent: true,
      reminderLabel: 'Primary reminder pending',
      documentType: 'bill due notice',
      facts: [
        ExtractedFact(label: 'Due date', value: '4/24/2026', confidence: ConfidenceLevel.high, isCritical: true, confirmed: true, evidence: EvidenceSnippet(label: 'Source snippet', text: 'Amount due \$84.20 by 04/24/2026.')),
        ExtractedFact(label: 'Amount', value: '\$84.20', confidence: ConfidenceLevel.high, isCritical: true, confirmed: true, evidence: EvidenceSnippet(label: 'Source snippet', text: 'Amount due \$84.20 by 04/24/2026.')),
      ],
      history: [TimelineEvent(label: 'Seeded example', at: now.subtract(const Duration(hours: 3)))],
    ),
    InboxItem(
      id: 'seed-2',
      sourceType: CaptureSourceType.forwardedEmail,
      sourceTitle: 'Forwarded insurance EOB',
      sourceText: 'Explanation of Benefits. For your records. No action required.',
      summary: 'Insurance EOB saved as an informational record.',
      plainLanguageExplanation: 'This looks informational, so archiving it is safer than creating unnecessary urgency.',
      recommendedNextStep: 'Archive as record',
      state: ItemState.archived,
      category: TopicCategory.healthcare,
      createdAt: now.subtract(const Duration(days: 1)),
      documentType: 'insurance EOB',
      facts: [
        ExtractedFact(label: 'Action required', value: 'No clear action required', confidence: ConfidenceLevel.low, evidence: EvidenceSnippet(label: 'Source snippet', text: 'For your records. No action required.')),
      ],
      history: [TimelineEvent(label: 'Seeded example', at: now.subtract(const Duration(days: 1)))],
    ),
    InboxItem(
      id: 'seed-3',
      sourceType: CaptureSourceType.scan,
      sourceTitle: 'School form reminder',
      sourceText: 'Please return the field trip form by April 28, 2026.',
      summary: 'School form likely needs action, but the due date should be checked.',
      plainLanguageExplanation: 'The app found a likely deadline and wants you to confirm it before creating reminders.',
      recommendedNextStep: 'Review and confirm due date',
      state: ItemState.needsReview,
      category: TopicCategory.school,
      createdAt: now.subtract(const Duration(hours: 8)),
      documentType: 'school form reminder',
      facts: [
        ExtractedFact(label: 'Due date', value: '4/28/2026', confidence: ConfidenceLevel.low, isCritical: true, evidence: EvidenceSnippet(label: 'Source snippet', text: 'return the field trip form by April 28, 2026.')),
      ],
      history: [TimelineEvent(label: 'Seeded example', at: now.subtract(const Duration(hours: 8)))],
    ),
  ];
}
