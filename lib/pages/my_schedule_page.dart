import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/schedule_model.dart';

class MySchedulePage extends StatefulWidget {
  const MySchedulePage({super.key});
  @override
  State<MySchedulePage> createState() => _MySchedulePageState();
}

class _MySchedulePageState extends State<MySchedulePage> {
  bool _loading = true;
  String? _error;
  int? _employeeId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<WorkSchedule> _items = [];
  bool _isCalendarView = false; // Toggle view mode

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final me = auth.user;
      if (me == null) throw Exception('Session kosong');

      final mapRes = await ApiService.findEmployeeForUser(me.id);
      if (mapRes['success'] != true) {
        throw Exception(mapRes['error'] ?? 'Gagal memetakan employee');
      }
      _employeeId = int.tryParse(mapRes['data']?['id']?.toString() ?? '');
      if (_employeeId == null) throw Exception('employee_id tidak valid');

      await _loadSchedules();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(_month.year - 2),
      lastDate: DateTime(_month.year + 2),
      helpText: 'choose month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
      await _loadSchedules();
    }
  }

  Future<void> _loadSchedules() async {
    if (_employeeId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.getSchedulesByEmployeeMonth(
        employeeId: _employeeId!,
        year: _month.year,
        month: _month.month,
      );
      if (res['success'] != true) {
        throw Exception(res['error'] ?? 'Failed to load schedules');
      }
      final List data = (res['data'] ?? []) as List;
      _items = data
          .map((e) => WorkSchedule.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _getMonthName() {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[_month.month - 1]} ${_month.year}';
  }

  String _getDayName(String date) {
    try {
      final d = DateTime.parse(date);
      final days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[d.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  String _getShortDayName(int weekday) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  Color _getShiftColor(String shiftCode) {
    if (shiftCode.toUpperCase().contains('PAGI')) return Colors.orange.shade100;
    if (shiftCode.toUpperCase().contains('SIANG')) return Colors.blue.shade100;
    if (shiftCode.toUpperCase().contains('MALAM'))
      return Colors.indigo.shade100;
    if (shiftCode.isEmpty) return Colors.grey.shade100;
    return Colors.teal.shade100;
  }

  WorkSchedule? _getScheduleForDate(DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    try {
      return _items.firstWhere((s) => s.workDate == dateStr);
    } catch (_) {
      return null;
    }
  }

  List<DateTime> _getDaysInMonth() {
    final firstDay = DateTime(_month.year, _month.month, 1);
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final days = <DateTime>[];

    // Add empty cells for days before the first day of month
    final firstWeekday = firstDay.weekday;
    for (int i = 1; i < firstWeekday; i++) {
      days.add(firstDay.subtract(Duration(days: firstWeekday - i)));
    }

    // Add all days in the month
    for (int i = 0; i < lastDay.day; i++) {
      days.add(DateTime(_month.year, _month.month, i + 1));
    }

    // Add empty cells to complete the last week
    final remaining = 7 - (days.length % 7);
    if (remaining < 7) {
      for (int i = 1; i <= remaining; i++) {
        days.add(lastDay.add(Duration(days: i)));
      }
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text(
          'My Schedules',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _isCalendarView = !_isCalendarView);
            },
            icon: Icon(
              _isCalendarView
                  ? Icons.view_list_rounded
                  : Icons.calendar_view_month_rounded,
            ),
            tooltip: _isCalendarView ? 'List Videw' : 'Calendar View',
          ),
          IconButton(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Choose Month',
          ),
          IconButton(
            onPressed: _loadSchedules,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header bulan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.indigo,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getMonthName(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_items.length} work schedule${_items.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _isCalendarView
                        ? Icons.calendar_view_month_rounded
                        : Icons.view_list_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadSchedules,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Try Again',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo, // warna tombol
                              foregroundColor:
                                  Colors.white, // warna teks & ikon
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isCalendarView
                ? _buildCalendarView()
                : _buildListView(),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Schedules Found',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'For ${_getMonthName()}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final s = _items[i];
        final dayName = _getDayName(s.workDate);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Tanggal
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _getShiftColor(s.shiftCode),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s.workDate.substring(8),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            s.workDate.substring(5, 7),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Info jadwal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (dayName.isNotEmpty)
                            Text(
                              dayName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            s.shiftCode.isEmpty
                                ? 'Tidak ada shift'
                                : s.shiftCode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                (s.startTime ?? '').isEmpty &&
                                        (s.endTime ?? '').isEmpty
                                    ? 'Waktu belum di-set'
                                    : '${s.startTime ?? ''} - ${s.endTime ?? ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Arrow icon
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCalendarView() {
    final days = _getDaysInMonth();
    final isCurrentMonth =
        _month.year == DateTime.now().year &&
        _month.month == DateTime.now().month;
    final today = DateTime.now().day;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Header hari
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: List.generate(7, (i) {
                return Expanded(
                  child: Center(
                    child: Text(
                      _getShortDayName(i + 1),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Grid kalender
          Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.75,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: days.length,
              itemBuilder: (_, i) {
                final date = days[i];
                final isInCurrentMonth = date.month == _month.month;
                final schedule = _getScheduleForDate(date);
                final isToday =
                    isCurrentMonth && isInCurrentMonth && date.day == today;

                return GestureDetector(
                  onTap: schedule != null
                      ? () {
                          _showScheduleDetail(schedule);
                        }
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: !isInCurrentMonth
                          ? Colors.transparent
                          : schedule != null
                          ? _getShiftColor(schedule.shiftCode)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: Colors.indigo, width: 2)
                          : Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: !isInCurrentMonth
                                ? Colors.grey.shade300
                                : isToday
                                ? Colors.indigo
                                : Colors.black87,
                          ),
                        ),
                        if (schedule != null && isInCurrentMonth) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              schedule.shiftCode.length > 4
                                  ? schedule.shiftCode.substring(0, 4)
                                  : schedule.shiftCode,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if ((schedule.startTime ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                schedule.startTime!,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                        ],
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

  void _showScheduleDetail(WorkSchedule schedule) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final dayName = _getDayName(schedule.workDate);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getShiftColor(schedule.shiftCode),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.event_rounded,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          schedule.workDate,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailRow(
                Icons.work_outline,
                'Shift',
                schedule.shiftCode.isEmpty ? 'No Shift' : schedule.shiftCode,
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                Icons.access_time_rounded,
                'Time',
                (schedule.startTime ?? '').isEmpty &&
                        (schedule.endTime ?? '').isEmpty
                    ? 'Time Not Set'
                    : '${schedule.startTime ?? ''} - ${schedule.endTime ?? ''}',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}
