import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/employee_model.dart';
import 'employee_detail_page.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  // ===== Role & Scope =====
  String _role = 'staff'; // admin | superadmin | manager | staff
  String _myBranch = '';
  bool get _isAdmin => _role == 'admin' || _role == 'superadmin';
  bool get _isManager => _role == 'manager';

  // ===== Data & Filters =====
  List<Employee> _employees = [];
  List<String> _branches = [];
  List<String> _departments = [];
  List<String> _positions = [];
  bool _loading = true;
  bool _importing = false;

  // current selections
  String _selectedBranch = ''; // admin/superadmin bisa pilih; manager dikunci
  String _selectedDepartment = '';
  String _selectedPosition = '';
  String _searchQuery = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // ambil role & branch user setelah context siap
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthService>(context, listen: false);
      final me = auth.user;
      _role = (me?.role ?? 'staff').toLowerCase().trim();
      _myBranch = (me?.branch ?? '').toString();

      // manager: kunci selectedBranch ke cabang miliknya
      if (!_isAdmin && _isManager && _myBranch.isNotEmpty) {
        _selectedBranch = _myBranch;
      }
      await _loadEmployees();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ===== Helpers: onChange dropdown =====
  void _onBranchChanged(String v) {
    // admin saja yang bisa ubah branch
    if (!_isAdmin) return;
    setState(() {
      _selectedBranch = (v == 'ALL') ? '' : v;
      // reset dependent
      _selectedDepartment = '';
      _selectedPosition = '';
    });
    _loadEmployees();
  }

  void _onDepartmentChanged(String v) {
    setState(() {
      _selectedDepartment = (v == 'ALL') ? '' : v;
      _selectedPosition = '';
    });
    _loadEmployees();
  }

  void _onPositionChanged(String v) {
    setState(() {
      _selectedPosition = (v == 'ALL') ? '' : v;
    });
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);

    // Manager (atau non admin/superadmin) dipaksa branch = myBranch
    final effectiveBranch = _isAdmin
        ? (_selectedBranch.isEmpty ? null : _selectedBranch)
        : (_myBranch.isEmpty ? null : _myBranch);

    final result = await ApiService.getEmployees(
      branch: effectiveBranch,
      department: _selectedDepartment.isEmpty ? null : _selectedDepartment,
      position: _selectedPosition.isEmpty ? null : _selectedPosition,
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result['success'] == true) {
        final data = result['data'];

        List listRaw;
        Map<String, dynamic> meta = {};
        if (data is Map && data['employees'] is List) {
          listRaw = data['employees'] as List;
          meta = Map<String, dynamic>.from(data['meta'] ?? {});
        } else if (data is Map && data['rows'] is List) {
          listRaw = data['rows'] as List;
          meta = Map<String, dynamic>.from(data['meta'] ?? {});
        } else if (data is List) {
          listRaw = data;
        } else {
          listRaw = const [];
        }

        _employees = listRaw
            .map(
              (e) => Employee.fromMap(
                e is Map<String, dynamic>
                    ? e
                    : Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();

        // meta → branches, departments, positions (sudah difilter di backend)
        var branchesMeta = List<String>.from(
          meta['branches'] ?? const <String>[],
        );
        final departmentsMeta = List<String>.from(
          meta['departments'] ?? const <String>[],
        );
        final positionsMeta = List<String>.from(
          meta['positions'] ?? const <String>[],
        );

        // untuk manager: branches dikunci ke myBranch
        if (!_isAdmin) {
          branchesMeta = _myBranch.isEmpty ? <String>[] : <String>[_myBranch];
        }
        _branches = branchesMeta;
        _departments = departmentsMeta;
        _positions = positionsMeta;

        // jaga konsistensi pilihan yang tidak lagi valid
        if (_isAdmin) {
          if (_selectedBranch.isNotEmpty &&
              !_branches.contains(_selectedBranch)) {
            _selectedBranch = '';
          }
        } else {
          // manager: pastikan branch terkunci ke _myBranch
          if (_selectedBranch != _myBranch) _selectedBranch = _myBranch;
        }

        if (_selectedDepartment.isNotEmpty &&
            !_departments.contains(_selectedDepartment)) {
          _selectedDepartment = '';
        }
        if (_selectedPosition.isNotEmpty &&
            !_positions.contains(_selectedPosition)) {
          _selectedPosition = '';
        }
      } else {
        _employees = [];
        _branches = [];
        _departments = [];
        _positions = [];
      }
    });
  }

  Future<void> _importExcel() async {
    if (!_isAdmin) return; // hanya admin/superadmin
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _importing = true);

        final file = result.files.single;
        final importResult = await ApiService.importEmployees(File(file.path!));

        if (!mounted) return;

        setState(() => _importing = false);
        if (importResult['success'] == true) {
          final data = Map<String, dynamic>.from(importResult['data'] ?? {});
          final message = importResult['message'] ?? 'Import completed';
          _showImportResult(data, message);
          _loadEmployees();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(importResult['error'] ?? 'Import failed'),
              backgroundColor: Colors.red.shade400,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _importing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _showImportResult(Map<String, dynamic> data, String message) {
    final errors = List<String>.from(data['errors'] ?? []);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Import Results'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 16),
              _buildResultRow(
                Icons.add_circle_outline,
                'Added',
                data['added'] ?? 0,
                Colors.green,
              ),
              _buildResultRow(
                Icons.update,
                'Updated',
                data['updated'] ?? 0,
                Colors.blue,
              ),
              _buildResultRow(
                Icons.skip_next,
                'Skipped',
                data['skipped'] ?? 0,
                Colors.orange,
              ),
              if (errors.isNotEmpty) ...[
                const Divider(height: 24),
                const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Errors:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...errors
                    .take(5)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text(
                          '• $e',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('OK', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(IconData icon, String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            '$value',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm({Employee? employee}) async {
    final refresh = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmployeeFormPage(employee: employee)),
    );
    if (refresh == true) _loadEmployees();
  }

  // ===== Dropdown Filters Row =====
  Widget _buildDropdownFilters() {
  final isTablet = MediaQuery.of(context).size.width > 600;

  final branchItems = _isAdmin
      ? <String>['ALL', ..._branches]
      : <String>[_myBranch.isEmpty ? 'N/A' : _myBranch];

  final departmentItems = <String>['ALL', ..._departments];
  final positionItems   = <String>['ALL', ..._positions];

  final branchValue     = _isAdmin
      ? (_selectedBranch.isEmpty ? 'ALL' : _selectedBranch)
      : (_myBranch.isEmpty ? 'N/A' : _myBranch);
  final departmentValue = _selectedDepartment.isEmpty ? 'ALL' : _selectedDepartment;
  final positionValue   = _selectedPosition.isEmpty  ? 'ALL' : _selectedPosition;

  final row = Row(
    children: [
      Expanded(
        child: _niceDropdown(
          caption: 'Branch',
          value: branchValue,
          items: branchItems,
          onChanged: (v) => _onBranchChanged(v),
          enabled: _isAdmin,
          icon: Icons.business_outlined,
          showClear: _isAdmin,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _niceDropdown(
          caption: 'Department (Bar/kitchen)',
          value: departmentValue,
          items: departmentItems,
          onChanged: (v) => _onDepartmentChanged(v),
          icon: Icons.local_dining_outlined,
          showClear: true,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _niceDropdown(
          caption: 'Position',
          value: positionValue,
          items: positionItems,
          onChanged: (v) => _onPositionChanged(v),
          icon: Icons.work_outline,
          showClear: true,
        ),
      ),
    ],
  );

  return Container(
    padding: EdgeInsets.symmetric(horizontal: isTablet ? 12 : 8, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 0),
        child: SizedBox(
          width: isTablet ? null : 900,
          child: row,
        ),
      ),
    ),
  );
}


  InputDecoration _ddDecoration(
  String label, {
  IconData? icon,
  Widget? suffix,
}) =>
    InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: Colors.blueGrey.shade600),
      suffixIcon: suffix,
      // jangan terlalu dense agar label/value tidak kepotong
      isDense: false,
      contentPadding: const EdgeInsets.fromLTRB(14, 20, 12, 16),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
    );

  Widget _niceDropdown({
  required String caption,          // <— ganti dari label → caption
  required String value,
  required List<String> items,
  required ValueChanged<String> onChanged,
  bool enabled = true,
  IconData? icon,
  bool showClear = false,
}) {
  final isAll = value == 'ALL';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          caption,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: .2,
          ),
        ),
      ),
      DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          menuMaxHeight: 320,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          decoration: InputDecoration(
            // TANPA labelText → tidak ada floating label yg bisa kepotong
            prefixIcon: icon == null
                ? null
                : Icon(icon, size: 18, color: Colors.blueGrey.shade600),
            suffixIcon: showClear && !isAll
                ? IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: enabled ? () => onChanged('ALL') : null,
                  )
                : null,
            isDense: false,
            contentPadding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
            ),
          ),
          items: items
              .map((e) => DropdownMenuItem<String>(
                    value: e,
                    child: Text(e, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: enabled ? (v) => onChanged(v ?? 'ALL') : null,
        ),
      ),
    ],
  );
}


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isPhone = size.width < 600;

    int cols = 1;
    if (isTablet) {
      cols = size.width > 900 ? 3 : 2;
    } else if (size.width > 430) {
      cols = 2;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Employees',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: false,
        elevation: 0,
        actions: [
          if (_importing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else if (_isAdmin)
            IconButton(
              icon: const Icon(Icons.upload_file_outlined),
              tooltip: 'Import Excel',
              onPressed: _importExcel,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmployees,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add),
        label: Text(isPhone ? 'Add' : 'Add Employee'),
        backgroundColor: Colors.blue.shade600,
        elevation: 2,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEmployees,
              child: ListView(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                children: [
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by name, position, or branch...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.shade400,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() => _searchQuery = '');
                                  _debounce?.cancel();
                                  _loadEmployees();
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      onChanged: (v) {
                        _searchQuery = v;
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(
                          const Duration(milliseconds: 500),
                          () {
                            if (_searchQuery.trim().length >= 2 ||
                                _searchQuery.isEmpty) {
                              _loadEmployees();
                            }
                          },
                        );
                      },
                      onSubmitted: (_) => _loadEmployees(),
                      textInputAction: TextInputAction.search,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ===== DROPDOWN FILTERS (1 baris; manager branch locked) =====
                  if (_isAdmin ? _branches.isNotEmpty : _myBranch.isNotEmpty)
                    _buildDropdownFilters(),

                  const SizedBox(height: 20),

                  // Results Count
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${_employees.length} ${_employees.length == 1 ? 'employee' : 'employees'} found',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Employee Grid/List
                  if (_employees.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(48),
                        child: Column(
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No employees found',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    _EmployeeGrid(
                      employees: _employees,
                      onReload: _loadEmployees,
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

// ==== EMPLOYEE GRID & CARD ====

class _EmployeeGrid extends StatelessWidget {
  const _EmployeeGrid({required this.employees, required this.onReload});
  final List<Employee> employees;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    int cols = 1;
    if (isTablet) {
      cols = size.width > 900 ? 3 : 2;
    } else if (size.width > 430) {
      cols = 2;
    }

    return GridView.builder(
      itemCount: employees.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
        mainAxisExtent: isTablet ? 300 : (cols == 1 ? 140 : 260),
        childAspectRatio: isTablet ? 0.85 : (cols == 1 ? 2.2 : 0.75),
      ),
      itemBuilder: (context, i) {
        final emp = employees[i];
        return _EmployeeCard(
          employee: emp,
          onUpdate: onReload,
          onEdit: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmployeeFormPage(employee: emp),
              ),
            ).then((v) {
              if (v == true) onReload();
            });
          },
          isSingleColumn: cols == 1,
        );
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback onUpdate;
  final VoidCallback onEdit;
  final bool isSingleColumn;

  const _EmployeeCard({
    required this.employee,
    required this.onUpdate,
    required this.onEdit,
    this.isSingleColumn = false,
  });

  String _formatJoinDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Delete Employee'),
          ],
        ),
        content: Text('Are you sure you want to delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final res = await ApiService.deleteEmployee(employee.id);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Employee deleted successfully'),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        onUpdate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = employee.name
        .split(' ')
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e[0].toUpperCase())
        .join();

    final statusColor = employee.status == 'active'
        ? Colors.green
        : Colors.grey;

    // Single-column → list style
    if (isSingleColumn) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EmployeeDetailPage(employeeId: employee.id),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        employee.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        employee.position,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if ((employee.department ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          employee.department!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.business,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              employee.branch,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (employee.joinDate.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Joined ${_formatJoinDate(employee.joinDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 12),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'view') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EmployeeDetailPage(employeeId: employee.id),
                        ),
                      );
                    } else if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      _delete(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Multi-column → grid style
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmployeeDetailPage(employeeId: employee.id),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      initials,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                employee.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                employee.position,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          employee.branch,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (employee.joinDate.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Joined ${_formatJoinDate(employee.joinDate)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            EmployeeDetailPage(employeeId: employee.id),
                      ),
                    ),
                    tooltip: 'View',
                    color: Colors.blue.shade600,
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: onEdit,
                    tooltip: 'Edit',
                    color: Colors.orange.shade600,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _delete(context),
                    tooltip: 'Delete',
                    color: Colors.red.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==== FORM PAGE ====

class EmployeeFormPage extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormPage({super.key, this.employee});

  @override
  State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _branch = TextEditingController();
  final _position = TextEditingController();
  final _department = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _joinDate = TextEditingController();
  String _status = 'active';
  bool _saving = false;

  String _myRole = 'staff';
  String _myBranch = '';

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    if (e != null) {
      _name.text = e.name;
      _branch.text = e.branch;
      _position.text = e.position;
      _department.text = e.department ?? '';
      _phone.text = e.phone;
      _email.text = e.email;
      _joinDate.text = e.joinDate;
      _status = e.status;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      final me = auth.user;
      _myRole = (me?.role ?? 'staff').toLowerCase().trim();
      _myBranch = (me?.branch ?? '').toString();

      if (_myRole == 'manager' && _myBranch.isNotEmpty) {
        setState(() {
          _branch.text = _myBranch;
        });
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue.shade600),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _joinDate.text =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isEdit = widget.employee != null;
    Map<String, dynamic> res;

    if (isEdit) {
      res = await ApiService.updateEmployee(
        employeeId: widget.employee!.id,
        name: _name.text.trim(),
        branch: _branch.text.trim(),
        position: _position.text.trim(),
        department: _department.text.trim().isEmpty
            ? null
            : _department.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        status: _status.trim(),
      );
    } else {
      res = await ApiService.createEmployee(
        name: _name.text.trim(),
        branch: _branch.text.trim(),
        position: _position.text.trim(),
        department: _department.text.trim().isEmpty
            ? null
            : _department.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        joinDate: _joinDate.text.trim(),
        status: _status.trim(),
      );
    }

    if (!mounted) return;

    setState(() => _saving = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Employee updated successfully'
                : 'Employee added successfully',
          ),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Something went wrong'),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool required = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: onTap != null,
        onTap: onTap,
        validator: required
            ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            borderSide: BorderSide(color: Colors.red),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.employee != null;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Employee' : 'Add New Employee',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(isTablet ? 32 : 20),
          children: [
            if (!isEdit) ...[
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person_add,
                    size: 40,
                    color: Colors.blue.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basic Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    label: 'Full Name',
                    controller: _name,
                    icon: Icons.person_outline,
                    required: true,
                  ),
                  _buildTextField(
                    label: 'Position',
                    controller: _position,
                    icon: Icons.work_outline,
                  ),
                  _buildTextField(
                    label: 'Department',
                    controller: _department,
                    icon: Icons.apartment_outlined,
                  ),
                  if (_myRole == 'manager')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: TextFormField(
                        controller: _branch,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Branch (locked)',
                          prefixIcon: const Icon(
                            Icons.business_outlined,
                            size: 20,
                          ),
                          suffixIcon: const Icon(Icons.lock_outline, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    )
                  else
                    _buildTextField(
                      label: 'Branch',
                      controller: _branch,
                      icon: Icons.business_outlined,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    label: 'Phone Number',
                    controller: _phone,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    required: true,
                  ),
                  _buildTextField(
                    label: 'Email Address',
                    controller: _email,
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Employment Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    label: 'Join Date',
                    controller: _joinDate,
                    icon: Icons.calendar_today_outlined,
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _status = 'active'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _status == 'active'
                                  ? Colors.green.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _status == 'active'
                                    ? Colors.green.shade300
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: _status == 'active'
                                      ? Colors.green.shade700
                                      : Colors.grey.shade500,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Active',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _status == 'active'
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _status = 'inactive'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _status == 'inactive'
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _status == 'inactive'
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.remove_circle,
                                  color: _status == 'inactive'
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade500,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Inactive',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _status == 'inactive'
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                disabledBackgroundColor: Colors.grey.shade300,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      isEdit ? 'Update Employee' : 'Create Employee',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 15)),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
