import 'package:ai_life_admin/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pipeline marks duplicates and suppresses new action creation', () {
    final first = pipelineOutcomeToItem(
      runPipeline(
        sourceText: 'City Power statement from City Power. Amount due \$84.20 by 04/24/2026. Account 5519.',
        inputType: CaptureInputType.forwardedEmail,
        existingItems: const [],
      ),
      'one',
    );

    final duplicate = runPipeline(
      sourceText: 'City Power statement from City Power. Amount due \$84.20 by 04/24/2026. Account 5519.',
      inputType: CaptureInputType.upload,
      existingItems: [first],
    );

    expect(duplicate.processingState, ProcessingState.duplicate);
    expect(duplicate.suggestedAction, ActionType.archive);
  });

  test('pipeline returns spec-aligned stages and searchable fields', () {
    final outcome = runPipeline(
      sourceText: 'Dental booking confirmation from Bright Dental scheduled May 6. Reference BK-2201.',
      inputType: CaptureInputType.upload,
      existingItems: const [],
    );

    expect(outcome.category, ItemCategory.bookingAppointment);
    expect(outcome.pipelineStages.map((stage) => stage.code), containsAll(['received', 'normalize', 'extract', 'classify', 'fields', 'action', 'confidence', 'review']));
    expect(outcome.fields.any((field) => field.label == 'Provider / Sender'), isTrue);
    expect(outcome.fields.any((field) => field.label == 'Suggested next step'), isTrue);
  });

  testWidgets('review sheet keeps accept disabled until confirmations are checked', (tester) async {
    final outcome = runPipeline(
      sourceText: 'City Power statement from City Power. Amount due \$84.20 by 04/24/2026. Account 5519.',
      inputType: CaptureInputType.forwardedEmail,
      existingItems: const [],
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ReviewSheet(initial: outcome, sourceText: 'City Power statement from City Power. Amount due \$84.20 by 04/24/2026. Account 5519.'))));

    final acceptBefore = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Accept'));
    expect(acceptBefore.onPressed, isNull);

    await tester.ensureVisible(find.byType(CheckboxListTile).first);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.ensureVisible(find.byType(CheckboxListTile).last);
    await tester.tap(find.byType(CheckboxListTile).last);
    await tester.pump();

    final acceptAfter = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Accept'));
    expect(acceptAfter.onPressed, isNotNull);
  });
}
