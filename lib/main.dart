import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AiLifeAdminApp());
}

enum CaptureInputType { forwardedEmail, upload, screenshot, paperDoc, pastedText }
enum ProcessingState { received, processing, needsReview, completed, failed, duplicate }
enum WorkflowState { newItem, reviewed, actioned, waiting, done, archived }
enum ItemCategory { billPayment, bookingAppointment, receiptReturn, formNotice, other }
enum ActionType { reminder, task, markDone, archive }
enum ConfidenceLevel { high, medium, low }
enum StageState { pending, complete, failed, skipped }

class ExtractedField {
  ExtractedField({
    required this.label,
    required this.value,
    required this.confidence,
    required this.sourceSnippet,
    this.requiresConfirmation = false,
    this.confirmed = false,
  });

  String label;
  String value;
  ConfidenceLevel confidence;
  String sourceSnippet;
  bool requiresConfirmation;
  bool confirmed;

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    'confidence': confidence.name,
    'sourceSnippet': sourceSnippet,
    'requiresConfirmation': requiresConfirmation,
    'confirmed': confirmed,
  };

  factory ExtractedField.fromJson(Map<String, dynamic> json) => ExtractedField(
    label: json['label'] as String,
    value: json['value'] as String? ?? '',
    confidence: ConfidenceLevel.values.byName(json['confidence'] as String),
    sourceSnippet: json['sourceSnippet'] as String? ?? '',
    requiresConfirmation: json['requiresConfirmation'] as bool? ?? false,
    confirmed: json['confirmed'] as bool? ?? false,
  );
}

class PipelineStage {
  PipelineStage({required this.code, required this.label, required this.state, required this.detail});

  String code;
  String label;
  StageState state;
  String detail;

  Map<String, dynamic> toJson() => {
    'code': code,
    'label': label,
    'state': state.name,
    'detail': detail,
  };

  factory PipelineStage.fromJson(Map<String, dynamic> json) => PipelineStage(
    code: json['code'] as String,
    label: json['label'] as String,
    state: StageState.values.byName(json['state'] as String),
    detail: json['detail'] as String? ?? '',
  );
}

class LifeAdminItem {
  LifeAdminItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.sourceText,
    required this.inputType,
    required this.processingState,
    required this.workflowState,
    required this.category,
    required this.suggestedAction,
    required this.fields,
    required this.pipelineStages,
    required this.dedupeSignature,
    this.primaryDate,
    this.amount,
    this.providerOrSender,
    this.reference,
    this.sourcePath,
    this.failureReason,
    this.deleted = false,
  });

  String id;
  String title;
  String summary;
  String sourceText;
  CaptureInputType inputType;
  ProcessingState processingState;
  WorkflowState workflowState;
  ItemCategory category;
  ActionType suggestedAction;
  List<ExtractedField> fields;
  List<PipelineStage> pipelineStages;
  String dedupeSignature;
  DateTime? primaryDate;
  String? amount;
  String? providerOrSender;
  String? reference;
  String? sourcePath;
  String? failureReason;
  bool deleted;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'sourceText': sourceText,
    'inputType': inputType.name,
    'processingState': processingState.name,
    'workflowState': workflowState.name,
    'category': category.name,
    'suggestedAction': suggestedAction.name,
    'fields': fields.map((e) => e.toJson()).toList(),
    'pipelineStages': pipelineStages.map((e) => e.toJson()).toList(),
    'dedupeSignature': dedupeSignature,
    'primaryDate': primaryDate?.toIso8601String(),
    'amount': amount,
    'providerOrSender': providerOrSender,
    'reference': reference,
    'sourcePath': sourcePath,
    'failureReason': failureReason,
    'deleted': deleted,
  };

  factory LifeAdminItem.fromJson(Map<String, dynamic> json) => LifeAdminItem(
    id: json['id'] as String,
    title: json['title'] as String,
    summary: json['summary'] as String,
    sourceText: json['sourceText'] as String? ?? '',
    inputType: CaptureInputType.values.byName(json['inputType'] as String),
    processingState: ProcessingState.values.byName(json['processingState'] as String),
    workflowState: WorkflowState.values.byName(json['workflowState'] as String),
    category: ItemCategory.values.byName(json['category'] as String),
    suggestedAction: ActionType.values.byName(json['suggestedAction'] as String),
    fields: ((json['fields'] as List?) ?? []).map((e) => ExtractedField.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    pipelineStages: ((json['pipelineStages'] as List?) ?? []).map((e) => PipelineStage.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    dedupeSignature: json['dedupeSignature'] as String? ?? '',
    primaryDate: json['primaryDate'] == null ? null : DateTime.parse(json['primaryDate'] as String),
    amount: json['amount'] as String?,
    providerOrSender: json['providerOrSender'] as String?,
    reference: json['reference'] as String?,
    sourcePath: json['sourcePath'] as String?,
    failureReason: json['failureReason'] as String?,
    deleted: json['deleted'] as bool? ?? false,
  );
}

class PipelineOutcome {
  PipelineOutcome({
    required this.title,
    required this.summary,
    required this.category,
    required this.suggestedAction,
    required this.fields,
    required this.pipelineStages,
    required this.processingState,
    required this.workflowState,
    required this.inputType,
    required this.dedupeSignature,
    this.primaryDate,
    this.amount,
    this.providerOrSender,
    this.reference,
    this.sourcePath,
    this.failureReason,
  });

  String title;
  String summary;
  ItemCategory category;
  ActionType suggestedAction;
  List<ExtractedField> fields;
  List<PipelineStage> pipelineStages;
  ProcessingState processingState;
  WorkflowState workflowState;
  CaptureInputType inputType;
  String dedupeSignature;
  DateTime? primaryDate;
  String? amount;
  String? providerOrSender;
  String? reference;
  String? sourcePath;
  String? failureReason;
}

class AiLifeAdminApp extends StatelessWidget {
  const AiLifeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Life Admin Inbox',
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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final activeItems = _items.where((e) => !e.deleted && e.workflowState != WorkflowState.archived && e.workflowState != WorkflowState.done).toList();
    final upcoming = _items.where((e) => !e.deleted && (e.suggestedAction == ActionType.reminder || e.suggestedAction == ActionType.task) && e.primaryDate != null).toList();
    final history = _searchableItems(_searchController.text);

    return Scaffold(
      appBar: AppBar(title: const Text('AI Life Admin Inbox')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _showCaptureSheet, icon: const Icon(Icons.add), label: const Text('Capture')),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Upcoming'),
          NavigationDestination(icon: Icon(Icons.search_outlined), label: 'Search/History'),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                    Text('Forward or upload bills, bookings, receipts, and forms.'),
                    SizedBox(height: 8),
                    Text('Each item gets staged processing, field-level confidence, source snippets, conservative dedupe, and an editable review before action creation.'),
                  ]),
                ),
              ),
              _section('Inbox', activeItems),
            ],
          ),
          ListView(padding: const EdgeInsets.all(16), children: [_section('Upcoming actions', upcoming)]),
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search summaries, fields, OCR text, archived and active items', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              _section('Search results', history),
            ],
          ),
        ],
      ),
    );
  }

  List<LifeAdminItem> _searchableItems(String query) {
    final q = query.trim().toLowerCase();
    final items = _items.where((e) => !e.deleted).toList();
    if (q.isEmpty) return items;
    return items.where((item) {
      final haystack = [
        item.title,
        item.summary,
        item.sourceText,
        item.category.name,
        item.processingState.name,
        item.workflowState.name,
        item.amount ?? '',
        item.providerOrSender ?? '',
        item.reference ?? '',
        item.primaryDate == null ? '' : _fmtDate(item.primaryDate!),
        ...item.fields.map((f) => '${f.label} ${f.value} ${f.sourceSnippet} ${f.confidence.name}'),
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Widget _section(String title, List<LifeAdminItem> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if (items.isEmpty) Card(child: ListTile(title: Text('Nothing in $title'))),
      ...items.map((item) => Card(
        child: ListTile(
          title: Text(item.title),
          subtitle: Text('${_categoryLabel(item.category)} • ${item.processingState.name} • ${item.workflowState.name}\n${item.summary}'),
          isThreeLine: true,
          onTap: () => _openItem(item),
        ),
      )),
    ],
  );

  Future<void> _showCaptureSheet() async {
    _captureController.clear();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capture or forward an item', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              OutlinedButton.icon(onPressed: () { Navigator.pop(context); _pickUpload(); }, icon: const Icon(Icons.attach_file), label: const Text('Upload file')),
              OutlinedButton.icon(onPressed: () { Navigator.pop(context); _capturePaperDoc(); }, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Scan paper doc')),
            ]),
            const SizedBox(height: 16),
            Text('Forwarding address: user-inbox@ailifeadmin.app', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextField(controller: _captureController, minLines: 5, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste forwarded email, OCR text, or notes here.')),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: () { Navigator.pop(context); _reviewParsedCapture(_captureController.text.trim(), CaptureInputType.forwardedEmail); }, icon: const Icon(Icons.forward_to_inbox_outlined), label: const Text('Review forwarded text')),
          ],
        ),
      ),
    );
  }

  Future<void> _pickUpload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowMultiple: false, allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'txt']);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final text = await _promptForImportedText('Uploaded file', path);
    if (text == null) return;
    await _reviewParsedCapture(text, CaptureInputType.upload, sourcePath: path);
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
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(sourcePath, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            TextField(controller: controller, minLines: 5, maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Paste OCR or visible text so the pipeline can classify and extract fields.')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Continue')),
        ],
      ),
    );
  }

  Future<void> _reviewParsedCapture(String sourceText, CaptureInputType inputType, {String? sourcePath}) async {
    if (sourceText.isEmpty) {
      _showMessage('Add some text first.');
      return;
    }
    final outcome = runPipeline(sourceText: sourceText, inputType: inputType, existingItems: _items, sourcePath: sourcePath);
    final decision = await showModalBottomSheet<_ReviewDecision>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReviewSheet(initial: outcome, sourceText: sourceText),
    );
    if (decision == null || !mounted) return;
    if (decision.kind == ReviewDecisionKind.dismiss) return;

    final result = decision.outcome;
    result.workflowState = decision.kind == ReviewDecisionKind.archive ? WorkflowState.archived : result.workflowState;
    result.suggestedAction = decision.kind == ReviewDecisionKind.archive ? ActionType.archive : result.suggestedAction;

    _items.insert(0, LifeAdminItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: result.title,
      summary: result.summary,
      sourceText: sourceText,
      inputType: result.inputType,
      processingState: result.processingState,
      workflowState: result.workflowState,
      category: result.category,
      suggestedAction: result.suggestedAction,
      fields: result.fields,
      pipelineStages: result.pipelineStages,
      dedupeSignature: result.dedupeSignature,
      primaryDate: result.primaryDate,
      amount: result.amount,
      providerOrSender: result.providerOrSender,
      reference: result.reference,
      sourcePath: result.sourcePath,
      failureReason: result.failureReason,
    ));
    await _persist();
    setState(() {});
    _showMessage(result.processingState == ProcessingState.duplicate ? 'Duplicate safely captured without a new reminder.' : 'Item saved.');
  }

  Future<void> _openItem(LifeAdminItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(item.summary),
              const SizedBox(height: 12),
              Text('Processing: ${item.processingState.name} • Workflow: ${item.workflowState.name}'),
              Text('Category: ${_categoryLabel(item.category)} • Suggested action: ${item.suggestedAction.name}'),
              if (item.failureReason != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Failure: ${item.failureReason}')),
              const SizedBox(height: 12),
              Text('Pipeline', style: Theme.of(context).textTheme.titleMedium),
              ...item.pipelineStages.map((stage) => ListTile(contentPadding: EdgeInsets.zero, title: Text(stage.label), subtitle: Text(stage.detail), trailing: Text(stage.state.name))),
              const SizedBox(height: 8),
              Text('Editable extracted fields', style: Theme.of(context).textTheme.titleMedium),
              ...item.fields.map((field) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${field.label} • ${field.confidence.name}'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: field.value),
                      onChanged: (value) {
                        field.value = value;
                        item.workflowState = WorkflowState.reviewed;
                      },
                    ),
                    const SizedBox(height: 6),
                    Text('Source: ${field.sourceSnippet}'),
                  ]),
                ),
              )),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton(
                  onPressed: () async {
                    setState(() {
                      item.workflowState = WorkflowState.actioned;
                      item.processingState = item.processingState == ProcessingState.needsReview ? ProcessingState.completed : item.processingState;
                    });
                    await _persist();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Create task/reminder'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    setState(() => item.workflowState = WorkflowState.done);
                    await _persist();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Mark done'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    setState(() => item.workflowState = WorkflowState.archived);
                    await _persist();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Archive'),
                ),
                TextButton(
                  onPressed: () async {
                    setState(() => item.deleted = true);
                    await _persist();
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Delete item'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

enum ReviewDecisionKind { accept, archive, dismiss }

class _ReviewDecision {
  _ReviewDecision(this.kind, this.outcome);
  final ReviewDecisionKind kind;
  final PipelineOutcome outcome;
}

class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key, required this.initial, required this.sourceText});
  final PipelineOutcome initial;
  final String sourceText;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;
  late final List<TextEditingController> _fieldControllers;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial.title);
    _summaryController = TextEditingController(text: widget.initial.summary);
    _fieldControllers = widget.initial.fields.map((f) => TextEditingController(text: f.value)).toList();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    for (final controller in _fieldControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  PipelineOutcome _current() {
    final updatedFields = <ExtractedField>[];
    for (var i = 0; i < widget.initial.fields.length; i++) {
      final field = widget.initial.fields[i];
      updatedFields.add(ExtractedField(
        label: field.label,
        value: _fieldControllers[i].text.trim(),
        confidence: field.confidence,
        sourceSnippet: field.sourceSnippet,
        requiresConfirmation: field.requiresConfirmation,
        confirmed: field.confirmed,
      ));
    }
    return PipelineOutcome(
      title: _titleController.text.trim(),
      summary: _summaryController.text.trim(),
      category: widget.initial.category,
      suggestedAction: widget.initial.suggestedAction,
      fields: updatedFields,
      pipelineStages: widget.initial.pipelineStages,
      processingState: updatedFields.any((f) => f.requiresConfirmation && !f.confirmed) ? ProcessingState.needsReview : widget.initial.processingState,
      workflowState: WorkflowState.reviewed,
      inputType: widget.initial.inputType,
      dedupeSignature: widget.initial.dedupeSignature,
      primaryDate: widget.initial.primaryDate,
      amount: updatedFields.firstWhereOrNull((f) => f.label == 'Amount')?.value,
      providerOrSender: updatedFields.firstWhereOrNull((f) => f.label == 'Provider / Sender')?.value,
      reference: updatedFields.firstWhereOrNull((f) => f.label == 'Reference')?.value,
      sourcePath: widget.initial.sourcePath,
      failureReason: widget.initial.failureReason,
    );
  }

  bool get _canAccept {
    final current = _current();
    if (current.title.isEmpty || current.summary.isEmpty) return false;
    return current.fields.where((f) => f.requiresConfirmation).every((f) => f.confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Review before creating an action', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
          const SizedBox(height: 12),
          TextField(controller: _summaryController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Summary')),
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)), child: Text(widget.sourceText)),
          const SizedBox(height: 12),
          ...List.generate(widget.initial.fields.length, (index) {
            final field = widget.initial.fields[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${field.label} • ${field.confidence.name}'),
                  const SizedBox(height: 6),
                  TextField(controller: _fieldControllers[index], onChanged: (_) => setState(() {})),
                  const SizedBox(height: 6),
                  Text('Source: ${field.sourceSnippet}'),
                  if (field.requiresConfirmation)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: field.confirmed,
                      onChanged: (value) => setState(() => field.confirmed = value ?? false),
                      title: Text('Confirm ${field.label.toLowerCase()} before action creation'),
                    ),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
          Text('Pipeline stages', style: Theme.of(context).textTheme.titleMedium),
          ...widget.initial.pipelineStages.map((stage) => ListTile(contentPadding: EdgeInsets.zero, title: Text(stage.label), subtitle: Text(stage.detail), trailing: Text(stage.state.name))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(onPressed: _canAccept ? () => Navigator.pop(context, _ReviewDecision(ReviewDecisionKind.accept, _current())) : null, child: const Text('Accept')),
            OutlinedButton(onPressed: () => Navigator.pop(context, _ReviewDecision(ReviewDecisionKind.archive, _current())), child: const Text('Archive without action')),
            TextButton(onPressed: () => Navigator.pop(context, _ReviewDecision(ReviewDecisionKind.dismiss, _current())), child: const Text('Dismiss')),
          ]),
        ]),
      ),
    );
  }
}

PipelineOutcome runPipeline({required String sourceText, required CaptureInputType inputType, required List<LifeAdminItem> existingItems, String? sourcePath}) {
  final normalized = sourceText.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  final dedupeSignature = _dedupeSignature(normalized);
  final stages = <PipelineStage>[
    PipelineStage(code: 'received', label: 'Item received', state: StageState.complete, detail: 'Capture accepted from ${inputType.name}.'),
    PipelineStage(code: 'normalize', label: 'Normalization', state: StageState.complete, detail: 'Normalized whitespace and source metadata.'),
  ];

  final duplicate = existingItems.any((item) => item.dedupeSignature == dedupeSignature || _nearDuplicate(item.sourceText.toLowerCase(), normalized));
  if (duplicate) {
    stages.addAll([
      PipelineStage(code: 'extract', label: 'OCR / text extraction', state: StageState.complete, detail: 'Source text available for review.'),
      PipelineStage(code: 'classify', label: 'Classification', state: StageState.complete, detail: 'Potential duplicate detected during classification.'),
      PipelineStage(code: 'fields', label: 'Field extraction', state: StageState.skipped, detail: 'Skipped action field generation to avoid duplicate reminders.'),
      PipelineStage(code: 'action', label: 'Action suggestion', state: StageState.complete, detail: 'Safe default is archive existing record linkage.'),
      PipelineStage(code: 'confidence', label: 'Confidence scoring', state: StageState.complete, detail: 'Duplicate match confidence is high.'),
      PipelineStage(code: 'review', label: 'Review-ready item creation', state: StageState.complete, detail: 'Marked as duplicate for user review.'),
    ]);
    return PipelineOutcome(
      title: 'Possible duplicate item',
      summary: 'This capture closely matches an existing item, so no new reminder or task is created automatically.',
      category: ItemCategory.other,
      suggestedAction: ActionType.archive,
      fields: [ExtractedField(label: 'Duplicate reason', value: 'Matched an existing upload or forwarded item', confidence: ConfidenceLevel.high, sourceSnippet: sourceText)],
      pipelineStages: stages,
      processingState: ProcessingState.duplicate,
      workflowState: WorkflowState.reviewed,
      inputType: inputType,
      dedupeSignature: dedupeSignature,
      sourcePath: sourcePath,
    );
  }

  if (normalized.contains('blurry') || normalized.contains('password protected') || normalized.length < 12) {
    stages.addAll([
      PipelineStage(code: 'extract', label: 'OCR / text extraction', state: StageState.failed, detail: 'Source text is incomplete or unreadable.'),
      PipelineStage(code: 'classify', label: 'Classification', state: StageState.skipped, detail: 'Skipped because extraction failed.'),
      PipelineStage(code: 'fields', label: 'Field extraction', state: StageState.skipped, detail: 'No reliable fields available.'),
      PipelineStage(code: 'action', label: 'Action suggestion', state: StageState.complete, detail: 'Route to manual review or archive.'),
      PipelineStage(code: 'confidence', label: 'Confidence scoring', state: StageState.complete, detail: 'Low confidence due to unreadable input.'),
      PipelineStage(code: 'review', label: 'Review-ready item creation', state: StageState.complete, detail: 'Item preserved with failure guidance.'),
    ]);
    return PipelineOutcome(
      title: 'Unreadable item needs review',
      summary: 'We preserved the item, but extraction failed. Re-upload a clearer file or transcribe more text.',
      category: ItemCategory.other,
      suggestedAction: ActionType.task,
      fields: [],
      pipelineStages: stages,
      processingState: ProcessingState.failed,
      workflowState: WorkflowState.newItem,
      inputType: inputType,
      dedupeSignature: dedupeSignature,
      sourcePath: sourcePath,
      failureReason: 'Unreadable image, unsupported content, or password-protected attachment.',
    );
  }

  stages.add(PipelineStage(code: 'extract', label: 'OCR / text extraction', state: StageState.complete, detail: 'Source text extracted and ready for parsing.'));

  final category = _classifyCategory(normalized);
  stages.add(PipelineStage(code: 'classify', label: 'Classification', state: StageState.complete, detail: 'Classified as ${_categoryLabel(category)}.'));

  final dateMatch = RegExp(r'(\d{1,2}/\d{1,2}/\d{2,4}|may\s+\d{1,2}|april\s+\d{1,2}|june\s+\d{1,2})', caseSensitive: false).firstMatch(sourceText);
  final amountMatch = RegExp(r'\$\s?(\d+[\d,.]*)').firstMatch(sourceText);
  final providerMatch = RegExp(r'(?:from|provider|merchant|sender)\s*[:\-]?\s*([A-Z][A-Za-z& ]+)', caseSensitive: false).firstMatch(sourceText);
  final referenceMatch = RegExp(r'(?:reference|ref|confirmation|account)\s*[#: -]?\s*([A-Z0-9-]+)', caseSensitive: false).firstMatch(sourceText);
  final date = _parseDate(dateMatch?.group(1));
  final amount = amountMatch == null ? null : '\$${amountMatch.group(1)}';
  final provider = providerMatch?.group(1)?.trim() ?? _fallbackProvider(sourceText);
  final reference = referenceMatch?.group(1);

  final fields = <ExtractedField>[
    ExtractedField(label: 'Summary', value: _summaryFor(category), confidence: ConfidenceLevel.medium, sourceSnippet: sourceText),
    ExtractedField(label: 'Category', value: _categoryLabel(category), confidence: ConfidenceLevel.high, sourceSnippet: sourceText),
    if (date != null)
      ExtractedField(label: category == ItemCategory.bookingAppointment ? 'Event date' : 'Due date', value: _fmtDate(date), confidence: ConfidenceLevel.high, sourceSnippet: dateMatch!.group(0)!, requiresConfirmation: true),
    if (amount != null) ExtractedField(label: 'Amount', value: amount, confidence: ConfidenceLevel.high, sourceSnippet: amountMatch!.group(0)!, requiresConfirmation: true),
    if (provider != null) ExtractedField(label: 'Provider / Sender', value: provider, confidence: ConfidenceLevel.medium, sourceSnippet: provider),
    if (reference != null) ExtractedField(label: 'Reference', value: reference, confidence: ConfidenceLevel.medium, sourceSnippet: reference),
    ExtractedField(label: 'Suggested next step', value: _actionLabel(_suggestedAction(category)), confidence: ConfidenceLevel.medium, sourceSnippet: sourceText),
  ];

  final needsReview = date == null && amount == null;
  stages.add(PipelineStage(code: 'fields', label: 'Field extraction', state: StageState.complete, detail: 'Extracted ${fields.length} reviewable fields.'));
  stages.add(PipelineStage(code: 'action', label: 'Action suggestion', state: StageState.complete, detail: 'Primary next step is ${_actionLabel(_suggestedAction(category))}.'));
  stages.add(PipelineStage(code: 'confidence', label: 'Confidence scoring', state: StageState.complete, detail: needsReview ? 'Key date or amount fields are missing, so manual review is required.' : 'Key fields are present with source snippets.'));
  stages.add(PipelineStage(code: 'review', label: 'Review-ready item creation', state: StageState.complete, detail: 'Created editable review item before any side effects.'));

  return PipelineOutcome(
    title: _titleFor(category, provider, amount),
    summary: _summaryFor(category),
    category: category,
    suggestedAction: _suggestedAction(category),
    fields: fields,
    pipelineStages: stages,
    processingState: needsReview ? ProcessingState.needsReview : ProcessingState.completed,
    workflowState: WorkflowState.newItem,
    inputType: inputType,
    dedupeSignature: dedupeSignature,
    primaryDate: date,
    amount: amount,
    providerOrSender: provider,
    reference: reference,
    sourcePath: sourcePath,
  );
}

String _dedupeSignature(String normalized) {
  final compact = normalized.replaceAll(RegExp(r'[^a-z0-9$]'), '');
  return compact.length <= 120 ? compact : compact.substring(0, 120);
}

bool _nearDuplicate(String a, String b) {
  final aa = _dedupeSignature(a);
  final bb = _dedupeSignature(b);
  if (aa == bb) return true;
  final shorter = aa.length < bb.length ? aa : bb;
  final longer = aa.length < bb.length ? bb : aa;
  return shorter.isNotEmpty && longer.contains(shorter.substring(0, shorter.length.clamp(0, 24)));
}

ItemCategory _classifyCategory(String normalized) {
  if (normalized.contains('bill') || normalized.contains('amount due') || normalized.contains('statement')) return ItemCategory.billPayment;
  if (normalized.contains('booking') || normalized.contains('appointment') || normalized.contains('scheduled')) return ItemCategory.bookingAppointment;
  if (normalized.contains('receipt') || normalized.contains('return')) return ItemCategory.receiptReturn;
  if (normalized.contains('notice') || normalized.contains('form')) return ItemCategory.formNotice;
  return ItemCategory.other;
}

ActionType _suggestedAction(ItemCategory category) {
  switch (category) {
    case ItemCategory.billPayment:
      return ActionType.task;
    case ItemCategory.bookingAppointment:
      return ActionType.reminder;
    case ItemCategory.receiptReturn:
      return ActionType.archive;
    case ItemCategory.formNotice:
      return ActionType.task;
    case ItemCategory.other:
      return ActionType.archive;
  }
}

String _actionLabel(ActionType action) {
  switch (action) {
    case ActionType.reminder:
      return 'Create internal reminder';
    case ActionType.task:
      return 'Create internal task';
    case ActionType.markDone:
      return 'Mark done';
    case ActionType.archive:
      return 'Archive for later retrieval';
  }
}

String _categoryLabel(ItemCategory category) {
  switch (category) {
    case ItemCategory.billPayment:
      return 'Bill / Payment';
    case ItemCategory.bookingAppointment:
      return 'Booking / Appointment';
    case ItemCategory.receiptReturn:
      return 'Receipt / Return';
    case ItemCategory.formNotice:
      return 'Form / Notice';
    case ItemCategory.other:
      return 'Other';
  }
}

String _titleFor(ItemCategory category, String? provider, String? amount) {
  switch (category) {
    case ItemCategory.billPayment:
      return 'Review bill${amount == null ? '' : ' for $amount'}';
    case ItemCategory.bookingAppointment:
      return 'Review booking or appointment';
    case ItemCategory.receiptReturn:
      return 'Save receipt or return record';
    case ItemCategory.formNotice:
      return 'Review notice or form';
    case ItemCategory.other:
      return provider == null ? 'Review captured item' : 'Review item from $provider';
  }
}

String _summaryFor(ItemCategory category) {
  switch (category) {
    case ItemCategory.billPayment:
      return 'Bill details extracted and ready for reminder or task confirmation.';
    case ItemCategory.bookingAppointment:
      return 'Booking details extracted for a conservative reminder workflow.';
    case ItemCategory.receiptReturn:
      return 'Receipt captured for searchable records and any follow-up.';
    case ItemCategory.formNotice:
      return 'Notice fields extracted so you can review the next required step.';
    case ItemCategory.other:
      return 'Item captured with a safe fallback and review-first workflow.';
  }
}

String? _fallbackProvider(String sourceText) {
  final firstLine = sourceText.split('\n').firstOrNull?.trim();
  if (firstLine == null || firstLine.isEmpty) return null;
  return firstLine.length > 40 ? firstLine.substring(0, 40) : firstLine;
}

DateTime? _parseDate(String? raw) {
  if (raw == null) return null;
  final now = DateTime.now();
  final slash = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(raw);
  if (slash != null) {
    final year = int.parse(slash.group(3)!);
    return DateTime(year < 100 ? 2000 + year : year, int.parse(slash.group(1)!), int.parse(slash.group(2)!));
  }
  for (final month in {'april': 4, 'may': 5, 'june': 6}.entries) {
    final match = RegExp('${month.key}\\s+(\\d{1,2})', caseSensitive: false).firstMatch(raw);
    if (match != null) return DateTime(now.year, month.value, int.parse(match.group(1)!));
  }
  return null;
}

String _fmtDate(DateTime date) => '${date.month}/${date.day}/${date.year}';

List<LifeAdminItem> _seedItems() => [
  pipelineOutcomeToItem(
    runPipeline(
      sourceText: 'City Power statement from City Power. Amount due \$84.20 by 04/24/2026. Account 5519.',
      inputType: CaptureInputType.forwardedEmail,
      existingItems: const [],
    ),
    'seed-1',
  ),
  pipelineOutcomeToItem(
    runPipeline(
      sourceText: 'Dental booking confirmation from Bright Dental scheduled May 6. Reference BK-2201.',
      inputType: CaptureInputType.upload,
      existingItems: const [],
    ),
    'seed-2',
  ),
  LifeAdminItem(
    id: 'seed-3',
    title: 'Possible duplicate item',
    summary: 'This capture closely matches an existing item, so no new reminder or task is created automatically.',
    sourceText: 'City Power statement from City Power. Amount due \$84.20 by 04/24/2026. Account 5519.',
    inputType: CaptureInputType.upload,
    processingState: ProcessingState.duplicate,
    workflowState: WorkflowState.reviewed,
    category: ItemCategory.other,
    suggestedAction: ActionType.archive,
    fields: [ExtractedField(label: 'Duplicate reason', value: 'Matched an existing upload or forwarded item', confidence: ConfidenceLevel.high, sourceSnippet: 'City Power statement')],
    pipelineStages: [
      PipelineStage(code: 'received', label: 'Item received', state: StageState.complete, detail: 'Duplicate example preserved for review.'),
      PipelineStage(code: 'review', label: 'Review-ready item creation', state: StageState.complete, detail: 'No action was created.'),
    ],
    dedupeSignature: _dedupeSignature('city power statement from city power amount due 84.20 by 04/24/2026 account 5519'),
  ),
];

LifeAdminItem pipelineOutcomeToItem(PipelineOutcome outcome, String id) => LifeAdminItem(
  id: id,
  title: outcome.title,
  summary: outcome.summary,
  sourceText: outcome.fields.firstOrNull?.sourceSnippet ?? outcome.summary,
  inputType: outcome.inputType,
  processingState: outcome.processingState,
  workflowState: outcome.workflowState,
  category: outcome.category,
  suggestedAction: outcome.suggestedAction,
  fields: outcome.fields,
  pipelineStages: outcome.pipelineStages,
  dedupeSignature: outcome.dedupeSignature,
  primaryDate: outcome.primaryDate,
  amount: outcome.amount,
  providerOrSender: outcome.providerOrSender,
  reference: outcome.reference,
  sourcePath: outcome.sourcePath,
  failureReason: outcome.failureReason,
);

extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;

  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
