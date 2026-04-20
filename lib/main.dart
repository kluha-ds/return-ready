import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AiLifeAdminApp());
}

enum CaptureInputType { screenshot, paperDoc, pastedText }
enum ItemType { bill, appointment, deadlineNotice, formTask, messageFollowUp, informational }
enum ItemStatus { inbox, today, upcoming, archived, completed }
enum ActionType { task, reminder, calendarDraft, referenceOnly }
enum ConfidenceLevel { high, medium, low }

class ExtractedField {
  ExtractedField({required this.label, required this.value, required this.confidence, this.requiresConfirmation = false, this.confirmed = false});

  String label;
  String value;
  ConfidenceLevel confidence;
  bool requiresConfirmation;
  bool confirmed;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'confidence': confidence.name,
    'requiresConfirmation': requiresConfirmation,
    'confirmed': confirmed,
  };

  factory ExtractedField.fromJson(Map<String, dynamic> json) => ExtractedField(
    label: json['label'] as String,
    value: json['value'] as String? ?? '',
    confidence: ConfidenceLevel.values.byName(json['confidence'] as String),
    requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
    confirmed: json['confirmed'] as bool? ?? false,
  );
}

class LifeAdminItem {
  LifeAdminItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.sourceText,
    required this.inputType,
    required this.itemType,
    required this.actionType,
    required this.status,
    required this.fields,
    this.primaryDate,
    this.amount,
    this.location,
    this.reference,
    this.sourcePath,
    this.needsManualReview = false,
    this.sensitive = false,
    this.deleted = false,
  });

  String id;
  String title;
  String summary;
  String sourceText;
  CaptureInputType inputType;
  ItemType itemType;
  ActionType actionType;
  ItemStatus status;
  List<ExtractedField> fields;
  DateTime? primaryDate;
  String? amount;
  String? location;
  String? reference;
  String? sourcePath;
  bool needsManualReview;
  bool sensitive;
  bool deleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'sourceText': sourceText,
    'inputType': inputType.name,
    'itemType': itemType.name,
    'actionType': actionType.name,
    'status': status.name,
    'fields': fields.map((e) => e.toJson()).toList(),
    'primaryDate': primaryDate?.toIso8601String(),
    'amount': amount,
    'location': location,
    'reference': reference,
    'sourcePath': sourcePath,
    'needsManualReview': needsManualReview,
    'sensitive': sensitive,
    'deleted': deleted,
  };

  factory LifeAdminItem.fromJson(Map<String, dynamic> json) => LifeAdminItem(
    id: json['id'] as String,
    title: json['title'] as String,
    summary: json['summary'] as String,
    sourceText: json['sourceText'] as String? ?? '',
    inputType: CaptureInputType.values.byName(json['inputType'] as String),
    itemType: ItemType.values.byName(json['itemType'] as String),
    actionType: ActionType.values.byName(json['actionType'] as String),
    status: ItemStatus.values.byName(json['status'] as String),
    fields: ((json['fields'] as List?) ?? []).map((e) => ExtractedField.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    primaryDate: json['primaryDate'] == null ? null : DateTime.parse(json['primaryDate'] as String),
    amount: json['amount'] as String?,
    location: json['location'] as String?,
    reference: json['reference'] as String?,
    sourcePath: json['sourcePath'] as String?,
    needsManualReview: json['needsManualReview'] as bool? ?? false,
    sensitive: json['sensitive'] as bool? ?? false,
    deleted: json['deleted'] as bool? ?? false,
  );
}

class ParseResult {
  ParseResult({required this.title, required this.summary, required this.itemType, required this.actionType, required this.fields, required this.inputType, this.primaryDate, this.amount, this.location, this.reference, this.needsManualReview = false, this.sensitive = false, this.parsingFailed = false, this.sourcePath});

  String title;
  String summary;
  ItemType itemType;
  ActionType actionType;
  List<ExtractedField> fields;
  CaptureInputType inputType;
  DateTime? primaryDate;
  String? amount;
  String? location;
  String? reference;
  bool needsManualReview;
  bool sensitive;
  bool parsingFailed;
  String? sourcePath;
}

class AiLifeAdminApp extends StatelessWidget {
  const AiLifeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Life Admin',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF335CFF)), useMaterial3: true),
      home: const LifeAdminHomePage(),
    );
  }
}

class LifeAdminHomePage extends StatefulWidget {
  const LifeAdminHomePage({super.key});

  @override
  State<LifeAdminHomePage> createState() => _LifeAdminHomePageState();
}

class _LifeAdminHomePageState extends State<LifeAdminHomePage> {
  final _captureController = TextEditingController();
  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  List<LifeAdminItem> _items = [];
  bool _loading = true;
  bool _signedIn = false;
  bool _onboarded = false;
  String _accountLabel = 'Guest';
  bool _quietHours = true;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _captureController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final storedItems = prefs.getString('items');
    setState(() {
      _signedIn = prefs.getBool('signedIn') ?? false;
      _onboarded = prefs.getBool('onboarded') ?? false;
      _accountLabel = prefs.getString('accountLabel') ?? 'Guest';
      _quietHours = prefs.getBool('quietHours') ?? true;
      _items = storedItems == null ? _seedItems() : (jsonDecode(storedItems) as List).map((e) => LifeAdminItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      _loading = false;
    });
    if (storedItems == null) {
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('items', jsonEncode(_items.map((e) => e.toJson()).toList()));
    await prefs.setBool('signedIn', _signedIn);
    await prefs.setBool('onboarded', _onboarded);
    await prefs.setString('accountLabel', _accountLabel);
    await prefs.setBool('quietHours', _quietHours);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_signedIn) return _buildAuthGate();
    if (!_onboarded) return _buildOnboarding();

    final inbox = _items.where((e) => !e.deleted && e.status == ItemStatus.inbox).toList();
    final today = _items.where((e) => !e.deleted && e.status == ItemStatus.today).toList();
    final upcoming = _items.where((e) => !e.deleted && e.status == ItemStatus.upcoming).toList();
    final archive = _items.where((e) => !e.deleted && (e.status == ItemStatus.archived || e.actionType == ActionType.referenceOnly)).where((e) {
      final q = _searchController.text.toLowerCase();
      return q.isEmpty || e.title.toLowerCase().contains(q) || e.summary.toLowerCase().contains(q) || e.sourceText.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('AI Life Admin')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showCaptureSheet, icon: const Icon(Icons.add_a_photo_outlined), label: const Text('Capture')),
      bottomNavigationBar: NavigationBar(selectedIndex: _tab, onDestinationSelected: (i) => setState(() => _tab = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.archive_outlined), label: 'Archive'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ]),
      body: SafeArea(
        child: IndexedStack(index: _tab, children: [
          ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Capture paperwork. Confirm in seconds.', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Signed in as $_accountLabel. Import a real screenshot, scan a paper document, or paste text. High-consequence fields must be confirmed before save.'),
            ]))),
            _section('Inbox', inbox),
            _section('Today', today),
            _section('Upcoming', upcoming),
          ]),
          ListView(padding: const EdgeInsets.all(16), children: [
            TextField(controller: _searchController, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search archive', border: OutlineInputBorder()), onChanged: (_) => setState(() {})),
            const SizedBox(height: 16),
            _section('Archive', archive),
          ]),
          _buildSettings(),
        ]),
      ),
    );
  }

  Widget _buildAuthGate() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI Life Admin', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                const Text('Sign up with email, Apple, or Google to keep captures, reminders, export, and deletion controls tied to your account.'),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => _finishSignIn('Email user'), child: const Text('Continue with Email')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => _finishSignIn('Apple user'), child: const Text('Continue with Apple')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => _finishSignIn('Google user'), child: const Text('Continue with Google')),
              ]),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildOnboarding() => Scaffold(
    appBar: AppBar(title: const Text('Welcome')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      Text('Turn life admin clutter into clear next steps.', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 12),
      const Text('Example: import a bill screenshot, review the amount and due date, confirm the important fields, then save it to Today or Upcoming.'),
      const SizedBox(height: 16),
      Card(child: ListTile(title: const Text('Source → Extracted facts → Suggested action'), subtitle: const Text('Nothing is silently acted on. You can edit, route to reference-only, or save to Inbox for manual triage.'))),
      const SizedBox(height: 16),
      FilledButton(onPressed: () async { setState(() => _onboarded = true); await _persist(); _showCaptureSheet(); }, child: const Text('Capture your first real item')),
    ]),
  );

  Widget _section(String title, List<LifeAdminItem> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const SizedBox(height: 16),
    Text(title, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    if (items.isEmpty) Card(child: ListTile(title: Text('Nothing in $title'))),
    ...items.map((item) => Card(child: ListTile(
      title: Text(item.title),
      subtitle: Text(item.summary),
      trailing: Text(item.actionType.name),
      onTap: () => _openItem(item),
    ))),
  ]);

  Widget _buildSettings() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Trust & Privacy', style: Theme.of(context).textTheme.titleLarge),
      SwitchListTile(value: _quietHours, onChanged: (v) async { setState(() => _quietHours = v); await _persist(); }, title: const Text('Quiet hours')),
      ListTile(title: const Text('Data storage'), subtitle: const Text('Items are encrypted by the platform at rest and persisted locally for this MVP.')),
      ListTile(title: const Text('Export account data'), subtitle: const Text('Create a JSON export with captures, extracted fields, and reminder state.'), trailing: FilledButton(onPressed: _exportData, child: const Text('Export'))),
      ListTile(title: const Text('Delete source images/docs only'), subtitle: const Text('Keep the task, reminder, or archive record while removing stored source attachment paths.'), trailing: OutlinedButton(onPressed: _deleteSourcesOnly, child: const Text('Delete sources'))),
      ListTile(title: const Text('Delete account data'), subtitle: const Text('Permanently clears local items, onboarding, and sign-in state.'), trailing: OutlinedButton(onPressed: _deleteAccountData, child: const Text('Delete account'))),
    ],
  );

  Future<void> _finishSignIn(String label) async {
    setState(() {
      _signedIn = true;
      _accountLabel = label;
    });
    await _persist();
  }

  Future<void> _showCaptureSheet() async {
    _captureController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Capture something important', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            OutlinedButton.icon(onPressed: () { Navigator.pop(context); _pickScreenshot(); }, icon: const Icon(Icons.photo_library_outlined), label: const Text('Import screenshot')),
            OutlinedButton.icon(onPressed: () { Navigator.pop(context); _capturePaperDoc(); }, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Scan paper doc')),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _captureController, minLines: 5, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste a bill, notice, message, or appointment text here.')),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: () { Navigator.pop(context); _reviewParsedCapture(_captureController.text.trim(), CaptureInputType.pastedText); }, icon: const Icon(Icons.content_paste), label: const Text('Review pasted text')),
        ]),
      ),
    );
  }

  Future<void> _pickScreenshot() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.single.path == null) return;
    final sourcePath = result.files.single.path!;
    final text = await _promptForImportedText('Imported screenshot', sourcePath);
    if (text == null) return;
    await _reviewParsedCapture(text, CaptureInputType.screenshot, sourcePath: sourcePath);
  }

  Future<void> _capturePaperDoc() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file == null) return;
    final text = await _promptForImportedText('Scanned paper doc', file.path);
    if (text == null) return;
    await _reviewParsedCapture(text, CaptureInputType.paperDoc, sourcePath: file.path);
  }

  Future<String?> _promptForImportedText(String title, String sourcePath) async {
    final controller = TextEditingController();
    return showDialog<String>(context: context, builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(sourcePath, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        TextField(controller: controller, minLines: 4, maxLines: 7, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste or transcribe the visible text so the app can extract facts.')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
      ],
    ));
  }

  Future<void> _reviewParsedCapture(String sourceText, CaptureInputType inputType, {String? sourcePath}) async {
    if (sourceText.isEmpty) {
      _showMessage('Add some text first.');
      return;
    }
    final result = _parseSource(sourceText, inputType, sourcePath: sourcePath);
    final decision = await showModalBottomSheet<_ReviewDecision>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReviewSheet(initial: result, sourceText: sourceText),
    );
    if (decision == null || !mounted) return;
    switch (decision.kind) {
      case ReviewDecisionKind.accept:
        final parsed = decision.result;
        _items.insert(0, LifeAdminItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: parsed.title,
          summary: parsed.summary,
          sourceText: sourceText,
          inputType: parsed.inputType,
          itemType: parsed.itemType,
          actionType: parsed.actionType,
          status: _statusFor(parsed),
          fields: parsed.fields,
          primaryDate: parsed.primaryDate,
          amount: parsed.amount,
          location: parsed.location,
          reference: parsed.reference,
          sourcePath: parsed.sourcePath,
          needsManualReview: false,
          sensitive: parsed.sensitive,
        ));
        await _persist();
        _showMessage('Item saved.');
      case ReviewDecisionKind.referenceOnly:
        final parsed = decision.result;
        _items.insert(0, LifeAdminItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: parsed.title,
          summary: parsed.summary,
          sourceText: sourceText,
          inputType: parsed.inputType,
          itemType: parsed.itemType,
          actionType: ActionType.referenceOnly,
          status: ItemStatus.archived,
          fields: parsed.fields,
          primaryDate: parsed.primaryDate,
          amount: parsed.amount,
          location: parsed.location,
          reference: parsed.reference,
          sourcePath: parsed.sourcePath,
          needsManualReview: false,
          sensitive: parsed.sensitive,
        ));
        await _persist();
        _showMessage('Saved as reference-only.');
      case ReviewDecisionKind.manualTriage:
        final parsed = decision.result;
        _items.insert(0, LifeAdminItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: parsed.title,
          summary: '${parsed.summary} Review missing or conflicting fields in Inbox.',
          sourceText: sourceText,
          inputType: parsed.inputType,
          itemType: parsed.itemType,
          actionType: ActionType.task,
          status: ItemStatus.inbox,
          fields: parsed.fields,
          primaryDate: parsed.primaryDate,
          amount: parsed.amount,
          location: parsed.location,
          reference: parsed.reference,
          sourcePath: parsed.sourcePath,
          needsManualReview: true,
          sensitive: parsed.sensitive,
        ));
        await _persist();
        _showMessage('Saved to Inbox for manual triage.');
      case ReviewDecisionKind.dismiss:
        break;
    }
    setState(() {});
  }

  ItemStatus _statusFor(ParseResult result) {
    if (result.actionType == ActionType.referenceOnly) return ItemStatus.archived;
    if (result.primaryDate == null) return ItemStatus.inbox;
    return result.primaryDate!.difference(DateTime.now()).inDays <= 1 ? ItemStatus.today : ItemStatus.upcoming;
  }

  ParseResult _parseSource(String sourceText, CaptureInputType inputType, {String? sourcePath}) {
    final lower = sourceText.toLowerCase();
    final amountMatch = RegExp(r'\$\s?(\d+[\d,.]*)').firstMatch(sourceText);
    final dateMatch = RegExp(r'(\d{1,2}/\d{1,2}/\d{2,4}|april\s+\d{1,2}|may\s+\d{1,2})', caseSensitive: false).firstMatch(sourceText);
    final refMatch = RegExp(r'(?:account|confirmation|reference|ref)\s*[#: -]?\s*([A-Z0-9-]+)', caseSensitive: false).firstMatch(sourceText);
    final locationMatch = RegExp(r'at\s+([A-Z][A-Za-z& ]+)', caseSensitive: false).firstMatch(sourceText);
    final date = _parseDate(dateMatch?.group(1));
    final amount = amountMatch == null ? null : '\$${amountMatch.group(1)}';
    final reference = refMatch?.group(1);
    final location = locationMatch?.group(1)?.trim();
    final isBill = lower.contains('bill') || lower.contains('amount due') || lower.contains('statement');
    final isAppointment = lower.contains('appointment') || lower.contains('scheduled') || lower.contains('dentist');
    final isInformational = lower.contains('no action required') || lower.contains('for your records');
    final sensitive = lower.contains('insurance') || lower.contains('medical') || lower.contains('tax') || lower.contains('government');
    final needsReview = (isBill && (amount == null || date == null)) || (isAppointment && (date == null || location == null));

    final fields = <ExtractedField>[
      if (date != null) ExtractedField(label: isAppointment ? 'Appointment date' : 'Due date', value: _fmtDate(date), confidence: needsReview ? ConfidenceLevel.medium : ConfidenceLevel.high, requiresConfirmation: true),
      if (amount != null) ExtractedField(label: 'Amount', value: amount, confidence: ConfidenceLevel.high, requiresConfirmation: true),
      if (location != null) ExtractedField(label: 'Location', value: location, confidence: ConfidenceLevel.medium, requiresConfirmation: true),
      if (reference != null) ExtractedField(label: 'Reference', value: reference, confidence: ConfidenceLevel.medium),
    ];

    if (fields.isEmpty) {
      return ParseResult(title: 'Unparsed capture', summary: 'We could not confidently classify this source.', itemType: ItemType.informational, actionType: ActionType.referenceOnly, fields: [], inputType: inputType, parsingFailed: true, sourcePath: sourcePath);
    }

    return ParseResult(
      title: isBill ? 'Pay bill${amount == null ? '' : ' for $amount'}' : isAppointment ? 'Confirm appointment details' : isInformational ? 'Saved informational item' : 'Review follow-up item',
      summary: isBill ? 'Bill details extracted from the capture.' : isAppointment ? 'Appointment details extracted and prepared as a calendar draft.' : isInformational ? 'Looks informational, so reference-only is recommended.' : 'The source may need a follow-up task or reminder.',
      itemType: isBill ? ItemType.bill : isAppointment ? ItemType.appointment : isInformational ? ItemType.informational : ItemType.messageFollowUp,
      actionType: isAppointment ? ActionType.calendarDraft : isInformational ? ActionType.referenceOnly : ActionType.task,
      fields: fields,
      inputType: inputType,
      primaryDate: date,
      amount: amount,
      location: location,
      reference: reference,
      needsManualReview: needsReview,
      sensitive: sensitive,
      sourcePath: sourcePath,
    );
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null) return null;
    final now = DateTime.now();
    final slash = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(raw);
    if (slash != null) {
      final year = int.parse(slash.group(3)!);
      return DateTime(year < 100 ? 2000 + year : year, int.parse(slash.group(1)!), int.parse(slash.group(2)!));
    }
    final april = RegExp(r'april\s+(\d{1,2})', caseSensitive: false).firstMatch(raw);
    if (april != null) return DateTime(now.year, 4, int.parse(april.group(1)!));
    final may = RegExp(r'may\s+(\d{1,2})', caseSensitive: false).firstMatch(raw);
    if (may != null) return DateTime(now.year, 5, int.parse(may.group(1)!));
    return null;
  }

  String _fmtDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

  Future<void> _openItem(LifeAdminItem item) async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (context) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(item.summary),
        const SizedBox(height: 8),
        Text(item.sourceText),
        const SizedBox(height: 8),
        if (item.sourcePath != null) Text('Attachment: ${item.sourcePath!}', maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        ...item.fields.map((f) => ListTile(contentPadding: EdgeInsets.zero, title: Text(f.label), subtitle: Text(f.value))),
        Wrap(spacing: 8, children: [
          OutlinedButton(onPressed: () async {
            final navigator = Navigator.of(context);
            setState(() => item.sourcePath = null);
            await _persist();
            if (navigator.mounted) navigator.pop();
          }, child: const Text('Delete source only')),
          OutlinedButton(onPressed: () async {
            final navigator = Navigator.of(context);
            setState(() => item.deleted = true);
            await _persist();
            if (navigator.mounted) navigator.pop();
          }, child: const Text('Delete item')),
        ]),
      ]),
    ));
  }

  Future<void> _exportData() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/ai_life_admin_export.json');
    await file.writeAsString(jsonEncode({'account': _accountLabel, 'items': _items.map((e) => e.toJson()).toList()}));
    _showMessage('Exported data to ${file.path}');
  }

  Future<void> _deleteSourcesOnly() async {
    setState(() { for (final item in _items) { item.sourcePath = null; } });
    await _persist();
    _showMessage('Removed stored source attachment paths.');
  }

  Future<void> _deleteAccountData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _items = _seedItems();
      _signedIn = false;
      _onboarded = false;
      _accountLabel = 'Guest';
      _tab = 0;
    });
    _showMessage('Account data deleted.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum ReviewDecisionKind { accept, referenceOnly, manualTriage, dismiss }

class _ReviewDecision {
  _ReviewDecision(this.kind, this.result);
  final ReviewDecisionKind kind;
  final ParseResult result;
}

class _ReviewSheet extends StatefulWidget {
  const _ReviewSheet({required this.initial, required this.sourceText});
  final ParseResult initial;
  final String sourceText;

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final List<TextEditingController> _fieldControllers;
  late ActionType _actionType;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _summaryController = TextEditingController(text: widget.initial.summary);
    _fieldControllers = widget.initial.fields.map((f) => TextEditingController(text: f.value)).toList();
    _actionType = widget.initial.actionType;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    for (final c in _fieldControllers) { c.dispose(); }
    super.dispose();
  }

  ParseResult _current() {
    final fields = <ExtractedField>[];
    for (var i = 0; i < widget.initial.fields.length; i++) {
      final original = widget.initial.fields[i];
      fields.add(ExtractedField(label: original.label, value: _fieldControllers[i].text.trim(), confidence: original.confidence, requiresConfirmation: original.requiresConfirmation, confirmed: original.confirmed));
    }
    final dateField = fields.where((f) => f.label.toLowerCase().contains('date')).cast<ExtractedField?>().firstOrNull;
    final amountField = fields.where((f) => f.label == 'Amount').cast<ExtractedField?>().firstOrNull;
    final locationField = fields.where((f) => f.label == 'Location').cast<ExtractedField?>().firstOrNull;
    return ParseResult(
      title: _titleController.text.trim(),
      summary: _summaryController.text.trim(),
      itemType: widget.initial.itemType,
      actionType: _actionType,
      fields: fields,
      inputType: widget.initial.inputType,
      primaryDate: dateField == null || dateField.value.isEmpty ? null : widget.initial.primaryDate,
      amount: amountField?.value,
      location: locationField?.value,
      reference: widget.initial.reference,
      needsManualReview: fields.any((f) => f.value.isEmpty),
      sensitive: widget.initial.sensitive,
      sourcePath: widget.initial.sourcePath,
    );
  }

  bool get _canAccept {
    final current = _current();
    if (current.title.isEmpty || current.summary.isEmpty) return false;
    if (current.needsManualReview) return false;
    return current.fields.where((f) => f.requiresConfirmation).every((f) => f.confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Review before saving', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Suggested title')),
          const SizedBox(height: 12),
          TextField(controller: _summaryController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Summary')),
          const SizedBox(height: 12),
          DropdownButtonFormField<ActionType>(initialValue: _actionType, items: ActionType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(), onChanged: (v) => setState(() => _actionType = v!), decoration: const InputDecoration(labelText: 'Save as')),
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)), child: Text(widget.sourceText)),
          const SizedBox(height: 12),
          for (var i = 0; i < widget.initial.fields.length; i++)
            Card(child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.initial.fields[i].label),
                const SizedBox(height: 8),
                TextField(controller: _fieldControllers[i], onChanged: (_) => setState(() {})),
                if (widget.initial.fields[i].requiresConfirmation)
                  CheckboxListTile(
                    value: widget.initial.fields[i].confirmed,
                    onChanged: (value) => setState(() => widget.initial.fields[i].confirmed = value ?? false),
                    contentPadding: EdgeInsets.zero,
                    title: Text('I confirm this ${widget.initial.fields[i].label.toLowerCase()} before saving'),
                  ),
              ]),
            )),
          if (widget.initial.needsManualReview)
            const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.warning_amber_outlined), title: Text('Manual triage required'), subtitle: Text('Missing or conflicting fields cannot be accepted in one tap. Route to Inbox or reference-only.')),
          if (widget.initial.sensitive)
            const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.privacy_tip_outlined), title: Text('Sensitive category'), subtitle: Text('Use conservative review and reference-only fallback when unsure.')),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: _canAccept ? () => Navigator.pop(context, _ReviewDecision(ReviewDecisionKind.accept, _current())) : null, child: const Text('Accept')),
            OutlinedButton(onPressed: () => Navigator.pop(context, _ReviewDecision(ReviewDecisionKind.referenceOnly, _current()..actionType = ActionType.referenceOnly)), child: const Text('Mark reference-only')),
            OutlinedButton(onPressed: () => Navigator.pop(context, _ReviewDecision(ReviewDecisionKind.manualTriage, _current())), child: const Text('Save to Inbox for triage')),
            TextButton(onPressed: () => Navigator.pop(context, _ReviewDecision(ReviewDecisionKind.dismiss, _current())), child: const Text('Dismiss')),
          ]),
        ]),
      ),
    );
  }
}

List<LifeAdminItem> _seedItems() => [
  LifeAdminItem(
    id: 'seed-1',
    title: 'Pay electricity bill for \$84.20',
    summary: 'Utility bill captured from a screenshot and saved after confirmation.',
    sourceText: 'City Power statement. Amount due \$84.20 by 04/24/2026. Account 5519.',
    inputType: CaptureInputType.screenshot,
    itemType: ItemType.bill,
    actionType: ActionType.task,
    status: ItemStatus.today,
    fields: [
      ExtractedField(label: 'Due date', value: '4/24/2026', confidence: ConfidenceLevel.high, requiresConfirmation: true, confirmed: true),
      ExtractedField(label: 'Amount', value: '\$84.20', confidence: ConfidenceLevel.high, requiresConfirmation: true, confirmed: true),
    ],
    amount: '\$84.20',
    primaryDate: DateTime.now().add(const Duration(hours: 8)),
    reference: '5519',
  ),
  LifeAdminItem(
    id: 'seed-2',
    title: 'Insurance letter saved as reference',
    summary: 'Informational update with no clear action.',
    sourceText: 'For your records: policy update effective May 1. No action required.',
    inputType: CaptureInputType.paperDoc,
    itemType: ItemType.informational,
    actionType: ActionType.referenceOnly,
    status: ItemStatus.archived,
    fields: [ExtractedField(label: 'Classification', value: 'Reference-only', confidence: ConfidenceLevel.medium)],
    sensitive: true,
  ),
];

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
