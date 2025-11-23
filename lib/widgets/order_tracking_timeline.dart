// lib/widgets/order_tracking_timeline.dart
import 'package:flutter/material.dart';

/// Lifecycle yang kita pakai:
/// Requested → Order by Purchasing → Delivery → Arrive
/// (Refund = terminal cancel)
const kLifecycleOrdered = <String>[
  'Requested',
  'Order by Purchasing',
  'Delivery',
  'Arrive',
];

class OrderTrackingEvent {
  final String label;
  final DateTime? at;     // waktu terjadi (boleh null)
  final String? note;     // catatan opsional
  OrderTrackingEvent({required this.label, this.at, this.note});
}

/// Warna & ikon tiap status
Color lifecycleColor(String s) {
  switch (s.toLowerCase()) {
    case 'requested': return const Color(0xFF6366F1); // indigo
    case 'order by purchasing': return const Color(0xFF3B82F6); // blue
    case 'delivery': return const Color(0xFFF59E0B); // amber
    case 'arrive': return const Color(0xFF10B981); // green
    case 'refund': return const Color(0xFFEF4444); // red
    default: return const Color(0xFF6B7280); // neutral
  }
}

IconData lifecycleIcon(String s) {
  switch (s.toLowerCase()) {
    case 'requested': return Icons.assignment_outlined;
    case 'order by purchasing': return Icons.receipt_long_outlined;
    case 'delivery': return Icons.local_shipping_outlined;
    case 'arrive': return Icons.check_circle_outline;
    case 'refund': return Icons.reply_all_outlined;
    default: return Icons.radio_button_unchecked;
  }
}

/// Widget timeline ala marketplace.
/// - [currentStatus] = status aktif sekarang (dipakai hitung progress).
/// - [events] = daftar event (label harus salah satu lifecycle atau 'Refund').
///   kalau tanggal null, step dianggap belum terjadi.
class OrderTrackingTimeline extends StatelessWidget {
  final String currentStatus;
  final List<OrderTrackingEvent> events;
  final bool isRefund; // kalau true, tampilkan Refund sebagai terminal

  const OrderTrackingTimeline({
    super.key,
    required this.currentStatus,
    required this.events,
    this.isRefund = false,
  });

  int _statusIndex(String s) {
    final idx = kLifecycleOrdered.indexWhere(
      (e) => e.toLowerCase() == s.toLowerCase(),
    );
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final curIdx = _statusIndex(currentStatus);
    final steps = isRefund ? [...kLifecycleOrdered, 'Refund'] : kLifecycleOrdered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Order Tracking',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...List.generate(steps.length, (i) {
          final label = steps[i];
          final ev = events.firstWhere(
            (e) => e.label.toLowerCase() == label.toLowerCase(),
            orElse: () => OrderTrackingEvent(label: label),
          );
          final happened = ev.at != null;
          final active = i == curIdx && !isRefund;
          final done = happened || i < curIdx;
          final color = lifecycleColor(label);

          return _TimelineRow(
            label: label,
            subtitle: ev.at != null ? _fmt(ev.at!) : (active ? 'On progress' : 'Pending'),
            note: ev.note,
            color: color,
            icon: lifecycleIcon(label),
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            done: done,
            active: active,
          );
        }),
        const SizedBox(height: 8),
        if (isRefund)
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Order dibatalkan (Refund).',
                  style: TextStyle(color: Colors.red.shade400),
                ),
              ),
            ],
          ),
      ],
    );
  }

  String _fmt(DateTime d) {
    // Format singkat: yyyy-mm-dd HH:mm
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String? note;
  final Color color;
  final IconData icon;
  final bool isFirst;
  final bool isLast;
  final bool done;
  final bool active;

  const _TimelineRow({
    required this.label,
    required this.subtitle,
    required this.note,
    required this.color,
    required this.icon,
    required this.isFirst,
    required this.isLast,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = done ? color : Colors.grey.shade400;
    final lineColor = done ? color.withOpacity(.5) : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // timeline rail
        Column(
          children: [
            SizedBox(height: isFirst ? 10 : 0),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: dotColor.withOpacity(.12),
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 2),
              ),
              child: Icon(icon, size: 14, color: dotColor),
            ),
            if (!isLast)
              Container(width: 2, height: 36, color: lineColor),
          ],
        ),
        const SizedBox(width: 12),
        // content
        Expanded(
          child: Container(
            margin: EdgeInsets.only(top: isFirst ? 2 : 0, bottom: isLast ? 4 : 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(.06) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: active ? color.withOpacity(.25) : const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: active ? color : const Color(0xFF0F172A),
                    )),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
                if (note != null && note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(note!, style: const TextStyle(color: Color(0xFF374151))),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
