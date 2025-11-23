// // import 'package:shared_preferences/shared_preferences.dart';

// // class DatabaseService {
// //   Future<void> saveAttendance(Map<String, dynamic> attendanceData) async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final userId = attendanceData['userId'];
    
// //     // Get existing attendances
// //     final String? attendancesString = prefs.getString('attendances_$userId');
// //     List<Map<String, dynamic>> attendances = [];
    
// //     if (attendancesString != null) {
// //       // Convert string to list of maps (in a real app, use proper serialization)
// //       attendances = List<Map<String, dynamic>>.from(
// //         (attendancesString.split(';').map((item) {
// //           final parts = item.split(':');
// //           return {
// //             'date': parts[0],
// //             'type': parts[1],
// //             'time': parts[2],
// //           };
// //         })).toList()
// //       );
// //     }
    
// //     // Add new attendance
// //     attendances.add({
// //       'date': attendanceData['date'],
// //       'type': attendanceData['type'],
// //       'time': attendanceData['time'],
// //       'location': attendanceData['location'],
// //       'photoPath': attendanceData['photoPath'],
// //     });
    
// //     // Save back to shared preferences
// //     final String newAttendancesString = attendances.map((attendance) {
// //       return "${attendance['date']}:${attendance['type']}:${attendance['time']}";
// //     }).join(';');
    
// //     await prefs.setString('attendances_$userId', newAttendancesString);
// //   }

// //   Future<List<Map<String, dynamic>>> getAttendances(String userId) async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final String? attendancesString = prefs.getString('attendances_$userId');
    
// //     if (attendancesString == null) {
// //       return [];
// //     }
    
// //     // Convert string to list of maps (simplified for demo)
// //     return attendancesString.split(';').map((item) {
// //       final parts = item.split(':');
// //       return {
// //         'date': parts[0],
// //         'type': parts[1],
// //         'time': parts[2],
// //       };
// //     }).toList();
// //   }
// // }

// // import 'dart:io';
// // import '../services/api_service.dart';

// // class DatabaseService {
// //   Future<void> saveAttendance({
// //     required String userId,
// //     required String type,
// //     required String time,
// //     required String location,
// //     required File image,
// //   }) async {
// //     // Panggil API untuk menyimpan absensi
// //     final result = await ApiService.saveAttendance(
// //       userId: userId,
// //       type: type,
// //       time: time,
// //       location: location,
// //       image: image,
// //     );

// //     if (!result['success']) {
// //       throw Exception(result['message']);
// //     }
// //   }

// //   Future<List<Map<String, dynamic>>> getAttendances(String userId) async {
// //     // Panggil API untuk mendapatkan data absensi
// //     final result = await ApiService.getAttendances(userId);

// //     if (result['success']) {
// //       return List<Map<String, dynamic>>.from(result['attendances']);
// //     } else {
// //       throw Exception(result['message']);
// //     }
// //   }
// // }

// import 'dart:io';
// import '../services/api_service.dart';

// class DatabaseService {
//   Future<void> saveAttendance({
//     required String userId,
//     required String type,
//     required String time,
//     required String location,
//     required File image,
//   }) async {
//     // Panggil API untuk menyimpan absensi
//     final result = await ApiService.saveAttendance(
//       userId: userId,
//       type: type,
//       time: time,
//       location: location,
//       image: image,
//     );

//     if (result['success'] != true) {
//       throw Exception(result['message']);
//     }
//   }

//   Future<List<Map<String, dynamic>>> getAttendances(String userId) async {
//     // Panggil API untuk mendapatkan data absensi
//     final result = await ApiService.getAttendances(userId);

//     if (result['success'] == true) {
//       return List<Map<String, dynamic>>.from(result['attendances']);
//     } else {
//       throw Exception(result['message']);
//     }
//   }
// }


import 'dart:io';
import '../services/api_service.dart';

class DatabaseService {
  Future<void> saveAttendance({
    required String userId,
    required String type,
    required String time,
    required String location,
    required File image,
  }) async {
    final result = await ApiService.saveAttendance(
      userId: userId,
      type: type,
      time: time,
      location: location,
      image: image,
    );

    if (result['success'] != true) {
      // Tetap lempar saat simpan agar user tahu kalau absen gagal
      throw Exception(result['error'] ?? 'Gagal menyimpan absensi');
    }
  }

  Future<List<Map<String, dynamic>>> getAttendances(String userId) async {
    try {
      final result = await ApiService.getAttendances(userId);

      if (result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data'] ?? {});
        final list = List<Map<String, dynamic>>.from(data['attendances'] ?? []);
        return list;
      }

      // Kalau server balas error (termasuk 404), jangan ganggu UI: return list kosong
      return <Map<String, dynamic>>[];
    } catch (_) {
      // Jaga-jaga jaringan/format JSON
      return <Map<String, dynamic>>[];
    }
  }
}
