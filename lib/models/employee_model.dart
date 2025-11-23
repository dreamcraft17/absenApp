// class Employee {
//   final String id;
//   final String name;
//   final String branch;
//   final String position;
//   final String phone;
//   final String email;
//   final String joinDate;
//   final String status;
//   final String createdAt;
//   final EmployeeStats? stats;

//   Employee({
//     required this.id,
//     required this.name,
//     required this.branch,
//     required this.position,
//     required this.phone,
//     required this.email,
//     required this.joinDate,
//     required this.status,
//     required this.createdAt,
//     this.stats,
//   });

//   factory Employee.fromMap(Map<String, dynamic> map) {
//     return Employee(
//       id: map['id']?.toString() ?? '',
//       name: map['name']?.toString() ?? '',
//       branch: map['branch']?.toString() ?? '',
//       position: map['position']?.toString() ?? '',
//       phone: map['phone']?.toString() ?? '',
//       email: map['email']?.toString() ?? '',
//       joinDate: map['join_date']?.toString() ?? '',
//       status: map['status']?.toString() ?? 'active',
//       createdAt: map['created_at']?.toString() ?? '',
//       stats: map['stats'] != null ? EmployeeStats.fromMap(map['stats']) : null,
//     );
//   }

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'branch': branch,
//       'position': position,
//       'phone': phone,
//       'email': email,
//       'join_date': joinDate,
//       'status': status,
//       'created_at': createdAt,
//       'stats': stats?.toMap(),
//     };
//   }
// }

class Employee {
  final String id;
  final String name;
  final String branch;
  final String position;
  final String phone;
  final String? department;
  final String email;
  final String joinDate;
  final String status;
  final String createdAt;
  final EmployeeStats? stats;

  Employee({
    required this.id,
    required this.name,
    required this.branch,
    required this.position,
    this.department,
    required this.phone,
    required this.email,
    required this.joinDate,
    required this.status,
    required this.createdAt,
    this.stats,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      branch: map['branch']?.toString() ?? '',
      position: map['position']?.toString() ?? '',
        department: (map['department'] == null || '${map['department']}'.isEmpty)
          ? null
          : '${map['department']}',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      joinDate: map['join_date']?.toString() ?? '',
      status: map['status']?.toString() ?? 'active',
      createdAt: map['created_at']?.toString() ?? '',
      stats: map['stats'] != null ? EmployeeStats.fromMap(map['stats']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'branch': branch,
      'position': position,
      'department': department,
      'phone': phone,
      'email': email,
      'join_date': joinDate,
      'status': status,
      'created_at': createdAt,
      'stats': stats?.toMap(),
    };
  }

  // TAMBAHKAN METHOD COPYWITH
  Employee copyWith({
    String? id,
    String? name,
    String? branch,
    String? position,
    String? department,
    String? phone,
    String? email,
    String? joinDate,
    String? status,
    String? createdAt,
    EmployeeStats? stats,
  }) {
    return Employee(
      id: id ?? this.id,
      name: name ?? this.name,
      branch: branch ?? this.branch,
      position: position ?? this.position,
      department: department ?? this.department,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      joinDate: joinDate ?? this.joinDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      stats: stats ?? this.stats,
    );
  }
}

class EmployeeStats {
  final int totalCheckins;
  final int totalCheckouts;
  final int totalAbsences;

  EmployeeStats({
    required this.totalCheckins,
    required this.totalCheckouts,
    required this.totalAbsences,
  });

  factory EmployeeStats.fromMap(Map<String, dynamic> map) {
    return EmployeeStats(
      totalCheckins: (map['total_checkins'] ?? 0) as int,
      totalCheckouts: (map['total_checkouts'] ?? 0) as int,
      totalAbsences: (map['total_absences'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total_checkins': totalCheckins,
      'total_checkouts': totalCheckouts,
      'total_absences': totalAbsences,
    };
  }
}

class ImportResult {
  final int added;
  final int updated;
  final int skipped;
  final List<String> errors;

  ImportResult({
    required this.added,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  factory ImportResult.fromMap(Map<String, dynamic> map) {
    return ImportResult(
      added: (map['added'] ?? 0) as int,
      updated: (map['updated'] ?? 0) as int,
      skipped: (map['skipped'] ?? 0) as int,
      errors: List<String>.from(map['errors'] ?? []),
    );
  }
}