import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../presentation/providers/price_history_provider.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  final int productId;
  final String productName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = NumberFormat('#,###');
    final historyFuture =
        ref.read(priceHistoryProvider.notifier).historyForProduct(productId);
    return Scaffold(
      appBar: AppBar(title: Text(productName)),
      body: FutureBuilder(
        future: historyFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final history = snapshot.data!;
          if (history.isEmpty) {
            return const Center(child: Text('まだ履歴がありません'));
          }
          final minPrice =
              history.map((e) => e.finalPrice).reduce((a, b) => a < b ? a : b);
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final record = history[index];
              final isCheapest = record.finalPrice == minPrice;
              return ListTile(
                title: Text('${formatter.format(record.finalPrice.round())} 円'),
                subtitle: Text(
                    '${record.date.toLocal().toIso8601String().split('T').first} • 税率 ${(record.taxRate * 100).toStringAsFixed(0)}%'),
                trailing: Text(record.isTaxIncluded ? '税込' : '税抜'),
                tileColor: isCheapest
                    ? Colors.green.withAlpha((255 * 0.1).round())
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
