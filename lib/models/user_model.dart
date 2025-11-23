class User {
  String id;
  String name;
  String email;
  String branch;
  String position;
  String role; // NEW

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.branch,
    required this.position,
    required this.role, // NEW
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'branch': branch,
      'position': position,
      'role': role, // NEW
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      branch: map['branch'],
      position: map['position'],
      role: map['role'] ?? 'staff', // default safety
    );
  }
  
  User copyWith({
    String? id,
    String? name,
    String? email,
    String? branch,
    String? position,
    String? role, // NEW
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      branch: branch ?? this.branch,
      position: position ?? this.position,
      role: role ?? this.role, // NEW
    );
  }
}
