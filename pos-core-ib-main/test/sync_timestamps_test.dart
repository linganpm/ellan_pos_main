import 'package:pos_orders_offline/sync_timestamps.dart';
import 'package:test/test.dart';

void main() {
  test('naive device-local timestamps are exported as UTC', () {
    final local = DateTime(2026, 10, 18, 19, 15, 1);
    final out = normalizeSyncTimestamp(local.toIso8601String());
    expect(out.endsWith('Z'), isTrue);
    expect(DateTime.parse(out), local.toUtc());
  });

  test('zoned and date-only values are left unchanged', () {
    expect(
      normalizeSyncTimestamp('2026-10-18T13:45:01.000Z'),
      '2026-10-18T13:45:01.000Z',
    );
    expect(
      normalizeSyncTimestamp('2026-10-18T19:15:01+05:30'),
      '2026-10-18T19:15:01+05:30',
    );
    expect(normalizeSyncTimestamp('2026-10-18'), '2026-10-18');
    expect(normalizeSyncTimestamp('not a date'), 'not a date');
  });

  test('payload normalization is deep and only touches instant keys', () {
    final local = DateTime(2026, 10, 18, 8, 0).toIso8601String();
    final payload = {
      'data': [
        {
          'local_id': 'L1',
          'created_on': local,
          'due_date': '2026-10-20',
          'note': local,
          'payments': [
            {'created_on': local},
          ],
          'items': [
            {
              'kitchen_sent_at': local,
              'addons': [
                {'created_on': local},
              ],
            },
          ],
        },
      ],
    };
    final out = normalizeSyncPayloadTimestamps(payload) as Map;
    final order = (out['data'] as List).first as Map;
    final utc = DateTime.parse(local).toUtc().toIso8601String();
    expect(order['created_on'], utc);
    expect(order['due_date'], '2026-10-20');
    expect(order['note'], local);
    expect(((order['payments'] as List).first as Map)['created_on'], utc);
    final item = (order['items'] as List).first as Map;
    expect(item['kitchen_sent_at'], utc);
    expect(((item['addons'] as List).first as Map)['created_on'], utc);
    // Source payload is not mutated (it drives exported-row bookkeeping).
    expect((payload['data']!.first)['created_on'], local);
  });
}
