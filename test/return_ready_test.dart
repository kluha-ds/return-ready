import 'package:flutter_test/flutter_test.dart';
import 'package:return_ready/main.dart';

void main() {
  test('seed state contains launch-relevant sample orders', () {
    final state = AppState.seed();

    expect(state.orders, isNotEmpty);
    expect(
      state.orders.any((order) => order.status == OrderStatus.mightReturn),
      isTrue,
    );
    expect(
      state.orders.any((order) => order.status == OrderStatus.waitingForRefund),
      isTrue,
    );
    expect(
      state.orders.any(
        (order) => order.returnDeadlineConfidence == DeadlineConfidence.unknown,
      ),
      isTrue,
    );
  });

  test(
    'money at risk only counts Might Return and Waiting for Refund orders',
    () {
      final now = DateTime.now();
      final orders = [
        OrderRecord(
          id: '1',
          userId: 'u',
          merchantName: 'A',
          orderDate: now,
          totalAmount: 100,
          currency: '\$',
          source: OrderSource.manual,
          status: OrderStatus.mightReturn,
          returnDeadlineDate: now.add(const Duration(days: 2)),
          returnDeadlineConfidence: DeadlineConfidence.confirmed,
          createdAt: now,
          updatedAt: now,
        ),
        OrderRecord(
          id: '2',
          userId: 'u',
          merchantName: 'B',
          orderDate: now,
          totalAmount: 50,
          currency: '\$',
          source: OrderSource.manual,
          status: OrderStatus.waitingForRefund,
          returnDeadlineConfidence: DeadlineConfidence.unknown,
          expectedRefundAmount: 40,
          createdAt: now,
          updatedAt: now,
        ),
        OrderRecord(
          id: '3',
          userId: 'u',
          merchantName: 'C',
          orderDate: now,
          totalAmount: 999,
          currency: '\$',
          source: OrderSource.manual,
          status: OrderStatus.tracked,
          returnDeadlineDate: now.add(const Duration(days: 2)),
          returnDeadlineConfidence: DeadlineConfidence.confirmed,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      expect(moneyAtRisk(orders, now), 140);
    },
  );
}
