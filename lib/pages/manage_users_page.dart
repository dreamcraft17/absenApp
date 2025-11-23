import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'edit_user_page.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'create_manager_page.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});
  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> with RouteAware {
  final _search = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _all = [];
  String _selectedPosition = 'All';
  String _sortBy = 'Name';
  bool _sortAsc = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final id = (user['id'] ?? user['user_id'])?.toString();
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('User ID not found'),
            ],
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('Delete User'),
          ],
        ),
        content: Text('Are you sure you want to delete "${user['name'] ?? '-'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final res = await ApiService.deleteUser(id);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('User deleted successfully'),
            ],
          ),
          backgroundColor: Colors.green.shade500,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(res['error']?.toString() ?? 'Failed to delete user')),
            ],
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.listUsers(
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
        position: _selectedPosition == 'All' ? null : _selectedPosition,
        roleScope: '',
      );
      if (res['success'] == true) {
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        final rows = List<Map<String, dynamic>>.from(data['rows'] ?? []);
        setState(() => _all = rows);
      } else {
        setState(() => _all = []);
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
    } catch (e) {
      setState(() => _all = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _positions {
    final setPos = <String>{};
    for (final e in _all) {
      final p = (e['position'] ?? '').toString().trim();
      if (p.isNotEmpty) setPos.add(p);
    }
    final list = setPos.toList()..sort();
    return ['All', ...list];
  }

  List<Map<String, dynamic>> get _view {
    final q = _search.text.trim().toLowerCase();
    List<Map<String, dynamic>> list = _all.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final email = (e['email'] ?? '').toString().toLowerCase();
      final branch = (e['branch'] ?? '').toString().toLowerCase();
      final pos = (e['position'] ?? '').toString();
      final passFilter = _selectedPosition == 'All' || pos == _selectedPosition;
      final passQuery = q.isEmpty || name.contains(q) || email.contains(q) || branch.contains(q);
      return passFilter && passQuery;
    }).toList();

    int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

    list.sort((a, b) {
      int res;
      switch (_sortBy) {
        case 'Position':
          res = cmp((a['position'] ?? ''), (b['position'] ?? ''));
          break;
        case 'Branch':
          res = cmp((a['branch'] ?? ''), (b['branch'] ?? ''));
          break;
        case 'Name':
        default:
          res = cmp((a['name'] ?? ''), (b['name'] ?? ''));
      }
      return _sortAsc ? res : -res;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final me = auth.user;
    final role = (me?.role ?? '').toLowerCase().trim();

    final allowManagerAlso = true;
    final canView = role == 'admin' || role == 'superadmin' || (allowManagerAlso && role == 'manager');

    if (!canView) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Manage Users'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Unauthorized Access',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You don\'t have permission to view this page',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'User Directory',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          PopupMenuButton<String>(
            tooltip: 'Sort Options',
            onSelected: (v) => setState(() => _sortBy = v),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'Name',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 20),
                    const SizedBox(width: 12),
                    const Text('Sort by Name'),
                    if (_sortBy == 'Name') ...[
                      const Spacer(),
                      Icon(Icons.check, color: Colors.blue.shade600, size: 20),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Position',
                child: Row(
                  children: [
                    const Icon(Icons.work_outline, size: 20),
                    const SizedBox(width: 12),
                    const Text('Sort by Position'),
                    if (_sortBy == 'Position') ...[
                      const Spacer(),
                      Icon(Icons.check, color: Colors.black, size: 20),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Branch',
                child: Row(
                  children: [
                    const Icon(Icons.business_outlined, size: 20),
                    const SizedBox(width: 12),
                    const Text('Sort by Branch'),
                    if (_sortBy == 'Branch') ...[
                      const Spacer(),
                      Icon(Icons.check, color: Colors.blue.shade600, size: 20),
                    ],
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            tooltip: _sortAsc ? 'Ascending' : 'Descending',
            icon: Icon(_sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
            onPressed: () => setState(() => _sortAsc = !_sortAsc),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                      hintText: 'Search by name, email, or branch...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      suffixIcon: _search.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Filter Row
                Row(
                  children: [
                    Icon(Icons.filter_list, size: 20, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Position:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _positions.map((p) {
                            final isSelected = p == _selectedPosition;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(p),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedPosition = p),
                                backgroundColor: Colors.white,
                                selectedColor: Colors.black.withOpacity(0.1),
                                checkmarkColor: Colors.black,
                                side: BorderSide(
                                  color: isSelected ? Colors.black : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : Colors.grey.shade700,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Results Count
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text(
                  '${_view.length} ${_view.length == 1 ? 'user' : 'users'} found',
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

          // User List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _view.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                'No users found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting your search or filters',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.all(isTablet ? 20 : 16),
                          itemCount: _view.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _UserCard(
                            user: _view[i],
                            onEdit: () async {
                              final refresh = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditUserPage(user: _view[i]),
                                ),
                              );
                              if (refresh == true) _load();
                            },
                            onDelete: () => _confirmDeleteUser(_view[i]),
                          ),
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: (role == 'admin' || role == 'superadmin')
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateManagerPage()),
              ).then((_) => _load()),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add Manager'),
              backgroundColor: Colors.white,
              elevation: 2,
            )
          : null,
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'superadmin':
        return Colors.red;
      case 'manager':
        return Colors.orange;
      default:
        return Colors.black;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (user['name'] ?? '-').toString();
    final email = (user['email'] ?? '-').toString();
    final branch = (user['branch'] ?? '-').toString();
    final position = (user['position'] ?? '-').toString();
    final role = (user['role'] ?? '-').toString();
    
    final initials = name.isEmpty
        ? 'U'
        : name.trim().split(RegExp(r'\s+')).take(2).map((p) => p[0].toUpperCase()).join();

    final roleColor = _getRoleColor(role);
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
      child: Row(
        children: [
          // Avatar with role indicator
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: roleColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: roleColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: roleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Row(
                  children: [
                    Icon(Icons.email_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.business_outlined,
                      label: branch,
                      color: Colors.blue,
                    ),
                    _InfoChip(
                      icon: Icons.work_outline,
                      label: position,
                      color: Colors.green,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          if (isTablet) const SizedBox(width: 12),
          
          // Actions
          if (isTablet)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit user',
                  icon: Icon(Icons.edit_outlined, color: Colors.blue.shade600),
                  onPressed: onEdit,
                ),
                IconButton(
                  tooltip: 'Delete user',
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                  onPressed: onDelete,
                ),
                IconButton(
                  tooltip: 'View attendance',
                  icon: Icon(Icons.schedule_outlined, color: Colors.grey.shade600),
                  onPressed: () {},
                ),
              ],
            )
          else
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'attendance',
                  child: Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Attendance'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}