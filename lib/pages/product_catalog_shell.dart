import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'product_catalog_page.dart';

class ProductCatalogShell extends StatefulWidget {
  const ProductCatalogShell({super.key});
  @override
  State<ProductCatalogShell> createState() => _ProductCatalogShellState();
}

class _ProductCatalogShellState extends State<ProductCatalogShell> {
  bool _loading = true;
  String? _error;

  // pakai late (bukan late final) agar aman refresh
  late int _userId;
  late String _role;
  String? _posKey;
  List<Map<String, dynamic>> _branches = [];

  bool get _isAdmin => _role.toLowerCase() == 'admin' || _role.toLowerCase() == 'superadmin';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final user = auth.user;
      if (user == null) throw Exception('Session expired. Please re-login.');
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Products')),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)),
            ElevatedButton.icon(onPressed: _bootstrap, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        actions: [
          if (_isAdmin)
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _posKey,
                onChanged: (v) => setState(() => _posKey = v),
                items: _branches.map((b) {
                  final key = b['pos_key']?.toString() ?? b['key']?.toString() ?? '';
                  final name = b['branch_name']?.toString() ?? b['label']?.toString() ?? b['name']?.toString() ?? key;
                  return DropdownMenuItem(value: key, child: Text(name, overflow: TextOverflow.ellipsis));
                }).toList(),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: (_posKey == null)
          ? const Center(child: Text('Cabang tidak tersedia'))
          : ProductCatalogPage(
              userId: _userId,
              posKey: _posKey!,
              role: _role,
              canAddProduct: _role.toLowerCase() == 'staff',
              canRequest: _role.toLowerCase() == 'staff',
            ),
    );
  }
}
