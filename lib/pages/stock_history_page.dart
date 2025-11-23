// // stock_history_page.dart
// import 'package:flutter/material.dart';
// import '../services/database_service.dart';

// class StockHistoryPage extends StatefulWidget {
//   const StockHistoryPage({super.key});

//   @override
//   State<StockHistoryPage> createState() => _StockHistoryPageState();
// }

// class _StockHistoryPageState extends State<StockHistoryPage> {
//   List<dynamic> _stockMoves = [];
//   bool _loading = true;
//   String _error = '';

//   @override
//   void initState() {
//     super.initState();
//     _loadStockHistory();
//   }

//   Future<void> _loadStockHistory() async {
//     setState(() {
//       _loading = true;
//       _error = '';
//     });

//     try {
//       final db = DatabaseService();
//       final result = await db.getStockMoves();
      
//       if (result['success'] == true) {
//         setState(() {
//           _stockMoves = result['data']['stock_moves'] ?? [];
//         });
//       } else {
//         setState(() {
//           _error = result['error'] ?? 'Failed to load stock history';
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _error = 'Error: $e';
//       });
//     } finally {
//       setState(() {
//         _loading = false;
//       });
//     }
//   }

//   String _formatDate(String dateString) {
//     try {
//       final date = DateTime.parse(dateString);
//       return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
//     } catch (e) {
//       return dateString;
//     }
//   }

//   Color _getDeltaColor(int delta) {
//     if (delta > 0) return Colors.green;
//     if (delta < 0) return Colors.red;
//     return Colors.grey;
//   }

//   IconData _getDeltaIcon(int delta) {
//     if (delta > 0) return Icons.arrow_upward;
//     if (delta < 0) return Icons.arrow_downward;
//     return Icons.remove;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Stock History'),
//         actions: [
//           IconButton(
//             onPressed: _loadStockHistory,
//             icon: const Icon(Icons.refresh),
//           ),
//         ],
//       ),
//       body: _loading
//           ? const Center(child: CircularProgressIndicator())
//           : _error.isNotEmpty
//               ? Center(child: Text(_error))
//               : _stockMoves.isEmpty
//                   ? const Center(child: Text('No stock history found'))
//                   : RefreshIndicator(
//                       onRefresh: _loadStockHistory,
//                       child: ListView.builder(
//                         padding: const EdgeInsets.all(16),
//                         itemCount: _stockMoves.length,
//                         itemBuilder: (context, index) {
//                           final move = _stockMoves[index];
//                           final delta = int.tryParse(move['delta']?.toString() ?? '0') ?? 0;
                          
//                           return Card(
//                             margin: const EdgeInsets.only(bottom: 8),
//                             child: ListTile(
//                               leading: Container(
//                                 width: 40,
//                                 height: 40,
//                                 decoration: BoxDecoration(
//                                   color: _getDeltaColor(delta).withOpacity(0.1),
//                                   shape: BoxShape.circle,
//                                 ),
//                                 child: Icon(
//                                   _getDeltaIcon(delta),
//                                   color: _getDeltaColor(delta),
//                                 ),
//                               ),
//                               title: Text(move['sku'] ?? 'Unknown'),
//                               subtitle: Text(move['reason'] ?? 'No reason provided'),
//                               trailing: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     delta > 0 ? '+$delta' : '$delta',
//                                     style: TextStyle(
//                                       color: _getDeltaColor(delta),
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 16,
//                                     ),
//                                   ),
//                                   Text(
//                                     _formatDate(move['created_at'] ?? ''),
//                                     style: const TextStyle(fontSize: 12, color: Colors.grey),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//     );
//   }
// }