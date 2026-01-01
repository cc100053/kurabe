import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurabe/data/models/price_record_model.dart';
import 'package:kurabe/widgets/price_record_card.dart';

void main() {
  group('PriceRecordCard', () {
    testWidgets('displays product name', (tester) async {
      final record = PriceRecordModel(
        productName: 'テスト商品',
        price: 100,
        quantity: 1,
        shopName: 'テスト店舗',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceRecordCard(record: record),
          ),
        ),
      );

      expect(find.text('テスト商品'), findsOneWidget);
    });

    testWidgets('displays shop name', (tester) async {
      final record = PriceRecordModel(
        productName: 'りんご',
        price: 200,
        quantity: 1,
        shopName: 'スーパーマーケット',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceRecordCard(record: record),
          ),
        ),
      );

      expect(find.text('スーパーマーケット'), findsOneWidget);
    });

    testWidgets('displays formatted price', (tester) async {
      final record = PriceRecordModel(
        productName: 'みかん',
        price: 1234,
        quantity: 1,
        shopName: 'コンビニ',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceRecordCard(record: record),
          ),
        ),
      );

      expect(find.textContaining('1,234'), findsOneWidget);
    });

    testWidgets('shows cheapest badge when isCheapestOverride is true',
        (tester) async {
      final record = PriceRecordModel(
        productName: 'バナナ',
        price: 100,
        quantity: 1,
        shopName: '果物屋',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceRecordCard(
              record: record,
              isCheapestOverride: true,
            ),
          ),
        ),
      );

      expect(find.text('最安'), findsOneWidget);
    });

    testWidgets('does not show cheapest badge when isCheapestOverride is false',
        (tester) async {
      final record = PriceRecordModel(
        productName: 'ぶどう',
        price: 500,
        quantity: 1,
        shopName: 'フルーツ店',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceRecordCard(
              record: record,
              isCheapestOverride: false,
            ),
          ),
        ),
      );

      expect(find.text('最安'), findsNothing);
    });

    testWidgets('is tappable when onTap is provided', (tester) async {
      var tapped = false;
      final record = PriceRecordModel(
        productName: 'メロン',
        price: 3000,
        quantity: 1,
        shopName: '高級店',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PriceRecordCard(
              record: record,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(PriceRecordCard));
      await tester.pump();

      expect(tapped, isTrue);
    });
  });
}
