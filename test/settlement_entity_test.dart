import 'package:flutter_test/flutter_test.dart';
import 'package:leguejuste/features/settlements/domain/entities/settlement_entity.dart';

void main() {
  final now = DateTime(2026, 3, 1);

  SettlementEntity makeSettlement({
    String id = 's1',
    String groupId = 'g1',
    String fromUserId = 'alice',
    String toUserId = 'bob',
    double amount = 5000,
    String currency = 'XOF',
    DateTime? createdAt,
    DateTime? confirmedAt,
    SettlementStatus status = SettlementStatus.confirmed,
    String? note,
    PaymentMethod paymentMethod = PaymentMethod.manual,
  }) {
    return SettlementEntity(
      id: id,
      groupId: groupId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      amount: amount,
      currency: currency,
      createdAt: createdAt ?? now,
      confirmedAt: confirmedAt,
      status: status,
      note: note,
      paymentMethod: paymentMethod,
    );
  }

  group('PaymentMethod enum', () {
    test('has manual and wave values', () {
      expect(PaymentMethod.values, containsAll([PaymentMethod.manual, PaymentMethod.wave]));
      expect(PaymentMethod.values.length, 2);
    });

    test('name returns correct string', () {
      expect(PaymentMethod.manual.name, 'manual');
      expect(PaymentMethod.wave.name, 'wave');
    });
  });

  group('SettlementEntity construction', () {
    test('default paymentMethod is manual', () {
      final settlement = SettlementEntity(
        id: 's1',
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        createdAt: now,
        status: SettlementStatus.confirmed,
      );
      expect(settlement.paymentMethod, PaymentMethod.manual);
    });

    test('creates with wave paymentMethod', () {
      final settlement = makeSettlement(paymentMethod: PaymentMethod.wave);
      expect(settlement.paymentMethod, PaymentMethod.wave);
    });

    test('creates with manual paymentMethod explicitly', () {
      final settlement = makeSettlement(paymentMethod: PaymentMethod.manual);
      expect(settlement.paymentMethod, PaymentMethod.manual);
    });

    test('default currency is XOF', () {
      final settlement = SettlementEntity(
        id: 's1',
        groupId: 'g1',
        fromUserId: 'alice',
        toUserId: 'bob',
        amount: 5000,
        createdAt: now,
        status: SettlementStatus.confirmed,
      );
      expect(settlement.currency, 'XOF');
    });
  });

  group('SettlementEntity.isWavePayment', () {
    test('returns true for wave payment', () {
      final settlement = makeSettlement(paymentMethod: PaymentMethod.wave);
      expect(settlement.isWavePayment, true);
    });

    test('returns false for manual payment', () {
      final settlement = makeSettlement(paymentMethod: PaymentMethod.manual);
      expect(settlement.isWavePayment, false);
    });

    test('returns false for default payment', () {
      final settlement = makeSettlement();
      expect(settlement.isWavePayment, false);
    });
  });

  group('SettlementEntity.isConfirmed / isPending', () {
    test('isConfirmed for confirmed status', () {
      final settlement = makeSettlement(status: SettlementStatus.confirmed);
      expect(settlement.isConfirmed, true);
      expect(settlement.isPending, false);
    });

    test('isPending for pending status', () {
      final settlement = makeSettlement(status: SettlementStatus.pending);
      expect(settlement.isPending, true);
      expect(settlement.isConfirmed, false);
    });
  });

  group('SettlementEntity.copyWith', () {
    test('copies paymentMethod', () {
      final original = makeSettlement(paymentMethod: PaymentMethod.manual);
      final copied = original.copyWith(paymentMethod: PaymentMethod.wave);
      expect(copied.paymentMethod, PaymentMethod.wave);
      expect(original.paymentMethod, PaymentMethod.manual);
    });

    test('preserves paymentMethod when not specified', () {
      final original = makeSettlement(paymentMethod: PaymentMethod.wave);
      final copied = original.copyWith(amount: 10000);
      expect(copied.paymentMethod, PaymentMethod.wave);
      expect(copied.amount, 10000);
    });

    test('copies all fields correctly', () {
      final original = makeSettlement(
        note: 'original note',
        paymentMethod: PaymentMethod.wave,
      );
      final copied = original.copyWith(
        id: 's2',
        groupId: 'g2',
        fromUserId: 'charlie',
        toUserId: 'dave',
        amount: 10000,
        currency: 'EUR',
        createdAt: DateTime(2026, 6, 1),
        confirmedAt: DateTime(2026, 6, 2),
        status: SettlementStatus.pending,
        note: 'new note',
        paymentMethod: PaymentMethod.manual,
      );

      expect(copied.id, 's2');
      expect(copied.groupId, 'g2');
      expect(copied.fromUserId, 'charlie');
      expect(copied.toUserId, 'dave');
      expect(copied.amount, 10000);
      expect(copied.currency, 'EUR');
      expect(copied.createdAt, DateTime(2026, 6, 1));
      expect(copied.confirmedAt, DateTime(2026, 6, 2));
      expect(copied.status, SettlementStatus.pending);
      expect(copied.note, 'new note');
      expect(copied.paymentMethod, PaymentMethod.manual);
    });
  });

  group('SettlementEntity equality (Equatable)', () {
    test('two settlements with same props are equal', () {
      final a = makeSettlement(paymentMethod: PaymentMethod.wave);
      final b = makeSettlement(paymentMethod: PaymentMethod.wave);
      expect(a, equals(b));
    });

    test('different paymentMethod makes them unequal', () {
      final a = makeSettlement(paymentMethod: PaymentMethod.wave);
      final b = makeSettlement(paymentMethod: PaymentMethod.manual);
      expect(a, isNot(equals(b)));
    });

    test('different amount makes them unequal', () {
      final a = makeSettlement(amount: 5000);
      final b = makeSettlement(amount: 10000);
      expect(a, isNot(equals(b)));
    });

    test('paymentMethod is part of props', () {
      final settlement = makeSettlement(paymentMethod: PaymentMethod.wave);
      expect(settlement.props, contains(PaymentMethod.wave));
    });
  });
}
