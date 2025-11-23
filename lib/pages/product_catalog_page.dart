import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

const Color kPrimary = Color(0xFF2563EB);
const Color kSuccess = Color(0xFF10B981);
const Color kWarning = Color(0xFFF59E0B);
const Color kDanger = Color(0xFFEF4444);
const Color kNeutral = Color(0xFF6B7280);

class ProductCatalogPage extends StatefulWidget {
  final int userId;
  final String posKey;
  final String role;
  final bool canAddProduct;
  final bool canRequest;

  const ProductCatalogPage({
    super.key,
    required this.userId,
    required this.posKey,
    required this.role,
    this.canAddProduct = false,
    this.canRequest = false,
  });

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

enum _SortKey { name, price }
enum _ViewMode { list, grid }

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  final TextEditingController _searchC = TextEditingController();

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _visible = [];
  final List<String> _categories = [];
  String? _selectedCategory;

  _SortKey _sortKey = _SortKey.name;
  bool _sortAsc = true;
  _ViewMode _viewMode = _ViewMode.list;

  @override
  void initState() {
    super.initState();
    _load();
    _searchC.addListener(() => setState(_applyFilter));
  }

  @override
  void didUpdateWidget(covariant ProductCatalogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.posKey != widget.posKey ||
        oldWidget.userId != widget.userId ||
        oldWidget.role != widget.role) {
      _searchC.clear();
      _selectedCategory = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ApiService.listProductsByBranch(
        userId: widget.userId,
        posKey: widget.posKey,
        page: 1,
        perPage: 500,
        include: 'category',
        search: _searchC.text.trim(),
      );

      if (resp['success'] != true) {
        throw Exception(resp['error'] ?? 'Failed to load products');
      }

      final root = resp['data'];
      final rawItems = (root is Map ? (root['items'] ?? root['products'] ?? root['rows']) : root) ?? [];
      final list = (rawItems as List)
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final mapped = list.map<Map<String, dynamic>>((m) {
        final name  = (m['name'] ?? m['product_name'] ?? '').toString();
        final sku   = (m['sku'] ?? m['code'] ?? m['product_sku'] ?? '').toString();
        final price = int.tryParse('${m['price_cents'] ?? m['price'] ?? 0}') ?? 0;

        String? categoryName;
        final cat = m['category'];
        if (cat is Map) {
          categoryName = (cat['name'] ?? '').toString().trim();
          if (categoryName.isEmpty) categoryName = null;
        }
        categoryName ??= (m['category_name'] ?? (m['category'] is String ? m['category'] : null))?.toString();

        return {
          'name': name,
          'sku': sku,
          'price_cents': price,
          'category_name': (categoryName ?? '').trim(),
          '_raw': m,
        };
      }).toList();

      _categories
        ..clear()
        ..addAll({
          for (final p in mapped)
            if ((p['category_name'] ?? '').toString().trim().isNotEmpty)
              (p['category_name'] as String)
        }.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));

      setState(() {
        _all = mapped;
        _applyFilter();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _onRefresh() async => _load();

  void _applyFilter() {
    final q = _searchC.text.trim().toLowerCase();
    List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(_all);

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      final target = _selectedCategory!.toLowerCase();
      list = list.where((p) {
        final cat = (p['category_name'] ?? '').toString().toLowerCase();
        return cat == target;
      }).toList();
    }

    if (q.isNotEmpty) {
      list = list.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final sku  = (p['sku'] ?? '').toString().toLowerCase();
        final cat  = (p['category_name'] ?? '').toString().toLowerCase();
        return name.contains(q) || sku.contains(q) || cat.contains(q);
      }).toList();
    }

    list.sort((a, b) {
      int cmp;
      switch (_sortKey) {
        case _SortKey.name:
          cmp = (a['name'] ?? '').toString().toLowerCase()
                .compareTo((b['name'] ?? '').toString().toLowerCase());
          break;
        case _SortKey.price:
          cmp = ((a['price_cents'] ?? 0) as int).compareTo((b['price_cents'] ?? 0) as int);
          break;
      }
      return _sortAsc ? cmp : -cmp;
    });

    _visible = list;
  }

  String _formatPrice(int cents) => 'Rp${_thousands(cents)}';
  String _thousands(num n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final r = s.length - i;
      buf.write(s[i]);
      if (r > 1 && r % 3 == 1) buf.write('.');
    }
    return buf.toString();
  }

  void _openAddProduct() {
  if (!widget.canAddProduct) return;

  final skuC = TextEditingController();
  final nameC = TextEditingController();
  final priceC = TextEditingController();
  final stockC = TextEditingController(text: '0');
  final categoryC = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      bool submitting = false;
      String? err;

      Future<void> submit() async {
        if (submitting) return;
        FocusScope.of(ctx).unfocus();
        submitting = true;
        (ctx as Element).markNeedsBuild();

        try {
          final sku = skuC.text.trim();
          final name = nameC.text.trim();
          final price = int.tryParse(priceC.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
          final stock = int.tryParse(stockC.text) ?? 0;
          final category = categoryC.text.trim().isEmpty ? null : categoryC.text.trim();

          if (sku.isEmpty || name.isEmpty) {
            err = 'SKU dan Nama wajib diisi';
          } else {
            final resp = await ApiService.addProductByBranch(
              userId: widget.userId,
              posKey: widget.posKey,
              sku: sku,
              name: name,
              priceCents: price,
              stock: stock,
              category: category,
            );
            if (resp['success'] == true) {
              Navigator.pop(ctx);
              // refresh list
              if (mounted) _load();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Product added')),
              );
            } else {
              err = (resp['error'] ?? 'Gagal menambah product').toString();
            }
          }
        } catch (e) {
          err = e.toString();
        } finally {
          submitting = false;
          (ctx as Element).markNeedsBuild();
        }
      }

      final bottom = MediaQuery.of(ctx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: skuC, decoration: const InputDecoration(labelText: 'SKU')),
            TextField(controller: nameC, decoration: const InputDecoration(labelText: 'Name')),
            TextField(
              controller: priceC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (cents)'),
            ),
            TextField(
              controller: stockC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stock (optional)'),
            ),
            TextField(controller: categoryC, decoration: const InputDecoration(labelText: 'Category (optional)')),
            if (err != null) ...[
              const SizedBox(height: 8),
              Text(err!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: submitting ? null : submit,
                child: submitting ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

  @override
  void dispose() { _searchC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: widget.canAddProduct
          ? FloatingActionButton.extended(
              onPressed: _openAddProduct,
              backgroundColor: kPrimary,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Product Inventory', 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                          const SizedBox(height: 2),
                          Text('${_visible.length} of ${_all.length} products', 
                            style: const TextStyle(fontSize: 13, color: kNeutral, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _viewMode = _viewMode == _ViewMode.list ? _ViewMode.grid : _ViewMode.list;
                      }),
                      tooltip: _viewMode == _ViewMode.list ? 'Grid view' : 'List view',
                      icon: Icon(_viewMode == _ViewMode.list ? Icons.grid_view_rounded : Icons.view_list_rounded),
                      style: IconButton.styleFrom(foregroundColor: kNeutral),
                    ),
                    IconButton(
                      onPressed: _load, 
                      tooltip: 'Refresh', 
                      icon: const Icon(Icons.refresh_rounded),
                      style: IconButton.styleFrom(foregroundColor: kNeutral),
                    ),
                    PopupMenuButton<_SortKey>(
                      tooltip: 'Sort',
                      icon: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: kNeutral),
                      onSelected: (k) => setState(() {
                        if (_sortKey == k) { _sortAsc = !_sortAsc; } else { _sortKey = k; _sortAsc = true; }
                        _applyFilter();
                      }),
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: _SortKey.name,
                          child: Row(children: [
                            Icon(Icons.sort_by_alpha, size: 20, color: _sortKey == _SortKey.name ? kPrimary : kNeutral),
                            const SizedBox(width: 12),
                            const Text('Sort by Name'),
                          ]),
                        ),
                        PopupMenuItem(
                          value: _SortKey.price,
                          child: Row(children: [
                            Icon(Icons.payments_outlined, size: 20, color: _sortKey == _SortKey.price ? kPrimary : kNeutral),
                            const SizedBox(width: 12),
                            const Text('Sort by Price'),
                          ]),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchC,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Search products, SKU, category...',
                      hintStyle: TextStyle(color: kNeutral.withOpacity(0.6)),
                      prefixIcon: const Icon(Icons.search_rounded, color: kNeutral, size: 22),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                if (_categories.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _CategoryChip(
                          label: 'All',
                          count: _all.length,
                          selected: _selectedCategory == null,
                          onTap: () => setState(() { _selectedCategory = null; _applyFilter(); }),
                        ),
                        const SizedBox(width: 8),
                        ..._categories.map((c) {
                          final count = _all.where((p) => p['category_name'] == c).length;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CategoryChip(
                              label: c,
                              count: count,
                              selected: _selectedCategory == c,
                              onTap: () => setState(() { _selectedCategory = c; _applyFilter(); }),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: _loading
                ? const _ListSkeleton()
                : (_error != null)
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _onRefresh,
                        color: kPrimary,
                        child: _visible.isEmpty
                            ? const _EmptyState()
                            : _viewMode == _ViewMode.list
                                ? ListView.separated(
                                    padding: const EdgeInsets.all(20),
                                    itemBuilder: (_, i) {
                                      final p = _visible[i];
                                      return _ProductCard(
                                        name: p['name'] ?? '-',
                                        sku: p['sku'] ?? '-',
                                        price: _formatPrice(p['price_cents'] ?? 0),
                                        category: (p['category_name'] ?? '').toString(),
                                      );
                                    },
                                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                                    itemCount: _visible.length,
                                  )
                                : GridView.builder(
                                    padding: const EdgeInsets.all(20),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.85,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                    itemBuilder: (_, i) {
                                      final p = _visible[i];
                                      return _ProductGridCard(
                                        name: p['name'] ?? '-',
                                        sku: p['sku'] ?? '-',
                                        price: _formatPrice(p['price_cents'] ?? 0),
                                        category: (p['category_name'] ?? '').toString(),
                                      );
                                    },
                                    itemCount: _visible.length,
                                  ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.count, required this.selected, required this.onTap});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? kPrimary : const Color(0xFFE2E8F0), width: 1.5),
          boxShadow: selected ? [
            BoxShadow(color: kPrimary.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? Colors.white.withOpacity(0.25) : const Color(0xFFF1F5F9),
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
        ]),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final String name;
  final String sku;
  final String price;
  final String category;
  const _ProductCard({required this.name, required this.sku, required this.price, required this.category});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary.withOpacity(0.1), kPrimary.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: kPrimary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          sku,
                          style: const TextStyle(fontSize: 11, color: kNeutral, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (category.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: kNeutral.withOpacity(0.7)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              price,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kSuccess),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductGridCard extends StatelessWidget {
  final String name;
  final String sku;
  final String price;
  final String category;
  const _ProductGridCard({required this.name, required this.sku, required this.price, required this.category});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 10, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimary.withOpacity(0.1), kPrimary.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: kPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A), height: 1.3),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                sku,
                style: const TextStyle(fontSize: 10, color: kNeutral, fontWeight: FontWeight.w600),
              ),
            ),
            if (category.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: kNeutral.withOpacity(0.7)),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kSuccess),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemBuilder: (_, i) => Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10))),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(height: 14, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(height: 12, width: 100, decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(4))),
              ],
            )),
          ]),
        ),
      ),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: 8,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
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
          child: const Icon(Icons.inventory_2_outlined, size: 40, color: kNeutral),
        ),
        const SizedBox(height: 16),
        const Center(child: Text('No products found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
        const SizedBox(height: 6),
        Center(child: Text('Try adjusting your search or filters', style: TextStyle(color: kNeutral.withOpacity(0.7)))),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message; 
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  
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
          child: const Icon(Icons.error_outline_rounded, size: 40, color: kDanger),
        ),
        const SizedBox(height: 16),
        const Center(child: Text('Something went wrong', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF475569)))),
        const SizedBox(height: 8),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: kNeutral.withOpacity(0.8))),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}