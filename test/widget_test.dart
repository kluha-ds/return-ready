import 'package:ai_life_admin/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed data covers key lifecycle and fallback states', () {
    final items = seedItems();

    expect(items.any((item) => item.processingState == ProcessingState.needsReview), isTrue);
    expect(items.any((item) => item.processingState == ProcessingState.failed), isTrue);
    expect(items.any((item) => item.processingState == ProcessingState.duplicate), isTrue);
  });

  test('bill item exposes auditable date and amount fields', () {
    final bill = seedItems().firstWhere((item) => item.category == ItemCategory.billPayment);

    expect(bill.fields.any((field) => field.label == 'due date' && field.confidence == ConfidenceLevel.high), isTrue);
    expect(bill.fields.any((field) => field.label == 'amount' && field.source.contains('\$84.12')), isTrue);
  });

  test('generated sample produces review ready notice', () {
    final sample = generatedSample(IntakeChannel.upload, const []);

    expect(sample.processingState, ProcessingState.needsReview);
    expect(sample.category, ItemCategory.formNotice);
    expect(sample.suggestedNextStep, contains('task'));
  });
}
