// lib/services/api_service.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

// Tambahan agar Multipart punya MIME type yang benar saat upload Excel
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = "https://epluseapi.epluseglobal.com";
  static const Duration _defaultTimeout = Duration(seconds: 12);

  // ======== SIMPLE SESSION CACHE (di memori) ========
  static Map<String, dynamic>? _me;
  static String? posOrigin;
  static final Map<String, String> _posOriginByKey = {};
//   static String? getPosOriginCached(String posKey) {
//   final k = posKey.trim().toLowerCase();
//   return _posOriginByKey[k];
// }

static String? getPosOriginCached(String posKey) {
  if (posKey.trim().isEmpty) return null;
  return _posOriginCache[posKey.trim().toLowerCase()];
}

static final Map<String, String> _posOriginCache = {};

static String? getPosOriginCahced(String posKey) => _posOriginCache[posKey];

static void setPosOriginCache(String posKey, String origin) {
  if (posKey.trim().isEmpty || origin.trim().isEmpty) return;
  _posOriginCache[posKey.trim().toLowerCase()] = Uri.tryParse(origin)?.origin ?? origin;
}




    static void setPosOrigin(String? url) {
    if (url == null || url.trim().isEmpty) {
      posOrigin = null;
      return;
    }
    final u = Uri.tryParse(url.trim());
    if (u != null && u.hasScheme) {
      posOrigin = u.origin; // simpan hanya origin
    }
  }

 static Future<String?> resolvePosOrigin({required String posKey, String? branch}) async {
  final key = (posKey.isNotEmpty ? posKey : (branch ?? '')).trim();
  if (key.isEmpty) return null;

  // pakai cache kalau sudah ada
  final cached = getPosOriginCached(key);
  if ((cached ?? '').isNotEmpty) return cached;

  try {
    final res = await http.post(
      Uri.parse('$baseUrl/pos_access_api.php'),
      body: {
        'action': 'resolve_base',
        'pos_key': key,
        'branch': key,
      },
    ).timeout(_defaultTimeout);

    final obj = json.decode(res.body);
    if (obj is Map && obj['success'] == true) {
      final origin = (obj['pos_origin'] ?? obj['base_url'] ?? '').toString().trim();
      if (Uri.tryParse(origin)?.hasScheme == true) {
        setPosOriginCache(key, origin);
        return getPosOriginCached(key);
      }
    }
  } catch (_) {/* ignore */}
  return null;
}



static String _normalizePosPath(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;

  s = s.replaceAll('\\', '/');                              // windows → slash
  s = s.replaceFirst(RegExp(r'^(?:\./|/)+'), '');           // buang ./ atau // di depan
  s = s.replaceAll(RegExp(r'(?:^|/)pos-api/pos-api(?:/|$)'), 'pos-api/'); // dedup
  s = s.replaceFirst(RegExp(r'^public/'), '');              // buang public/ saja
  // ⚠️ JANGAN hapus 'pos-api/public/' → biarkan apa adanya

  if (!s.startsWith('/')) s = '/$s';
  return s;
}


// di dalam class ApiService, tambah fungsi ini (tanpa menyentuh yang lain)
static Future<String?> resolvePosOriginDirect({
  required String posKey,
  required String branch,
}) async {
  try {
    final uri = Uri.parse('$baseUrl/pos_access_api.php');
    final resp = await http.post(uri, body: {
      'action': 'get_pos_origin',
      'pos_key': posKey,
      'branch': branch,
    }).timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) return null;

    final data = jsonDecode(resp.body);
    final origin = data['pos_origin'] ?? data['origin'] ?? data['base_url'];
    if (origin != null && origin.toString().startsWith('http')) {
      return Uri.parse(origin.toString()).origin;
    }
    return null;
  } catch (e) {
    debugPrint('resolvePosOriginDirect error: $e');
    return null;
  }
}

// ApiService
static Future<Map<String, dynamic>> setItemTracking({
  required int userId,
  required String posKey,
  required int requestId,
  required int itemId,
  required String trackingNumber,
  String? userPosition, // kirim untuk guard purchasing
}) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/stock_request_api.php'),
      body: {
        'action': 'update_tracking',
        'user_id': '$userId',
        'pos_key': posKey,
        'request_id': '$requestId',
        'item_id': '$itemId',
        'tracking_number': trackingNumber,
        if ((userPosition ?? '').isNotEmpty) 'user_position': userPosition!,
      },
    ).timeout(const Duration(seconds: 12));
    return _decode(res);
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}



// Helper: absolutize dengan POS origin (fallback ke absensi base origin)
// ApiService
static String absolutizeWithPosOrigin(String raw, {String? posOrigin}) {
  if (raw.isEmpty) return '';

  final u = Uri.tryParse(raw);
  if (u != null && u.hasScheme) {
    // absolute
    if ((u.host == 'localhost' || u.host == '127.0.0.1') && (posOrigin ?? '').isNotEmpty) {
      final o = Uri.tryParse(posOrigin!);
      if (o != null && o.hasScheme) {
        return Uri(
          scheme: o.scheme,
          host: o.host,
          port: o.hasPort ? o.port : null,
          path: u.path,
          query: u.query,
          fragment: u.fragment,
        ).toString();
      }
    }
    return raw; // absolute & bukan localhost → biarkan
  }

  // relatif → resolve pakai posOrigin kalau ada
  if ((posOrigin ?? '').isNotEmpty) {
    final origin = Uri.tryParse(posOrigin!)?.origin ?? '';
    final norm = _normalizePosPath(raw);
    return Uri.parse(origin).resolve(norm).toString();
  }

  // tanpa origin → biarkan (biar kelihatan salahnya di UI, jangan fallback ke baseUrl)
  return raw;
}

  /// Simpan profil user yang sedang login (opsional dipanggil setelah login / saat restore session)
  static void setCurrentUser(Map<String, dynamic> user) {
    _me = Map<String, dynamic>.from(user);
  }

  /// Hapus session lokal
  static void clearCurrentUser() {
    _me = null;
  }

  /// Ambil user yang sedang login dari cache lokal.
  /// (Kalau mau dari server, buat endpoint sendiri dan ganti implementasi ini.)
  static Future<Map<String, dynamic>> currentUser() async {
    return {'success': true, 'data': _me ?? {}};
  }



  // --- Register ---
  static Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String password,
    required String branch,
    required String position,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/register.php'),
            body: {
              'name': name,
              'email': email,
              'password': password,
              'branch': branch,
              'position': position,
            },
          )
          .timeout(_defaultTimeout);
      final obj = _decode(res);
      // kalau backend balikin data user, simpan
      final data = obj['data'] ?? obj;
      if (obj['success'] == true && data is Map) _me = Map<String, dynamic>.from(data);
      return obj;
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // --- Login (pakai name/username) ---
  static Future<Map<String, dynamic>> loginUser(
    String name,
    String password,
  ) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/login.php'),
            body: {'name': name, 'password': password},
          )
          .timeout(_defaultTimeout);
      final obj = _decode(res);
      // simpan user ke cache kalau tersedia
      final data = obj['data'] ?? obj;
      if (obj['success'] == true && data is Map) _me = Map<String, dynamic>.from(data);
      return obj;
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // --- Admin create user ---
  static Future<Map<String, dynamic>> adminCreateUser({
    required String name,
    required String email,
    required String password,
    required String branch,
    required String position,
    required String role,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin_create_user.php'),
        body: {
          'name': name,
          'email': email,
          'password': password,
          'branch': branch,
          'position': position,
          'role': role,
        },
      ).timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // --- List users ---
  static Future<Map<String, dynamic>> listUsers({
    String? query,
    String? position,
    String? roleScope,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/get_users.php'),
            body: {
              if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
              if (position != null && position.trim().isNotEmpty) 'position': position.trim(),
              if (roleScope != null && roleScope.trim().isNotEmpty) 'role_scope': roleScope.trim(),
            },
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // --- Save attendance ---
  static Future<Map<String, dynamic>> saveAttendance({
    required String userId,
    required String type,
    required String time,
    required String location,
    required File image,
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload_image.php'),
      );
      req.files.add(await http.MultipartFile.fromPath(
        'image',
        image.path,
        filename: path.basename(image.path),
      ));

      final streamed = await req.send().timeout(_defaultTimeout);
      final imgBytes = await streamed.stream.toBytes();
      final imgJson = json.decode(String.fromCharCodes(imgBytes));

      if (streamed.statusCode < 200 || streamed.statusCode >= 300 || imgJson['success'] != true) {
        return {
          'success': false,
          'error': imgJson['error'] ?? 'Gagal upload gambar'
        };
      }

      final String imagePath = (imgJson['data']?['image_path'] ?? '').toString();

      final res = await http
          .post(
            Uri.parse('$baseUrl/save_attendance.php'),
            body: {
              'user_id': userId,
              'type': type,
              'time': time,
              'location': location,
              'image_path': imagePath,
            },
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // --- Get attendance list ---
  static Future<Map<String, dynamic>> getAttendances(String userId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/get_attendance.php'),
            body: {'user_id': userId},
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // --- Staff attendance (admin/manager) ---
  // static Future<Map<String, dynamic>> getStaffAttendance({
  //   required String date,
  //   String? roleScope,
  // }) async {
  //   try {
  //     final res = await http.post(
  //       Uri.parse('$baseUrl/get_staff_attendance.php'),
  //       body: {
  //         'date': date,
  //         if (roleScope != null) 'role_scope': roleScope,
  //       },
  //     ).timeout(_defaultTimeout);
  //     return _decode(res);
  //   } on TimeoutException catch (e) {
  //     return {'success': false, 'error': 'Timeout : $e'};
  //   } catch (e) {
  //     return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  //   }
  // }

  static Future<Map<String, dynamic>> getStaffAttendance({
  required String date,
  String? roleScope,
  String? branch, // <= tambah
}) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/get_staff_attendance.php'),
      body: {
        'date': date,
        if (roleScope != null) 'role_scope': roleScope,
        if (branch != null && branch.isNotEmpty) 'branch': branch, // <= kirim branch
      },
    ).timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout : $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}


  // --- Submit cuti/izin ---
  static Future<Map<String, dynamic>> submitAbsenceRequest({
    required String userId,
    required String type,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/submit_absence_request.php'),
        body: {
          'user_id': userId,
          'type': type,
          'start_date': startDate,
          'end_date': endDate,
          'reason': reason,
        },
      ).timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // --- List pengajuan cuti/izin ---
  static Future<Map<String, dynamic>> listAbsenceRequests({
    required String scope,
    required String userId,
    String? status,
    String? type,
  }) async {
    try {
      final body = <String, String>{
        'scope': scope,
        'user_id': userId,
        if (status != null && status.isNotEmpty) 'status': status,
        if (type != null && type.isNotEmpty) 'type': type,
      };
      final res = await http.post(
        Uri.parse('$baseUrl/list_absence_requests.php'),
        body: body,
      ).timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // --- Approve/Reject pengajuan ---
  static Future<Map<String, dynamic>> updateAbsenceStatus({
    required String requestId,
    required String action,
    required String approverId,
    required String approverRole,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/update_absence_status.php'),
        body: {
          'request_id': requestId,
          'action': action,
          'approver_id': approverId,
          'approver_role': approverRole,
        },
      ).timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // ====================== UTILITIES ======================
  static Future<Map<String, dynamic>> testConnection({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final sw = Stopwatch();
    sw.start();
    try {
      final uri = Uri.parse('$baseUrl/login.php');
      final res = await http.get(uri).timeout(timeout);
      sw.stop();

      final ok = res.statusCode >= 200 && res.statusCode < 500;
      return {
        'success': ok,
        'status': res.statusCode,
        'latency_ms': sw.elapsedMilliseconds,
        'message': ok ? 'Server reachable' : 'Server unreachable',
      };
    } on TimeoutException catch (e) {
      sw.stop();
      return {
        'success': false,
        'error': 'Timeout: $e',
        'latency_ms': sw.elapsedMilliseconds,
      };
    } catch (e) {
      sw.stop();
      return {
        'success': false,
        'error': e.toString(),
        'latency_ms': sw.elapsedMilliseconds,
      };
    }
  }

static Map<String, dynamic> _decode(http.Response res) {
  Map<String, dynamic>? parsed;
  try {
    final obj = json.decode(res.body);
    if (obj is Map<String, dynamic>) parsed = obj;
  } catch (_) {
    // body bukan JSON, biarin
  }

  // 2xx → sukses
  if (res.statusCode >= 200 && res.statusCode < 300) {
    if (parsed != null) {
      return parsed.containsKey('success') ? parsed : {'success': true, ...parsed};
    }
    return {'success': true, 'data': res.body};
  }

  // non-2xx → angkat pesan dari body kalau ada
  final msg = (parsed?['error'] ?? parsed?['message'] ?? 'HTTP ${res.statusCode}').toString();
  return {
    'success': false,
    'error': msg,
    'status': res.statusCode,
    if (parsed != null) 'data': parsed,
    'raw': res.body,
  };
}

  // ====================== POS PRODUCTS (proxy) ======================
  static Future<Map<String, dynamic>> listProducts({
    String? updatedSince,
    int? page,
    int? perPage,
    bool includeCategory = true,
  }) async {
    try {
      final body = <String, String>{
        'action': 'get_products',
        if (updatedSince != null && updatedSince.isNotEmpty) 'updatedSince': updatedSince,
        if (page != null) 'page': '$page',
        if (perPage != null) 'per_page': '$perPage',
        if (includeCategory) 'include': 'category',
      };
      final res = await http
          .post(
            Uri.parse('$baseUrl/product_api.php'),
            body: body,
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<Map<String, dynamic>> getProductDetail({
    required String sku,
    bool includeCategory = true,
  }) async {
    try {
      final body = <String, String>{
        'action': 'get_product_detail',
        'sku': sku,
        if (includeCategory) 'include': 'category',
      };
      final res = await http
          .post(
            Uri.parse('$baseUrl/product_api.php'),
            body: body,
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // ====================== STOCK REQUEST ======================
  static Future<Map<String, dynamic>> sendStockRequest({
    required String requestedBy,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final body = {
        'requested_by': requestedBy,
        'items': items.map((e) => {
              'name': e['name'],
              'request_qty': e['request_qty'],
              if ((e['note'] ?? '').toString().trim().isNotEmpty) 'note': e['note'],
            }).toList(),
        'notes': notes ?? '',
      };

      final res = await http
          .post(
            Uri.parse('$baseUrl/stock_request_api.php'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<Map<String, dynamic>> listStockRequests({
    String? requestStatus,
    int page = 1,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/stock_request_api.php'),
            body: {
              'action': 'list',
              'page': '$page',
              if (requestStatus != null && requestStatus.isNotEmpty)
                'request_status': requestStatus,
            },
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }


  static Future<Map<String, dynamic>> updateStockRequestApproval({
  required int userId,
  required String posKey,
  required int requestId,
  required String action, // 'approve' | 'reject'
}) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/stock_request_api.php'),
      body: {
        'action': 'update_approval',  // route
        'user_id': '$userId',
        'pos_key': posKey,
        'request_id': '$requestId',
        'decision': action,           // ⬅️ kirim keputusan di key TERPISAH
      },
    ).timeout(_defaultTimeout);
    return _decode(res);
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

// ApiService (tambahkan di bawah fungsi POS/Stock)
static Future<Map<String, dynamic>> uploadRequestItemProof({
  required int userId,
  required String posKey,
  required int requestId,
  required int itemId,
  required String resultStatus, // 'oke' or 'defect'
  String? defectNote,
  required List<File> images,
}) async {
  try {
    final uri = Uri.parse('$baseUrl/stock_request_api.php');
    final req = http.MultipartRequest('POST', uri)
      ..fields['action']        = 'upload_item_proof'
      ..fields['user_id']       = userId.toString()
      ..fields['pos_key']       = posKey
      ..fields['request_id']    = requestId.toString()
      ..fields['item_id']       = itemId.toString()
      ..fields['result_status'] = resultStatus
      ..fields['defect_note']   = defectNote ?? '';

    for (final f in images) {
      req.files.add(await http.MultipartFile.fromPath('files[]', f.path));
    }

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    return _decode(res); // pakai helper di ApiService kamu
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}




  static Future<Map<String, dynamic>> updateStockRequestStatus({
    required int id,
    required String requestStatus,
    required String userPosition,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/stock_request_api.php'),
            headers: {
              'X-User-Position': userPosition,
            },
            body: {
              'action': 'update_status',
              'id': id.toString(),
              'request_status': requestStatus,
            },
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // ====================== EMPLOYEE APIs ======================
  static Future<Map<String, dynamic>> getEmployees({
    String? branch,
    String? department,
    String? position,
    String status = 'active',
    String? search,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/employee_api.php'),
            body: {
              'action': 'get_employees',
              if (branch != null && branch.isNotEmpty) 'branch': branch,
              if (department != null && department.isNotEmpty) 'department': department,
              if (position != null && position.isNotEmpty) 'position': position,
              'status': status,
              if (search != null && search.isNotEmpty) 'search': search,
            },
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<Map<String, dynamic>> importEmployees(File excelFile) async {
    try {
      final uri = Uri.parse('$baseUrl/employee_api.php');
      final request = http.MultipartRequest('POST', uri)
        ..fields['action'] = 'import_excel';

      // Tentukan MIME berdasar file path; kalau gagal, fallback ke octet-stream
      final mime = lookupMimeType(excelFile.path) ?? 'application/octet-stream';
      final mediaType = MediaType.parse(mime);

      request.files.add(await http.MultipartFile.fromPath(
        'excel_file',
        excelFile.path,
        filename: _normalizeExcelFilename(excelFile.path),
        contentType: mediaType,
      ));

      // Upload Excel bisa agak lama → pakai timeout 30 detik
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  // Pastikan ekstensi yang dikirim rapi & valid (xlsx/xls/csv)
  static String _normalizeExcelFilename(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    final normalizedExt = (ext == 'xlsx' || ext == 'xls' || ext == 'csv') ? ext : 'xlsx';
    return 'employees_import.$normalizedExt';
  }

  static Future<Map<String, dynamic>> getEmployeeDetail(String employeeId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/employee_api.php'),
            body: {
              'action': 'get_employee_detail',
              'employee_id': employeeId,
            },
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<Map<String, dynamic>> updateEmployee({
    required String employeeId,
    required String name,
    required String branch,
    required String position,
    String? department,
    required String phone,
    required String email,
    required String status,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/employee_api.php'),
            body: {
              'action': 'update_employee',
              'employee_id': employeeId,
              'name': name,
              'branch': branch,
              'position': position,
              'department': department ?? '',
              'phone': phone,
              'email': email,
              'status': status,
            },
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<Map<String, dynamic>> deleteEmployee(String employeeId) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/employee_api.php'),
            body: {
              'action': 'delete_employee',
              'employee_id': employeeId,
            },
          )
          .timeout(_defaultTimeout);
      return _decode(res);
    } on TimeoutException catch (e) {
      return {'success': false, 'error': 'Timeout: $e'};
    } catch (e) {
      return {'success': false, 'error': 'Terjadi kesalahan: $e'};
    }
  }

  static Future<Map<String, dynamic>> createEmployee({
  required String name,
  required String branch,
  required String position,
  String? department,
  required String phone,
  required String email,
  String status = 'active',
  String? joinDate, // optional, format 'YYYY-MM-DD'
}) async {
  try {
    final res = await http
        .post(
          Uri.parse('$baseUrl/employee_api.php'),
          body: {
            'action': 'create_employee',
            'name': name,
            'branch': branch,
            'position': position,
            'department': department ?? '',
            'phone': phone,
            'email': email,
            'status': status,
            if (joinDate != null && joinDate.isNotEmpty) 'join_date': joinDate,
          },
        )
        .timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

// === Update user ===
static Future<Map<String, dynamic>> updateUser({
  required String id,
  required String name,
  required String email,
  required String branch,
  required String position,
  String? department,
  required String role,
  String? password, // optional: bila null/empty tidak diubah
}) async {
  try {
    final body = <String, String>{
      'id': id,
      'name': name,
      'email': email,
      'branch': branch,
      'position': position,
      'department': department ?? '',
      'role': role,
    };
    if (password != null && password.trim().isNotEmpty) {
      body['password'] = password.trim();
    }

    final res = await http
        .post(
          Uri.parse('$baseUrl/update_user.php'),
          body: body,
        )
        .timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

// === Delete user ===
static Future<Map<String, dynamic>> deleteUser(String id) async {
  try {
    final res = await http
        .post(
          Uri.parse('$baseUrl/delete_user.php'),
          body: {'id': id},
        )
        .timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

// === Profile: GET ===
// === PROFILE APIs ===
static Future<Map<String, dynamic>> getProfile(int userId) async {
  try {
    final res = await http
        .post(
          Uri.parse('$baseUrl/profile_api.php'),
          body: {
            'action': 'get_profile',
            'user_id': userId.toString(),
          },
        )
        .timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

static Future<Map<String, dynamic>> updateProfile({
  required int userId,
  required String name,
  required String email,
  required String branch,
  required String position,
  String? department,
}) async {
  try {
    final res = await http
        .post(
          Uri.parse('$baseUrl/profile_api.php'),
          body: {
            'action': 'update_profile',
            'user_id': userId.toString(),
            'name': name,
            'email': email,
            'branch': branch,
            'position': position,
            'department': department ?? '',
          },
        )
        .timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

static Future<Map<String, dynamic>> uploadProfilePicture({
  required int userId,
  required String userName,
  required String branch,
  required File file,
}) async {
  try {
    final uri = Uri.parse('$baseUrl/profile_api.php');
    final req = http.MultipartRequest('POST', uri)
      ..fields['action']   = 'upload_avatar'
      ..fields['user_id']  = userId.toString()
      ..fields['user_name']= userName
      ..fields['branch']   = branch;

    req.files.add(await http.MultipartFile.fromPath('avatar', file.path));

    final streamed = await req.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}


// static Future<Map<String, dynamic>> listShiftPresets() async {
//   try {
//     final res = await http.post(
//       Uri.parse('$baseUrl/schedule_api.php'),
//       body: {'action': 'list_presets'},
//     ).timeout(_defaultTimeout);
//     return _decode(res);
//   } catch (e) {
//     return {'success': false, 'error': 'Terjadi kesalahan: $e'};
//   }
// }

// Shift Presets
static Future<Map<String, dynamic>> listShiftPresets() async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/schedule_api.php'),
      body: {'action': 'list_presets'},
    ).timeout(_defaultTimeout);
    return _decode(res);
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

static Future<Map<String, dynamic>> saveShiftPreset({
  String? id,
  required String code,
  String? startTime,
  String? endTime,
  String? notes,
}) async {
  try {
    final body = {
      'action': 'save_preset',
      if (id != null && id.isNotEmpty) 'id': id,
      'code': code,
      'start_time': startTime ?? '',
      'end_time': endTime ?? '',
      'notes': notes ?? '',
    };
    final res = await http.post(
      Uri.parse('$baseUrl/schedule_api.php'),
      body: body,
    ).timeout(_defaultTimeout);
    return _decode(res);
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

// Work Schedules
static Future<Map<String, dynamic>> getSchedulesByBranchMonth({
  required String branch,
  required int year,
  required int month,
  String? search,
  String status = 'active',
}) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/schedule_api.php'),
      body: {
        'action': 'get_month_by_branch',
        'branch': branch,
        'year': year.toString(),
        'month': month.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        'status': status,
      },
    ).timeout(_defaultTimeout);
    return _decode(res);
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}



static Future<Map<String, dynamic>> deleteProfilePicture({
  required int userId,
}) async {
  try {
    final res = await http
        .post(
          Uri.parse('$baseUrl/profile_api.php'),
          body: {
            'action': 'delete_avatar',
            'user_id': userId.toString(),
          },
        )
        .timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}


static Future<Map<String, dynamic>> upsertSchedule({
  required int employeeId,
  required String branch,
  required String workDate,
  required String shiftCode,
  String? startTime,
  String? endTime,
  String? notes,
  int? userId,
}) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/schedule_api.php'),
      body: {
        'action': 'upsert_schedule',
        'employee_id': employeeId.toString(),
        'branch': branch,
        'work_date': workDate,
        'shift_code': shiftCode,
        'start_time': startTime ?? '',
        'end_time': endTime ?? '',
        'notes': notes ?? '',
        if (userId != null) 'user_id': userId.toString(),
      },
    ).timeout(_defaultTimeout);
    return _decode(res);
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

static Future<Map<String, dynamic>> deleteSchedule(int id) async {
  try {
    final res = await http.post(
      Uri.parse('$baseUrl/schedule_api.php'),
      body: {'action': 'delete_schedule', 'id': id.toString()},
    ).timeout(_defaultTimeout);
    return _decode(res);
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}


static Future<Map<String, dynamic>> findEmployeeForUser(String userId) async {
  try {
    final res = await http
        .post(
          Uri.parse('$baseUrl/employee_api.php'),
          body: {'action': 'find_employee_for_user', 'user_id': userId},
        )
        .timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}

static Future<Map<String, dynamic>> getSchedulesByEmployeeMonth({
  required int employeeId,
  required int year,
  required int month,
}) async {
  try {
    final res = await http
        .post(
          Uri.parse('$baseUrl/schedule_api.php'),
          body: {
            'action': 'get_month_by_employee',
            'employee_id': '$employeeId',
            'year': '$year',
            'month': '$month',
            'status': 'active',
          },
        )
        .timeout(_defaultTimeout);
    return _decode(res);
  } on TimeoutException catch (e) {
    return {'success': false, 'error': 'Timeout: $e'};
  } catch (e) {
    return {'success': false, 'error': 'Terjadi kesalahan: $e'};
  }
}



  static Future<Map<String, dynamic>> listUserPosOptions({required int userId}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/pos_access_api.php'),
        body: {'action': 'list_options', 'user_id': '$userId'},
      ).timeout(_defaultTimeout);
      return _decode(res);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

static Future<Map<String, dynamic>> listProductsByBranch({
    required int userId,
    required String posKey,
    int page = 1,
    int perPage = 50,
    String include = 'category',
    String search = '',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/product_api.php'),
        body: {
          'action': 'get_products',
          'user_id': '$userId',
          'pos_key': posKey,
          'page': '$page',
          'per_page': '$perPage',
          'include': include,
          if (search.isNotEmpty) 'search': search,
        },
      ).timeout(_defaultTimeout);
      return _decode(res);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

static Future<Map<String, dynamic>> sendStockRequestScoped({
    required int userId,
    required String posKey,
    required String requestedBy,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/stock_request_api.php'),
        body: {
          'action': 'send',
          'user_id': '$userId',
          'pos_key': posKey,
          'requested_by': requestedBy,
          'items': jsonEncode(items),
          'notes': notes ?? '',
        },
      ).timeout(_defaultTimeout);
      return _decode(res);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

static Future<Map<String, dynamic>> listStockRequestsScoped({
    required int userId,
    required String posKey,
    String? requestStatus,
    int page = 1,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/stock_request_api.php'),
        body: {
          'action': 'list',
          'user_id': '$userId',
          'pos_key': posKey,
          'page': '$page',
          if (requestStatus != null && requestStatus.isNotEmpty) 'request_status': requestStatus,
        },
      ).timeout(_defaultTimeout);
      return _decode(res);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addProductByBranch({
  required int userId,
  required String posKey,
  required String sku,
  required String name,
  required int priceCents,
  int stock = 0,
  String? category,
}) async {
  final url = Uri.parse('$baseUrl/product_api.php'); // endpoint absensi
  final body = {
    'action': 'add_product',
    'user_id': '$userId',
    'pos_key': posKey,
    'sku': sku,
    'name': name,
    'price_cents': '$priceCents',
    'stock': '$stock',
  };
  if (category != null && category.trim().isNotEmpty) {
    body['category'] = category.trim();
  }
  final res = await http.post(url, body: body);
  return jsonDecode(res.body) as Map<String, dynamic>;
}

// ====================== POS ORIGIN CACHE & RESOLVER ======================




}

