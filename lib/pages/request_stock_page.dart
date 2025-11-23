import 'package:flutter/material.dart';

// pakai warna yang sama dengan ProductListPage
const Color kAccent     = Color(0xFF0E7C66);

class RequestStockPage extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int minStock;
  const RequestStockPage({super.key, required this.items, required this.minStock});

  @override
  State<RequestStockPage> createState() => _RequestStockPageState();
}

class _RequestStockPageState extends State<RequestStockPage> {
  late List<Map<String, dynamic>> _items; // name, stock, request_qty, note?, _showNote?
  String _q = '';
  bool _onlyLow = false;
  final _notesC = TextEditingController(); // notes global

  @override
  void initState() {
    super.initState();
    _items = widget.items.map((e) => {...e}).toList();
  }

  @override
  void dispose() {
    _notesC.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _q.trim().toLowerCase();
    return _items.where((it) {
      final name = (it['name'] ?? '').toString().toLowerCase();
      final isLow = (it['stock'] ?? 0) < widget.minStock;
      final passLow = !_onlyLow || isLow;
      final passQ = q.isEmpty || name.contains(q);
      return passLow && passQ;
    }).toList();
  }

  void _submit() {
    final payload = _items
        .where((it) => ((it['request_qty'] ?? 0) as int) > 0)
        .map((it) => {
              'name': it['name'],
              'request_qty': it['request_qty'],
              if ((it['note'] ?? '').toString().trim().isNotEmpty) 'note': it['note'],
            })
        .toList();

    Navigator.of(context).pop({
      'items': payload,
      'notes': _notesC.text.trim(), // notes global
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      appBar: AppBar(title: const Text('Request Stock')),
      body: Column(
        children: [
          // --- search + only low ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      onChanged: (s) => setState(() => _q = s),
                      decoration: InputDecoration(
                        hintText: 'Search product…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colors.black12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilterChip(
                  selected: _onlyLow,
                  onSelected: (v) => setState(() => _onlyLow = v),
                  label: const Text('Only low stock'),
                ),
              ],
            ),
          ),

          // --- notes global ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: TextField(
              controller: _notesC,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Catatan tambahan untuk supplier…',
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.note_alt_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
              ),
            ),
          ),

          // --- list item + inline notes ---
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16 + 72),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final it = list[i];
                final name = it['name'] ?? '-';
                final stock = it['stock'] ?? 0;
                final qty = (it['request_qty'] ?? 0) as int;
                final isLow = stock < widget.minStock;
                final showNote = (it['_showNote'] ?? false) as bool;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                    boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: isLow ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5E9),
                            child: Icon(
                              isLow ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
                              color: isLow ? const Color(0xFFEF6C00) : const Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text('Stock: $stock', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: showNote ? 'Hide note' : 'Add note',
                            onPressed: () => setState(() => it['_showNote'] = !showNote),
                            icon: Icon(showNote ? Icons.expand_less_rounded : Icons.edit_note_rounded),
                          ),
                          IconButton(
                            onPressed: () => setState(() => it['request_qty'] = (qty > 0) ? qty - 1 : 0),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          SizedBox(
                            width: 52,
                            child: TextFormField(
                              key: ValueKey(qty),
                              initialValue: qty.toString(),
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              onChanged: (s) => setState(() {
                                final v = int.tryParse(s) ?? 0;
                                it['request_qty'] = v >= 0 ? v : 0;
                              }),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => it['request_qty'] = qty + 1),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      if (showNote) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: TextEditingController(text: (it['note'] ?? '').toString())
                            ..selection = TextSelection.fromPosition(
                              TextPosition(offset: (it['note'] ?? '').toString().length),
                            ),
                          onChanged: (s) => it['note'] = s,
                          maxLines: 2,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Catatan item (opsional): merek / ukuran / catatan lain…',
                            filled: true,
                            fillColor: const Color(0xFFFDFDFD),
                            prefixIcon: const Icon(Icons.sticky_note_2_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.black12),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),

      // tombol Kirim di bawah (fixed)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Builder(
            builder: (context) {
              final selectedCount = _items.where((e) => (e['request_qty'] ?? 0) > 0).length;
              final enabled = selectedCount > 0;

              return Row(
                children: [
                  Expanded(
                    child: Text('Choosen: $selectedCount item', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  ElevatedButton.icon(
                    onPressed: enabled ? _submit : null,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Kirim'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 44),
                      shape: const StadiumBorder(),
                      elevation: enabled ? 2 : 0,
                      backgroundColor: enabled ? kAccent : Colors.grey.shade300,
                      foregroundColor: enabled ? Colors.white : Colors.black54,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
