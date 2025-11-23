import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

const _brand = Colors.indigo;
const _neutral = Color(0xFF334155);

class ProductListPage extends StatefulWidget {
  final int userId;
  final String posKey;
  final String role;
  final bool canRequest;     // staff -> true
  final bool canAddProduct;  // staff -> true

  const ProductListPage({
    super.key,
    required this.userId,
    required this.posKey,
    required this.role,
    this.canRequest = false,
    this.canAddProduct = false,
  });

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final TextEditingController _searchC = TextEditingController();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _view = [];

  final Map<String, int> _requestCart = {};
  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _load();
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant ProductListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posKey != widget.posKey) {
      _searchC.clear();
      _load();
    }
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 250), () => _applyFilter());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ApiService.listProductsByBranch(
        userId: widget.userId,
        posKey: widget.posKey,
        page: 1,
        perPage: 300,
        include: 'category',
        search: _searchC.text.trim(),
      );

      if (resp['success'] != true) {
        throw Exception(resp['error'] ?? 'Failed to load products');
      }

      final items = (resp['data']?['items'] ?? resp['data'] ?? []) as List;
      final list = items
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final mapped = list.map<Map<String, dynamic>>((m) {
        final id    = '${m['id'] ?? m['product_id'] ?? m['sku'] ?? m['code'] ?? ''}';
        final name  = (m['name'] ?? m['product_name'] ?? '').toString();
        final sku   = (m['sku'] ?? m['code'] ?? m['product_sku'] ?? '').toString();
        final stock = int.tryParse('${m['stock'] ?? m['qty'] ?? m['quantity'] ?? 0}') ?? 0;
        final price = int.tryParse('${m['price_cents'] ?? m['price'] ?? 0}') ?? 0;

        String? categoryName;
        final cat = m['category'];
        if (cat is Map) {
          categoryName = '${cat['name'] ?? cat['category_name'] ?? ''}';
        } else if (m['category_name'] != null) {
          categoryName = '${m['category_name']}';
        }

        return {
          'id'   : id,
          'name' : name,
          'sku'  : sku,
          'stock': stock,
          'price': price,
          'category_name': categoryName ?? '',
          '_raw': m,
        };
      }).toList();

      _all = mapped..sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
      _applyFilter();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _searchC.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _view = List.of(_all));
      return;
    }
    setState(() {
      _view = _all.where((m) {
        final name = m['name']?.toString().toLowerCase() ?? '';
        final sku  = m['sku']?.toString().toLowerCase() ?? '';
        final cat  = m['category_name']?.toString().toLowerCase() ?? '';
        return name.contains(q) || sku.contains(q) || cat.contains(q);
      }).toList();
    });
  }

  void _addToCart(Map<String, dynamic> item) {
    final key = item['id']?.toString() ?? item['sku']?.toString() ?? '';
    if (key.isEmpty) return;
    setState(() {
      _requestCart.update(key, (v) => v + 1, ifAbsent: () => 1);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Ditambahkan: ${item['name']} (qty: ${_requestCart[key]})'),
      duration: const Duration(milliseconds: 800),
    ));
  }

  void _editQtyBottomSheet() {
    if (_requestCart.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final entries = _requestCart.entries.toList();
        return Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 12,
            bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: StatefulBuilder(builder: (ctx, setSt) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 12),
                const Text('Edit Qty Request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 12),
                ...entries.map((e) {
                  final prod = _all.firstWhere((m) => (m['id'] ?? m['sku']).toString() == e.key, orElse: () => {});
                  final name = prod['name'] ?? e.key;
                  return Row(
                    children: [
                      Expanded(child: Text('$name', maxLines: 1, overflow: TextOverflow.ellipsis)),
                      IconButton(
                        onPressed: () => setSt(() {
                          final cur = _requestCart[e.key] ?? 0;
                          if (cur > 1) _requestCart[e.key] = cur - 1;
                        }),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('${_requestCart[e.key] ?? 0}'),
                      IconButton(
                        onPressed: () => setSt(() {
                          final cur = _requestCart[e.key] ?? 0;
                          _requestCart[e.key] = cur + 1;
                        }),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      IconButton(
                        onPressed: () => setSt(() { _requestCart.remove(e.key); }),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Selesai'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          }),
        );
      },
    ).then((_) => setState(() {}));
  }

  Future<void> _sendRequest() async {
    if (!widget.canRequest) return;
    if (_requestCart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keranjang request kosong')));
      return;
    }

    final auth = Provider.of<AuthService>(context, listen: false);
    final requestedBy = auth.user?.name ?? 'Unknown';

    final items = _requestCart.entries.map((e) {
      final prod = _all.firstWhere((m) => (m['id'] ?? m['sku']).toString() == e.key, orElse: () => {});
      final idOrSku = (prod['id']?.toString().isNotEmpty ?? false) ? prod['id'] : prod['sku'];
      return {'product_key': idOrSku, 'qty': e.value};
    }).toList();

    final notes = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Catatan (opsional)'),
          content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'Tulis catatan')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Lewati')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Kirim')),
          ],
        );
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mengirim request...'), duration: Duration(milliseconds: 1200)));

    final res = await ApiService.sendStockRequestScoped(
      userId: widget.userId,
      posKey: widget.posKey,
      requestedBy: requestedBy,
      items: items,
      notes: notes,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      setState(() => _requestCart.clear());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request terkirim')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal kirim: ${res['error'] ?? 'Unknown error'}')));
    }
  }

  void _openAddProduct() {
    if (!widget.canAddProduct) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add Product (Cabang ini)', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text('Form add product sambungkan ke endpoint POS kamu.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRequest = widget.canRequest;
    final canAdd = widget.canAddProduct;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: const Text('Products', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      // floatingActionButton: canAdd
      //     ? FloatingActionButton.extended(
      //         onPressed: _openAddProduct,
      //         icon: const Icon(Icons.add),
      //         label: const Text('Add Product'),
      //       )
      //     : null,
      body: Column(
        children: [
          // search bar
          Container(
            color: _brand,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.black45),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchC,
                      decoration: const InputDecoration(hintText: 'Search name /Category', border: InputBorder.none),
                    ),
                  ),
                  if (_searchC.text.isNotEmpty)
                    IconButton(onPressed: () { _searchC.clear(); _applyFilter(); }, icon: const Icon(Icons.close)),
                ],
              ),
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : _view.isEmpty
                        ? _EmptyState(
                            title: 'Produk tidak ditemukan',
                            subtitle: 'Ubah kata kunci pencarian atau muat ulang.',
                            onRefresh: _load,
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                              itemCount: _view.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final m = _view[i];
                                return _ProductTile(
                                  data: m,
                                  onAdd: canRequest ? () => _addToCart(m) : null,
                                );
                              },
                            ),
                          ),
          ),

          if (canRequest)
            _RequestBar(
              totalItems: _requestCart.length,
              onEdit: _requestCart.isEmpty ? null : _editQtyBottomSheet,
              onSubmit: _requestCart.isEmpty ? null : _sendRequest,
            ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onAdd;
  const _ProductTile({required this.data, this.onAdd});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? '';
    final sku  = data['sku'] ?? '';
    final cat  = data['category_name'] ?? '';
    final stock = data['stock'] ?? 0;
    final price = data['price'] ?? 0;

    final color = stock <= 0 ? Colors.red : (stock < 5 ? Colors.orange : Colors.green);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(.12),
          child: Text((name.toString().isNotEmpty ? name.toString()[0] : '?').toUpperCase(), style: TextStyle(color: color)),
        ),
        title: Text('$name', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sku.toString().isNotEmpty)
              Text('SKU: $sku', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            if (cat.toString().isNotEmpty)
              Text('Kategori: $cat', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text('Stok: $stock', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
            if (price > 0)
              Text('Harga: ${_formatRupiah(price)}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
        trailing: onAdd == null
            ? null
            : IconButton(tooltip: 'Tambah ke Request', onPressed: onAdd, icon: const Icon(Icons.add_shopping_cart_rounded)),
      ),
    );
  }
}

class _RequestBar extends StatelessWidget {
  final int totalItems;
  final VoidCallback? onEdit;
  final VoidCallback? onSubmit;
  const _RequestBar({required this.totalItems, required this.onEdit, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final enabled = totalItems > 0;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.12), blurRadius: 12, offset: const Offset(0, -2))]),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            // Expanded(
            //   child: OutlinedButton.icon(
            //     onPressed: onEdit,
            //     icon: const Icon(Icons.edit_note_rounded, size: 20),
            //     label: Text('Edit (${totalItems})'),
            //     style: OutlinedButton.styleFrom(
            //       minimumSize: const Size.fromHeight(48),
            //       side: const BorderSide(color: Color(0x1F000000)),
            //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            //       backgroundColor: const Color(0xFFF8FAFC),
            //       foregroundColor: _neutral,
            //     ),
            //   ),
            // ),
            const SizedBox(width: 12),
            // Expanded(
            //   child: ElevatedButton.icon(
            //     onPressed: onSubmit,
            //     icon: const Icon(Icons.send_rounded, size: 20),
            //     label: const Text('Kirim Request'),
            //     style: ElevatedButton.styleFrom(
            //       minimumSize: const Size.fromHeight(48),
            //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            //       backgroundColor: enabled ? _brand : Colors.grey,
            //       foregroundColor: Colors.white,
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onRefresh;
  const _EmptyState({required this.title, required this.subtitle, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 18, color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
          ],
        ),
      ),
    );
  }
}

String _formatRupiah(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write('.');
  }
  return 'Rp${buf.toString()}';
}
