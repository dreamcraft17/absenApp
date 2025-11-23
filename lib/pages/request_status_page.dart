import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import '../services/auth_service.dart';
import '../services/api_service.dart';

const Color kPrimary = Color(0xFF2563EB);
const Color kSuccess = Color(0xFF10B981);
const Color kWarning = Color(0xFFF59E0B);
const Color kDanger = Color(0xFFEF4444);
const Color kNeutral = Color(0xFF6B7280);
const Color kPending = Color(0xFFF59E0B);
const Color kApproved = Color(0xFF3B82F6);
const Color kRejected = Color(0xFFEF4444);
const Color kDone = Color(0xFF10B981);

// Lifecycle yang disupport POS
const List<String> kLifecycle = <String>[
  'Requested',
  'Order by Purchasing',
  'Delivery',
  'Arrive',
  'Refund',
];

class RequestStatusPage extends StatefulWidget {
  const RequestStatusPage({super.key});

  @override
  State<RequestStatusPage> createState() => _RequestStatusPageState();
}

class _RequestStatusPageState extends State<RequestStatusPage> {
  late final int _userId;
  late final String _posKey;
  late final String _userRole;
  late final String _userPosition;

  final _scrollC = ScrollController();
  bool _loading = true;
  String? _error;

  String _selectedStatus = '';

  int _page = 1;
  final int _perPage = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  final List<Map<String, dynamic>> _items = [];

  static const String _endpoint = 'stock_request_api.php';

  // ===== POS ORIGIN AUTO-DETECT (prioritaskan POS, bukan baseUrl) =====
  String? _posOriginCached;

  String get posOrigin => _posOriginCached ?? '';

  /// Simpan origin POS dari response API + set ke cache global
  void _hydratePosOriginFromResp(Map<String, dynamic> resp) {
    // final fwd = (resp['forward_url'] ?? resp['pos_origin'] ?? resp['origin'] ?? '').toString();
    final fwd =
        (resp['forward_url'] ?? resp['pos_origin'] ?? resp['origin'] ?? '')
            .toString();
    final u = Uri.tryParse(fwd);
    if (u != null && u.hasScheme) {
      _posOriginCached = u.origin;
      ApiService.setPosOriginCache(
        _posKey,
        _posOriginCached!,
      ); // ⬅️ simpan global
    }
  }

  Future<void> _saveTrackingNumber(
    int requestId,
    int itemId,
    String tracking,
  ) async {
    final t = tracking.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor resi tidak boleh kosong')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resp = await _post({
        'action': 'update_tracking',
        'user_id': '$_userId',
        'pos_key': _posKey,
        'user_position': _userPosition,
        'request_id': '$requestId',
        'item_id': '$itemId',
        'tracking_number': t,
      });

      if (mounted) Navigator.pop(context);

      if (resp['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nomor resi tersimpan')));
        // refresh list & detail biar ke-update
        await _fetch(reset: true);
        Future.microtask(() => _fetchRequestDetail(context, requestId));
      } else {
        final err = (resp['error'] ?? 'Gagal menyimpan resi').toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // =========================
  // URL Helpers (POS-aware)
  // =========================
  // String buildImageUrl(String raw) {
  //   if (raw.isEmpty) return '';

  //   // absolut?
  //   final u = Uri.tryParse(raw);
  //   if (u != null && u.hasScheme) {
  //     // kalau localhost → ganti host ke POS origin bila ada
  //     if ((u.host == 'localhost' || u.host == '127.0.0.1') && posOrigin.isNotEmpty) {
  //       final o = Uri.tryParse(posOrigin);
  //       if (o != null && o.hasScheme) {
  //         return Uri(
  //           scheme: o.scheme,
  //           host: o.host,
  //           port: o.hasPort ? o.port : null,
  //           path: u.path,
  //           query: u.query,
  //           fragment: u.fragment,
  //         ).toString();
  //       }
  //     }
  //     return raw;
  //   }

  //   // relatif → HANYA resolve bila posOrigin ada
  //   if (posOrigin.isNotEmpty) {
  //     final clean = raw
  //         .replaceAll('\\', '/')
  //         .replaceFirst(RegExp(r'^(?:\./|/)+'), '')
  //         .replaceAll(RegExp(r'(?:^|/)pos-api/pos-api(?:/|$)'), 'pos-api/')
  //         .replaceFirst(RegExp(r'^public/'), '')
  //         .replaceFirst(RegExp(r'^pos-api/public/'), 'pos-api/');
  //     final withSlash = clean.startsWith('/') ? clean : '/$clean';

  //     if (withSlash.contains('stock-requests/proof-file')) {
  //       return Uri.parse(posOrigin).resolve('/pos-api$withSlash').toString();
  //     }
  //     return Uri.parse(posOrigin).resolve(withSlash).toString();
  //   }

  //   // ⛔ tanpa POS origin → biarin raw (supaya keliatan kalau backend kirim path yang salah)
  //   return raw;
  // }

  String buildImageUrl(String raw) {
    if (raw.isEmpty) return '';

    final u = Uri.tryParse(raw);
    if (u != null && u.hasScheme) {
      // kalau sudah absolut, tapi localhost → ganti ke posOrigin
      if ((u.host == 'localhost' || u.host == '127.0.0.1') &&
          posOrigin.isNotEmpty) {
        final o = Uri.tryParse(posOrigin);
        if (o != null && o.hasScheme) {
          return Uri(
            scheme: o.scheme,
            host: o.host,
            port: o.hasPort ? o.port : null,
            path: u.path,
            query: u.query,
            fragment: u.fragment,
          ).toString();
        }
      }
      return raw; // sudah full URL → return langsung
    }

    // ⬇️ Kalau bukan full URL dan mulai dari "pos-api/", tambahkan posOrigin di depan
    if (raw.startsWith('pos-api/') || raw.startsWith('/pos-api/')) {
      if (posOrigin.isNotEmpty) {
        final clean = raw.replaceFirst(
          RegExp(r'^/+'),
          '',
        ); // hapus slash depan kalau ada
        return '${posOrigin.endsWith('/') ? posOrigin.substring(0, posOrigin.length - 1) : posOrigin}/$clean';
      }
    }

    // fallback normal kalau path relatif lain
    if (posOrigin.isNotEmpty) {
      final clean = raw.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
      return '${posOrigin.endsWith('/') ? posOrigin.substring(0, posOrigin.length - 1) : posOrigin}/$clean';
    }

    // fallback terakhir
    return raw;
  }

  String _absolutizeToOrigin(String raw, String origin) {
    if (raw.isEmpty) return raw;

    final u = Uri.tryParse(raw);
    if (u != null && u.hasScheme) {
      if ((u.host == 'localhost' || u.host == '127.0.0.1') &&
          origin.isNotEmpty) {
        final o = Uri.tryParse(origin);
        if (o != null && o.hasScheme) {
          return Uri(
            scheme: o.scheme,
            host: o.host,
            port: o.hasPort ? o.port : null,
            path: u.path,
            query: u.query,
            fragment: u.fragment,
          ).toString();
        }
      }
      return raw;
    }

    if (origin.isNotEmpty) {
      final clean = raw.replaceFirst(RegExp(r'^/+'), '');
      return Uri.parse(origin).resolve('/$clean').toString();
    }

    return raw;
  }

  String absolutizeToBase(String raw) => buildImageUrl(raw);

  // =========================
  // Image widget (with fallback)
  // =========================
  Widget safeNetworkImage(
    String path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? radius,
  }) {
    final url = buildImageUrl(path);

    final img = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // shimmer/loading sederhana
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: radius ?? BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
      // fallback jika 404 / gagal — tampilkan URL + tombol copy
      errorBuilder: (context, error, stackTrace) {
        return LayoutBuilder(
          builder: (context, c) {
            final double maxH = (height ?? c.maxHeight).isFinite
                ? (height ?? c.maxHeight)
                : 100.0;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width ?? c.maxWidth,
                maxHeight: maxH,
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: radius ?? BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      color: kDanger,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Image not available',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: kDanger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: const Icon(Icons.copy, size: 14, color: kDanger),
                      tooltip: 'Copy URL',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('URL copied')),
                          );
                        }
                      },
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      icon: const Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: kDanger,
                      ),
                      tooltip: 'Show URL',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Image URL'),
                            content: SelectableText(
                              url,
                              style: const TextStyle(fontSize: 12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (radius != null) {
      return ClipRRect(borderRadius: radius, child: img);
    }
    return img;
  }

  Future<void> _showUploadResultModal({
    required bool success,
    required String title,
    String? subtitle,
    String? imageUrl,
    Map<String, dynamic>? details,
  }) async {
    if (!mounted) return;
    final color = success ? kSuccess : kDanger;
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    success
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: color,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: kNeutral),
                  ),
                ],
                if (imageUrl != null && imageUrl.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: safeNetworkImage(
                      imageUrl,
                      height: 160,
                      width: double.infinity,
                      radius: BorderRadius.circular(10),
                    ),
                  ),
                ],
                if (details != null && details.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: details.entries.map((e) {
                          final v = e.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${e.key}: ${v is List || v is Map ? jsonEncode(v) : v}',
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Oke'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.user!;
    _userId = int.tryParse(me.id.toString()) ?? 0;
    _posKey = (me.branch ?? '').trim(); // branch == pos_key
    _userRole = (me.role ?? '').trim().toLowerCase();
    _userPosition = (me.position ?? '').trim();

    _scrollC.addListener(_onScroll);

    // >>> Resolve POS origin langsung dari absensi_api.pos_instances
    Future.microtask(() async {
      final origin = await ApiService.resolvePosOriginDirect(
        posKey: _posKey,
        branch: _posKey,
      );

      if (mounted) {
        setState(() => _posOriginCached = origin ?? '');
      }

      _fetch(reset: true);
    });
  }

  @override
  void dispose() {
    _scrollC.dispose();
    super.dispose();
  }

  Future<void> _fetchRequestDetail(BuildContext context, int requestId) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final resp = await _post({
      'action': 'detail',
      'user_id': '$_userId',
      'pos_key': _posKey,
      'user_position': _userPosition,
      'request_id': '$requestId',
    });

    if (mounted) Navigator.pop(context);

    if (resp['success'] != true) {
      throw Exception((resp['error'] ?? 'Failed to load detail').toString());
    }

    _hydratePosOriginFromResp(resp);

    final data = resp['data'];
    List items = const [];
    if (data is Map) {
      if (data['items'] is List) {
        items = data['items'] as List;
      } else if (data['request'] is Map && (data['request']['items'] is List)) {
        items = data['request']['items'] as List;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stock Request Items',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Items in this request',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),

                // Items list
                Flexible(
                  child: SingleChildScrollView(
                    child: items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inventory_outlined,
                                    size: 64,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No items found',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: items.map((it) {
                              final itemId = int.tryParse((it['id'] ?? it['item_id'] ?? '').toString()) ?? 0;
                              final name = (it['name'] ?? it['product_name'] ?? '').toString();
                              final sku = (it['sku'] ?? it['product_sku'] ?? '').toString();
                              final qty = (it['request_qty'] ?? it['qty'] ?? it['quantity'] ?? '').toString();
                              final unit = (it['unit'] ?? '').toString();
                              final note = (it['note'] ?? it['notes'] ?? '').toString();

                              // --- BACA PROOF DARI DB ---
                              List<String> _extractProofImgs(dynamic v) {
                                if (v == null) return const [];
                                if (v is List) return v.map((e) => e.toString()).toList();

                                final s = v.toString().trim();
                                if (s.isEmpty) return const [];

                                if (s.startsWith('[') || s.startsWith('{') || s.startsWith('"')) {
                                  try {
                                    final j = jsonDecode(s);
                                    if (j is List) return j.map((e) => e.toString()).toList();
                                    if (j is String && j.isNotEmpty) return [j];
                                  } catch (_) {/* fallthrough */}
                                }

                                return [s];
                              }

                              final proofImgs = _extractProofImgs(
                                it['proof_images_json'] ?? it['proof_images'] ?? it['photo_url'],
                              ).map((s) => ApiService.absolutizeWithPosOrigin(s, posOrigin: posOrigin)).toList();

                              final photoUrl = proofImgs.isNotEmpty ? proofImgs.first : '';

                              final itemConditionRaw = (it['proof_status'] ?? it['item_condition'] ?? '').toString().toLowerCase();
                              final itemCondition = (itemConditionRaw == 'oke' || itemConditionRaw == 'ok')
                                  ? 'ok'
                                  : (itemConditionRaw == 'defect' ? 'defect' : '');

                              final defectNote = (it['defect_note'] ?? '').toString();

                              final data = resp['data'];
                              final lifecycleStr = (it['request_status'] ?? data['request_status'] ?? data['request']?['request_status'] ?? '')
                                  .toString()
                                  .toLowerCase();

                              final tracking = (it['tracking_number'] ?? it['tracking'] ?? '').toString();
                              final canEditTracking = lifecycleStr == 'order by purchasing' &&
                                  _userRole == 'staff' &&
                                  (_userPosition ?? '').toLowerCase() == 'purchasing';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Product name & SKU
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F4F6),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              Icons.shopping_bag_outlined,
                                              size: 20,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name.isEmpty ? (sku.isEmpty ? '-' : sku) : name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                    color: Color(0xFF111827),
                                                  ),
                                                ),
                                                if (sku.isNotEmpty && name.isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'SKU: $sku',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Quantity
                                      if (qty.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.tag, size: 16, color: Colors.blue.shade700),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Qty: ',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                              Text(
                                                [qty, if (unit.isNotEmpty) unit].join(' '),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      // Notes
                                      if (note.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.amber.shade200,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Icon(Icons.note_alt_outlined, size: 16, color: Colors.amber.shade800),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  note,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.amber.shade900,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],

                                      // --- Tracking (Nomor Resi) ---
                                      if (canEditTracking) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Nomor Resi (wajib)', style: TextStyle(fontWeight: FontWeight.w700)),
                                              const SizedBox(height: 8),
                                              GestureDetector(
                                                onTap: () async {
                                                  final c = TextEditingController(text: tracking);
                                                  await showDialog(
                                                    context: context,
                                                    builder: (_) => AlertDialog(
                                                      title: const Text('Isi / Ubah Nomor Resi'),
                                                      content: TextField(
                                                        controller: c,
                                                        decoration: const InputDecoration(
                                                          hintText: 'Mis. JNE: ABC123, SiCepat: XYZ987',
                                                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                                                        ),
                                                        autofocus: true,
                                                      ),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                                                        FilledButton(
                                                          onPressed: () async {
                                                            Navigator.pop(context);
                                                            await _saveTrackingNumber(requestId, itemId, c.text);
                                                          },
                                                          child: const Text('Simpan'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFE5E7EB)),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.local_shipping_outlined, size: 18),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          tracking.isEmpty ? 'Tap untuk isi nomor resi' : 'Resi: $tracking',
                                                          style: TextStyle(
                                                            color: tracking.isEmpty ? Colors.grey.shade600 : const Color(0xFF111827),
                                                            fontWeight: tracking.isEmpty ? FontWeight.w500 : FontWeight.w700,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      const Icon(Icons.edit_outlined, size: 18),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                'Semua item wajib memiliki nomor resi sebelum status maju ke "Delivery".',
                                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else if (tracking.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            const Icon(Icons.local_shipping_outlined, size: 18),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                'Resi: $tracking',
                                                style: const TextStyle(fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      // === Proof section (jika sudah upload foto) ===
                                      if (proofImgs.isNotEmpty) ...[
                                        const SizedBox(height: 12),

                                        // Galeri horizontal
                                        SizedBox(
                                          height: 100,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: proofImgs.length,
                                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                                            itemBuilder: (_, idx) {
                                              final p = proofImgs[idx];
                                              return GestureDetector(
                                                onTap: () {
                                                  // preview besar
                                                  showDialog(
                                                    context: context,
                                                    builder: (_) => Dialog(
                                                      insetPadding: const EdgeInsets.all(16),
                                                      child: InteractiveViewer(
                                                        child: safeNetworkImage(
                                                          p,
                                                          width: double.infinity,
                                                          height: 420,
                                                          fit: BoxFit.contain,
                                                          radius: BorderRadius.circular(0),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(10),
                                                  child: safeNetworkImage(
                                                    p,
                                                    width: 120,
                                                    height: 100,
                                                    fit: BoxFit.cover,
                                                    radius: BorderRadius.circular(10),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              itemCondition.toLowerCase() == 'ok'
                                                  ? Icons.check_circle_outline
                                                  : Icons.warning_amber_rounded,
                                              color: itemCondition.toLowerCase() == 'ok' ? kSuccess : kDanger,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                itemCondition.toLowerCase() == 'ok'
                                                    ? 'Barang Oke'
                                                    : (defectNote.isNotEmpty ? 'Barang Cacat: $defectNote' : 'Barang Cacat'),
                                                style: TextStyle(
                                                  color: itemCondition.toLowerCase() == 'ok' ? kSuccess : kDanger,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ]
                                      // Jika belum ada foto, tetap tampilkan tombol upload (syarat status & role)
                                      else if (lifecycleStr == 'arrive' && _userRole == 'staff') ...[
                                        const SizedBox(height: 16),
                                        FilledButton.icon(
                                          onPressed: () => _showUploadProofDialog(context, requestId, itemId),
                                          icon: const Icon(Icons.camera_alt_rounded),
                                          label: const Text('Upload Proof of Arrival'),
                                          style: FilledButton.styleFrom(backgroundColor: kSuccess),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } catch (e) {
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading details: $e')));
  }
}

  Future<void> _showUploadProofDialog(
    BuildContext context,
    int requestId,
    int itemId,
  ) async {
    final picker = ImagePicker();
    XFile? photo;
    String condition = 'ok';
    final noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (_, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload Proof of Arrival',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final img = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 70, // kompres biar < 4MB
                      maxWidth: 1600,
                    );
                    if (img != null) setState(() => photo = img);
                  },
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: photo == null
                        ? const Icon(
                            Icons.camera_alt_rounded,
                            size: 50,
                            color: Colors.grey,
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(photo!.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: condition,
                  items: const [
                    DropdownMenuItem(value: 'ok', child: Text('Barang Oke')),
                    DropdownMenuItem(
                      value: 'defect',
                      child: Text('Ada Cacat / Rusak'),
                    ),
                  ],
                  onChanged: (v) => setState(() => condition = v ?? 'ok'),
                  decoration: const InputDecoration(
                    labelText: 'Kondisi Barang',
                  ),
                ),
                if (condition == 'defect') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan kerusakan',
                      hintText: 'Contoh: Dus penyok di pojok kiri bawah',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (photo == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Harap ambil foto dulu'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context);
                      await _uploadProof(
                        requestId,
                        itemId,
                        photo!,
                        condition,
                        noteController.text,
                      );
                    },
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Submit Proof'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _uploadProof(
    int requestId,
    int itemId,
    XFile photo,
    String condition,
    String note,
  ) async {
    try {
      // progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final uri = Uri.parse('${ApiService.baseUrl}/stock_request_api.php');
      final req = http.MultipartRequest('POST', uri)
        ..fields['action'] = 'upload_item_proof'
        ..fields['user_id'] = '$_userId'
        ..fields['pos_key'] = _posKey
        ..fields['request_id'] = '$requestId'
        ..fields['item_id'] = '$itemId'
        ..fields['result_status'] = (condition == 'ok') ? 'oke' : 'defect'
        ..fields['defect_note'] = note
        ..files.add(
          await http.MultipartFile.fromPath(
            'photo', // ✅ field yang diterima POS
            photo.path,
            filename: path.basename(photo.path),
            contentType: MediaType('image', 'jpeg'),
          ),
        );

      final streamed = await req.send();
      final statusCode = streamed.statusCode;
      final body = await streamed.stream.bytesToString();

      // log respons
      debugPrint('🔹 Upload Proof Response: HTTP $statusCode');
      debugPrint('🔹 Response body: $body');

      if (mounted) Navigator.pop(context); // tutup progress dialog

      Map<String, dynamic> resp;
      try {
        resp = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        resp = {
          'success': false,
          'error': 'Invalid JSON',
          'raw': body,
          'status': statusCode,
        };
      }

      _hydratePosOriginFromResp(resp);

      final success = (resp['success'] == true);

      // kandidat url utama dari backend
      String? primaryUrl = (resp['primary_url'] ?? resp['photo_url'])
          ?.toString();
      if ((primaryUrl == null || primaryUrl.isEmpty) && resp['data'] is Map) {
        final data = resp['data'] as Map;
        if (data['photo_url'] != null &&
            data['photo_url'].toString().isNotEmpty) {
          primaryUrl = data['photo_url'].toString();
        } else if (data['saved_files'] is List &&
            (data['saved_files'] as List).isNotEmpty) {
          primaryUrl = (data['saved_files'] as List).first.toString();
        }
      }
      if ((primaryUrl == null || primaryUrl.isEmpty) &&
          resp['saved_files'] is List &&
          (resp['saved_files'] as List).isNotEmpty) {
        primaryUrl = (resp['saved_files'] as List).first.toString();
      }

      // ⬇️ SELALU absolutize ke POS origin (cache/state), bukan baseUrl
      final posOriginPrefer =
          _posOriginCached ??
          ApiService.getPosOriginCached(_posKey) ??
          (Uri.tryParse(ApiService.posOrigin ?? '')?.origin);

      if ((primaryUrl ?? '').isNotEmpty && (posOriginPrefer ?? '').isNotEmpty) {
        primaryUrl = ApiService.absolutizeWithPosOrigin(
          primaryUrl!,
          posOrigin: posOriginPrefer,
        );
      }

      final subtitle = success
          ? 'Foto berhasil di-upload dan disimpan.'
          : (resp['error'] ?? 'Upload gagal').toString();

      final details = <String, dynamic>{
        if (resp.containsKey('db')) 'db': resp['db'],
        'request_id': requestId,
        'item_id': itemId,
        'photo_url': primaryUrl,
        'status_code': statusCode,
        if (resp['update'] is Map && (resp['update'] as Map).isNotEmpty) ...{
          'affected': (resp['update'] as Map)['affected'],
          'sql_error': (resp['update'] as Map)['error'],
        },
        if (resp['readback_after'] is Map &&
            (resp['readback_after'] as Map)['photo_url'] != null)
          'db.photo_url': (resp['readback_after'] as Map)['photo_url'],
        if (resp['saved_files'] != null) 'saved_files': resp['saved_files'],
        if (resp['forward_url'] != null) 'forward_url': resp['forward_url'],
      };

      await _showUploadResultModal(
        success: success,
        title: success ? 'Upload Proof Berhasil' : 'Upload Proof Gagal',
        subtitle: subtitle,
        imageUrl: primaryUrl,
        details: details..removeWhere((k, v) => v == null),
      );

      if (success) {
        await _fetch(reset: true);
        Future.microtask(() => _fetchRequestDetail(context, requestId));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      debugPrint('❌ Upload proof exception: $e');
      await _showUploadResultModal(
        success: false,
        title: 'Upload Proof Error',
        subtitle: e.toString(),
      );
    }
  }

  Future<Map<String, dynamic>> _post(Map<String, String> body) async {
    final url = Uri.parse('${ApiService.baseUrl}/$_endpoint');
    final res = await http
        .post(url, body: body)
        .timeout(const Duration(seconds: 30));
    Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        'success': false,
        'error': 'Server error ${res.statusCode}',
        'raw': res.body,
      };
    }
    return json;
  }

  Future<void> _fetch({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _items.clear();
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final body = <String, String>{
        'action': 'list',
        'user_id': '$_userId',
        'pos_key': _posKey,
        'page': '$_page',
        'per_page': '$_perPage',
        'user_position': _userPosition,
      };
      if (_selectedStatus.isNotEmpty) {
        body['request_status'] = _selectedStatus;
        body['status'] = _selectedStatus;
      }

      final resp = await _post(body);

      if (resp['success'] != true) {
        throw Exception((resp['error'] ?? 'Gagal memuat data').toString());
      }
      _hydratePosOriginFromResp(resp);

      final data = resp['data'];
      List list;
      int? total;
      if (data is Map) {
        if (data['items'] is List) {
          list = data['items'] as List;
        } else if (data['requests'] is List) {
          list = data['requests'] as List;
        } else if (data['data'] is List) {
          list = data['data'] as List;
        } else {
          list = [];
        }
        total = (data['total'] is num) ? (data['total'] as num).toInt() : null;
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }

      final mapped = list
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      mapped.sort((a, b) {
        final sa = (a['request_status'] ?? '').toString().toLowerCase();
        final sb = (b['request_status'] ?? '').toString().toLowerCase();
        if (sa.contains('arrive') && !sb.contains('arrive')) return -1;
        if (!sa.contains('arrive') && sb.contains('arrive')) return 1;
        return 0;
      });

      setState(() {
        _items.addAll(mapped);
        _hasMore = mapped.length >= _perPage;
        if (!_hasMore && total != null) {
          _hasMore = _items.length < total;
        }
        if (reset) {
          _loading = false;
        } else {
          _isLoadingMore = false;
        }
        _page += 1;
      });
    } catch (e) {
      setState(() {
        if (reset) _loading = false;
        _isLoadingMore = false;
        _error = e.toString();
      });
    }
  }

  String _mapSimpleToLifecycle(String simple) {
    switch (simple.toLowerCase()) {
      case 'approved':
        return 'Order by Purchasing';
      case 'done':
        return 'Arrive';
      case 'rejected':
        return 'Refund';
      default:
        return 'Requested';
    }
  }

  Future<void> _updateStatus({
    required int id,
    required String newStatus,
  }) async {
    final isAdmin = _userRole == 'admin' || _userRole == 'superadmin';
    final isStaff = _userRole == 'staff';
    if (!isAdmin && !isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Admin/Staff can update status')),
      );
      return;
    }

    final lifecycle = kLifecycle.contains(newStatus)
        ? newStatus
        : _mapSimpleToLifecycle(newStatus);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resp = await _post({
        'action': 'update_status',
        'user_id': '$_userId',
        'pos_key': _posKey,
        'request_id': '$id',
        'request_status': lifecycle,
        'user_position': _userPosition,
      });

      if (mounted) Navigator.pop(context);

      if (resp['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Status updated → $lifecycle')));
        _fetch(reset: true);
      } else {
        final err = (resp['error'] ?? 'Failed to update').toString();
        final fwd = (resp['forward_url'] ?? '').toString();
        final detail = fwd.isNotEmpty ? '\nURL: $fwd' : '';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$err$detail')));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickAndUpdateStatus({
    required int id,
    required String current,
  }) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Change Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...kLifecycle.map(
                (s) => ListTile(
                  title: Text(
                    s,
                    style: TextStyle(
                      fontWeight: s == current
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: s == current ? kPrimary : const Color(0xFF0F172A),
                    ),
                  ),
                  trailing: s == current
                      ? const Icon(Icons.check_rounded, color: kPrimary)
                      : null,
                  onTap: () => Navigator.pop(context, s),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (chosen != null && chosen != current) {
      await _updateStatus(id: id, newStatus: chosen);
    }
  }

  // ---- Helpers untuk timeline ----
  DateTime? _parseDT(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  void _openTrackingSheet({
    required Map<String, dynamic> m,
    required String name,
    required String sku,
    required String status,
  }) {
    final st = status.toLowerCase();
    final isRefund =
        st.contains('refund') || st.contains('reject') || st.contains('cancel');

    final requestedAt = _parseDT(m['requested_at'] ?? m['created_at']);
    final orderedAt = _parseDT(m['ordered_at']);
    final deliveryAt = _parseDT(m['delivery_at'] ?? m['shipped_at']);
    final arrivedAt = _parseDT(m['arrived_at']);
    final refundedAt = _parseDT(m['refunded_at']);

    final events = <OrderTrackingEvent>[
      OrderTrackingEvent(
        label: 'Requested',
        at: requestedAt,
        note: 'Permintaan dibuat',
      ),
      OrderTrackingEvent(label: 'Order by Purchasing', at: orderedAt),
      OrderTrackingEvent(label: 'Delivery', at: deliveryAt),
      OrderTrackingEvent(label: 'Arrive', at: arrivedAt),
      if (isRefund)
        OrderTrackingEvent(
          label: 'Refund',
          at: refundedAt,
          note: 'Dibatalkan/Refund',
        ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name.isEmpty ? sku : name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: lifecycleColor(status).withOpacity(.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: lifecycleColor(status),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sku.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SKU: $sku',
                      style: const TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OrderTrackingTimeline(
                  currentStatus: status,
                  events: events,
                  isRefund: isRefund,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_scrollC.hasClients || _loading || _isLoadingMore || !_hasMore) return;
    final max = _scrollC.position.maxScrollExtent;
    final cur = _scrollC.position.pixels;
    if (cur > max - 240) {
      _fetch(reset: false);
    }
  }

  Future<void> _updateApproval({
    required int id,
    required String action,
  }) async {
    // hanya Manager/Admin
    if (!(_userRole == 'manager' ||
        _userRole == 'admin' ||
        _userRole == 'superadmin')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only Manager/Admin can approve/reject')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resp = await _post({
        'action': 'update_approval',
        'user_id': '$_userId',
        'pos_key': _posKey,
        'request_id': '$id',
        'decision': action, // 'approve' | 'reject'
        'user_position': _userPosition,
      });

      if (mounted) Navigator.pop(context);

      if (resp['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Approval ${action == "approve" ? "approved" : "rejected"}',
            ),
          ),
        );
        _fetch(reset: true);
      } else {
        final err = (resp['error'] ?? 'Failed to update approval').toString();
        final fwd = (resp['forward_url'] ?? '').toString();
        final detail = fwd.isNotEmpty ? '\nURL: $fwd' : '';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$err$detail')));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole == 'admin' || _userRole == 'superadmin';
    final isManager = _userRole == 'manager';
    final isStaff = _userRole == 'staff';

    // Update lifecycle boleh Admin/Staff (tetap)
    final canUpdateLifecycle = isAdmin || isStaff;

    // Approval khusus Manager/Admin
    final canApprove = isAdmin || isManager;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stock Requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              '${_items.length} requests',
              style: const TextStyle(
                fontSize: 13,
                color: kNeutral,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _fetch(reset: true),
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(foregroundColor: kNeutral),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // ALL
                  _FilterChip(
                    label: 'All',
                    count: _selectedStatus.isEmpty ? _items.length : null,
                    selected: _selectedStatus.isEmpty,
                    color: kNeutral,
                    onTap: () {
                      setState(() => _selectedStatus = '');
                      _fetch(reset: true);
                    },
                  ),
                  const SizedBox(width: 8),

                  // LIFECYCLE CHIPS
                  ...kLifecycleFilters.map((label) {
                    final Color color;
                    switch (label.toLowerCase()) {
                      case 'requested':
                        color = const Color(0xFF6366F1); // indigo
                        break;
                      case 'order by purchasing':
                        color = kApproved; // blue
                        break;
                      case 'delivery':
                        color = const Color(0xFFF59E0B); // amber
                        break;
                      case 'arrive':
                        color = kDone; // green
                        break;
                      case 'refund':
                        color = kDanger; // red
                        break;
                      default:
                        color = kNeutral;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: label,
                        selected:
                            _selectedStatus.toLowerCase() ==
                            label.toLowerCase(),
                        color: color,
                        onTap: () {
                          setState(() => _selectedStatus = label);
                          _fetch(reset: true);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorView(
                    message: _error!,
                    onRetry: () => _fetch(reset: true),
                  )
                : _items.isEmpty
                ? const _EmptyView()
                : RefreshIndicator(
                    onRefresh: () => _fetch(reset: true),
                    color: kPrimary,
                    child: ListView.separated(
                      controller: _scrollC,
                      padding: const EdgeInsets.all(20),
                      itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (_, i) {
                        if (i >= _items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final m = _items[i];
                        final id = _asInt(m['id']);
                        final sku = (m['sku'] ?? m['product_sku'] ?? '')
                            .toString();
                        final name = (m['name'] ?? m['product_name'] ?? '')
                            .toString();
                        final qty =
                            _asInt(
                              m['qty'] ?? m['quantity'] ?? m['request_qty'],
                            ) ??
                            0;
                        final note = (m['note'] ?? m['notes'] ?? '').toString();
                        final waStatus = (m['status'] ?? '').toString().trim();

                        final rawLifecycle =
                            (m['request_status'] ?? m['lifecycle'] ?? '')
                                .toString()
                                .trim();
                        final status = rawLifecycle.isNotEmpty
                            ? _normalizeLifecycle(rawLifecycle)
                            : 'Requested';

                        // ==== NEW: approval fields ====
                        final approvalRaw =
                            (m['approval_state'] ?? m['approval'] ?? '')
                                .toString()
                                .trim()
                                .toLowerCase();
                        final approvedBy = (m['approved_by'] ?? '')
                            .toString()
                            .trim();
                        final approvedAt = (m['approved_at'] ?? '')
                            .toString()
                            .trim();

                        return _RequestCard(
                          id: id,
                          name: name.isEmpty ? sku : name,
                          sku: sku,
                          qty: qty,
                          note: note,
                          status: status,
                          requestedBy: reqBySafe(m),
                          createdAt: (m['created_at'] ?? m['createdAt'] ?? '')
                              .toString(),
                          waStatus: waStatus,
                          canUpdate: canUpdateLifecycle,
                          canApprove:
                              (isAdmin || isManager) &&
                              approvalRaw != 'approved' &&
                              approvalRaw != 'rejected',
                          approvalState: approvalRaw.isEmpty
                              ? 'pending'
                              : approvalRaw,
                          approvedBy: approvedBy,
                          approvedAt: approvedAt,
                          onUpdateStatus: (newStatus) =>
                              _updateStatus(id: id!, newStatus: newStatus),
                          onTapDetail: id == null
                              ? null
                              : () => _fetchRequestDetail(context, id!),
                          onChangeStatus: () {
                            if (id != null) {
                              if (approvalRaw == 'rejected') {
                                showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (_) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white,
                                            Colors.red.shade50.withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: kRejected.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.block_rounded,
                                              color: kRejected,
                                              size: 48,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Text(
                                            'Request Rejected',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'This request was already rejected by ${_posKey.isEmpty ? "the branch" : _posKey} manager.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF6B7280),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'You cannot change its status anymore.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF9CA3AF),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: kRejected,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: const Text(
                                                'Got It',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }

                              if (approvalRaw == 'pending' ||
                                  approvalRaw == 'awaiting approval' ||
                                  approvalRaw.isEmpty) {
                                showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (_) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Colors.white,
                                            Colors.orange.shade50.withOpacity(
                                              0.3,
                                            ),
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: kWarning.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.watch_later_outlined,
                                              color: kWarning,
                                              size: 48,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          const Text(
                                            'Awaiting Approval',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'This request is still awaiting approval from ${_posKey.isEmpty ? "the branch" : _posKey} manager.',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF6B7280),
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'You can only update status after it is approved.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF9CA3AF),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: kWarning,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: const Text(
                                                'Understood',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }

                              _pickAndUpdateStatus(id: id, current: status);
                            }
                          },
                          onApprove: id == null
                              ? null
                              : () =>
                                    _updateApproval(id: id, action: 'approve'),
                          onReject: id == null
                              ? null
                              : () => _updateApproval(id: id, action: 'reject'),
                          onViewTracking: () {
                            _openTrackingSheet(
                              m: m,
                              name: name,
                              sku: sku,
                              status: status,
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String reqBySafe(Map<String, dynamic> m) =>
      (m['requested_by'] ?? m['requester'] ?? '').toString();

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.25)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : kNeutral,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final int? id;
  final String name;
  final String sku;
  final int qty;
  final String note;
  final String status;
  final String requestedBy;
  final String createdAt;
  final bool canUpdate;
  final bool canApprove;
  final Function(String) onUpdateStatus;
  final VoidCallback onChangeStatus;
  final VoidCallback onViewTracking;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final String? waStatus;
  final VoidCallback? onTapDetail;

  // NEW: approval info
  final String approvalState; // pending | approved | rejected
  final String approvedBy;
  final String approvedAt;

  const _RequestCard({
    required this.id,
    required this.name,
    required this.sku,
    required this.qty,
    required this.note,
    required this.status,
    required this.requestedBy,
    required this.createdAt,
    required this.canUpdate,
    required this.canApprove,
    required this.onUpdateStatus,
    required this.onChangeStatus,
    required this.onViewTracking,
    this.onApprove,
    this.onReject,
    this.waStatus,
    required this.approvalState,
    this.approvedBy = '',
    this.approvedAt = '',
    this.onTapDetail,
  });

  Color _lifecycleColor() {
    switch (status.toLowerCase()) {
      case 'requested':
        return kPending;
      case 'order by purchasing':
        return kApproved;
      case 'delivery':
        return const Color(0xFF06B6D4);
      case 'arrive':
        return kDone;
      case 'refund':
        return kDanger;
      default:
        return kNeutral;
    }
  }

  IconData _lifecycleIcon() {
    switch (status.toLowerCase()) {
      case 'requested':
        return Icons.pending_outlined;
      case 'order by purchasing':
        return Icons.shopping_bag_outlined;
      case 'delivery':
        return Icons.local_shipping_outlined;
      case 'arrive':
        return Icons.check_circle_outline;
      case 'refund':
        return Icons.receipt_long_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _approvalColor() {
    switch (approvalState.toLowerCase()) {
      case 'approved':
        return kSuccess;
      case 'rejected':
        return kRejected;
      default:
        return const Color(0xFF9CA3AF); // pending
    }
  }

  String _approvalText() {
    switch (approvalState.toLowerCase()) {
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      default:
        return 'AWAITING APPROVAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _lifecycleColor();
    final apColor = _approvalColor();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTapDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.15),
                          statusColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_lifecycleIcon(), color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        if (sku.isNotEmpty)
                          Text(
                            'SKU: $sku',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kNeutral,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // lifecycle chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // NEW: approval chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: apColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: apColor.withOpacity(0.25)),
                        ),
                        child: Text(
                          _approvalText(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: apColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        children: const [
                          Icon(
                            Icons.touch_app_rounded,
                            size: 14,
                            color: Color(0xFF9CA3AF),
                          ),
                          Text(
                            'Tap to view request details',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _InfoRow(
                      icon: Icons.shopping_cart_outlined,
                      label: 'Quantity',
                      value: '$qty',
                    ),
                    if (requestedBy.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Requested by',
                        value: requestedBy,
                      ),
                    ],
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.access_time_outlined,
                        label: 'Date',
                        value: createdAt,
                      ),
                    ],
                    if (note.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.note_outlined,
                        label: 'Note',
                        value: note,
                        maxLines: 3,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.verified_outlined,
                      label: 'Approval',
                      value: _approvalText().toLowerCase().replaceAll('_', ' '),
                    ),
                    if (approvedBy.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Approved by',
                        value: approvedBy,
                      ),
                    ],
                    if (approvedAt.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.event_available_outlined,
                        label: 'Approved at',
                        value: approvedAt,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Tracking',
                      icon: Icons.timeline_rounded,
                      color: const Color(0xFF6366F1),
                      onPressed: onViewTracking,
                    ),
                  ),
                  if (canUpdate) const SizedBox(width: 8),
                  if (canUpdate && id != null)
                    Expanded(
                      child: _ActionButton(
                        label: 'Change Status',
                        icon: Icons.swap_horiz_rounded,
                        color: kPrimary,
                        onPressed: onChangeStatus,
                      ),
                    ),
                ],
              ),
              if (canApprove && id != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Approve',
                        icon: Icons.check_circle,
                        color: kApproved,
                        onPressed: onApprove ?? () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Reject',
                        icon: Icons.cancel,
                        color: kRejected,
                        onPressed: onReject ?? () {},
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailModal(BuildContext context) {
    // (optional legacy) — tidak dipakai karena kita pakai _fetchRequestDetail
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: kNeutral),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: kNeutral.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            size: 40,
            color: kNeutral,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'No requests found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Try adjusting your filters',
            style: TextStyle(color: kNeutral.withOpacity(0.7)),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: kDanger.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: kDanger,
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: kNeutral.withOpacity(0.8)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/* =========================
   Timeline ala marketplace
   ========================= */

const kLifecycleOrdered = <String>[
  'Requested',
  'Order by Purchasing',
  'Delivery',
  'Arrive',
];

// Filter lifecycle
const List<String> kLifecycleFilters = <String>[
  'Requested',
  'Order by Purchasing',
  'Delivery',
  'Arrive',
  'Refund',
];

String _normalizeLifecycle(String s) {
  final t = s.trim().toLowerCase();
  if (t.contains('order')) return 'Order by Purchasing';
  if (t.contains('deliver') || t.contains('ship')) return 'Delivery';
  if (t.contains('arrive') || t.contains('done')) return 'Arrive';
  if (t.contains('refund') || t.contains('reject') || t.contains('cancel'))
    return 'Refund';
  return 'Requested';
}

class OrderTrackingEvent {
  final String label;
  final DateTime? at;
  final String? note;
  OrderTrackingEvent({required this.label, this.at, this.note});
}

Color lifecycleColor(String s) {
  switch (s.toLowerCase()) {
    case 'requested':
      return const Color(0xFF6366F1); // indigo
    case 'order by purchasing':
      return const Color(0xFF3B82F6); // blue
    case 'delivery':
      return const Color(0xFFF59E0B); // amber
    case 'arrive':
      return const Color(0xFF10B981); // green
    case 'refund':
      return const Color(0xFFEF4444); // red
    default:
      return const Color(0xFF6B7280); // neutral
  }
}

IconData lifecycleIcon(String s) {
  switch (s.toLowerCase()) {
    case 'requested':
      return Icons.assignment_outlined;
    case 'order by purchasing':
      return Icons.receipt_long_outlined;
    case 'delivery':
      return Icons.local_shipping_outlined;
    case 'arrive':
      return Icons.check_circle_outline;
    case 'refund':
      return Icons.reply_all_outlined;
    default:
      return Icons.radio_button_unchecked;
  }
}

class OrderTrackingTimeline extends StatelessWidget {
  final String currentStatus;
  final List<OrderTrackingEvent> events;
  final bool isRefund;

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
    final steps = isRefund
        ? [...kLifecycleOrdered, 'Refund']
        : kLifecycleOrdered;

    final baseIdx = kLifecycleOrdered.indexWhere(
      (e) => e.toLowerCase() == currentStatus.toLowerCase(),
    );
    final activeIdx = isRefund ? steps.length - 1 : (baseIdx < 0 ? 0 : baseIdx);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Order Tracking',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...List.generate(steps.length, (i) {
          final label = steps[i];
          final ev = events.firstWhere(
            (e) => e.label.toLowerCase() == label.toLowerCase(),
            orElse: () => OrderTrackingEvent(label: label),
          );

          final done = i < activeIdx || (i == activeIdx && ev.at != null);
          final active = i == activeIdx;
          final color = lifecycleColor(label);

          return _TimelineRow(
            label: label,
            subtitle: ev.at != null
                ? _fmt(ev.at!)
                : (active ? 'On progress' : 'Pending'),
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
              const Icon(
                Icons.info_outline,
                size: 16,
                color: Color(0xFFEF4444),
              ),
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
        // rail
        Column(
          children: [
            SizedBox(height: isFirst ? 10 : 0),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: dotColor.withOpacity(.12),
                shape: BoxShape.circle,
                border: Border.all(color: dotColor, width: 2),
              ),
              child: Icon(icon, size: 14, color: dotColor),
            ),
            if (!isLast) Container(width: 2, height: 36, color: lineColor),
          ],
        ),
        const SizedBox(width: 12),
        // content
        Expanded(
          child: Container(
            margin: EdgeInsets.only(
              top: isFirst ? 2 : 0,
              bottom: isLast ? 4 : 12,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active ? color.withOpacity(.06) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? color.withOpacity(.25)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: active ? color : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
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
