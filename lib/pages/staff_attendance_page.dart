import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
// Export & Download
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:file_saver/file_saver.dart';
import 'package:open_filex/open_filex.dart';

// Services
import '../services/auth_service.dart';
import '../services/api_service.dart';

class StaffAttendancePage extends StatefulWidget {
  const StaffAttendancePage({super.key});

  @override
  State<StaffAttendancePage> createState() => _StaffAttendancePageState();
}

enum _AttendanceFilter {
  all,
  checkedIn,
  notCheckedIn,
  checkedOut,
  notCheckedOut,
}

class _StaffAttendancePageState extends State<StaffAttendancePage>
    with WidgetsBindingObserver {
  final _search = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = true;
  List<Map<String, dynamic>> _raw = [];

  final _refreshKey = GlobalKey<RefreshIndicatorState>();
  final _dateFmt = DateFormat('dd MMM yyyy', 'en_US');

  _AttendanceFilter _filter = _AttendanceFilter.all;
  String? _selectedBranch; // null = all branches

  // Corporate colors
  static const _primaryBlue = Color(0xFF1565C0);
  static const _lightGray = Color(0xFFF5F7FA);
  static const _borderGray = Color(0xFFE0E5ED);
  static const _textPrimary = Color(0xFF1A2332);
  static const _textSecondary = Color(0xFF6B7785);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // ✅ Set _selectedBranch LEBIH AWAL utk non-admin/superadmin
    final auth = Provider.of<AuthService>(context, listen: false);
    final me = auth.user;
    final role = (me?.role ?? '').toLowerCase().trim();
    if (role != 'admin' && role != 'superadmin') {
      _selectedBranch = (me?.branch ?? '').toString();
    }

    // Baru load data
    _load();

    // Optional auto-refresh visual
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshKey.currentState?.show();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshKey.currentState?.show();
    }
  }

  String get _dateStr => DateFormat('yyyy-MM-dd').format(_date);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final me = auth.user;
      final role = (me?.role ?? '').toLowerCase().trim();
      final scope = role == 'superadmin' ? 'superadmin' : 'staff';
      final myBranch = (me?.branch ?? '').toString();

      // NOTE: kalau API kamu support filter branch, pakai ini:
      // final res = await ApiService.getStaffAttendance(
      //   date: _dateStr,
      //   roleScope: scope,
      //   branch: (role == 'admin' || role == 'superadmin') ? null : myBranch,
      // );

      // final res = await ApiService.getStaffAttendance(
      //   date: _dateStr,
      //   roleScope: scope,
      // );

      final res = await ApiService.getStaffAttendance(
  date: _dateStr,
  roleScope: scope,
  branch: role == 'superadmin' ? null : myBranch, // <= kirim branch utk manager/staff
);

      if (res['success'] == true) {
        final data = Map<String, dynamic>.from(res['data'] ?? {});
        final rows = List<Map<String, dynamic>>.from(data['rows'] ?? []);

        // ✅ Server-side filtering (fallback di client) — langsung batasi _raw ke branch user
        if (role != 'admin' && role != 'superadmin') {
          final selected = myBranch.trim().toLowerCase();
          final onlyMine = rows.where((e) {
            final br = (e['branch'] ?? '').toString().trim().toLowerCase();
            return br == selected;
          }).toList();
          setState(() => _raw = onlyMine);
        } else {
          setState(() => _raw = rows);
        }
      } else {
        setState(() => _raw = []);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['error']?.toString() ?? 'Failed to fetch data'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _raw = []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _isIn(Map<String, dynamic> e) =>
      ((e['first_in'] ?? '') as String).toString().isNotEmpty;
  bool _isOut(Map<String, dynamic> e) =>
      ((e['last_out'] ?? '') as String).toString().isNotEmpty;

  List<Map<String, dynamic>> get _filtered {
    final q = _search.text.trim().toLowerCase();
    Iterable<Map<String, dynamic>> it = _raw;

    // ✅ Filter by branch (normalized) — mestinya _raw sudah 1 branch utk manager,
    // tapi ini tetap disisakan supaya UI konsisten kalau admin pilih branch via chips.
    final selected = (_selectedBranch ?? '').trim().toLowerCase();
    if (selected.isNotEmpty) {
      it = it.where((e) {
        final br = (e['branch'] ?? '').toString().trim().toLowerCase();
        return br == selected;
      });
    }

    if (q.isNotEmpty) {
      it = it.where((e) {
        final name = (e['name'] ?? '').toString().toLowerCase();
        final email = (e['email'] ?? '').toString().toLowerCase();
        final branch = (e['branch'] ?? '').toString().toLowerCase();
        return name.contains(q) || email.contains(q) || branch.contains(q);
      });
    }

    it = it.where((e) {
      switch (_filter) {
        case _AttendanceFilter.all:
          return true;
        case _AttendanceFilter.checkedIn:
          return _isIn(e);
        case _AttendanceFilter.notCheckedIn:
          return !_isIn(e);
        case _AttendanceFilter.checkedOut:
          return _isOut(e);
        case _AttendanceFilter.notCheckedOut:
          return !_isOut(e);
      }
    });

    return it.toList();
  }

  // GROUP BY BRANCH
  Map<String, List<Map<String, dynamic>>> get _groupedByBranch {
    final filtered = _filtered;
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final item in filtered) {
      final branch = (item['branch'] ?? 'Unknown').toString();
      grouped.putIfAbsent(branch, () => []);
      grouped[branch]!.add(item);
    }
    final sortedKeys = grouped.keys.toList()..sort();
    final sortedMap = <String, List<Map<String, dynamic>>>{};
    for (final key in sortedKeys) {
      sortedMap[key] = grouped[key]!;
    }
    return sortedMap;
  }

  // Get all unique branches from raw data
  List<String> get _allBranches {
    final branches =
        _raw.map((e) => (e['branch'] ?? '').toString()).toSet().toList();
    branches.sort();
    return branches;
  }

  int get _countTotal => _filtered.length;
  int get _countCheckedIn => _filtered.where(_isIn).length;
  int get _countCheckedOut => _filtered.where(_isOut).length;

  Duration? _calcDuration(String? inTime, String? outTime) {
    if (inTime == null || outTime == null) return null;
    try {
      final partsIn =
          inTime.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      final partsOut =
          outTime.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      final dtIn = DateTime(
        _date.year,
        _date.month,
        _date.day,
        partsIn[0],
        partsIn[1],
        partsIn.length > 2 ? partsIn[2] : 0,
      );
      final dtOut = DateTime(
        _date.year,
        _date.month,
        _date.day,
        partsOut[0],
        partsOut[1],
        partsOut.length > 2 ? partsOut[2] : 0,
      );
      if (dtOut.isBefore(dtIn)) return null;
      return dtOut.difference(dtIn);
    } catch (_) {
      return null;
    }
  }

  String _fmtDurCsv(Duration? d) {
    if (d == null) return '-';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtDurHuman(Duration? d) {
    if (d == null) return '-';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    return '${h}h ${m}m';
  }

  bool _isLate(String? inTime) {
    if (inTime == null || inTime.isEmpty) return false;
    try {
      final parts = inTime.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      final dt =
          DateTime(_date.year, _date.month, _date.day, parts[0], parts[1]);
      final nine = DateTime(_date.year, _date.month, _date.day, 9, 0);
      return dt.isAfter(nine);
    } catch (_) {
      return false;
    }
  }

  Duration? _lateDuration(String? inTime) {
    if (inTime == null || inTime.isEmpty) return null;
    try {
      final parts = inTime.split(':').map((e) => int.tryParse(e) ?? 0).toList();
      final dt =
          DateTime(_date.year, _date.month, _date.day, parts[0], parts[1]);
      final nine = DateTime(_date.year, _date.month, _date.day, 9, 0);
      if (dt.isBefore(nine)) return null;
      return dt.difference(nine);
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _date = picked);
      _refreshKey.currentState?.show();
    }
  }

  Future<void> _downloadExcelXlsx() async {
    try {
      final wb = xlsio.Workbook();
      final sheet = wb.worksheets[0];
      sheet.name = 'Attendance';

      final headers = [
        'Date',
        'Branch',
        'Name',
        'Email',
        'Position',
        'Role',
        'Check In',
        'Check Out',
        'Work Duration (HH:MM)',
        'Late?',
        'Late Duration (HH:MM)',
      ];
      for (var c = 0; c < headers.length; c++) {
        sheet.getRangeByIndex(1, c + 1).setText(headers[c]);
      }
      sheet.getRangeByIndex(1, 1, 1, headers.length).cellStyle.bold = true;

      var r = 2;
      for (final e in _filtered) {
        final name = (e['name'] ?? '').toString();
        final email = (e['email'] ?? '').toString();
        final branch = (e['branch'] ?? '').toString();
        final position = (e['position'] ?? '').toString();
        final role = (e['role'] ?? '').toString();
        final inTimeRaw = (e['first_in'] ?? '').toString();
        final outTimeRaw = (e['last_out'] ?? '').toString();
        final inTime = inTimeRaw.isEmpty ? '-' : inTimeRaw;
        final outTime = outTimeRaw.isEmpty ? '-' : outTimeRaw;
        final dur = _fmtDurCsv(
          _calcDuration(
              inTime == '-' ? null : inTime, outTime == '-' ? null : outTime),
        );
        final late = _isLate(inTime == '-' ? null : inTime);
        final lateDur = _lateDuration(inTime == '-' ? null : inTime);
        final lateStr = _fmtDurCsv(lateDur);

        final row = [
          _dateStr,
          branch,
          name,
          email,
          position,
          role,
          inTime == '-' ? '' : _toHM(inTime),
          outTime == '-' ? '' : _toHM(outTime),
          dur,
          late ? 'Yes' : 'No',
          late ? lateStr : '',
        ];

        for (var c = 0; c < row.length; c++) {
          sheet.getRangeByIndex(r, c + 1).setText(row[c].toString());
        }
        r++;
      }

      for (var c = 1; c <= headers.length; c++) {
        sheet.autoFitColumn(c);
      }

      final bytes = Uint8List.fromList(wb.saveAsStream());
      wb.dispose();

      final fileName = 'attendance_${_dateStr}.xlsx';

      final savedPath = await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        mimeType: MimeType.microsoftExcel,
        fileExtension: 'xlsx',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: $fileName'),
          action: SnackBarAction(
            label: 'OPEN',
            onPressed: () async {
              final p = savedPath?.toString() ?? '';
              if (p.isNotEmpty) await OpenFilex.open(p);
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<_UserDayDetail> _fetchUserDayDetail(String userId) async {
    final res = await ApiService.getAttendances(userId);
    if (res['success'] != true) {
      throw Exception(res['error'] ?? 'Failed to fetch attendance detail');
    }

    final data = res['data'];
    List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    if (data is Map && data['attendances'] is List) {
      rows = List<Map<String, dynamic>>.from(
        (data['attendances'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } else if (data is List) {
      rows = List<Map<String, dynamic>>.from(
        data.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }

    final sameDate = rows.where((r) => (r['date'] ?? '') == _dateStr).toList();
    final masuk = sameDate.where((r) => (r['type'] ?? '') == 'masuk').toList()
      ..sort((a, b) =>
          (a['time'] ?? '').toString().compareTo((b['time'] ?? '').toString()));
    final pulang =
        sameDate.where((r) => (r['type'] ?? '') == 'pulang').toList()
          ..sort((a, b) => (a['time'] ?? '')
              .toString()
              .compareTo((b['time'] ?? '').toString()));

    final firstIn = masuk.isNotEmpty ? masuk.first : null;
    final lastOut = pulang.isNotEmpty ? pulang.last : null;

    String? _urlFrom(Map<String, dynamic>? m) {
      if (m == null) return null;
      final p = (m['image_path'] ?? '').toString();
      return p.isEmpty ? null : '${ApiService.baseUrl}/$p';
    }

    return _UserDayDetail(
      inTime: (firstIn?['time'] ?? '').toString(),
      inLocation: (firstIn?['location'] ?? '').toString(),
      inImageUrl: _urlFrom(firstIn),
      outTime: (lastOut?['time'] ?? '').toString(),
      outLocation: (lastOut?['location'] ?? '').toString(),
      outImageUrl: _urlFrom(lastOut),
    );
  }

  void _openDetail(Map<String, dynamic> userRow) {
    final userId = (userRow['user_id'] ?? '').toString();
    final name = (userRow['name'] ?? '-').toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: FutureBuilder<_UserDayDetail>(
                future: _fetchUserDayDetail(userId),
                builder: (context, snap) {
                  return Column(
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
                              Icons.person_outline,
                              color: _primaryBlue,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Attendance Detail',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                                Text(
                                  '${_dateFmt.format(_date)} • $name',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: _textSecondary),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (snap.connectionState != ConnectionState.done)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snap.hasError)
                        const Expanded(
                          child: Center(child: Text('Failed to load detail')),
                        )
                      else
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            children: [
                              _DetailBlock(
                                title: 'Check In',
                                time: snap.data!.inTime,
                                location: snap.data!.inLocation,
                                imageUrl: snap.data!.inImageUrl,
                              ),
                              const SizedBox(height: 16),
                              _DetailBlock(
                                title: 'Check Out',
                                time: snap.data!.outTime,
                                location: snap.data!.outLocation,
                                imageUrl: snap.data!.outImageUrl,
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  String _toHM(String hhmmOrHhmmss) {
    final t = hhmmOrHhmmss.split(':');
    final h = (t.isNotEmpty ? int.tryParse(t[0]) ?? 0 : 0)
        .toString()
        .padLeft(2, '0');
    final m =
        (t.length > 1 ? int.tryParse(t[1]) ?? 0 : 0).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final me = auth.user;
    final role = (me?.role ?? '').toLowerCase().trim();
    final isExporter = role == 'manager' || role == 'superadmin';
    final canView =
        role == 'admin' || role == 'superadmin' || role == 'manager';

    if (!canView) {
      return Scaffold(
        appBar: AppBar(title: const Text('Staff Attendance')),
        body: const Center(child: Text('Unauthorized')),
      );
    }

    final grouped = _groupedByBranch;

    // ✅ Hanya admin/superadmin yang boleh ganti branch via chips
    final canFilterBranch = role == 'admin' || role == 'superadmin';
    final meBranch = (me?.branch ?? '').toString();

    return Scaffold(
      backgroundColor: _lightGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Staff Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: _textPrimary,
            fontSize: 18,
          ),
        ),
        actions: [
          if (isExporter)
            IconButton(
              tooltip: 'Download Excel',
              onPressed: _downloadExcelXlsx,
              icon: const Icon(Icons.download_rounded, color: _textSecondary),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refreshKey.currentState?.show(),
            icon: const Icon(Icons.refresh_rounded, color: _textSecondary),
          ),
        ],
      ),
      body: RefreshIndicator(
        key: _refreshKey,
        color: _primaryBlue,
        onRefresh: _load,
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Search name, email, branch',
                            hintStyle: const TextStyle(fontSize: 13),
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _search.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      _search.clear();
                                      setState(() {});
                                    },
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
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _lightGray,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _borderGray),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today,
                                  size: 16, color: _textSecondary),
                              const SizedBox(width: 8),
                              Text(
                                _dateFmt.format(_date),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _StatusFilterChips(
                    value: _filter,
                    onChanged: (f) => setState(() => _filter = f),
                  ),
                  const SizedBox(height: 12),

                  // ✅ Kondisional: admin/superadmin bisa pilih branch, lainnya hanya melihat badge branch aktif
                  if (canFilterBranch)
                    _BranchFilterChips(
                      branches: _allBranches,
                      selected: _selectedBranch,
                      onChanged: (b) => setState(() => _selectedBranch = b),
                    )
                  else
                    _CurrentBranchBadge(meBranch),

                  const SizedBox(height: 12),
                  _StatsRow(
                    total: _countTotal,
                    checkedIn: _countCheckedIn,
                    checkedOut: _countCheckedOut,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : grouped.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.search_off,
                                      size: 64, color: _textSecondary),
                                  SizedBox(height: 16),
                                  Text(
                                    'No attendance data found',
                                    style: TextStyle(
                                        fontSize: 14, color: _textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: grouped.length,
                          itemBuilder: (context, index) {
                            final branchName = grouped.keys.elementAt(index);
                            final branchData = grouped[branchName]!;

                            // Stats per branch
                            final branchTotal = branchData.length;
                            final branchIn = branchData.where(_isIn).length;
                            final branchOut = branchData.where(_isOut).length;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Branch Header
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        _primaryBlue,
                                        Color(0xFF1976D2)
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _primaryBlue.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.store_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              branchName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$branchTotal employees • $branchIn in • $branchOut out',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$branchTotal',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: _primaryBlue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Staff Cards
                                ...branchData.asMap().entries.map((entry) {
                                  final e = entry.value;
                                  final name = (e['name'] ?? '-').toString();
                                  final email = (e['email'] ?? '-').toString();
                                  final branch =
                                      (e['branch'] ?? '-').toString();
                                  final position =
                                      (e['position'] ?? '-').toString();
                                  final roleTxt =
                                      (e['role'] ?? '-').toString();
                                  final inTime =
                                      (e['first_in'] ?? '')
                                              .toString()
                                              .isEmpty
                                          ? null
                                          : (e['first_in'] as String);
                                  final outTime =
                                      (e['last_out'] ?? '')
                                              .toString()
                                              .isEmpty
                                          ? null
                                          : (e['last_out'] as String);
                                  final dur = _calcDuration(inTime, outTime);
                                  final late = _isLate(inTime);
                                  final lateDur = _lateDuration(inTime);

                                  String initials = name.trim().isEmpty
                                      ? 'U'
                                      : name
                                          .trim()
                                          .split(RegExp(r'\s+'))
                                          .where((p) => p.isNotEmpty)
                                          .take(2)
                                          .map((p) => p[0].toUpperCase())
                                          .join();

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: _StaffCard(
                                      initials: initials,
                                      name: name,
                                      email: email,
                                      branch: branch,
                                      position: position,
                                      role: roleTxt,
                                      inTime: inTime == null
                                          ? '-'
                                          : _toHM(inTime),
                                      outTime: outTime == null
                                          ? '-'
                                          : _toHM(outTime),
                                      durationText: _fmtDurHuman(dur),
                                      isLate: late,
                                      lateText: lateDur == null
                                          ? null
                                          : _fmtDurHuman(lateDur),
                                      onTap: () => _openDetail(e),
                                    ),
                                  );
                                }).toList(),

                                const SizedBox(height: 12),
                              ],
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

class _CurrentBranchBadge extends StatelessWidget {
  const _CurrentBranchBadge(this.branch);
  final String branch;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          border: Border.all(color: Color(0xFFE0E5ED)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.store_rounded, size: 14, color: Color(0xFF6B7785)),
            const SizedBox(width: 6),
            Text(
              'Branch: ${branch.isEmpty ? "-" : branch}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7785),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchFilterChips extends StatelessWidget {
  const _BranchFilterChips({
    required this.branches,
    required this.selected,
    required this.onChanged,
  });
  final List<String> branches;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (branches.isEmpty) return const SizedBox.shrink();

    Widget chip(String? value, String label, {bool isAll = false}) {
      final isSelected = selected == value;
      return InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1565C0) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1565C0)
                  : const Color(0xFFE0E5ED),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAll
                    ? Icons.store_mall_directory_rounded
                    : Icons.store_rounded,
                size: 14,
                color: isSelected ? Colors.white : const Color(0xFF6B7785),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF6B7785),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Filter by Branch',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7785),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(null, 'All Branches', isAll: true),
              const SizedBox(width: 8),
              ...branches.map((b) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: chip(b, b),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({required this.value, required this.onChanged});
  final _AttendanceFilter value;
  final ValueChanged<_AttendanceFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_AttendanceFilter v, String label) {
      final selected = value == v;
      return InkWell(
        onTap: () => onChanged(v),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1565C0) : const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  selected ? const Color(0xFF1565C0) : const Color(0xFFE0E5ED),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF6B7785),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip(_AttendanceFilter.all, 'All'),
          const SizedBox(width: 8),
          chip(_AttendanceFilter.checkedIn, 'Checked In'),
          const SizedBox(width: 8),
          chip(_AttendanceFilter.notCheckedIn, 'Not In'),
          const SizedBox(width: 8),
          chip(_AttendanceFilter.checkedOut, 'Checked Out'),
          const SizedBox(width: 8),
          chip(_AttendanceFilter.notCheckedOut, 'Not Out'),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.total,
    required this.checkedIn,
    required this.checkedOut,
  });
  final int total;
  final int checkedIn;
  final int checkedOut;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E5ED)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF6B7785)),
            const SizedBox(width: 8),
            Text(
              label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF6B7785)),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          stat('Total', '$total', Icons.people_alt_rounded),
          const SizedBox(width: 8),
          stat('In', '$checkedIn', Icons.login_rounded),
          const SizedBox(width: 8),
          stat('Out', '$checkedOut', Icons.logout_rounded),
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.initials,
    required this.name,
    required this.email,
    required this.branch,
    required this.position,
    required this.role,
    required this.inTime,
    required this.outTime,
    required this.durationText,
    required this.onTap,
    this.isLate = false,
    this.lateText,
  });

  final String initials;
  final String name;
  final String email;
  final String branch;
  final String position;
  final String role;
  final String inTime;
  final String outTime;
  final String durationText;
  final VoidCallback onTap;
  final bool isLate;
  final String? lateText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E5ED)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    child: Text(
                      initials,
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
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2332),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7785),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF6B7785)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(icon: Icons.work_outline, text: position),
                _Tag(icon: Icons.shield_outlined, text: role),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeInfo(
                    icon: Icons.login_rounded,
                    label: 'In',
                    value: inTime,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeInfo(
                    icon: Icons.logout_rounded,
                    label: 'Out',
                    value: outTime,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeInfo(
                    icon: Icons.timer_outlined,
                    label: 'Work',
                    value: durationText,
                  ),
                ),
              ],
            ),
            if (isLate) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Late ${lateText ?? ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E5ED)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF6B7785)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2332),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  const _TimeInfo({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7785)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7785),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2332),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.title,
    required this.time,
    required this.location,
    required this.imageUrl,
  });
  final String title;
  final String time;
  final String location;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E5ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  title.contains('In')
                      ? Icons.login_rounded
                      : Icons.logout_rounded,
                  color: const Color(0xFF1565C0),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2332),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PreviewImage(url: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      label: 'Time',
                      value: time.isEmpty ? '-' : time,
                    ),
                    const SizedBox(height: 8),
                    if (location.isEmpty)
                      const _InfoRow(label: 'Location', value: '-')
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Location',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7785),
                            ),
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => _openInMaps(context, location),
                            child: Text(
                              location,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1565C0),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openInMaps(context, location),
                            icon: const Icon(Icons.map_rounded, size: 16),
                            label: const Text('Open Maps'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7785),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2332),
          ),
        ),
      ],
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const size = 80.0;
    if (url == null || url!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E5ED)),
        ),
        child: const Icon(
          Icons.image_not_supported_outlined,
          color: Color(0xFF6B7785),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E5ED)),
          ),
          child: const Icon(
            Icons.broken_image_outlined,
            color: Color(0xFF6B7785),
          ),
        ),
      ),
    );
  }
}

class _UserDayDetail {
  final String inTime;
  final String inLocation;
  final String? inImageUrl;
  final String outTime;
  final String outLocation;
  final String? outImageUrl;

  _UserDayDetail({
    required this.inTime,
    required this.inLocation,
    required this.inImageUrl,
    required this.outTime,
    required this.outLocation,
    required this.outImageUrl,
  });
}

String _buildGmapsUrl(String raw) {
  final loc = raw.trim();
  if (loc.isEmpty) return 'https://maps.google.com';

  final parts = loc.split(',').map((e) => e.trim()).toList();
  if (parts.length == 2) {
    final lat = double.tryParse(parts[0]);
    final lng = double.tryParse(parts[1]);
    if (lat != null && lng != null) {
      return 'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    }
  }

  final q = Uri.encodeComponent(loc);
  return 'https://www.google.com/maps/search/?api=1&query=$q';
}

Future<void> _openInMaps(BuildContext context, String raw) async {
  final url = _buildGmapsUrl(raw);
  final ok = await launchUrlString(url, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cannot open Google Maps')),
    );
  }
}
