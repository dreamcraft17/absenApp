import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/api_service.dart';

class AbsenceRequestsPage extends StatefulWidget {
  const AbsenceRequestsPage({super.key});
  @override
  State<AbsenceRequestsPage> createState() => _AbsenceRequestsPageState();
}

class _AbsenceRequestsPageState extends State<AbsenceRequestsPage>
    with WidgetsBindingObserver {
  String _statusFilter = 'pending';

  bool _loadingTeam = false;
  List<Map<String, dynamic>> _team = [];

  final DateFormat _dateFmt = DateFormat('EEE, dd MMM yyyy', 'en_US');
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTeam();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshKey.currentState?.show();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshKey.currentState?.show();
    }
  }

  Future<void> _loadTeam() async {
    setState(() => _loadingTeam = true);
    final res = await ApiService.listAbsenceRequests(scope: 'team', userId: '');
    if (res['success'] == true) {
      final rows = List<Map<String, dynamic>>.from(
          (res['data']?['rows'] ?? []) as List);
      const order = {'pending': 0, 'approved': 1, 'rejected': 2};
      rows.sort((a, b) {
        final sa = (a['status'] ?? '').toString().toLowerCase();
        final sb = (b['status'] ?? '').toString().toLowerCase();
        return (order[sa] ?? 3).compareTo(order[sb] ?? 3);
      });
      setState(() => _team = rows);
    } else {
      setState(() => _team = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(res['error']?.toString() ?? 'Failed to fetch')),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
    if (mounted) setState(() => _loadingTeam = false);
  }

  Future<void> _act(String requestId, String action) async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.user!;
    final role = (me.role).toLowerCase().trim();
    if (!(role == 'manager' || role == 'superadmin')) return;

    final res = await ApiService.updateAbsenceStatus(
      requestId: requestId,
      action: action,
      approverId: me.id,
      approverRole: role,
    );

    if (res['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(action == 'approve' ? 'Request approved' : 'Request rejected'),
            ],
          ),
          backgroundColor: action == 'approve' ? Colors.green.shade500 : Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _refreshKey.currentState?.show();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(res['error']?.toString() ?? 'Failed to update')),
            ],
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _applyStatusFilter(List<Map<String, dynamic>> list) {
    if (_statusFilter == 'all') return list;
    return list
        .where((e) => (e['status'] ?? '').toString().toLowerCase() == _statusFilter)
        .toList();
  }

  String _formatRange(String start, String end) {
    String fmt(String raw) {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return raw;
      return _dateFmt.format(parsed);
    }
    if (start.isEmpty && end.isEmpty) return '-';
    if (start == end || end.isEmpty) return fmt(start);
    if (start.isEmpty) return fmt(end);
    return '${fmt(start)} → ${fmt(end)}';
  }

  int _calculateDays(String start, String end) {
    final s = DateTime.tryParse(start);
    final e = DateTime.tryParse(end);
    if (s == null || e == null) return 1;
    return e.difference(s).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final me = auth.user;
    final role = (me?.role ?? '').toLowerCase().trim();
    final canReview = role == 'manager' || role == 'superadmin';

    final list = _applyStatusFilter(_team);
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    // Count by status
    final pendingCount = _team.where((e) => (e['status'] ?? '').toString().toLowerCase() == 'pending').length;
    final approvedCount = _team.where((e) => (e['status'] ?? '').toString().toLowerCase() == 'approved').length;
    final rejectedCount = _team.where((e) => (e['status'] ?? '').toString().toLowerCase() == 'rejected').length;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Absence Requests',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refreshKey.currentState?.show(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: canReview
          ? Column(
              children: [
                // Filter Section
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(isTablet ? 20 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list, size: 20, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Filter by status',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'All',
                              count: _team.length,
                              selected: _statusFilter == 'all',
                              color: Colors.grey,
                              onTap: () => setState(() => _statusFilter = 'all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Pending',
                              count: pendingCount,
                              selected: _statusFilter == 'pending',
                              color: Colors.black,
                              onTap: () => setState(() => _statusFilter = 'pending'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Approved',
                              count: approvedCount,
                              selected: _statusFilter == 'approved',
                              color: Colors.green,
                              onTap: () => setState(() => _statusFilter = 'approved'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'Rejected',
                              count: rejectedCount,
                              selected: _statusFilter == 'rejected',
                              color: Colors.red,
                              onTap: () => setState(() => _statusFilter = 'rejected'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 1),

                // Results Count
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(isTablet ? 20 : 16, 0, isTablet ? 20 : 16, 12),
                  child: Row(
                    children: [
                      Text(
                        '${list.length} ${list.length == 1 ? 'request' : 'requests'} found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // List
                Expanded(
                  child: RefreshIndicator(
                    key: _refreshKey,
                    onRefresh: _loadTeam,
                    child: _loadingTeam
                        ? const Center(child: CircularProgressIndicator())
                        : list.isEmpty
                            ? _EmptyState(statusFilter: _statusFilter)
                            : ListView.separated(
                                padding: EdgeInsets.all(isTablet ? 20 : 16),
                                itemCount: list.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final e = list[i];
                                  final rawStatus = (e['status'] ?? '').toString().toLowerCase();
                                  final type = (e['type'] ?? '').toString().toLowerCase();
                                  final start = (e['start_date'] ?? '').toString();
                                  final end = (e['end_date'] ?? '').toString();
                                  final name = (e['name'] ?? '').toString();
                                  final reason = (e['reason'] ?? '').toString();
                                  final days = _calculateDays(start, end);

                                  return _RequestCard(
                                    name: name,
                                    type: type,
                                    typeLabel: type == 'izin' ? 'Permission' : 'Leave',
                                    range: _formatRange(start, end),
                                    days: days,
                                    status: rawStatus,
                                    reason: reason,
                                    onApprove: rawStatus == 'pending'
                                        ? () => _act(e['id'], 'approve')
                                        : null,
                                    onReject: rawStatus == 'pending'
                                        ? () => _act(e['id'], 'reject')
                                        : null,
                                  );
                                },
                              ),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'Access Restricted',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Only managers and superadmins can review requests',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 14,
                color: selected ? Colors.black : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? color : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String name;
  final String type;
  final String typeLabel;
  final String range;
  final int days;
  final String status;
  final String reason;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _RequestCard({
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.range,
    required this.days,
    required this.status,
    required this.reason,
    this.onApprove,
    this.onReject,
  });

  Color _getStatusColor() {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon() {
    return type == 'izin' ? Icons.event_busy : Icons.beach_access_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: statusColor.withOpacity(0.15),
                child: Text(
                  name.isEmpty ? 'U' : name.split(' ').take(2).map((e) => e[0].toUpperCase()).join(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '-' : name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: type == 'izin' ? Colors.white : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: type == 'izin' ? Colors.black : Colors.black,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getTypeIcon(), size: 12, color: type == 'izin' ? Colors.black : Colors.black),
                              const SizedBox(width: 4),
                              Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: type == 'izin' ? Colors.black : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (type != 'izin')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$days ${days == 1 ? 'day' : 'days'}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status == 'approved' ? Icons.check_circle : status == 'rejected' ? Icons.cancel : Icons.pending,
                      size: 14,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Date Range
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    range,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String statusFilter;
  const _EmptyState({required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    String message = 'No requests found';
    if (statusFilter == 'pending') {
      message = 'No pending requests';
    } else if (statusFilter == 'approved') {
      message = 'No approved requests';
    } else if (statusFilter == 'rejected') {
      message = 'No rejected requests';
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                message,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pull down to refresh',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 400),
      ],
    );
  }
}