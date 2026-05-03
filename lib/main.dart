import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const AiLifeAdminApp());
}

enum InboxCategory {
  bills,
  appointments,
  forms,
  renewals,
  homeServices,
  medical,
  travel,
  other,
}

enum InboxActionType { pay, attend, submit, sign, renew, call, review, other }

enum InboxStatus { open, done, archived }

enum ReviewState { needsReview, ready }

enum InboxDateType { due, appointment, renewal, deadline, unknown }

enum SourceKind { image, pdf }

enum InboxView { needsReview, dueSoon, overdue, done }

enum ReminderKind { defaultReminder, followUp, overdue, sameDay }

class SourceRef {
  const SourceRef({
    required this.kind,
    required this.path,
    required this.label,
  });

  final SourceKind kind;
  final String path;
  final String label;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'path': path,
    'label': label,
  };

  factory SourceRef.fromJson(Map<String, dynamic> json) => SourceRef(
    kind: SourceKind.values.byName(
      json['kind'] as String? ?? SourceKind.image.name,
    ),
    path: json['path'] as String? ?? '',
    label: json['label'] as String? ?? 'Source file',
  );
}

class ReminderSchedule {
  const ReminderSchedule({
    required this.kind,
    required this.when,
    required this.label,
  });

  final ReminderKind kind;
  final DateTime when;
  final String label;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'when': when.toIso8601String(),
    'label': label,
  };

  factory ReminderSchedule.fromJson(Map<String, dynamic> json) =>
      ReminderSchedule(
        kind: ReminderKind.values.byName(
          json['kind'] as String? ?? ReminderKind.defaultReminder.name,
        ),
        when: DateTime.parse(json['when'] as String),
        label: json['label'] as String? ?? '',
      );
}

class ConfidenceFlag {
  const ConfidenceFlag({required this.field, required this.message});

  final String field;
  final String message;

  Map<String, dynamic> toJson() => {'field': field, 'message': message};

  factory ConfidenceFlag.fromJson(Map<String, dynamic> json) => ConfidenceFlag(
    field: json['field'] as String? ?? '',
    message: json['message'] as String? ?? '',
  );
}

class InboxItem {
  InboxItem({
    required this.id,
    required this.title,
    required this.category,
    required this.actionType,
    required this.actionSummary,
    required this.status,
    required this.reviewState,
    required this.dateType,
    required this.nextImportantDate,
    required this.sourceRef,
    required this.createdAt,
    this.sourceName,
    this.amount,
    this.summary,
    this.reminderAt,
    this.notes,
    this.confidenceFlags = const [],
    this.reminderSchedule = const [],
    this.dateConfirmed = false,
    this.actionConfirmed = false,
  });

  String id;
  String title;
  InboxCategory category;
  InboxActionType actionType;
  String actionSummary;
  InboxStatus status;
  ReviewState reviewState;
  InboxDateType dateType;
  DateTime? nextImportantDate;
  SourceRef sourceRef;
  DateTime createdAt;
  String? sourceName;
  double? amount;
  String? summary;
  DateTime? reminderAt;
  String? notes;
  List<ConfidenceFlag> confidenceFlags;
  List<ReminderSchedule> reminderSchedule;
  bool dateConfirmed;
  bool actionConfirmed;

  bool get hasDateUncertainty =>
      confidenceFlags.any((flag) => flag.field == 'next_important_date');
  bool get hasActionUncertainty =>
      confidenceFlags.any((flag) => flag.field == 'action_type');
  bool get remindersActive =>
      reviewState == ReviewState.ready &&
      status == InboxStatus.open &&
      nextImportantDate != null &&
      (!hasDateUncertainty || dateConfirmed) &&
      (!hasActionUncertainty || actionConfirmed);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'actionType': actionType.name,
    'actionSummary': actionSummary,
    'status': status.name,
    'reviewState': reviewState.name,
    'dateType': dateType.name,
    'nextImportantDate': nextImportantDate?.toIso8601String(),
    'sourceRef': sourceRef.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'sourceName': sourceName,
    'amount': amount,
    'summary': summary,
    'reminderAt': reminderAt?.toIso8601String(),
    'notes': notes,
    'confidenceFlags': confidenceFlags.map((flag) => flag.toJson()).toList(),
    'reminderSchedule': reminderSchedule
        .map((reminder) => reminder.toJson())
        .toList(),
    'dateConfirmed': dateConfirmed,
    'actionConfirmed': actionConfirmed,
  };

  factory InboxItem.fromJson(Map<String, dynamic> json) => InboxItem(
    id: json['id'] as String,
    title: json['title'] as String,
    category: InboxCategory.values.byName(json['category'] as String),
    actionType: InboxActionType.values.byName(json['actionType'] as String),
    actionSummary: json['actionSummary'] as String,
    status: InboxStatus.values.byName(json['status'] as String),
    reviewState: ReviewState.values.byName(json['reviewState'] as String),
    dateType: InboxDateType.values.byName(json['dateType'] as String),
    nextImportantDate: json['nextImportantDate'] == null
        ? null
        : DateTime.parse(json['nextImportantDate'] as String),
    sourceRef: SourceRef.fromJson(
      Map<String, dynamic>.from(json['sourceRef'] as Map),
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
    sourceName: json['sourceName'] as String?,
    amount: (json['amount'] as num?)?.toDouble(),
    summary: json['summary'] as String?,
    reminderAt: json['reminderAt'] == null
        ? null
        : DateTime.parse(json['reminderAt'] as String),
    notes: json['notes'] as String?,
    confidenceFlags: ((json['confidenceFlags'] as List?) ?? const [])
        .map(
          (flag) =>
              ConfidenceFlag.fromJson(Map<String, dynamic>.from(flag as Map)),
        )
        .toList(),
    reminderSchedule: ((json['reminderSchedule'] as List?) ?? const [])
        .map(
          (item) =>
              ReminderSchedule.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(),
    dateConfirmed: json['dateConfirmed'] as bool? ?? false,
    actionConfirmed: json['actionConfirmed'] as bool? ?? false,
  );
}

class ExtractedDraft {
  ExtractedDraft({
    required this.title,
    required this.category,
    required this.actionType,
    required this.actionSummary,
    required this.reviewState,
    required this.dateType,
    required this.nextImportantDate,
    required this.sourceRef,
    required this.createdAt,
    this.sourceName,
    this.amount,
    this.summary,
    this.notes,
    this.confidenceFlags = const [],
    this.dateConfirmed = false,
    this.actionConfirmed = false,
  });

  String title;
  InboxCategory category;
  InboxActionType actionType;
  String actionSummary;
  ReviewState reviewState;
  InboxDateType dateType;
  DateTime? nextImportantDate;
  SourceRef sourceRef;
  DateTime createdAt;
  String? sourceName;
  double? amount;
  String? summary;
  String? notes;
  List<ConfidenceFlag> confidenceFlags;
  bool dateConfirmed;
  bool actionConfirmed;

  InboxItem toInboxItem(String id) {
    final item = InboxItem(
      id: id,
      title: title,
      category: category,
      actionType: actionType,
      actionSummary: actionSummary,
      status: InboxStatus.open,
      reviewState: reviewState,
      dateType: dateType,
      nextImportantDate: nextImportantDate,
      sourceRef: sourceRef,
      createdAt: createdAt,
      sourceName: sourceName,
      amount: amount,
      summary: summary,
      notes: notes,
      confidenceFlags: confidenceFlags,
      dateConfirmed: dateConfirmed,
      actionConfirmed: actionConfirmed,
    );
    return applyReminderRules(item);
  }
}

class AiLifeAdminApp extends StatelessWidget {
  const AiLifeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life Admin Inbox',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3158F5)),
        useMaterial3: true,
      ),
      home: const LifeAdminShell(),
    );
  }
}

class LifeAdminShell extends StatefulWidget {
  const LifeAdminShell({super.key});

  @override
  State<LifeAdminShell> createState() => _LifeAdminShellState();
}

class _LifeAdminShellState extends State<LifeAdminShell> {
  static const _prefsKeyItems = 'inbox_items_v2';
  static const _prefsKeyOnboarding = 'onboarding_complete_v1';

  final _searchController = TextEditingController();
  final _picker = ImagePicker();
  List<InboxItem> _items = [];
  bool _loading = true;
  bool _onboardingComplete = false;
  bool _notificationsEnabled = false;
  InboxView _selectedView = InboxView.needsReview;
  InboxCategory? _categoryFilter;
  InboxStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_prefsKeyItems);
    final onboarding = prefs.getBool(_prefsKeyOnboarding) ?? false;
    setState(() {
      _items = encoded == null
          ? seedInboxItems()
          : (jsonDecode(encoded) as List)
                .map(
                  (item) => InboxItem.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList();
      _onboardingComplete = onboarding;
      _notificationsEnabled = onboarding;
      _loading = false;
    });
    if (encoded == null) {
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeyItems,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
    await prefs.setBool(_prefsKeyOnboarding, _onboardingComplete);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_onboardingComplete) {
      return _buildOnboarding();
    }

    final itemsForView = filteredInboxItems(
      items: _items,
      view: _selectedView,
      searchQuery: _searchController.text,
      categoryFilter: _categoryFilter,
      statusFilter: _statusFilter,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Life Admin Inbox'),
        actions: [
          IconButton(
            tooltip: 'Privacy and trust',
            onPressed: _showPrivacySheet,
            icon: const Icon(Icons.privacy_tip_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCaptureSheet,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Capture'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Save important bills, appointments, renewals, and forms. We extract the next action, ask you to confirm uncertain fields, and remind you before anything is missed.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          _notificationsEnabled
                              ? 'Notifications enabled'
                              : 'Notifications off',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${_items.where((item) => item.reviewState == ReviewState.needsReview && item.status == InboxStatus.open).length} need review',
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${_items.where((item) => classifyView(item) == InboxView.overdue).length} overdue',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<InboxView>(
            segments: const [
              ButtonSegment(
                value: InboxView.needsReview,
                label: Text('Needs review'),
              ),
              ButtonSegment(value: InboxView.dueSoon, label: Text('Due soon')),
              ButtonSegment(value: InboxView.overdue, label: Text('Overdue')),
              ButtonSegment(value: InboxView.done, label: Text('Done')),
            ],
            selected: {_selectedView},
            onSelectionChanged: (selection) =>
                setState(() => _selectedView = selection.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search title or summary',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownMenu<InboxCategory?>(
                initialSelection: _categoryFilter,
                hintText: 'Filter category',
                onSelected: (value) => setState(() => _categoryFilter = value),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All categories'),
                  ...InboxCategory.values.map(
                    (category) => DropdownMenuEntry(
                      value: category,
                      label: categoryLabel(category),
                    ),
                  ),
                ],
              ),
              DropdownMenu<InboxStatus?>(
                initialSelection: _statusFilter,
                hintText: 'Filter status',
                onSelected: (value) => setState(() => _statusFilter = value),
                dropdownMenuEntries: [
                  const DropdownMenuEntry(value: null, label: 'All statuses'),
                  ...InboxStatus.values.map(
                    (status) =>
                        DropdownMenuEntry(value: status, label: status.name),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (itemsForView.isEmpty)
            Card(
              child: ListTile(
                title: Text('Nothing in ${viewLabel(_selectedView)}'),
              ),
            )
          else
            ...itemsForView.map(
              (item) => Card(
                child: ListTile(
                  title: Text(item.title),
                  subtitle: Text(
                    '${categoryLabel(item.category)} • ${item.actionSummary}${item.nextImportantDate == null ? '' : '\n${dateTypeLabel(item.dateType)} ${formatDateTime(item.nextImportantDate!)}'}',
                  ),
                  isThreeLine: item.nextImportantDate != null,
                  trailing: item.reviewState == ReviewState.needsReview
                      ? const Icon(Icons.flag_outlined)
                      : const Icon(Icons.chevron_right),
                  onTap: () => _openItem(item),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Scaffold _buildOnboarding() {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Life Admin Inbox',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Save important household admin items, confirm the next action, and get reminded before you miss something.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              const ListTile(
                leading: Icon(Icons.notifications_active_outlined),
                title: Text('Enable notifications'),
                subtitle: Text(
                  'Required for due date and appointment reminders.',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.photo_library_outlined),
                title: Text('Upload image, photo, or screenshot'),
                subtitle: Text('Launch capture method 1'),
              ),
              const ListTile(
                leading: Icon(Icons.picture_as_pdf_outlined),
                title: Text('Upload PDF'),
                subtitle: Text('Launch capture method 2'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  setState(() {
                    _onboardingComplete = true;
                    _notificationsEnabled = true;
                  });
                  await _persist();
                },
                child: const Text('Sign up and continue'),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCaptureSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture an inbox item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text('Choose one of the two MVP launch capture methods.'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Image, photo, or screenshot'),
                subtitle: const Text(
                  'Import from camera or gallery and confirm extracted text.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _captureImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('PDF upload'),
                subtitle: const Text(
                  'Select a PDF and paste visible text for this prototype.',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _capturePdf();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    final source = SourceRef(
      kind: SourceKind.image,
      path: image.path,
      label: 'Image upload',
    );
    final text = await _promptForSourceText(source);
    if (text == null || text.trim().isEmpty) return;
    await _reviewAndSaveDraft(
      extractInboxItem(
        text: text.trim(),
        sourceRef: source,
        now: DateTime.now(),
      ),
    );
  }

  Future<void> _capturePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    final source = SourceRef(
      kind: SourceKind.pdf,
      path: result.files.single.path!,
      label: 'PDF upload',
    );
    final text = await _promptForSourceText(source);
    if (text == null || text.trim().isEmpty) return;
    await _reviewAndSaveDraft(
      extractInboxItem(
        text: text.trim(),
        sourceRef: source,
        now: DateTime.now(),
      ),
    );
  }

  Future<String?> _promptForSourceText(SourceRef sourceRef) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(sourceRef.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sourceRef.path, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            const Text(
              'Paste the visible text from the document so this prototype can extract fields.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    'Example: Electric bill from City Power, amount due \$84.20 by 05/10/2026',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewAndSaveDraft(ExtractedDraft draft) async {
    final reviewed = await showModalBottomSheet<ExtractedDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ReviewItemSheet(initialDraft: draft),
    );
    if (reviewed == null) return;
    setState(() {
      _items.insert(
        0,
        reviewed.toInboxItem(DateTime.now().microsecondsSinceEpoch.toString()),
      );
    });
    await _persist();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Inbox item saved.')));
  }

  Future<void> _openItem(InboxItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(item.summary ?? item.actionSummary),
                  const SizedBox(height: 16),
                  Text(
                    'What this is',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Category'),
                    subtitle: Text(categoryLabel(item.category)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Next action'),
                    subtitle: Text(
                      '${actionTypeLabel(item.actionType)} • ${item.actionSummary}',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('When it matters'),
                    subtitle: Text(
                      item.nextImportantDate == null
                          ? 'No reliable date yet'
                          : '${dateTypeLabel(item.dateType)} on ${formatDateTime(item.nextImportantDate!)}',
                    ),
                  ),
                  if (item.sourceName != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Source name'),
                      subtitle: Text(item.sourceName!),
                    ),
                  if (item.amount != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Amount'),
                      subtitle: Text(formatAmount(item.amount!)),
                    ),
                  if (item.confidenceFlags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Needs review',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...item.confidenceFlags.map(
                      (flag) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.report_gmailerrorred_outlined,
                        ),
                        title: Text(flag.field),
                        subtitle: Text(flag.message),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: item.actionConfirmed,
                    onChanged: item.hasActionUncertainty
                        ? (value) {
                            setState(() => item.actionConfirmed = value);
                            setSheetState(() {});
                          }
                        : null,
                    title: const Text('Confirm action'),
                    subtitle: const Text(
                      'Required before reminders activate when action confidence is low.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: item.dateConfirmed,
                    onChanged: item.hasDateUncertainty
                        ? (value) {
                            setState(() => item.dateConfirmed = value);
                            setSheetState(() {});
                          }
                        : null,
                    title: const Text('Confirm date'),
                    subtitle: const Text(
                      'Required before reminders activate when date confidence is low.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      setState(() {
                        item.reviewState =
                            item.remindersActive ||
                                (!item.hasDateUncertainty &&
                                    !item.hasActionUncertainty)
                            ? ReviewState.ready
                            : ReviewState.needsReview;
                        applyReminderRules(item);
                      });
                      await _persist();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(
                      item.remindersActive
                          ? 'Confirm and keep reminders active'
                          : 'Save review state',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (item.reminderSchedule.isNotEmpty) ...[
                    Text(
                      'Reminder schedule',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    ...item.reminderSchedule.map(
                      (reminder) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(reminder.label),
                        subtitle: Text(formatDateTime(reminder.when)),
                      ),
                    ),
                  ] else
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Automatic reminders are paused until review is complete.',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () async {
                          setState(
                            () => item.reminderAt = DateTime.now().add(
                              const Duration(hours: 4),
                            ),
                          );
                          await _persist();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Snooze 4h'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          setState(() => item.status = InboxStatus.done);
                          await _persist();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Mark done'),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          setState(() => item.status = InboxStatus.archived);
                          await _persist();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Archive'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPrivacySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Privacy and trust'),
              SizedBox(height: 12),
              Text(
                'Uploads are processed by AI to extract title, action, and date fields.',
              ),
              Text(
                'Sensitive source files should only be visible to the authenticated user.',
              ),
              Text(
                'Users must be able to delete an item and its source material permanently.',
              ),
              Text(
                'Documents should not be used to train AI vendors used for inference.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReviewItemSheet extends StatefulWidget {
  const ReviewItemSheet({super.key, required this.initialDraft});

  final ExtractedDraft initialDraft;

  @override
  State<ReviewItemSheet> createState() => _ReviewItemSheetState();
}

class _ReviewItemSheetState extends State<ReviewItemSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _actionSummaryController;
  late final TextEditingController _summaryController;
  late final TextEditingController _sourceNameController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateController;
  late InboxCategory _category;
  late InboxActionType _actionType;
  late InboxDateType _dateType;
  late bool _dateConfirmed;
  late bool _actionConfirmed;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialDraft.title);
    _actionSummaryController = TextEditingController(
      text: widget.initialDraft.actionSummary,
    );
    _summaryController = TextEditingController(
      text: widget.initialDraft.summary ?? '',
    );
    _sourceNameController = TextEditingController(
      text: widget.initialDraft.sourceName ?? '',
    );
    _amountController = TextEditingController(
      text: widget.initialDraft.amount?.toStringAsFixed(2) ?? '',
    );
    _dateController = TextEditingController(
      text: widget.initialDraft.nextImportantDate == null
          ? ''
          : formatDateTime(widget.initialDraft.nextImportantDate!),
    );
    _category = widget.initialDraft.category;
    _actionType = widget.initialDraft.actionType;
    _dateType = widget.initialDraft.dateType;
    _dateConfirmed = widget.initialDraft.dateConfirmed;
    _actionConfirmed = widget.initialDraft.actionConfirmed;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _actionSummaryController.dispose();
    _summaryController.dispose();
    _sourceNameController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  ExtractedDraft _buildDraft() {
    final nextDate =
        parseEditorDate(_dateController.text.trim()) ??
        widget.initialDraft.nextImportantDate;
    final amount = double.tryParse(_amountController.text.trim());
    final flags = <ConfidenceFlag>[];
    if (widget.initialDraft.confidenceFlags.any(
          (flag) => flag.field == 'action_type',
        ) &&
        !_actionConfirmed) {
      flags.add(
        const ConfidenceFlag(
          field: 'action_type',
          message: 'Action still needs confirmation before reminders activate.',
        ),
      );
    }
    if (widget.initialDraft.confidenceFlags.any(
          (flag) => flag.field == 'next_important_date',
        ) &&
        !_dateConfirmed) {
      flags.add(
        const ConfidenceFlag(
          field: 'next_important_date',
          message: 'Date still needs confirmation before reminders activate.',
        ),
      );
    }
    if (nextDate == null) {
      flags.add(
        const ConfidenceFlag(
          field: 'next_important_date',
          message:
              'No reliable date yet. Reminders stay off until a date is added.',
        ),
      );
    }
    return ExtractedDraft(
      title: _titleController.text.trim(),
      category: _category,
      actionType: _actionType,
      actionSummary: _actionSummaryController.text.trim(),
      reviewState: flags.isEmpty ? ReviewState.ready : ReviewState.needsReview,
      dateType: _dateType,
      nextImportantDate: nextDate,
      sourceRef: widget.initialDraft.sourceRef,
      createdAt: widget.initialDraft.createdAt,
      sourceName: _sourceNameController.text.trim().isEmpty
          ? null
          : _sourceNameController.text.trim(),
      amount: amount,
      summary: _summaryController.text.trim().isEmpty
          ? null
          : _summaryController.text.trim(),
      notes: widget.initialDraft.notes,
      confidenceFlags: flags,
      dateConfirmed: _dateConfirmed,
      actionConfirmed: _actionConfirmed,
    );
  }

  bool get _canSave =>
      _titleController.text.trim().isNotEmpty &&
      _actionSummaryController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final draft = _buildDraft();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review extracted item',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<InboxCategory>(
              initialValue: _category,
              items: InboxCategory.values
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(categoryLabel(category)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value!),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<InboxActionType>(
              initialValue: _actionType,
              items: InboxActionType.values
                  .map(
                    (action) => DropdownMenuItem(
                      value: action,
                      child: Text(actionTypeLabel(action)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _actionType = value!),
              decoration: const InputDecoration(labelText: 'Action type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actionSummaryController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Action summary'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<InboxDateType>(
              initialValue: _dateType,
              items: InboxDateType.values
                  .map(
                    (dateType) => DropdownMenuItem(
                      value: dateType,
                      child: Text(dateTypeLabel(dateType)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _dateType = value!),
              decoration: const InputDecoration(labelText: 'Date type'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Next important date (MM/DD/YYYY or YYYY-MM-DD)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceNameController,
              decoration: const InputDecoration(labelText: 'Source name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _summaryController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Summary'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _actionConfirmed,
              onChanged:
                  widget.initialDraft.confidenceFlags.any(
                    (flag) => flag.field == 'action_type',
                  )
                  ? (value) => setState(() => _actionConfirmed = value)
                  : null,
              title: const Text('Confirm action if uncertain'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _dateConfirmed,
              onChanged:
                  widget.initialDraft.confidenceFlags.any(
                    (flag) => flag.field == 'next_important_date',
                  )
                  ? (value) => setState(() => _dateConfirmed = value)
                  : null,
              title: const Text('Confirm date if uncertain'),
            ),
            if (draft.confidenceFlags.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...draft.confidenceFlags.map(
                (flag) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined),
                  title: Text(flag.field),
                  subtitle: Text(flag.message),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _canSave ? () => Navigator.pop(context, draft) : null,
              child: const Text('Save inbox item'),
            ),
          ],
        ),
      ),
    );
  }
}

ExtractedDraft extractInboxItem({
  required String text,
  required SourceRef sourceRef,
  DateTime? now,
}) {
  final createdAt = now ?? DateTime.now();
  final normalized = text.toLowerCase();
  final category = detectCategory(normalized);
  final actionType = detectActionType(normalized, category);
  final dateType = detectDateType(category);
  final nextDate = parseDetectedDate(text);
  final sourceName = detectSourceName(text);
  final amount = detectAmount(text);
  final title = buildTitle(category, sourceName);
  final actionSummary = buildActionSummary(actionType, category, sourceName);
  final summary = buildSummary(category, nextDate, amount);
  final confidenceFlags = <ConfidenceFlag>[];

  final lowActionConfidence = actionType == InboxActionType.review;
  final lowDateConfidence = nextDate == null;
  if (lowActionConfidence) {
    confidenceFlags.add(
      const ConfidenceFlag(
        field: 'action_type',
        message: 'We could not confidently determine the next action.',
      ),
    );
  }
  if (lowDateConfidence) {
    confidenceFlags.add(
      const ConfidenceFlag(
        field: 'next_important_date',
        message: 'We could not confidently determine the key date.',
      ),
    );
  }
  if (category == InboxCategory.bills &&
      amount != null &&
      normalized.contains('estimate')) {
    confidenceFlags.add(
      const ConfidenceFlag(
        field: 'amount',
        message: 'Bill amount may be estimated.',
      ),
    );
  }

  return ExtractedDraft(
    title: title,
    category: category,
    actionType: actionType,
    actionSummary: actionSummary,
    reviewState: confidenceFlags.isEmpty
        ? ReviewState.ready
        : ReviewState.needsReview,
    dateType: dateType,
    nextImportantDate: nextDate,
    sourceRef: sourceRef,
    createdAt: createdAt,
    sourceName: sourceName,
    amount: amount,
    summary: summary,
    confidenceFlags: confidenceFlags,
    dateConfirmed: !lowDateConfidence,
    actionConfirmed: !lowActionConfidence,
  );
}

InboxItem applyReminderRules(InboxItem item) {
  if (!item.remindersActive) {
    item.reminderSchedule = const [];
    item.reminderAt = null;
    item.reviewState = ReviewState.needsReview;
    return item;
  }

  final date = item.nextImportantDate!;
  switch (item.category) {
    case InboxCategory.bills:
      item.reminderSchedule = [
        ReminderSchedule(
          kind: ReminderKind.defaultReminder,
          when: date.subtract(const Duration(days: 3)),
          label: 'Bill reminder',
        ),
        ReminderSchedule(
          kind: ReminderKind.overdue,
          when: date.add(const Duration(days: 1)),
          label: 'Overdue bill follow-up',
        ),
      ];
      break;
    case InboxCategory.appointments:
      item.reminderSchedule = [
        ReminderSchedule(
          kind: ReminderKind.defaultReminder,
          when: date.subtract(const Duration(days: 1)),
          label: 'Appointment reminder',
        ),
        ReminderSchedule(
          kind: ReminderKind.sameDay,
          when: date.subtract(const Duration(hours: 2)),
          label: 'Appointment soon',
        ),
      ];
      break;
    case InboxCategory.forms:
    case InboxCategory.renewals:
      item.reminderSchedule = [
        ReminderSchedule(
          kind: ReminderKind.defaultReminder,
          when: date.subtract(const Duration(days: 7)),
          label: 'Deadline reminder',
        ),
        ReminderSchedule(
          kind: ReminderKind.followUp,
          when: date.subtract(const Duration(days: 1)),
          label: 'Deadline tomorrow',
        ),
      ];
      break;
    case InboxCategory.homeServices:
    case InboxCategory.medical:
    case InboxCategory.travel:
    case InboxCategory.other:
      item.reminderSchedule = [
        ReminderSchedule(
          kind: ReminderKind.defaultReminder,
          when: date.subtract(const Duration(days: 2)),
          label: 'Upcoming item reminder',
        ),
      ];
      break;
  }
  item.reminderAt = item.reminderSchedule.first.when;
  item.reviewState = ReviewState.ready;
  return item;
}

List<InboxItem> filteredInboxItems({
  required List<InboxItem> items,
  required InboxView view,
  required String searchQuery,
  InboxCategory? categoryFilter,
  InboxStatus? statusFilter,
  DateTime? now,
}) {
  final q = searchQuery.trim().toLowerCase();
  return items.where((item) {
    if (classifyView(item, now: now) != view) return false;
    if (categoryFilter != null && item.category != categoryFilter) return false;
    if (statusFilter != null && item.status != statusFilter) return false;
    if (q.isEmpty) return true;
    final haystack = '${item.title} ${item.summary ?? ''}'.toLowerCase();
    return haystack.contains(q);
  }).toList()..sort((a, b) {
    final aDate = a.nextImportantDate ?? a.createdAt;
    final bDate = b.nextImportantDate ?? b.createdAt;
    return aDate.compareTo(bDate);
  });
}

InboxView classifyView(InboxItem item, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  if (item.status == InboxStatus.done || item.status == InboxStatus.archived) {
    return InboxView.done;
  }
  if (item.reviewState == ReviewState.needsReview) {
    return InboxView.needsReview;
  }
  if (item.nextImportantDate != null &&
      item.nextImportantDate!.isBefore(clock)) {
    return InboxView.overdue;
  }
  return InboxView.dueSoon;
}

List<InboxItem> seedInboxItems() {
  final now = DateTime(2026, 5, 3, 12);
  return [
    extractInboxItem(
      text:
          'City Power bill from City Power. Amount due \$84.20 by 05/10/2026.',
      sourceRef: const SourceRef(
        kind: SourceKind.pdf,
        path: '/seed/city-power.pdf',
        label: 'PDF upload',
      ),
      now: now,
    ).toInboxItem('seed-bill'),
    extractInboxItem(
      text: 'Dental appointment with Bright Dental on 05/06/2026 at 3:00 PM.',
      sourceRef: const SourceRef(
        kind: SourceKind.image,
        path: '/seed/dentist.png',
        label: 'Image upload',
      ),
      now: now,
    ).toInboxItem('seed-appointment'),
    extractInboxItem(
      text: 'School permission slip. Return by 05/02/2026.',
      sourceRef: const SourceRef(
        kind: SourceKind.image,
        path: '/seed/form.png',
        label: 'Image upload',
      ),
      now: now,
    ).toInboxItem('seed-form'),
    extractInboxItem(
      text: 'Unclear notice from provider. Please review this soon.',
      sourceRef: const SourceRef(
        kind: SourceKind.pdf,
        path: '/seed/review.pdf',
        label: 'PDF upload',
      ),
      now: now,
    ).toInboxItem('seed-review'),
  ]..[0].status = InboxStatus.done;
}

InboxCategory detectCategory(String normalized) {
  if (normalized.contains('bill') ||
      normalized.contains('amount due') ||
      normalized.contains('statement') ||
      normalized.contains('payment')) {
    return InboxCategory.bills;
  }
  if (normalized.contains('appointment') ||
      normalized.contains('scheduled') ||
      normalized.contains('dentist') ||
      normalized.contains('doctor')) {
    return InboxCategory.appointments;
  }
  if (normalized.contains('renew') ||
      normalized.contains('expiration') ||
      normalized.contains('expires')) {
    return InboxCategory.renewals;
  }
  if (normalized.contains('form') ||
      normalized.contains('permission slip') ||
      normalized.contains('submit')) {
    return InboxCategory.forms;
  }
  if (normalized.contains('utility') || normalized.contains('service')) {
    return InboxCategory.homeServices;
  }
  if (normalized.contains('medical') || normalized.contains('lab')) {
    return InboxCategory.medical;
  }
  if (normalized.contains('flight') ||
      normalized.contains('hotel') ||
      normalized.contains('travel')) {
    return InboxCategory.travel;
  }
  return InboxCategory.other;
}

InboxActionType detectActionType(String normalized, InboxCategory category) {
  if (normalized.contains('pay')) {
    return InboxActionType.pay;
  }
  if (normalized.contains('attend') ||
      normalized.contains('appointment') ||
      normalized.contains('scheduled')) {
    return InboxActionType.attend;
  }
  if (normalized.contains('submit')) {
    return InboxActionType.submit;
  }
  if (normalized.contains('sign')) {
    return InboxActionType.sign;
  }
  if (normalized.contains('renew')) {
    return InboxActionType.renew;
  }
  if (normalized.contains('call')) {
    return InboxActionType.call;
  }
  switch (category) {
    case InboxCategory.bills:
      return InboxActionType.pay;
    case InboxCategory.appointments:
      return InboxActionType.attend;
    case InboxCategory.forms:
      return InboxActionType.submit;
    case InboxCategory.renewals:
      return InboxActionType.renew;
    case InboxCategory.homeServices:
    case InboxCategory.medical:
    case InboxCategory.travel:
    case InboxCategory.other:
      return InboxActionType.review;
  }
}

InboxDateType detectDateType(InboxCategory category) {
  switch (category) {
    case InboxCategory.bills:
      return InboxDateType.due;
    case InboxCategory.appointments:
      return InboxDateType.appointment;
    case InboxCategory.renewals:
      return InboxDateType.renewal;
    case InboxCategory.forms:
    case InboxCategory.homeServices:
    case InboxCategory.medical:
    case InboxCategory.travel:
      return InboxDateType.deadline;
    case InboxCategory.other:
      return InboxDateType.unknown;
  }
}

String buildTitle(InboxCategory category, String? sourceName) {
  final source = sourceName == null ? '' : ' from $sourceName';
  switch (category) {
    case InboxCategory.bills:
      return 'Bill$source';
    case InboxCategory.appointments:
      return 'Appointment$source';
    case InboxCategory.forms:
      return 'Form$source';
    case InboxCategory.renewals:
      return 'Renewal$source';
    case InboxCategory.homeServices:
      return 'Home service item$source';
    case InboxCategory.medical:
      return 'Medical item$source';
    case InboxCategory.travel:
      return 'Travel item$source';
    case InboxCategory.other:
      return sourceName == null ? 'Inbox item' : 'Inbox item from $sourceName';
  }
}

String buildActionSummary(
  InboxActionType actionType,
  InboxCategory category,
  String? sourceName,
) {
  final target = sourceName ?? categoryLabel(category).toLowerCase();
  switch (actionType) {
    case InboxActionType.pay:
      return 'Pay $target';
    case InboxActionType.attend:
      return 'Attend $target';
    case InboxActionType.submit:
      return 'Submit $target';
    case InboxActionType.sign:
      return 'Sign $target';
    case InboxActionType.renew:
      return 'Renew $target';
    case InboxActionType.call:
      return 'Call $target';
    case InboxActionType.review:
      return 'Review $target';
    case InboxActionType.other:
      return 'Take care of $target';
  }
}

String buildSummary(
  InboxCategory category,
  DateTime? nextDate,
  double? amount,
) {
  final dateText = nextDate == null
      ? 'No date confirmed yet.'
      : 'Next date: ${formatDateTime(nextDate)}.';
  final amountText = amount == null ? '' : ' Amount: ${formatAmount(amount)}.';
  return '${categoryLabel(category)} item captured. $dateText$amountText'
      .trim();
}

DateTime? parseDetectedDate(String text) {
  final slash = RegExp(r'(\d{1,2})/(\d{1,2})/(\d{4})').firstMatch(text);
  if (slash != null) {
    return DateTime(
      int.parse(slash.group(3)!),
      int.parse(slash.group(1)!),
      int.parse(slash.group(2)!),
    );
  }
  final iso = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) {
    return DateTime(
      int.parse(iso.group(1)!),
      int.parse(iso.group(2)!),
      int.parse(iso.group(3)!),
    );
  }
  return null;
}

DateTime? parseEditorDate(String text) => parseDetectedDate(text);

double? detectAmount(String text) {
  final match = RegExp(r'\$(\d+(?:\.\d{2})?)').firstMatch(text);
  return match == null ? null : double.tryParse(match.group(1)!);
}

String? detectSourceName(String text) {
  final fromMatch = RegExp(
    r'from ([A-Z][A-Za-z0-9& ]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (fromMatch != null) return fromMatch.group(1)!.trim();
  final withMatch = RegExp(
    r'with ([A-Z][A-Za-z0-9& ]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (withMatch != null) return withMatch.group(1)!.trim();
  return null;
}

String categoryLabel(InboxCategory category) {
  switch (category) {
    case InboxCategory.bills:
      return 'Bills';
    case InboxCategory.appointments:
      return 'Appointments';
    case InboxCategory.forms:
      return 'Forms';
    case InboxCategory.renewals:
      return 'Renewals';
    case InboxCategory.homeServices:
      return 'Home/Services';
    case InboxCategory.medical:
      return 'Medical';
    case InboxCategory.travel:
      return 'Travel';
    case InboxCategory.other:
      return 'Other';
  }
}

String actionTypeLabel(InboxActionType actionType) {
  switch (actionType) {
    case InboxActionType.pay:
      return 'pay';
    case InboxActionType.attend:
      return 'attend';
    case InboxActionType.submit:
      return 'submit';
    case InboxActionType.sign:
      return 'sign';
    case InboxActionType.renew:
      return 'renew';
    case InboxActionType.call:
      return 'call';
    case InboxActionType.review:
      return 'review';
    case InboxActionType.other:
      return 'other';
  }
}

String dateTypeLabel(InboxDateType dateType) {
  switch (dateType) {
    case InboxDateType.due:
      return 'Due';
    case InboxDateType.appointment:
      return 'Appointment';
    case InboxDateType.renewal:
      return 'Renewal';
    case InboxDateType.deadline:
      return 'Deadline';
    case InboxDateType.unknown:
      return 'Unknown date';
  }
}

String viewLabel(InboxView view) {
  switch (view) {
    case InboxView.needsReview:
      return 'Needs review';
    case InboxView.dueSoon:
      return 'Due soon';
    case InboxView.overdue:
      return 'Overdue';
    case InboxView.done:
      return 'Done';
  }
}

String formatDateTime(DateTime date) =>
    '${date.month}/${date.day}/${date.year}';
String formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';
