import 'package:ai_life_admin/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extractInboxItem uses canonical fields and review gating', () {
    final draft = extractInboxItem(
      text: 'Utility notice from City Power. Please review soon.',
      sourceRef: const SourceRef(
        kind: SourceKind.pdf,
        path: '/tmp/test.pdf',
        label: 'PDF upload',
      ),
      now: DateTime(2026, 5, 3),
    );

    expect(draft.title, isNotEmpty);
    expect(draft.reviewState, ReviewState.needsReview);
    expect(draft.actionType, InboxActionType.review);
    expect(draft.dateType, InboxDateType.deadline);
    expect(
      draft.confidenceFlags.map((flag) => flag.field),
      containsAll(['action_type', 'next_important_date']),
    );
  });

  test('applyReminderRules matches bill and appointment MVP schedules', () {
    final bill = extractInboxItem(
      text: 'Bill from City Power. Amount due \$84.20 by 05/10/2026.',
      sourceRef: const SourceRef(
        kind: SourceKind.pdf,
        path: '/tmp/bill.pdf',
        label: 'PDF upload',
      ),
      now: DateTime(2026, 5, 3),
    ).toInboxItem('bill');

    expect(bill.reviewState, ReviewState.ready);
    expect(bill.reminderSchedule.length, 2);
    expect(bill.reminderSchedule.first.when, DateTime(2026, 5, 7));
    expect(bill.reminderSchedule.last.when, DateTime(2026, 5, 11));

    final appointment = extractInboxItem(
      text: 'Dental appointment with Bright Dental on 05/06/2026.',
      sourceRef: const SourceRef(
        kind: SourceKind.image,
        path: '/tmp/appt.png',
        label: 'Image upload',
      ),
      now: DateTime(2026, 5, 3),
    ).toInboxItem('appointment');

    expect(appointment.reminderSchedule.length, 2);
    expect(appointment.reminderSchedule.first.when, DateTime(2026, 5, 5));
    expect(appointment.reminderSchedule.last.when, DateTime(2026, 5, 5, 22));
  });

  test(
    'filteredInboxItems supports required views, keyword search, and category/status filters',
    () {
      final items = seedInboxItems();
      final dueSoon = filteredInboxItems(
        items: items,
        view: InboxView.dueSoon,
        searchQuery: 'dental',
        categoryFilter: InboxCategory.appointments,
        statusFilter: InboxStatus.open,
        now: DateTime(2026, 5, 3),
      );

      expect(dueSoon, hasLength(1));
      expect(dueSoon.single.title.toLowerCase(), contains('appointment'));

      final overdue = filteredInboxItems(
        items: items,
        view: InboxView.overdue,
        searchQuery: '',
        now: DateTime(2026, 5, 3),
      );
      expect(overdue, hasLength(1));

      final done = filteredInboxItems(
        items: items,
        view: InboxView.done,
        searchQuery: '',
        now: DateTime(2026, 5, 3),
      );
      expect(done, hasLength(1));
    },
  );

  testWidgets(
    'review sheet keeps save enabled while unresolved fields remain flagged',
    (tester) async {
      final uncertainDraft = extractInboxItem(
        text: 'Unclear notice from provider. Please review this soon.',
        sourceRef: const SourceRef(
          kind: SourceKind.pdf,
          path: '/tmp/review.pdf',
          label: 'PDF upload',
        ),
        now: DateTime(2026, 5, 3),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ReviewItemSheet(initialDraft: uncertainDraft)),
        ),
      );

      expect(
        find.text('Action still needs confirmation before reminders activate.'),
        findsOneWidget,
      );
      expect(
        find.text('Date still needs confirmation before reminders activate.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Confirm action if uncertain'));
      await tester.tap(find.text('Confirm action if uncertain'));
      await tester.pump();
      await tester.ensureVisible(find.text('Confirm date if uncertain'));
      await tester.tap(find.text('Confirm date if uncertain'));
      await tester.pump();

      expect(
        find.text(
          'No reliable date yet. Reminders stay off until a date is added.',
        ),
        findsOneWidget,
      );
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save inbox item'),
      );
      expect(saveButton.onPressed, isNotNull);
    },
  );
}
