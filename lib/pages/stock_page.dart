import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'product_list_page.dart';
import 'request_stock_page.dart';
import 'request_status_page.dart';

class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  bool _loading = true;
  String? _error;

  late int _userId;
  late String _role;
  String? _posKey;
  List<Map<String, dynamic>> _branches = [];

  bool get _isAdmin => _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'superadmin';
  bool get _isStaff => _role.toLowerCase() == 'staff';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.user;
      if (user == null) throw Exception('Session expired');

      _userId = int.tryParse('${user.id}') ?? 0;
      _role = (user.role ?? '').trim();

      final res = await ApiService.listUserPosOptions(userId: _userId);
      if (res['success'] != true) throw Exception(res['error'] ?? 'Gagal ambil cabang');

      _branches = List<Map<String, dynamic>>.from(res['data']?['branches'] ?? const []);
      if (_branches.isEmpty) throw Exception('Tidak ada cabang yang diizinkan.');

      _posKey = _branches.first['pos_key']?.toString() ?? _branches.first['key']?.toString();
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openRequestStock() {
    // Ambil data produk dari ProductListPage atau fetch ulang
    // Untuk contoh, kita fetch ulang
    _fetchProductsForRequest();
  }

  Future<void> _fetchProductsForRequest() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resp = await ApiService.listProductsByBranch(
        userId: _userId,
        posKey: _posKey!,
        page: 1,
        perPage: 500,
        include: 'category',
      );

      if (!mounted) return;
      Navigator.pop(context); // close loading

      if (resp['success'] != true) {
        throw Exception(resp['error'] ?? 'Failed to load products');
      }

      final items = (resp['data']?['items'] ?? resp['data'] ?? []) as List;
      final products = items
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return {
              'name': (m['name'] ?? m['product_name'] ?? '').toString(),
              'stock': int.tryParse('${m['stock'] ?? m['qty'] ?? 0}') ?? 0,
              'request_qty': 0,
            };
          })
          .toList();

      if (!mounted) return;

      // Buka RequestStockPage
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (_) => RequestStockPage(
            items: products,
            minStock: 5, // threshold untuk "low stock"
          ),
        ),
      );

if (result != null && mounted) {
  final requestItems = (result['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  final notes = (result['notes'] as String?) ?? '';

  if (requestItems.isEmpty) return;

  // nama peminta dari user login (fallback Unknown User)
  final auth = Provider.of<AuthService>(context, listen: false);
  final requester = (auth.user?.name ?? '').trim().isEmpty ? 'Unknown User' : auth.user!.name!;

  // show loading
  showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

  try {
    final resp = await ApiService.sendStockRequestScoped(
      userId: _userId,
      posKey: _posKey!,
      requestedBy: requester,
      items: requestItems,
      notes: notes,
    );

    if (!mounted) return;
    Navigator.pop(context); // close loading

    if (resp['success'] == true) {
      final fwd = (resp['forward_url'] ?? '').toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request dikirim (${requestItems.length} item). ${fwd.isNotEmpty ? "→ $fwd" : ""}')),
      );
      // opsional: buka halaman status
      // _openRequestStatus();
    } else {
      final err = (resp['error'] ?? resp['message'] ?? 'Gagal mengirim').toString();
      final fwd = (resp['forward_url'] ?? '').toString();
      final detail = fwd.isNotEmpty ? '\nURL: $fwd' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim: $err$detail')),
      );
    }
  } catch (e) {
    if (!mounted) return;
    Navigator.pop(context); // close loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load products: $e')),
      );
    }
  }

  void _openRequestStatus() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RequestStatusPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)),
            ElevatedButton.icon(onPressed: _bootstrap, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
    }

    if (_posKey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: const Center(child: Text('Cabang tidak tersedia')),
      );
    }

    return Scaffold(
      body: ProductListPage(
        userId: _userId,
        posKey: _posKey!,
        role: _role,
        canRequest: _isStaff,
        canAddProduct: _isStaff,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openRequestStock,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: const Text('Request Stock'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openRequestStatus,
                  icon: const Icon(Icons.receipt_long_rounded, size: 20),
                  label: const Text('View Status'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}