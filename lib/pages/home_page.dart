import 'package:ee_employee/pages/product_catalog_shell.dart';
import 'package:ee_employee/services/home_menu_config_service.dart';
import 'my_schedule_page.dart';
import 'package:ee_employee/pages/profile_page.dart';
import 'package:ee_employee/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'product_catalog_page.dart';
import 'stock_page.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'attendance_page.dart';
import 'manage_users_page.dart';
import 'staff_attendance_page.dart';
import 'absence_request_page.dart';
import 'absence_requests_page.dart';
import 'product_list_page.dart';
import 'stock_history_page.dart';
import 'employee_list_page.dart';
import 'schedule_management_page.dart';
import 'home_menu_settings_page.dart';

// ===== Modern Color Palette =====
const Color kPrimary = Color(0xFF6366F1); // Indigo
const Color kSecondary = Color.fromARGB(255, 212, 6, 68); // Purple
const Color kAccent = Color(0xFF06B6D4); // Cyan
const Color kDanger = Color(0xFFEF4444); // Red
const Color kSuccess = Color(0xFF10B981); // Green
const Color kWarning = Color(0xFFF59E0B); // Amber
const Color kDark = Color(0xFF1F2937); // Dark Gray
const Color kLight = Color(0xFFF9FAFB); // Light Gray
const Color kWhite = Colors.white;
const Color kText = Color(0xFF111827);
const Color kTextLight = Color(0xFF6B7280);
const Color kBorder = Color(0xFFE5E7EB);

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  String? _checkIn;
  String? _checkOut;
  String? _workHours;
  bool _loading = true;
  bool _warnNoHistory = false;
  String? _avatarUrl;
  AnimationController? _animController;
  Animation<double>? _fadeAnimation;

  // Konfigurasi menu dari HomeMenuConfigService
  Map<String, bool> _menuConfig = {};

  bool _isMenuEnabled(String key) {
    // kalau belum ada konfigurasi, default ON
    if (_menuConfig.isEmpty) return true;
    return _menuConfig[key] ?? true;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController!,
      curve: Curves.easeOut,
    );
    _loadTodayAttendance();
    _loadAvatar();
    _loadMenuConfig(); // load config per role
    _animController!.forward();
  }

  @override
  void dispose() {
    _animController?.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() => _loading = true);
    try {
      await Future.wait([_loadTodayAttendance(), _reloadProfile(), _loadMenuConfig()]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMenuConfig() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;
    final role = (user?.role ?? 'staff').toLowerCase();

    final cfg = await HomeMenuConfigService.loadForRole(role);
    if (!mounted) return;
    setState(() {
      _menuConfig = cfg;
    });
  }

  Future<void> _reloadProfile() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    final res = await ApiService.getProfile(int.parse(user.id.toString()));
    if (!mounted) return;

    if (res['success'] == true) {
      final d = Map<String, dynamic>.from(res['data'] ?? {});
      final raw = (d['avatar_url'] ?? d['avatar'] ?? '').toString();
      final url = _absUrl(raw);
      setState(() {
        _avatarUrl = url.isEmpty
            ? null
            : '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      });
      auth.updateUser(
        user.copyWith(
          name: d['name'] ?? user.name,
          email: d['email'] ?? user.email,
          branch: d['branch'] ?? user.branch,
          position: d['position'] ?? user.position,
          role: d['role'] ?? user.role,
        ),
      );
    }
  }

  String _absUrl(String raw) {
    if (raw.isEmpty) return '';
    var u = raw.trim();
    if (!u.startsWith('http')) {
      final base = ApiService.baseUrl.replaceAll(RegExp(r'\/$'), '');
      u = '$base/${u.replaceFirst(RegExp(r'^\/'), '')}';
    }
    u = u.replaceFirst(RegExp(r'^http:'), 'https:');
    return u;
  }

  Future<void> _loadAvatar() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;
    if (user == null) return;

    final res = await ApiService.getProfile(int.parse(user.id.toString()));
    if (!mounted) return;

    if (res['success'] == true) {
      final d = Map<String, dynamic>.from(res['data'] ?? {});
      final raw = (d['avatar_url'] ?? d['avatar'] ?? '').toString();
      final url = _absUrl(raw);
      setState(() {
        _avatarUrl = url.isEmpty
            ? null
            : '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      });
    }
  }

  DateTime _parseDateTimeFlex(String yyyyMmDd, String hhmm) {
    final d = yyyyMmDd.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    final t = hhmm.split(':');
    final h = int.tryParse(t[0]) ?? 0;
    final m = t.length > 1 ? int.tryParse(t[1]) ?? 0 : 0;
    return DateTime(d[0], d[1], d[2], h, m);
  }

  String _toHM(String hhmm) {
    final t = hhmm.split(':');
    final h = (int.tryParse(t[0]) ?? 0).toString().padLeft(2, '0');
    final m = (t.length > 1 ? int.tryParse(t[1]) ?? 0 : 0).toString().padLeft(
          2,
          '0',
        );
    return '$h:$m';
  }

  String _formatWorkDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;

    final hhmm =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    final human = (h > 0)
        ? '$h H${m > 0 ? ' $m min' : ''}'
        : (m > 0 ? '$m min' : '<1 min');

    return '$hhmm ($human)';
  }

  Future<void> _loadTodayAttendance() async {
    setState(() {
      _loading = true;
      _warnNoHistory = false;
      _workHours = null;
    });

    final auth = Provider.of<AuthService>(context, listen: false);
    final user = auth.user;
    if (user == null) {
      setState(() {
        _loading = false;
        _warnNoHistory = true;
      });
      return;
    }

    final db = DatabaseService();
    final list = await db.getAttendances(user.id);
    if (!mounted) return;

    final today = DateTime.now().toString().split(' ').first;

    List<Map<String, dynamic>> typeToday(String type) =>
        list
            .where(
              (e) =>
                  (e['type'] ?? '').toString().toLowerCase() == type &&
                  (e['date'] ?? '').toString() == today,
            )
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
          ..sort(
            (a, b) => _parseDateTimeFlex(today, (a['time'] ?? '').toString())
                .compareTo(
                  _parseDateTimeFlex(today, (b['time'] ?? '').toString()),
                ),
          );

    final ins = typeToday('masuk');
    final outs = typeToday('pulang');

    final latestIn = ins.isNotEmpty
        ? _toHM((ins.last['time'] ?? '').toString())
        : null;
    final latestOut = outs.isNotEmpty
        ? _toHM((outs.last['time'] ?? '').toString())
        : null;

    Duration? totalDuration;
    if (ins.isNotEmpty && outs.isNotEmpty) {
      final firstInDT = _parseDateTimeFlex(
        today,
        (ins.first['time'] ?? '').toString(),
      );
      final lastOutDT = _parseDateTimeFlex(
        today,
        (outs.last['time'] ?? '').toString(),
      );
      if (!lastOutDT.isBefore(firstInDT)) {
        totalDuration = lastOutDT.difference(firstInDT);
      }
    }

    setState(() {
      _checkIn = latestIn;
      _checkOut = latestOut;
      _workHours = totalDuration == null
          ? null
          : _formatWorkDuration(totalDuration);
      _loading = false;
      _warnNoHistory = list.isEmpty;
    });
  }

  Future<void> _goAttendance(BuildContext context, String type) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AttendancePage(type: type)),
    );
    if (mounted) await _loadTodayAttendance();
  }

  void _showAvatarDialog() {
    final hasAvatar = (_avatarUrl != null && _avatarUrl!.isNotEmpty);
    
    if (!hasAvatar) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _avatarUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(40),
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 60,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final user = auth.user;

    final initials = (user?.name ?? '-')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    final roleLC = (user?.role ?? '').trim().toLowerCase();
    final isAdmin = roleLC == 'admin' || roleLC == 'superadmin';
    final isManager = roleLC == 'manager';
    final isSuperAdmin = roleLC == 'superadmin';
    final canReview = isManager || isSuperAdmin;

    return Scaffold(
      backgroundColor: kLight,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              color: kPrimary,
              onRefresh: _refreshAll,
              child: CustomScrollView(
                slivers: [
                  // ===== Modern App Bar =====
                  SliverAppBar(
                    expandedHeight: 140,
                    collapsedHeight: 60,
                    toolbarHeight: 60,
                    floating: false,
                    pinned: true,
                    backgroundColor: kPrimary,
                    flexibleSpace: FlexibleSpaceBar(
                      background: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [kPrimary, kSecondary],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: _fadeAnimation != null
                                ? FadeTransition(
                                    opacity: _fadeAnimation!,
                                    child: _ModernHeader(
                                      initials: initials.isEmpty
                                          ? 'U'
                                          : initials,
                                      name: user?.name ?? '-',
                                      branch: user?.branch ?? '-',
                                      position: user?.position ?? '-',
                                      avatarUrl: _avatarUrl,
                                      onAvatarTap: _showAvatarDialog,
                                    ),
                                  )
                                : _ModernHeader(
                                    initials: initials.isEmpty ? 'U' : initials,
                                    name: user?.name ?? '-',
                                    branch: user?.branch ?? '-',
                                    position: user?.position ?? '-',
                                    avatarUrl: _avatarUrl,
                                    onAvatarTap: _showAvatarDialog,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Profile',
                        icon: const Icon(Icons.person_outline, color: kWhite),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ProfilePage(),
                          ),
                        ).then((_) => _loadAvatar()),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh, color: kWhite),
                        onPressed: _refreshAll,
                      ),
                      IconButton(
                        tooltip: 'Logout',
                        icon: const Icon(Icons.logout, color: kWhite),
                        onPressed: () async {
                          await auth.logout();
                          if (!mounted) return;
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                      ),
                    ],
                  ),

                  // ===== Quick Actions =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _GradientButton(
                                icon: Icons.login,
                                label: 'Check In',
                                gradient: const LinearGradient(
                                  colors: [kSuccess, Color(0xFF059669)],
                                ),
                                onPressed: _checkIn != null
                                    ? null
                                    : () => _goAttendance(context, 'masuk'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _GradientButton(
                                icon: Icons.logout,
                                label: 'Check Out',
                                gradient: const LinearGradient(
                                  colors: [kDanger, Color(0xFFDC2626)],
                                ),
                                onPressed: _checkOut != null
                                    ? null
                                    : () => _goAttendance(context, 'pulang'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== Today's Stats =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatsCard(
                              icon: Icons.login,
                              title: 'Check In',
                              value: _checkIn ?? '--:--',
                              color: kSuccess,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatsCard(
                              icon: Icons.logout,
                              title: 'Check Out',
                              value: _checkOut ?? '--:--',
                              color: kDanger,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatsCard(
                              icon: Icons.access_time,
                              title: 'Hours',
                              value: _workHours ?? '--:--',
                              color: kAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===== My Schedule (only for staff + menu enabled) =====
                  if (roleLC == 'staff' && _isMenuEnabled('my_schedule')) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: const _SectionHeader(
                          'My Schedule',
                          icon: Icons.calendar_today,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: _FeatureCard(
                                icon: Icons.calendar_today,
                                title: 'My Schedule',
                                subtitle: 'Lihat jadwal saya',
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFF4F46E5)
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const MySchedulePage(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // ===== Products & Inventory =====
                  if (_isMenuEnabled('products') ||
                      _isMenuEnabled('stock'))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: const _SectionHeader(
                          'Products & Inventory',
                          icon: Icons.inventory_2,
                        ),
                      ),
                    ),

                  if (_isMenuEnabled('products') ||
                      _isMenuEnabled('stock'))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Builder(
                          builder: (context) {
                            final auth = Provider.of<AuthService>(
                              context,
                              listen: false,
                            );
                            final user = auth.user;
                            final roleLC = (user?.role ?? '')
                                .trim()
                                .toLowerCase();
                            final branchLC = (user?.branch ?? '')
                                .trim()
                                .toLowerCase();

                            final isAdmin =
                                roleLC == 'admin' || roleLC == 'superadmin';
                            final isManager = roleLC == 'manager';
                            final isHeadOffice = branchLC == 'head office';

                            final canSeeProducts =
                                (isAdmin || isManager) && !isHeadOffice;

                            // kalau mau balikin rule lama, bisa pakai ini:
                            // if (!canSeeProducts) { ... }

                            return Row(
                              children: [
                                if (_isMenuEnabled('products'))
                                  Expanded(
                                    child: _FeatureCard(
                                      icon: Icons.category,
                                      title: 'Products',
                                      subtitle: 'Browse catalog',
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF8B5CF6),
                                          Color(0xFF7C3AED),
                                        ],
                                      ),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const ProductCatalogShell(),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_isMenuEnabled('products') &&
                                    _isMenuEnabled('stock'))
                                  const SizedBox(width: 12),
                                if (_isMenuEnabled('stock'))
                                  Expanded(
                                    child: _FeatureCard(
                                      icon: Icons.inventory,
                                      title: 'Stock',
                                      subtitle: 'Check & request',
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF06B6D4),
                                          Color(0xFF0891B2),
                                        ],
                                      ),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const StockPage(),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                  // ===== Employee Management =====
                  if ((isAdmin || isManager) &&
                      (_isMenuEnabled('employees') ||
                          _isMenuEnabled('import_employees')))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: const _SectionHeader(
                          'Employee Management',
                          icon: Icons.people,
                        ),
                      ),
                    ),
                  if ((isAdmin || isManager) &&
                      (_isMenuEnabled('employees') ||
                          _isMenuEnabled('import_employees')))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Row(
                          children: [
                            if (_isMenuEnabled('employees'))
                              Expanded(
                                child: _FeatureCard(
                                  icon: Icons.groups,
                                  title: 'Employees',
                                  subtitle: 'View directory',
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFF59E0B),
                                      Color(0xFFD97706),
                                    ],
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const EmployeeListPage(),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isMenuEnabled('employees') &&
                                _isMenuEnabled('import_employees'))
                              const SizedBox(width: 12),
                            if (_isMenuEnabled('import_employees'))
                              Expanded(
                                child: _FeatureCard(
                                  icon: Icons.upload_file,
                                  title: 'Import',
                                  subtitle: 'Excel/CSV',
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF10B981),
                                      Color(0xFF059669),
                                    ],
                                  ),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const EmployeeListPage(),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // ===== Admin & Team =====
                  if ((isAdmin || isManager) &&
                      (_isMenuEnabled('manage_users') ||
                          _isMenuEnabled('staff_attendance') ||
                          _isMenuEnabled('work_schedules') ||
                          isSuperAdmin))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: const _SectionHeader(
                          'Admin & Team',
                          icon: Icons.admin_panel_settings,
                        ),
                      ),
                    ),
                  if ((isAdmin || isManager) &&
                      (_isMenuEnabled('manage_users') ||
                          _isMenuEnabled('staff_attendance') ||
                          _isMenuEnabled('work_schedules') ||
                          isSuperAdmin))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Builder(
                          builder: (context) {
                            final auth = Provider.of<AuthService>(
                              context,
                              listen: false,
                            );
                            final user = auth.user;
                            final roleLC = (user?.role ?? '')
                                .trim()
                                .toLowerCase();
                            final isAdminLocal =
                                roleLC == 'admin' || roleLC == 'superadmin';
                            final isSuperAdminLocal =
                                roleLC == 'superadmin';

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    if (isAdminLocal &&
                                        _isMenuEnabled('manage_users'))
                                      Expanded(
                                        child: _MenuCard(
                                          icon: Icons.group_add,
                                          title: 'Manage Users',
                                          color: kPrimary,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ManageUsersPage(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (isAdminLocal &&
                                        _isMenuEnabled('manage_users') &&
                                        _isMenuEnabled('staff_attendance'))
                                      const SizedBox(width: 12),
                                    if (_isMenuEnabled('staff_attendance'))
                                      Expanded(
                                        child: _MenuCard(
                                          icon: Icons.event_available,
                                          title: 'Staff Attendance',
                                          color: kAccent,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const StaffAttendancePage(),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_isMenuEnabled('work_schedules'))
                                  _MenuCard(
                                    icon: Icons.calendar_today,
                                    title: 'Work Schedules',
                                    color: kSecondary,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ScheduleManagementPage(),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                if (isSuperAdminLocal)
                                  _MenuCard(
                                    icon: Icons.tune,
                                    title: 'Home Menu Settings',
                                    color: kPrimary,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const HomeMenuSettingsPage(),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),

                  // ===== Leave & Permission =====
                  if (_isMenuEnabled('leave_request') ||
                      _isMenuEnabled('permission_request') ||
                      (canReview && _isMenuEnabled('review_absence')))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        child: const _SectionHeader(
                          'Leave & Permission',
                          icon: Icons.beach_access,
                        ),
                      ),
                    ),
                  if (_isMenuEnabled('leave_request') ||
                      _isMenuEnabled('permission_request'))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Row(
                          children: [
                            if (_isMenuEnabled('leave_request'))
                              Expanded(
                                child: _MenuCard(
                                  icon: Icons.beach_access,
                                  title: 'Leave Request',
                                  color: kSuccess,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AbsenceRequestPage(
                                              type: 'cuti'),
                                    ),
                                  ),
                                ),
                              ),
                            if (_isMenuEnabled('leave_request') &&
                                _isMenuEnabled('permission_request'))
                              const SizedBox(width: 12),
                            if (_isMenuEnabled('permission_request'))
                              Expanded(
                                child: _MenuCard(
                                  icon: Icons.event_busy,
                                  title: 'Permission',
                                  color: kWarning,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AbsenceRequestPage(
                                              type: 'izin'),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (canReview && _isMenuEnabled('review_absence'))
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: _MenuCard(
                          icon: Icons.approval,
                          title: 'Review Absence Requests',
                          color: kDanger,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AbsenceRequestsPage(),
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_warnNoHistory)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: const _InfoCard(
                          icon: Icons.info_outline,
                          text: 'No attendance history available.',
                          color: kTextLight,
                        ),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }
}

// =================== MODERN WIDGETS ===================

class _ModernHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String branch;
  final String position;
  final String? avatarUrl;
  final VoidCallback onAvatarTap;

  const _ModernHeader({
    required this.initials,
    required this.name,
    required this.branch,
    required this.position,
    this.avatarUrl,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = (avatarUrl != null && avatarUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onAvatarTap,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kWhite.withOpacity(0.3), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  backgroundColor: kWhite,
                  foregroundColor: kPrimary,
                  backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back,',
                    style: TextStyle(
                      color: kWhite.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: kWhite.withOpacity(0.8),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Branch : $branch',
                              style: TextStyle(
                                color: kWhite.withOpacity(0.8),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.badge,
                            color: kWhite.withOpacity(0.8),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Position : $position',
                              style: TextStyle(
                                color: kWhite.withOpacity(0.8),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: isDisabled ? null : gradient,
        color: isDisabled ? kBorder : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: kPrimary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isDisabled ? kTextLight : kWhite, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isDisabled ? kTextLight : kWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatsCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: kTextLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: kText,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader(this.title, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: kPrimary, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            color: kText,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [kPrimary, kSecondary]),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kWhite.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: kWhite, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: kWhite.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: kText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: kTextLight, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color == kWarning ? kDark : color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}