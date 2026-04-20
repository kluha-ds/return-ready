import 'dart:math';

import 'package:flutter/material.dart';

void main() {
  runApp(const AiLifeAdminApp());
}

enum CaptureInputType { screenshot, paperDoc, pastedText }

enum ItemType {
  bill,
  appointment,
  deadlineNotice,
  formTask,
  messageFollowUp,
  informational,
}

enum ItemStatus { inbox, today, upcoming, completed, archived }

enum ActionType { task, reminder, calendarDraft, referenceOnly }

enum ConfidenceLevel { high, medium, low }

class ExtractedField {
  ExtractedField({
    required this.label,
    required this.value,
    required this.confidence,
  });

  final String label;
  final String value;
  final ConfidenceLevel confidence;
}

class TimelineEntry {
  TimelineEntry({required this.label, required this.at});

  final String label;
  final DateTime at;
}

class LifeAdminItem {
  LifeAdminItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.sourceTitle,
    required this.sourceText,
    required this.inputType,
    required this.itemType,
    required this.actionType,
    required this.status,
    required this.actionLikelyRequired,
    required this.fields,
    this.primaryDate,
    this.amount,
    this.location,
    this.reference,
    this.reminderLabel,
    this.isMuted = false,
    this.duplicateWarning = false,
    this.needsManualReview = false,
    this.sensitive = false,
    this.deleted = false,
    List<TimelineEntry>? history,
  }) : history = history ?? [];

  final String id;
  String title;
  String summary;
  final String sourceTitle;
  final String sourceText;
  final CaptureInputType inputType;
  final ItemType itemType;
  ActionType actionType;
  ItemStatus status;
  final bool actionLikelyRequired;
  final List<ExtractedField> fields;
  DateTime? primaryDate;
  String? amount;
  String? location;
  String? reference;
  String? reminderLabel;
  bool isMuted;
  bool duplicateWarning;
  bool needsManualReview;
  bool sensitive;
  bool deleted;
  final List<TimelineEntry> history;
}

class ParseResult {
  ParseResult({
    required this.title,
    required this.summary,
    required this.itemType,
    required this.actionType,
    required this.actionLikelyRequired,
    required this.fields,
    required this.inputType,
    this.primaryDate,
    this.amount,
    this.location,
    this.reference,
    this.needsManualReview = false,
    this.sensitive = false,
    this.parsingFailed = false,
    this.duplicateWarning = false,
  });

  final String title;
  final String summary;
  final ItemType itemType;
  final ActionType actionType;
  final bool actionLikelyRequired;
  final List<ExtractedField> fields;
  final CaptureInputType inputType;
  final DateTime? primaryDate;
  final String? amount;
  final String? location;
  final String? reference;
  final bool needsManualReview;
  final bool sensitive;
  final bool parsingFailed;
  final bool duplicateWarning;
}

class AiLifeAdminApp extends StatelessWidget {
  const AiLifeAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Life Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF335CFF)),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        useMaterial3: true,
      ),
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
  final List<LifeAdminItem> _items = _seedItems();
  final TextEditingController _captureController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _onboardingSeen = false;
  int _currentIndex = 0;
  bool _quietHours = true;
  String _reminderMode = 'Balanced';

  @override
  void dispose() {
    _captureController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _items
        .where((item) => item.status == ItemStatus.inbox && !item.deleted)
        .toList();
    final today = _items
        .where((item) => item.status == ItemStatus.today && !item.deleted)
        .toList();
    final upcoming = _items
        .where((item) => item.status == ItemStatus.upcoming && !item.deleted)
        .toList();
    final archive = _items
        .where(
          (item) =>
              (item.status == ItemStatus.archived ||
                  item.actionType == ActionType.referenceOnly) &&
              !item.deleted,
        )
        .toList();
    final tabs = [
      _buildHomeView(inbox, today, upcoming),
      _buildArchiveView(archive),
      _buildSettingsView(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Life Admin'),
        actions: [
          IconButton(
            onPressed: _showCaptureSheet,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Capture',
          ),
        ],
      ),
      body: SafeArea(child: tabs[_currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) => setState(() => _currentIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive),
            label: 'Archive',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCaptureSheet,
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text('Capture'),
      ),
    );
  }

  Widget _buildHomeView(
    List<LifeAdminItem> inbox,
    List<LifeAdminItem> today,
    List<LifeAdminItem> upcoming,
  ) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroCard(),
        const SizedBox(height: 16),
        _buildSection(
          'Inbox',
          'Review new captures before anything is saved.',
          inbox,
        ),
        const SizedBox(height: 16),
        _buildSection('Today', 'Time-sensitive tasks and reminders.', today),
        const SizedBox(height: 16),
        _buildSection('Upcoming', 'Important items coming soon.', upcoming),
      ],
    );
  }

  Widget _buildHeroCard() {
    final reviewedCount = _items
        .where((item) => item.status != ItemStatus.inbox && !item.deleted)
        .length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _onboardingSeen
                  ? 'Keep nothing important from slipping through.'
                  : 'Capture paperwork. Confirm in seconds.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _onboardingSeen
                  ? 'Suggestion-first review, source-linked context, and conservative reminders.'
                  : 'Drop in a screenshot, paper doc, or pasted text. We extract the details, highlight uncertainty, and turn it into a task, reminder, event draft, or reference item.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: () {
                    setState(() => _onboardingSeen = true);
                    _showCaptureSheet();
                  },
                  child: Text(
                    _onboardingSeen
                        ? 'Capture another item'
                        : 'Try your first capture',
                  ),
                ),
                OutlinedButton(
                  onPressed: _showExampleFlow,
                  child: const Text('See example flow'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip('Reviewed', '$reviewedCount'),
                _metricChip('Quiet hours', _quietHours ? 'On' : 'Off'),
                _metricChip('Reminder mode', _reminderMode),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Chip(label: Text('$label: $value'));
  }

  Widget _buildSection(
    String title,
    String subtitle,
    List<LifeAdminItem> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Card(
            child: ListTile(
              title: Text('Nothing in $title'),
              subtitle: const Text('That is a good sign.'),
            ),
          )
        else
          ...items.map(_buildItemCard),
      ],
    );
  }

  Widget _buildItemCard(LifeAdminItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openItemDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _statusPill(item),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.summary),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(_actionLabel(item.actionType))),
                  Chip(label: Text(_inputLabel(item.inputType))),
                  if (item.primaryDate != null)
                    Chip(label: Text(_dateLabel(item.primaryDate!))),
                  if (item.reminderLabel != null)
                    Chip(label: Text(item.reminderLabel!)),
                  if (item.duplicateWarning)
                    const Chip(label: Text('Possible duplicate')),
                  if (item.needsManualReview)
                    const Chip(label: Text('Needs confirmation')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(LifeAdminItem item) {
    final color = switch (item.status) {
      ItemStatus.inbox => Colors.orange,
      ItemStatus.today => Colors.red,
      ItemStatus.upcoming => Colors.blue,
      ItemStatus.archived => Colors.grey,
      ItemStatus.completed => Colors.green,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(item.status),
        style: TextStyle(color: color.shade700, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildArchiveView(List<LifeAdminItem> archive) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = archive.where((item) {
      final haystack = '${item.title} ${item.summary} ${item.sourceText}'
          .toLowerCase();
      return query.isEmpty || haystack.contains(query);
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search saved references and completed items',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text('Archive & Search', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
          'Reopen the original source, verify what was extracted, or keep a low-confidence item as reference-only.',
        ),
        const SizedBox(height: 16),
        ...filtered.map(_buildItemCard),
      ],
    );
  }

  Widget _buildSettingsView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Trust & Privacy', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Card(
          child: Column(
            children: [
              ListTile(
                title: Text('Encryption in transit and at rest'),
                subtitle: Text('Required baseline for launch.'),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('Account export and delete'),
                subtitle: Text('Users can export or fully delete their data.'),
              ),
              Divider(height: 1),
              ListTile(
                title: Text('No training by default'),
                subtitle: Text(
                  'User content is not used to train models unless explicitly enabled later.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Reminder controls',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SwitchListTile(
          value: _quietHours,
          onChanged: (value) => setState(() => _quietHours = value),
          title: const Text('Quiet hours'),
          subtitle: const Text('Bundle reminders and avoid noise overnight.'),
        ),
        ListTile(
          title: const Text('Reminder mode'),
          subtitle: Text(_reminderMode),
          trailing: DropdownButton<String>(
            value: _reminderMode,
            items: const [
              DropdownMenuItem(value: 'Quiet', child: Text('Quiet')),
              DropdownMenuItem(value: 'Balanced', child: Text('Balanced')),
              DropdownMenuItem(value: 'Proactive', child: Text('Proactive')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _reminderMode = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showCaptureSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capture something important',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _capturePresetButton(
                    'Import screenshot',
                    Icons.photo_library_outlined,
                    CaptureInputType.screenshot,
                    _sampleScreenshotText(),
                  ),
                  _capturePresetButton(
                    'Scan paper doc',
                    Icons.document_scanner_outlined,
                    CaptureInputType.paperDoc,
                    _samplePaperDocText(),
                  ),
                  _capturePresetButton(
                    'Paste sample text',
                    Icons.content_paste_outlined,
                    CaptureInputType.pastedText,
                    _samplePastedText(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _captureController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Paste a bill, notice, message, or appointment details here.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  final text = _captureController.text.trim();
                  Navigator.of(context).pop();
                  if (text.isEmpty) {
                    _showMessage(
                      'Paste something first, or try a sample capture.',
                    );
                    return;
                  }
                  _reviewParsedCapture(text, CaptureInputType.pastedText);
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Review extraction'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _capturePresetButton(
    String label,
    IconData icon,
    CaptureInputType type,
    String payload,
  ) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.of(context).pop();
        _reviewParsedCapture(payload, type);
      },
      icon: Icon(icon),
      label: Text(label),
    );
  }

  Future<void> _reviewParsedCapture(
    String sourceText,
    CaptureInputType inputType,
  ) async {
    final result = _parseSource(sourceText, inputType);
    if (!mounted) return;

    if (result.parsingFailed) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('We could not confidently parse that'),
          content: const Text(
            'You can create a manual task instead, or save the source as reference-only.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _saveManualFallback(sourceText, inputType, asReference: true);
              },
              child: const Text('Save as reference'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _saveManualFallback(sourceText, inputType, asReference: false);
              },
              child: const Text('Quick-add task'),
            ),
          ],
        ),
      );
      return;
    }

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _ReviewSheet(result: result, sourceText: sourceText),
    );

    if (accepted == true) {
      _saveParsedItem(result, sourceText);
    }
  }

  void _saveManualFallback(
    String sourceText,
    CaptureInputType inputType, {
    required bool asReference,
  }) {
    final now = DateTime.now();
    final item = LifeAdminItem(
      id: 'item-${now.microsecondsSinceEpoch}',
      title: asReference ? 'Saved reference item' : 'Manual follow-up task',
      summary: asReference
          ? 'Stored for later review because extraction was uncertain.'
          : 'Created manually after parsing failed.',
      sourceTitle: 'Manual capture',
      sourceText: sourceText,
      inputType: inputType,
      itemType: ItemType.informational,
      actionType: asReference ? ActionType.referenceOnly : ActionType.task,
      status: asReference ? ItemStatus.archived : ItemStatus.inbox,
      actionLikelyRequired: !asReference,
      fields: [
        ExtractedField(
          label: 'Fallback',
          value: asReference ? 'Reference-only' : 'Manual quick-add',
          confidence: ConfidenceLevel.medium,
        ),
      ],
      history: [TimelineEntry(label: 'Created from fallback flow', at: now)],
    );
    setState(() => _items.insert(0, item));
    _showMessage(
      asReference ? 'Saved as reference-only.' : 'Manual task added to Inbox.',
    );
  }

  void _saveParsedItem(ParseResult result, String sourceText) {
    final now = DateTime.now();
    final item = LifeAdminItem(
      id: 'item-${now.microsecondsSinceEpoch}',
      title: result.title,
      summary: result.summary,
      sourceTitle: 'Captured source',
      sourceText: sourceText,
      inputType: result.inputType,
      itemType: result.itemType,
      actionType: result.actionType,
      status: _statusFromResult(result),
      actionLikelyRequired: result.actionLikelyRequired,
      fields: result.fields,
      primaryDate: result.primaryDate,
      amount: result.amount,
      location: result.location,
      reference: result.reference,
      reminderLabel: _defaultReminderLabel(result),
      duplicateWarning: result.duplicateWarning,
      needsManualReview: result.needsManualReview,
      sensitive: result.sensitive,
      history: [
        TimelineEntry(label: 'Captured and reviewed', at: now),
        TimelineEntry(
          label: 'Saved as ${_actionLabel(result.actionType)}',
          at: now,
        ),
      ],
    );

    setState(() {
      _items.insert(0, item);
      _captureController.clear();
      _onboardingSeen = true;
    });
    _showMessage('Saved to ${_statusLabel(item.status)}.');
  }

  ItemStatus _statusFromResult(ParseResult result) {
    if (result.actionType == ActionType.referenceOnly) {
      return ItemStatus.archived;
    }
    if (result.primaryDate == null) {
      return ItemStatus.inbox;
    }
    final now = DateTime.now();
    final difference = result.primaryDate!.difference(now).inHours;
    if (difference <= 24) {
      return ItemStatus.today;
    }
    return ItemStatus.upcoming;
  }

  String? _defaultReminderLabel(ParseResult result) {
    if (result.actionType == ActionType.referenceOnly ||
        result.primaryDate == null) {
      return null;
    }
    return result.primaryDate!.difference(DateTime.now()).inHours <= 36
        ? 'Primary reminder'
        : 'Early nudge + primary';
  }

  void _openItemDetail(LifeAdminItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
                  Text(item.summary),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text(_actionLabel(item.actionType))),
                      Chip(label: Text(_statusLabel(item.status))),
                      if (item.sensitive)
                        const Chip(label: Text('Sensitive handling')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Extracted fields',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...item.fields.map(
                    (field) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(field.label),
                      subtitle: Text(field.value),
                      trailing: Text(_confidenceLabel(field.confidence)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Source preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white,
                    ),
                    child: Text(item.sourceText),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reminder controls',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SwitchListTile(
                    value: item.isMuted,
                    onChanged: (value) {
                      setState(() => item.isMuted = value);
                      setSheetState(() {});
                    },
                    title: const Text('Mute this item'),
                    subtitle: Text(
                      item.isMuted
                          ? 'Reminders are muted.'
                          : 'Conservative reminders are enabled.',
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          setState(
                            () => item.reminderLabel = 'Snoozed until tomorrow',
                          );
                          setSheetState(() {});
                        },
                        child: const Text('Snooze'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(() => item.status = ItemStatus.completed);
                          item.history.add(
                            TimelineEntry(
                              label: 'Marked complete',
                              at: DateTime.now(),
                            ),
                          );
                          setSheetState(() {});
                        },
                        child: const Text('Complete'),
                      ),
                      OutlinedButton(
                        onPressed: () {
                          setState(
                            () => item.actionType = ActionType.referenceOnly,
                          );
                          item.status = ItemStatus.archived;
                          item.history.add(
                            TimelineEntry(
                              label: 'Moved to reference-only',
                              at: DateTime.now(),
                            ),
                          );
                          setSheetState(() {});
                        },
                        child: const Text('Reference-only'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Edit history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...item.history.reversed.map(
                    (event) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(event.label),
                      subtitle: Text(_timestampLabel(event.at)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => item.deleted = true);
                      Navigator.pop(context);
                      _showMessage(
                        'Item deleted. Source and derived actions removed from the list.',
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete item'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showExampleFlow() {
    _reviewParsedCapture(_sampleScreenshotText(), CaptureInputType.screenshot);
  }

  ParseResult _parseSource(String text, CaptureInputType inputType) {
    final lower = text.toLowerCase();
    if (text.trim().length < 12) {
      return ParseResult(
        title: 'Unknown item',
        summary: 'Not enough text to extract a trustworthy action.',
        itemType: ItemType.informational,
        actionType: ActionType.referenceOnly,
        actionLikelyRequired: false,
        fields: const [],
        inputType: inputType,
        parsingFailed: true,
      );
    }

    final date = _extractDate(text);
    final amount = RegExp(r'\$\s?\d+[\d,.]*').firstMatch(text)?.group(0);
    final reference = RegExp(
      r'(account|ref|reference|confirmation)[:#\s-]*([A-Z0-9-]{4,})',
      caseSensitive: false,
    ).firstMatch(text)?.group(2);
    final location = RegExp(
      r'(at|location)\s+([A-Z][A-Za-z0-9 .,-]+)',
    ).firstMatch(text)?.group(2);
    final sensitive = [
      'insurance',
      'tax',
      'medical',
      'legal',
      'government',
      'claim',
    ].any(lower.contains);
    final duplicateWarning = _items.any(
      (item) =>
          !item.deleted &&
          item.sourceText.toLowerCase().contains(
            lower.substring(0, min(lower.length, 24)),
          ),
    );

    if (lower.contains('appointment') ||
        lower.contains('scheduled') ||
        lower.contains('visit') ||
        lower.contains('dentist')) {
      return ParseResult(
        title: 'Confirm appointment details',
        summary:
            'Clear appointment detected. Review the date, time, and location before saving the event draft.',
        itemType: ItemType.appointment,
        actionType: ActionType.calendarDraft,
        actionLikelyRequired: true,
        inputType: inputType,
        primaryDate: date,
        location: location ?? 'Clinic front desk',
        reference: reference,
        needsManualReview: date == null,
        sensitive: sensitive,
        duplicateWarning: duplicateWarning,
        fields: [
          ExtractedField(
            label: 'Appointment date',
            value: date != null ? _dateLabel(date) : 'Missing',
            confidence: date != null
                ? ConfidenceLevel.high
                : ConfidenceLevel.low,
          ),
          ExtractedField(
            label: 'Location',
            value: location ?? 'Clinic front desk',
            confidence: ConfidenceLevel.medium,
          ),
          if (reference != null)
            ExtractedField(
              label: 'Confirmation',
              value: reference,
              confidence: ConfidenceLevel.medium,
            ),
        ],
      );
    }

    if (lower.contains('due') ||
        lower.contains('bill') ||
        lower.contains('payment')) {
      final needsReview = date == null || amount == null;
      return ParseResult(
        title: amount != null
            ? 'Pay bill for $amount'
            : 'Review bill and confirm payment details',
        summary:
            'Potential bill detected. High-consequence fields stay user-confirmed before save.',
        itemType: ItemType.bill,
        actionType: ActionType.task,
        actionLikelyRequired: true,
        inputType: inputType,
        primaryDate: date,
        amount: amount,
        reference: reference,
        needsManualReview: needsReview,
        sensitive: sensitive,
        duplicateWarning: duplicateWarning,
        fields: [
          ExtractedField(
            label: 'Due date',
            value: date != null ? _dateLabel(date) : 'Missing',
            confidence: date != null
                ? ConfidenceLevel.high
                : ConfidenceLevel.low,
          ),
          ExtractedField(
            label: 'Amount',
            value: amount ?? 'Missing',
            confidence: amount != null
                ? ConfidenceLevel.high
                : ConfidenceLevel.low,
          ),
          if (reference != null)
            ExtractedField(
              label: 'Reference',
              value: reference,
              confidence: ConfidenceLevel.medium,
            ),
        ],
      );
    }

    if (lower.contains('renew') ||
        lower.contains('form') ||
        lower.contains('deadline') ||
        lower.contains('submit')) {
      return ParseResult(
        title: 'Handle admin deadline',
        summary:
            'Deadline-style item detected. Save a reminder or task after confirming the date.',
        itemType: ItemType.deadlineNotice,
        actionType: ActionType.reminder,
        actionLikelyRequired: true,
        inputType: inputType,
        primaryDate: date,
        reference: reference,
        needsManualReview: date == null,
        sensitive: sensitive,
        duplicateWarning: duplicateWarning,
        fields: [
          ExtractedField(
            label: 'Deadline',
            value: date != null ? _dateLabel(date) : 'Choose a date',
            confidence: date != null
                ? ConfidenceLevel.medium
                : ConfidenceLevel.low,
          ),
          if (reference != null)
            ExtractedField(
              label: 'Reference',
              value: reference,
              confidence: ConfidenceLevel.medium,
            ),
        ],
      );
    }

    if (lower.contains('fyi') ||
        lower.contains('for your records') ||
        lower.contains('information only')) {
      return ParseResult(
        title: 'Save as reference',
        summary:
            'This looks informational, so the app suggests reference-only instead of inventing a weak task.',
        itemType: ItemType.informational,
        actionType: ActionType.referenceOnly,
        actionLikelyRequired: false,
        inputType: inputType,
        duplicateWarning: duplicateWarning,
        fields: [
          ExtractedField(
            label: 'Classification',
            value: 'Informational item',
            confidence: ConfidenceLevel.medium,
          ),
        ],
      );
    }

    return ParseResult(
      title: 'Review possible follow-up',
      summary:
          'The source might need action, but confidence is limited. Review before saving.',
      itemType: ItemType.messageFollowUp,
      actionType: date != null ? ActionType.reminder : ActionType.referenceOnly,
      actionLikelyRequired: date != null,
      inputType: inputType,
      primaryDate: date,
      duplicateWarning: duplicateWarning,
      needsManualReview: true,
      fields: [
        ExtractedField(
          label: 'Summary',
          value: 'Possible follow-up from message or notice',
          confidence: ConfidenceLevel.medium,
        ),
        ExtractedField(
          label: 'Suggested handling',
          value: date != null ? 'Reminder draft' : 'Reference-only fallback',
          confidence: ConfidenceLevel.medium,
        ),
      ],
    );
  }

  DateTime? _extractDate(String text) {
    final now = DateTime.now();
    final lower = text.toLowerCase();
    if (lower.contains('tomorrow')) return now.add(const Duration(days: 1));
    if (lower.contains('next week')) return now.add(const Duration(days: 7));

    final numericMatch = RegExp(
      r'(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?',
    ).firstMatch(text);
    if (numericMatch != null) {
      final month = int.parse(numericMatch.group(1)!);
      final day = int.parse(numericMatch.group(2)!);
      final yearGroup = numericMatch.group(3);
      final year = yearGroup == null
          ? now.year
          : (yearGroup.length == 2
                ? 2000 + int.parse(yearGroup)
                : int.parse(yearGroup));
      return DateTime(year, month, day, 9);
    }

    final months = <String, int>{
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
    final match = RegExp(
      r'(january|february|march|april|may|june|july|august|september|october|november|december)\s+(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      final month = months[match.group(1)!.toLowerCase()]!;
      final day = int.parse(match.group(2)!);
      return DateTime(now.year, month, day, 9);
    }
    return null;
  }

  String _actionLabel(ActionType type) => switch (type) {
    ActionType.task => 'Task',
    ActionType.reminder => 'Reminder',
    ActionType.calendarDraft => 'Calendar draft',
    ActionType.referenceOnly => 'Reference-only',
  };

  String _inputLabel(CaptureInputType type) => switch (type) {
    CaptureInputType.screenshot => 'Screenshot',
    CaptureInputType.paperDoc => 'Paper doc',
    CaptureInputType.pastedText => 'Pasted text',
  };

  String _statusLabel(ItemStatus status) => switch (status) {
    ItemStatus.inbox => 'Inbox',
    ItemStatus.today => 'Today',
    ItemStatus.upcoming => 'Upcoming',
    ItemStatus.completed => 'Completed',
    ItemStatus.archived => 'Archive',
  };

  String _confidenceLabel(ConfidenceLevel confidence) => switch (confidence) {
    ConfidenceLevel.high => 'High',
    ConfidenceLevel.medium => 'Medium',
    ConfidenceLevel.low => 'Low',
  };

  String _dateLabel(DateTime date) => '${date.month}/${date.day}/${date.year}';

  String _timestampLabel(DateTime date) =>
      '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({required this.result, required this.sourceText});

  final ParseResult result;
  final String sourceText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review before saving',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(result.summary),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                border: Border.all(color: Colors.black12),
              ),
              child: Text(sourceText),
            ),
            const SizedBox(height: 16),
            ...result.fields.map(
              (field) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(field.label),
                subtitle: Text(field.value),
                trailing: Text(
                  field.confidence.name.toUpperCase(),
                  style: TextStyle(
                    color: switch (field.confidence) {
                      ConfidenceLevel.high => Colors.green,
                      ConfidenceLevel.medium => Colors.orange,
                      ConfidenceLevel.low => Colors.red,
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (result.needsManualReview)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('Manual confirmation required'),
                subtitle: Text(
                  'Missing or conflicting fields should be reviewed before saving.',
                ),
              ),
            if (result.duplicateWarning)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.copy_all_outlined),
                title: Text('Possible duplicate'),
                subtitle: Text(
                  'The app found a similar source and will warn instead of auto-merging.',
                ),
              ),
            if (result.sensitive)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.privacy_tip_outlined),
                title: Text('Sensitive category'),
                subtitle: Text(
                  'Treat this conservatively and prefer review or reference-only when unsure.',
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Accept'),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

List<LifeAdminItem> _seedItems() {
  final now = DateTime.now();
  return [
    LifeAdminItem(
      id: 'seed-1',
      title: 'Pay electricity bill for \$84.20',
      summary:
          'Utility bill captured from a screenshot. Due date and amount were extracted with high confidence.',
      sourceTitle: 'City Power bill',
      sourceText:
          'City Power statement. Amount due \$84.20 by 04/24/2026. Account 5519.',
      inputType: CaptureInputType.screenshot,
      itemType: ItemType.bill,
      actionType: ActionType.task,
      status: ItemStatus.today,
      actionLikelyRequired: true,
      amount: '\$84.20',
      reference: '5519',
      primaryDate: now.add(const Duration(hours: 18)),
      reminderLabel: 'Primary reminder',
      fields: [
        ExtractedField(
          label: 'Due date',
          value: '4/24/2026',
          confidence: ConfidenceLevel.high,
        ),
        ExtractedField(
          label: 'Amount',
          value: '\$84.20',
          confidence: ConfidenceLevel.high,
        ),
      ],
      history: [
        TimelineEntry(
          label: 'Accepted from review',
          at: now.subtract(const Duration(hours: 2)),
        ),
      ],
    ),
    LifeAdminItem(
      id: 'seed-2',
      title: 'Confirm dentist appointment details',
      summary: 'Appointment draft waiting for final confirmation.',
      sourceTitle: 'Dental office text',
      sourceText:
          'Reminder: dentist appointment on April 28 at 2:30 PM at River Dental. Confirmation 8A2F.',
      inputType: CaptureInputType.pastedText,
      itemType: ItemType.appointment,
      actionType: ActionType.calendarDraft,
      status: ItemStatus.upcoming,
      actionLikelyRequired: true,
      primaryDate: now.add(const Duration(days: 4)),
      location: 'River Dental',
      reference: '8A2F',
      reminderLabel: 'Early nudge + primary',
      fields: [
        ExtractedField(
          label: 'Appointment date',
          value: '4/28/2026',
          confidence: ConfidenceLevel.high,
        ),
        ExtractedField(
          label: 'Location',
          value: 'River Dental',
          confidence: ConfidenceLevel.medium,
        ),
      ],
      history: [
        TimelineEntry(
          label: 'Drafted from captured text',
          at: now.subtract(const Duration(days: 1)),
        ),
      ],
    ),
    LifeAdminItem(
      id: 'seed-3',
      title: 'Insurance letter saved as reference',
      summary:
          'Informational update with no clear action. Kept in the archive for traceability.',
      sourceTitle: 'Insurance notice',
      sourceText:
          'For your records: policy update effective May 1. No action required.',
      inputType: CaptureInputType.paperDoc,
      itemType: ItemType.informational,
      actionType: ActionType.referenceOnly,
      status: ItemStatus.archived,
      actionLikelyRequired: false,
      sensitive: true,
      fields: [
        ExtractedField(
          label: 'Classification',
          value: 'Reference-only',
          confidence: ConfidenceLevel.medium,
        ),
      ],
      history: [
        TimelineEntry(
          label: 'Saved as reference-only',
          at: now.subtract(const Duration(days: 2)),
        ),
      ],
    ),
  ];
}

String _sampleScreenshotText() =>
    'Utility Bill\nAmount due: \$84.20\nDue 04/24/2026\nAccount #5519\nPay online or by mail.';
String _samplePaperDocText() =>
    'Renewal notice\nPlease submit the building form by May 12. Reference FORM-8821. Late submissions may lose coverage.';
String _samplePastedText() =>
    'Hi! This is a reminder that your dentist appointment is scheduled for April 28 at River Dental. Confirmation 8A2F.';
