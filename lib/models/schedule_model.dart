class WorkSchedule {
  final int? id;
  final int employeeId;
  final String employeeName;
  final String branch;
  final String workDate; // YYYY-MM-DD
  final String shiftCode;
  final String? startTime; // HH:MM
  final String? endTime;   // HH:MM
  final String? notes;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  WorkSchedule({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.branch,
    required this.workDate,
    required this.shiftCode,
    this.startTime,
    this.endTime,
    this.notes,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory WorkSchedule.fromMap(Map<String, dynamic> map) {
    return WorkSchedule(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      employeeId: int.tryParse(map['employee_id'].toString()) ?? 0,
      employeeName: map['employee_name']?.toString() ?? '',
      branch: map['branch']?.toString() ?? '',
      workDate: map['work_date']?.toString() ?? '',
      shiftCode: map['shift_code']?.toString() ?? '',
      startTime: map['start_time']?.toString(),
      endTime: map['end_time']?.toString(),
      notes: map['notes']?.toString(),
      status: map['status']?.toString(),
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'branch': branch,
      'work_date': workDate,
      'shift_code': shiftCode,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (notes != null) 'notes': notes,
      if (status != null) 'status': status,
    };
  }

  WorkSchedule copyWith({
    int? id,
    int? employeeId,
    String? employeeName,
    String? branch,
    String? workDate,
    String? shiftCode,
    String? startTime,
    String? endTime,
    String? notes,
    String? status,
    String? createdAt,
    String? updatedAt,
  }) {
    return WorkSchedule(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      branch: branch ?? this.branch,
      workDate: workDate ?? this.workDate,
      shiftCode: shiftCode ?? this.shiftCode,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ShiftPreset {
  final int? id;
  final String code;
  final String? startTime;
  final String? endTime;
  final String? notes;
  final String? createdAt;

  ShiftPreset({
    this.id,
    required this.code,
    this.startTime,
    this.endTime,
    this.notes,
    this.createdAt,
  });

  factory ShiftPreset.fromMap(Map<String, dynamic> map) {
    return ShiftPreset(
      id: map['id'] != null ? int.tryParse(map['id'].toString()) : null,
      code: map['code']?.toString() ?? '',
      startTime: map['start_time']?.toString(),
      endTime: map['end_time']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: map['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (notes != null) 'notes': notes,
    };
  }

  ShiftPreset copyWith({
    int? id,
    String? code,
    String? startTime,
    String? endTime,
    String? notes,
    String? createdAt,
  }) {
    return ShiftPreset(
      id: id ?? this.id,
      code: code ?? this.code,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}