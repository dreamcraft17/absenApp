import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Definisi item menu di Home yang bisa diatur visibilitasnya.
class HomeMenuItemDef {
  final String key;
  final String title;
  final String description;

  const HomeMenuItemDef({
    required this.key,
    required this.title,
    required this.description,
  });
}

/// Semua menu yang mau kita kontrol.
class HomeMenuItems {
  static const mySchedule = HomeMenuItemDef(
    key: 'my_schedule',
    title: 'My Schedule',
    description: 'Card / menu jadwal pribadi staff.',
  );

  static const products = HomeMenuItemDef(
    key: 'products',
    title: 'Products',
    description: 'Card katalog produk di section Products & Inventory.',
  );

  static const stock = HomeMenuItemDef(
    key: 'stock',
    title: 'Stock',
    description: 'Card stok & request di section Products & Inventory.',
  );

  static const employees = HomeMenuItemDef(
    key: 'employees',
    title: 'Employees',
    description: 'Menu Employees di section Employee Management.',
  );

  static const importEmployees = HomeMenuItemDef(
    key: 'import_employees',
    title: 'Import Employees',
    description: 'Menu Import Excel/CSV di section Employee Management.',
  );

  static const manageUsers = HomeMenuItemDef(
    key: 'manage_users',
    title: 'Manage Users',
    description: 'Menu Manage Users di section Admin & Team.',
  );

  static const staffAttendance = HomeMenuItemDef(
    key: 'staff_attendance',
    title: 'Staff Attendance',
    description: 'Menu Staff Attendance di section Admin & Team.',
  );

  static const workSchedules = HomeMenuItemDef(
    key: 'work_schedules',
    title: 'Work Schedules',
    description: 'Menu Work Schedules di section Admin & Team.',
  );

  static const leaveRequest = HomeMenuItemDef(
    key: 'leave_request',
    title: 'Leave Request',
    description: 'Menu pengajuan cuti.',
  );

  static const permissionRequest = HomeMenuItemDef(
    key: 'permission_request',
    title: 'Permission',
    description: 'Menu pengajuan izin.',
  );

  static const reviewAbsence = HomeMenuItemDef(
    key: 'review_absence',
    title: 'Review Absence Requests',
    description: 'Menu approval cuti/izin.',
  );

  static const all = <HomeMenuItemDef>[
    mySchedule,
    products,
    stock,
    employees,
    importEmployees,
    manageUsers,
    staffAttendance,
    workSchedules,
    leaveRequest,
    permissionRequest,
    reviewAbsence,
  ];
}

class HomeMenuConfigService {
  static const _prefix = 'home_menu_config_';

  /// Role yang kita support (bisa disesuaikan dengan backend).
  static const supportedRoles = <String>[
    'staff',
    'manager',
    'admin',
    'superadmin',
  ];

  /// Load konfigurasi untuk role tertentu.
  /// Return: map `keyMenu -> bool` (true = tampil).
  static Future<Map<String, bool>> loadForRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${role.toLowerCase()}';

    final jsonStr = prefs.getString(key);
    if (jsonStr == null) {
      // default: semua aktif
      return {
        for (final item in HomeMenuItems.all) item.key: true,
      };
    }

    try {
      final obj = jsonDecode(jsonStr);
      if (obj is Map<String, dynamic>) {
        final result = <String, bool>{};
        for (final item in HomeMenuItems.all) {
          final v = obj[item.key];
          result[item.key] = v == null ? true : v == true;
        }
        return result;
      }
    } catch (_) {
      // kalau rusak, fallback semua ON
    }

    return {
      for (final item in HomeMenuItems.all) item.key: true,
    };
  }

  /// Simpan konfigurasi untuk role tertentu.
  static Future<void> saveForRole(
    String role,
    Map<String, bool> config,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix${role.toLowerCase()}';

    // Pastikan key yang disimpan cuma yang known.
    final normalized = <String, bool>{
      for (final item in HomeMenuItems.all)
        item.key: config[item.key] ?? true,
    };

    await prefs.setString(key, jsonEncode(normalized));
  }
}
