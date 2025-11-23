// // import 'package:flutter/foundation.dart';
// // import 'package:shared_preferences/shared_preferences.dart';
// // import '../models/user_model.dart';

// // class AuthService with ChangeNotifier {
// //   User? _user;
// //   bool _isLoggedIn = false;

// //   User? get user => _user;
// //   bool get isLoggedIn => _isLoggedIn;

// //   // Simulasi database pengguna
// //   final List<Map<String, String>> _usersDatabase = [];

// //   AuthService() {
// //     _loadUserData();
// //   }

// //   Future<void> _loadUserData() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     final userId = prefs.getString('userId');
// //     final userEmail = prefs.getString('userEmail');
// //     final userName = prefs.getString('userName');
// //     final userBranch = prefs.getString('userBranch');
// //     final userPosition = prefs.getString('userPosition');

// //     if (userId != null && userEmail != null) {
// //       _user = User(
// //         id: userId,
// //         name: userName ?? '',
// //         email: userEmail,
// //         branch: userBranch ?? '',
// //         position: userPosition ?? '',
// //       );
// //       _isLoggedIn = true;
// //       notifyListeners();
// //     }
// //   }

// //   Future<bool> register({
// //     required String name,
// //     required String email,
// //     required String password,
// //     required String branch,
// //     required String position,
// //   }) async {
// //     // Cek jika email sudah terdaftar
// //     if (_usersDatabase.any((user) => user['email'] == email)) {
// //       return false;
// //     }

// //     // Simpan user baru
// //     final newUser = {
// //       'id': DateTime.now().millisecondsSinceEpoch.toString(),
// //       'name': name,
// //       'email': email,
// //       'password': password, // Dalam aplikasi nyata, password harus di-hash
// //       'branch': branch,
// //       'position': position,
// //     };

// //     _usersDatabase.add(newUser);

// //     // Simpan ke shared preferences
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.setString('userId', newUser['id']!);
// //     await prefs.setString('userEmail', newUser['email']!);
// //     await prefs.setString('userName', newUser['name']!);
// //     await prefs.setString('userBranch', newUser['branch']!);
// //     await prefs.setString('userPosition', newUser['position']!);

// //     _user = User(
// //       id: newUser['id']!,
// //       name: name,
// //       email: email,
// //       branch: branch,
// //       position: position,
// //     );
// //     _isLoggedIn = true;
// //     notifyListeners();

// //     return true;
// //   }

// //   Future<bool> login(String email, String password) async {
// //     // Cari user dengan email dan password yang sesuai
// //     final user = _usersDatabase.firstWhere(
// //       (user) => user['email'] == email && user['password'] == password,
// //       orElse: () => {},
// //     );

// //     if (user.isNotEmpty) {
// //       // Simpan ke shared preferences
// //       final prefs = await SharedPreferences.getInstance();
// //       await prefs.setString('userId', user['id']!);
// //       await prefs.setString('userEmail', user['email']!);
// //       await prefs.setString('userName', user['name']!);
// //       await prefs.setString('userBranch', user['branch']!);
// //       await prefs.setString('userPosition', user['position']!);

// //       _user = User(
// //         id: user['id']!,
// //         name: user['name']!,
// //         email: user['email']!,
// //         branch: user['branch']!,
// //         position: user['position']!,
// //       );
// //       _isLoggedIn = true;
// //       notifyListeners();
// //       return true;
// //     }

// //     return false;
// //   }

// //   Future<void> logout() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.remove('userId');
// //     await prefs.remove('userEmail');
// //     await prefs.remove('userName');
// //     await prefs.remove('userBranch');
// //     await prefs.remove('userPosition');

// //     _user = null;
// //     _isLoggedIn = false;
// //     notifyListeners();
// //   }
// // }

// import 'package:flutter/foundation.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../models/user_model.dart';
// import '../services/api_service.dart'; // Import API Service

// class AuthService with ChangeNotifier {
//   User? _user;
//   bool _isLoggedIn = false;

//   User? get user => _user;
//   bool get isLoggedIn => _isLoggedIn;

//   AuthService() {
//     _loadUserData();
//   }

//   Future<void> _loadUserData() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userId = prefs.getString('userId');
//     final userEmail = prefs.getString('userEmail');
//     final userName = prefs.getString('userName');
//     final userBranch = prefs.getString('userBranch');
//     final userPosition = prefs.getString('userPosition');

//     if (userId != null && userEmail != null) {
//       _user = User(
//         id: userId,
//         name: userName ?? '',
//         email: userEmail,
//         branch: userBranch ?? '',
//         position: userPosition ?? '',
//       );
//       _isLoggedIn = true;
//       notifyListeners();
//     }
//   }

//   Future<bool> register({
//     required String name,
//     required String email,
//     required String password,
//     required String branch,
//     required String position,
//   }) async {
//     // Panggil API register
//     final result = await ApiService.registerUser(
//       name: name,
//       email: email,
//       password: password,
//       branch: branch,
//       position: position,
//     );

//     if (result['success']) {
//       // Simpan ke shared preferences
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userId', result['user_id']);
//       await prefs.setString('userEmail', email);
//       await prefs.setString('userName', name);
//       await prefs.setString('userBranch', branch);
//       await prefs.setString('userPosition', position);

//       _user = User(
//         id: result['user_id'],
//         name: name,
//         email: email,
//         branch: branch,
//         position: position,
//       );
//       _isLoggedIn = true;
//       notifyListeners();

//       return true;
//     }

//     return false;
//   }

//   Future<bool> login(String email, String password) async {
//     // Panggil API login
//     final result = await ApiService.loginUser(email, password);

//     if (result['success']) {
//       // Simpan ke shared preferences
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setString('userId', result['user_id']);
//       await prefs.setString('userEmail', email);
//       await prefs.setString('userName', result['name']);
//       await prefs.setString('userBranch', result['branch']);
//       await prefs.setString('userPosition', result['position']);

//       _user = User(
//         id: result['user_id'],
//         name: result['name'],
//         email: email,
//         branch: result['branch'],
//         position: result['position'],
//       );
//       _isLoggedIn = true;
//       notifyListeners();
//       return true;
//     }

//     return false;
//   }

//   Future<void> logout() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('userId');
//     await prefs.remove('userEmail');
//     await prefs.remove('userName');
//     await prefs.remove('userBranch');
//     await prefs.remove('userPosition');

//     _user = null;
//     _isLoggedIn = false;
//     notifyListeners();
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthService with ChangeNotifier {
  User? _user;
  bool _isLoggedIn = false;

  User? get user => _user;
  bool get isLoggedIn => _isLoggedIn;

  AuthService() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final userEmail = prefs.getString('userEmail');
    final userName = prefs.getString('userName');
    final userBranch = prefs.getString('userBranch');
    final userPosition = prefs.getString('userPosition');
    final userRole = prefs.getString('userRole');

    if (userId != null && userEmail != null) {
      _user = User(
        id: userId,
        name: userName ?? '',
        email: userEmail,
        branch: userBranch ?? '',
        position: userPosition ?? '',
        role: userRole ?? 'staff',
      );
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String branch,
    required String position,
  }) async {
    final result = await ApiService.registerUser(
      name: name,
      email: email,
      password: password,
      branch: branch,
      position: position,
    );
    return result['success'] == true;
  }

  // === LOGIN pakai name
  Future<bool> login(String name, String password) async {
    final result = await ApiService.loginUser(name, password);

    if (result['success'] == true) {
      final data = Map<String, dynamic>.from(result['data'] ?? {});
      final id = (data['user_id'] ?? '').toString();
      final realName = (data['name'] ?? '').toString();
      final email = (data['email'] ?? '').toString();
      final branch = (data['branch'] ?? '').toString();
      final position = (data['position'] ?? '').toString();
      final role = (data['role'] ?? 'staff').toString();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', id);
      await prefs.setString('userEmail', email);
      await prefs.setString('userName', realName);
      await prefs.setString('userBranch', branch);
      await prefs.setString('userPosition', position);
      await prefs.setString('userRole', role);

      _user = User(
        id: id,
        name: realName,
        email: email,
        branch: branch,
        position: position,
        role: role,
      );
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('userName');
    await prefs.remove('userBranch');
    await prefs.remove('userPosition');
    await prefs.remove('userRole');
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }

  Future<void> _mergeAndPersistUser(Map<String, dynamic> d) async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final newUser = _user!.copyWith(
      name: (d['name'] ?? _user!.name)?.toString(),
      email: (d['email'] ?? _user!.email)?.toString(),
      branch: (d['branch'] ?? _user!.branch)?.toString(),
      position: (d['position'] ?? _user!.position)?.toString(),
      role: (d['role'] ?? _user!.role ?? 'staff')?.toString(),
    );

    _user = newUser;

    await prefs.setString('userId', newUser.id.toString());
    await prefs.setString('userEmail', newUser.email);
    await prefs.setString('userName', newUser.name);
    await prefs.setString('userBranch', newUser.branch);
    await prefs.setString('userPosition', newUser.position);
    await prefs.setString('userRole', newUser.role ?? 'staff');
    notifyListeners();
  }

  void updateUser(User updated){
    _user = updated;
    notifyListeners();
  }

  Future<bool> refreshProfileFromServer() async{
    if(_user == null) return false;
    final res = await ApiService.getProfile(int.parse(_user!.id.toString()));
    if(res['success'] == true){
      final data = Map<String, dynamic>.from(res['data'] ?? {});
      await _mergeAndPersistUser(data);
      return true;
    }
    return false;
  }
}
