import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/schedule_model.dart';
import '../models/employee_model.dart';

enum ViewMode { calendar, grouped }

class ScheduleManagementPage extends StatefulWidget {
  const ScheduleManagementPage({super.key});

  @override
  State<ScheduleManagementPage> createState() => _ScheduleManagementPageState();
}

class _ScheduleManagementPageState extends State<ScheduleManagementPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _branch;
  late DateTime _month;
  ViewMode _view = ViewMode.calendar;

  String _role = 'staff';
  int? _myEmployeeId;
  String? _myName;

  bool _loading = true;
  String? _error;

  // Data
  List<WorkSchedule> _schedules = [];
  List<ShiftPreset> _presets = [];
  List<String> _allBranches = [];

  bool get _isAdmin => _role == 'admin' || _role == 'superadmin';
  bool get _isManager => _role == 'manager';
  bool get _isStaff => !_isAdmin && !_isManager;

  // Corporate colors
  static const _primaryBlue = Color(0xFF1565C0);
  static const _accentBlue = Color(0xFF1976D2);
  static const _lightGray = Color(0xFFF5F7FA);
  static const _borderGray = Color(0xFFE0E5ED);
  static const _textPrimary = Color(0xFF1A2332);
  static const _textSecondary = Color(0xFF6B7785);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final me = auth.user;
      _role = (me?.role ?? 'staff').toLowerCase();
      _branch = me?.branch ?? _branch;
      _myEmployeeId = int.tryParse(me?.id.toString() ?? '');
      _myName = me?.name;

      final pr = await ApiService.listShiftPresets();
      if (pr['success'] == true) {
        final List data = (pr['data'] ?? []) as List;
        _presets = data
            .map((e) => ShiftPreset.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }

      if (_isAdmin) {
        await _loadBranches();
        _branch ??= _allBranches.isNotEmpty ? _allBranches.first : null;
      }

      await _loadSchedules();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBranches() async {
    try {
      final empRes = await ApiService.getEmployees();
      if (empRes['success'] == true) {
        final data = Map<String, dynamic>.from(empRes['data'] ?? {});
        final meta = Map<String, dynamic>.from(data['meta'] ?? {});
        final List brs = (meta['branches'] ?? []) as List;
        _allBranches =
            brs
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
      } else {
        _allBranches = [];
      }
    } catch (_) {
      _allBranches = [];
    }
  }

  Future<void> _loadSchedules() async {
    if (!_isAdmin && (_branch ?? '').isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.getSchedulesByBranchMonth(
        branch: _branch ?? '',
        year: _month.year,
        month: _month.month,
        search: _searchCtrl.text.trim().isEmpty
            ? null
            : _searchCtrl.text.trim(),
      );
      if (res['success'] != true) {
        throw Exception(res['error'] ?? 'Failed load schedules');
      }
      final List data = (res['data'] ?? []) as List;
      var items = data
          .map((e) => WorkSchedule.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      if (_isStaff && _myEmployeeId != null) {
        items = items.where((s) => s.employeeId == _myEmployeeId).toList();
      }

      _schedules = items;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<WorkSchedule>> _groupByEmployee() {
    final map = <String, List<WorkSchedule>>{};
    for (final s in _schedules) {
      final key = '${s.employeeId}|${s.employeeName}';
      map.putIfAbsent(key, () => []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.workDate.compareTo(b.workDate));
    }
    return map;
  }

  Map<String, List<WorkSchedule>> _groupByDate() {
    final map = <String, List<WorkSchedule>>{};
    for (final s in _schedules) {
      map.putIfAbsent(s.workDate, () => []).add(s);
    }
    for (final list in map.values) {
      list.sort((a, b) => (a.employeeName).compareTo(b.employeeName));
    }
    return map;
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(_month.year - 3),
      lastDate: DateTime(_month.year + 3),
      helpText: 'Select Month',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
      await _loadSchedules();
    }
  }

  // Future<void> _openAddDialog({DateTime? fixedDate}) async {
  //   final restrictedEmployee = _isStaff && _myEmployeeId != null
  //       ? Employee(
  //           id: _myEmployeeId.toString(),
  //           name: _myName ?? 'Me',
  //           branch: _branch ?? '',
  //           position: '',
  //           phone: '',
  //           email: '',
  //           joinDate: '',
  //           status: 'active',
  //           createdAt: '',
  //         )
  //       : null;

  //   await showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.white,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //     ),
  //     builder: (ctx) => _ScheduleEditorSheet(
  //       branch: _branch ?? '',
  //       presets: _presets,
  //       restrictedEmployee: restrictedEmployee,
  //       onSaved: () async {
  //         Navigator.of(ctx).pop();
  //         await _loadSchedules();
  //       },
  //     ),
  //   );
  // }

  Future<void> _openAddDialog({DateTime? fixedDate}) async {
    final restrictedEmployee = _isStaff && _myEmployeeId != null
        ? Employee(
            id: _myEmployeeId.toString(),
            name: _myName ?? 'Me',
            branch: _branch ?? '',
            position: '',
            phone: '',
            email: '',
            joinDate: '',
            status: 'active',
            createdAt: '',
          )
        : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ScheduleEditorSheet(
        branch: _branch ?? '',
        presets: _presets,
        restrictedEmployee: restrictedEmployee,
        initialDate: fixedDate, // ⬅️ penting: prefill tanggal
        onSaved: () async {
          Navigator.of(ctx).pop();
          await _loadSchedules();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Work Schedule',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadSchedules,
            icon: const Icon(Icons.refresh_rounded, color: _textSecondary),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        backgroundColor: _primaryBlue,
        child: const Icon(Icons.add, size: 28),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header section with white background
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    children: [
                      // Branch & Month selector
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _isAdmin
                                ? _BranchDropdown(
                                    branches: _allBranches,
                                    value: _branch,
                                    onChanged: (v) async {
                                      setState(() => _branch = v);
                                      await _loadSchedules();
                                    },
                                  )
                                : _BranchField(
                                    value: _branch,
                                    caption: _isManager
                                        ? 'Branch (Manager)'
                                        : 'Branch',
                                  ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _MonthButton(
                              month: _month,
                              onTap: _pickMonth,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Search bar
                      TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.search,
                            size: 20,
                            color: _textSecondary,
                          ),
                          hintText: _isStaff
                              ? 'Search schedules'
                              : 'Search by name, position',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                          ),
                          filled: true,
                          fillColor: _lightGray,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _loadSchedules(),
                      ),
                      const SizedBox(height: 12),

                      // View toggle
                      Row(
                        children: [
                          Expanded(
                            child: _ViewButton(
                              icon: Icons.calendar_view_month_rounded,
                              label: 'Calendar',
                              isSelected: _view == ViewMode.calendar,
                              onTap: () =>
                                  setState(() => _view = ViewMode.calendar),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ViewButton(
                              icon: Icons.list_alt_rounded,
                              label: 'By Employee',
                              isSelected: _view == ViewMode.grouped,
                              onTap: () =>
                                  setState(() => _view = ViewMode.grouped),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Content area
                // Content area
                Expanded(
                  child: _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(12),
                          child: _view == ViewMode.calendar
                              ? _CalendarMonthGrid(
                                  month: _month,
                                  byDate: _groupByDate(),
                                  onTapEdit: (s) {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.white,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(20),
                                        ),
                                      ),
                                      builder: (ctx) => _ScheduleEditorSheet(
                                        branch: s.branch,
                                        presets: _presets,
                                        seed: s,
                                        onSaved: () async {
                                          Navigator.of(ctx).pop();
                                          await _loadSchedules();
                                        },
                                      ),
                                    );
                                  },
                                  onTapAdd: (date) => _openAddDialog(
                                    fixedDate: date,
                                  ), // ⬅️ baru
                                )
                              : _schedules.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.event_busy_rounded,
                                        size: 64,
                                        color: _textSecondary.withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No schedules found',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: _textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _EmployeeGroupedList(
                                  month: _month,
                                  groups: _groupByEmployee(),
                                  presets: _presets,
                                  onReload: _loadSchedules,
                                ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ============= CALENDAR GRID =============
class _CalendarMonthGrid extends StatelessWidget {
  final DateTime month;
  final Map<String, List<WorkSchedule>> byDate;
  final ValueChanged<WorkSchedule> onTapEdit;
  final ValueChanged<DateTime>? onTapAdd;

  const _CalendarMonthGrid({
    required this.month,
    required this.byDate,
    required this.onTapEdit,
    required this.onTapAdd,
  });

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final totalCells = ((firstWeekday - 1) + daysInMonth);
    final rows = (totalCells / 7.0).ceil();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E5ED)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: const [
                _DowLabel('M'),
                _DowLabel('T'),
                _DowLabel('W'),
                _DowLabel('T'),
                _DowLabel('F'),
                _DowLabel('S'),
                _DowLabel('S'),
              ],
            ),
          ),

          // Calendar grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.85,
                ),
                itemCount: rows * 7,
                itemBuilder: (_, index) {
                  final dayNumber = index - (firstWeekday - 2);
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const _CalendarCellEmpty();
                  }
                  final d = DateTime(month.year, month.month, dayNumber);
                  final key =
                      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                  final items = byDate[key] ?? const [];

                  return _CalendarCell(
                    date: d,
                    schedules: items,
                    onTapEdit: onTapEdit,
                    onTapAdd: onTapAdd,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DowLabel extends StatelessWidget {
  final String text;
  const _DowLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7785),
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _CalendarCellEmpty extends StatelessWidget {
  const _CalendarCellEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFFAFBFC),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final DateTime date;
  final List<WorkSchedule> schedules;
  final ValueChanged<WorkSchedule> onTapEdit;
  final ValueChanged<DateTime>? onTapAdd;

  const _CalendarCell({
    required this.date,
    required this.schedules,
    required this.onTapEdit,
    this.onTapAdd,
  });

  @override
  Widget build(BuildContext context) {
    final isToday =
        DateTime.now().day == date.day &&
        DateTime.now().month == date.month &&
        DateTime.now().year == date.year;

    return InkWell(
      onTap: () {
        if (schedules.isEmpty) {
          onTapAdd!(date);
        } else {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => _StaffListModal(
              date: date,
              schedules: schedules,
              onTapEdit: onTapEdit,
              onTapAdd: () => onTapAdd!(date), // ⬅️ pass ke modal
            ),
          );
        }
      },
      onLongPress: () => onTapAdd!(date),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isToday ? const Color(0xFF1565C0) : const Color(0xFFE0E5ED),
            width: isToday ? 1.5 : 1,
          ),
          color: schedules.isEmpty ? Colors.white : const Color(0xFFF8FAFE),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date number
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isToday
                        ? const Color(0xFF1565C0)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: isToday ? Colors.white : const Color(0xFF1A2332),
                    ),
                  ),
                ),
                if (schedules.length > 2)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '+${schedules.length - 2}',
                      style: const TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),

            // Employee list (max 2)
            Expanded(
              child: schedules.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: schedules.length > 2 ? 2 : schedules.length,
                      itemBuilder: (_, i) {
                        final s = schedules[i];
                        final firstName = s.employeeName.split(' ').first;
                        final displayText = firstName.length > 8
                            ? '${firstName.substring(0, 7)}.'
                            : firstName;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              s.shiftCode.isNotEmpty
                                  ? '$displayText-${s.shiftCode}'
                                  : displayText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= STAFF LIST MODAL =============
// ============= STAFF LIST MODAL =============
class _StaffListModal extends StatelessWidget {
  final DateTime date;
  final List<WorkSchedule> schedules;
  final ValueChanged<WorkSchedule> onTapEdit;
  final VoidCallback? onTapAdd;

  const _StaffListModal({
    required this.date,
    required this.schedules,
    required this.onTapEdit,
    this.onTapAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: Color(0xFF1565C0),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Scheduled Staff',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A2332),
                      ),
                    ),
                    Text(
                      '${date.day} ${_getMonthName(date.month)} ${date.year}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7785),
                      ),
                    ),
                  ],
                ),
              ),

              // ➕ Add schedule on this date
              if (onTapAdd != null)
                IconButton(
                  tooltip: 'Add schedule on this date',
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF1565C0),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onTapAdd!();
                  },
                ),

              // ✖️ Close
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF6B7785)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: schedules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = schedules[i];
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    onTapEdit(s);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E5ED)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              s.employeeName.isNotEmpty
                                  ? s.employeeName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1A2332),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${s.shiftCode} • ${s.startTime ?? ''} - ${s.endTime ?? ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7785),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF6B7785),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }
}

// ============= EMPLOYEE GROUPED LIST =============
class _EmployeeGroupedList extends StatelessWidget {
  final DateTime month;
  final Map<String, List<WorkSchedule>> groups;
  final List<ShiftPreset> presets;
  final VoidCallback onReload;

  const _EmployeeGroupedList({
    required this.month,
    required this.groups,
    required this.presets,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, idx) {
        final key = groups.keys.elementAt(idx);
        final parts = key.split('|');
        final empId = int.tryParse(parts.first) ?? 0;
        final empName = parts.length > 1 ? parts[1] : 'Employee $empId';
        final items = groups[key]!;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E5ED)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Employee header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          empName.isNotEmpty ? empName[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            empName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1A2332),
                            ),
                          ),
                          Text(
                            'ID: $empId',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7785),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length} days',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Schedule list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (_, i) {
                  final s = items[i];
                  return _ScheduleRow(
                    schedule: s,
                    presets: presets,
                    onReload: onReload,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  final WorkSchedule schedule;
  final List<ShiftPreset> presets;
  final VoidCallback onReload;

  const _ScheduleRow({
    required this.schedule,
    required this.presets,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Date
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            children: [
              Text(
                schedule.workDate.substring(8),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2332),
                ),
              ),
              Text(
                _getMonthAbbr(int.parse(schedule.workDate.substring(5, 7))),
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7785)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Shift & Time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                schedule.shiftCode.isEmpty ? '-' : schedule.shiftCode,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2332),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                (schedule.startTime ?? '').isEmpty &&
                        (schedule.endTime ?? '').isEmpty
                    ? 'No time set'
                    : '${schedule.startTime ?? ''} - ${schedule.endTime ?? ''}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7785)),
              ),
            ],
          ),
        ),

        // Actions
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: const Color(0xFF1565C0),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (ctx) => _ScheduleEditorSheet(
                    branch: schedule.branch,
                    presets: presets,
                    seed: schedule,
                    onSaved: () {
                      Navigator.of(ctx).pop();
                      onReload();
                    },
                  ),
                );
              },
            ),
            if (schedule.id != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.red.shade400,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text(
                        'Delete Schedule',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      content: Text(
                        'Remove schedule for ${schedule.workDate}?',
                        style: const TextStyle(fontSize: 14),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );

                  if (ok == true) {
                    final res = await ApiService.deleteSchedule(schedule.id!);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          res['success'] == true
                              ? 'Schedule deleted'
                              : (res['error'] ?? 'Failed to delete'),
                        ),
                      ),
                    );
                    if (res['success'] == true) onReload();
                  }
                },
              ),
          ],
        ),
      ],
    );
  }

  String _getMonthAbbr(int month) {
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
    return months[month - 1];
  }
}

// ============= SCHEDULE EDITOR SHEET =============
class _ScheduleEditorSheet extends StatefulWidget {
  final String branch;
  final List<ShiftPreset> presets;
  final VoidCallback onSaved;
  final WorkSchedule? seed;
  final Employee? restrictedEmployee;
  final DateTime? initialDate;

  const _ScheduleEditorSheet({
    required this.branch,
    required this.presets,
    required this.onSaved,
    this.seed,
    this.restrictedEmployee,
    this.initialDate,
  });

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  Employee? _employee;
  late DateTime _workDate;
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _shiftCtrl = TextEditingController();
  final TextEditingController _startCtrl = TextEditingController();
  final TextEditingController _endCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  List<ShiftPreset> _presets = [];
  bool _saving = false;

  bool get _lockedEmployee => widget.restrictedEmployee != null;

  @override
  void initState() {
    super.initState();
    _presets = widget.presets;

    final today = DateTime.now();
    // _workDate = widget.seed != null
    //     ? _parseDate(widget.seed!.workDate)
    //     : DateTime(today.year, today.month, today.day);
    _workDate = widget.seed != null
        ? _parseDate(widget.seed!.workDate)
        : (widget.initialDate != null
              ? DateTime(
                  widget.initialDate!.year,
                  widget.initialDate!.month,
                  widget.initialDate!.day,
                )
              : DateTime(
                  today.year,
                  today.month,
                  today.day,
                )); // ⬅️ pakai initialDate

    _dateCtrl.text = _fmtYmd(_workDate);

    if (widget.seed != null) {
      _employee = Employee(
        id: (widget.seed!.employeeId).toString(),
        name: widget.seed!.employeeName,
        branch: widget.seed!.branch,
        position: '',
        phone: '',
        email: '',
        joinDate: '',
        status: 'active',
        createdAt: '',
      );
      _shiftCtrl.text = widget.seed!.shiftCode;
      _startCtrl.text = widget.seed!.startTime ?? '';
      _endCtrl.text = widget.seed!.endTime ?? '';
      _notesCtrl.text = widget.seed!.notes ?? '';
    }

    if (_lockedEmployee) {
      _employee = widget.restrictedEmployee!;
    }

    if (_presets.isEmpty) _loadPresets();
  }

  DateTime _parseDate(String yyyyMmDd) {
    final p = yyyyMmDd.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  String _fmtYmd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadPresets() async {
    final res = await ApiService.listShiftPresets();
    if (res['success'] == true) {
      final List data = (res['data'] ?? []) as List;
      if (!mounted) return;
      setState(() {
        _presets = data
            .map((e) => ShiftPreset.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate,
      firstDate: DateTime(_workDate.year - 1),
      lastDate: DateTime(_workDate.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _workDate = picked;
        _dateCtrl.text = _fmtYmd(picked);
      });
    }
  }

  void _applyPreset(ShiftPreset p) {
    _shiftCtrl.text = p.code;
    _startCtrl.text = (p.startTime ?? '').trim();
    _endCtrl.text = (p.endTime ?? '').trim();
  }

  Future<void> _save() async {
    if (_employee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee')),
      );
      return;
    }
    if (_shiftCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shift code is required')));
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final me = auth.user;

      final res = await ApiService.upsertSchedule(
        employeeId: int.tryParse(_employee!.id) ?? 0,
        branch: _employee!.branch.isNotEmpty
            ? _employee!.branch
            : widget.branch,
        workDate: _fmtYmd(_workDate),
        shiftCode: _shiftCtrl.text.trim(),
        startTime: _startCtrl.text.trim().isEmpty
            ? null
            : _startCtrl.text.trim(),
        endTime: _endCtrl.text.trim().isEmpty ? null : _endCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        userId: int.tryParse(me?.id.toString() ?? ''),
      );

      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule saved successfully')),
        );
        widget.onSaved();
      } else {
        throw Exception(res['error'] ?? 'Failed to save schedule');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_calendar_rounded,
                  color: Color(0xFF1565C0),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.seed == null ? 'Add Schedule' : 'Edit Schedule',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2332),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF6B7785)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Employee picker
          if (_lockedEmployee)
            _FormField(
              label: 'Employee',
              child: TextField(
                controller: TextEditingController(
                  text: '${_employee!.name} — ${_employee!.branch}',
                ),
                readOnly: true,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.person_outline, size: 20),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            )
          else
            _EmployeePicker(
              initial: _employee,
              onSelected: (e) => setState(() => _employee = e),
              branchFilter: widget.branch,
            ),
          const SizedBox(height: 16),

          // Date & Preset
          // Date & Preset
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label: 'Date',
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.event_outlined, size: 20),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _dateCtrl.text,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(
                  label: 'Preset',
                  // ⬇️ make it nullable: DropdownButtonFormField<ShiftPreset?>
                  child: DropdownButtonFormField<ShiftPreset?>(
                    // cari preset yang lagi terpilih dari _shiftCtrl (kalau ada)
                    value: _presets.any((p) => p.code == _shiftCtrl.text.trim())
                        ? _presets.firstWhere(
                            (p) => p.code == _shiftCtrl.text.trim(),
                          )
                        : null,
                    items: <DropdownMenuItem<ShiftPreset?>>[
                      const DropdownMenuItem<ShiftPreset?>(
                        value: null,
                        child: Text('Choose', style: TextStyle(fontSize: 14)),
                      ),
                      ..._presets.map(
                        (p) => DropdownMenuItem<ShiftPreset?>(
                          value: p,
                          child: Text(
                            p.code,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (p) {
                      if (p == null) {
                        // pilih "Choose" → kosongkan field preset & waktu
                        _shiftCtrl.clear();
                        _startCtrl.clear();
                        _endCtrl.clear();
                      } else {
                        _applyPreset(p);
                      }
                      setState(() {}); // refresh tampilan kalau perlu
                    },
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.schedule, size: 20),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Shift code
          _FormField(
            label: 'Shift Code',
            child: TextField(
              controller: _shiftCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.work_outline, size: 20),
                hintText: 'e.g. Morning, S1, OFF',
                hintStyle: TextStyle(fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Time range
          Row(
            children: [
              Expanded(
                child: _FormField(
                  label: 'Start Time',
                  child: TextField(
                    controller: _startCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.access_time, size: 20),
                      hintText: 'HH:MM',
                      hintStyle: TextStyle(fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FormField(
                  label: 'End Time',
                  child: TextField(
                    controller: _endCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.access_time_filled, size: 20),
                      hintText: 'HH:MM',
                      hintStyle: TextStyle(fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Notes
          _FormField(
            label: 'Notes (Optional)',
            child: TextField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.note_outlined, size: 20),
                hintText: 'Additional information...',
                hintStyle: TextStyle(fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Schedule',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============= FORM FIELD WRAPPER =============
class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7785),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E5ED)),
          ),
          child: child,
        ),
      ],
    );
  }
}

// ============= BRANCH FIELD =============
class _BranchField extends StatelessWidget {
  final String? value;
  final String? caption;

  const _BranchField({required this.value, this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E5ED)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.apartment_outlined,
            size: 18,
            color: Color(0xFF6B7785),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A2332)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============= BRANCH DROPDOWN =============
class _BranchDropdown extends StatelessWidget {
  final List<String> branches;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _BranchDropdown({
    required this.branches,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E5ED)),
      ),
      child: DropdownButtonFormField<String>(
        value: (value != null && branches.contains(value))
            ? value
            : (branches.isNotEmpty ? branches.first : null),
        items: branches
            .map(
              (b) => DropdownMenuItem(
                value: b,
                child: Text(b, style: const TextStyle(fontSize: 14)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.apartment_outlined, size: 18),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A2332)),
      ),
    );
  }
}

// ============= MONTH BUTTON =============
class _MonthButton extends StatelessWidget {
  final DateTime month;
  final VoidCallback onTap;

  const _MonthButton({required this.month, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E5ED)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_month,
              size: 18,
              color: Color(0xFF6B7785),
            ),
            const SizedBox(width: 8),
            Text(
              '${month.year}-${month.month.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2332),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= VIEW BUTTON =============
class _ViewButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ViewButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1565C0)
                : const Color(0xFFE0E5ED),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF6B7785),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF6B7785),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= EMPLOYEE PICKER =============
class _EmployeePicker extends StatefulWidget {
  final Employee? initial;
  final ValueChanged<Employee> onSelected;
  final String? branchFilter;

  const _EmployeePicker({
    required this.initial,
    required this.onSelected,
    this.branchFilter,
  });

  @override
  State<_EmployeePicker> createState() => _EmployeePickerState();
}

class _EmployeePickerState extends State<_EmployeePicker> {
  final TextEditingController _ctrl = TextEditingController();
  List<Employee> _items = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _ctrl.text = '${widget.initial!.name} — ${widget.initial!.branch}';
    }
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getEmployees(
        search: q.trim().isEmpty ? null : q.trim(),
        branch: widget.branchFilter,
      );
      if (res['success'] == true) {
        final root = Map<String, dynamic>.from(res['data'] ?? {});
        final listAny = root.containsKey('employees')
            ? (root['employees'] as List)
            : (root['rows'] as List? ?? (res['data'] as List? ?? const []));
        _items = listAny
            .map((e) => Employee.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        _items = [];
      }
    } catch (_) {
      _items = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openPicker() async {
    await _search('');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final TextEditingController search = TextEditingController();
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: Color(0xFF1565C0),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Employee',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A2332),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Color(0xFF6B7785)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search by name, position, branch',
                  hintStyle: const TextStyle(fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (q) async {
                  await _search(q);
                  (ctx as Element).markNeedsBuild();
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 400,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                    ? const Center(
                        child: Text(
                          'No employees found',
                          style: TextStyle(color: Color(0xFF6B7785)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = _items[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  e.name.isNotEmpty
                                      ? e.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              e.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${e.position} • ${e.branch}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7785),
                              ),
                            ),
                            onTap: () {
                              widget.onSelected(e);
                              _ctrl.text = '${e.name} — ${e.branch}';
                              Navigator.pop(ctx);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Employee',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7785),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _openPicker,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE0E5ED)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 20,
                  color: Color(0xFF6B7785),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _ctrl.text.isEmpty ? 'Select employee' : _ctrl.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: _ctrl.text.isEmpty
                          ? const Color(0xFF6B7785)
                          : const Color(0xFF1A2332),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Color(0xFF6B7785)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
