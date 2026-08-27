enum AttStatus { present, absent, halfDay, leave, holiday }

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AttRecord {
  AttStatus status;
  String checkIn;
  String checkOut;
  String note;

  AttRecord({
    required this.status,
    this.checkIn = '',
    this.checkOut = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'checkIn': checkIn,
        'checkOut': checkOut,
        'note': note,
      };

  factory AttRecord.fromJson(Map<String, dynamic> json) {
    AttStatus parsedStatus = AttStatus.present;
    final statusStr = json['status']?.toString() ?? 'present';
    for (final s in AttStatus.values) {
      if (s.name.toLowerCase() == statusStr.toLowerCase()) {
        parsedStatus = s;
        break;
      }
    }
    return AttRecord(
      status: parsedStatus,
      checkIn: json['checkIn'] ?? '',
      checkOut: json['checkOut'] ?? '',
      note: json['note'] ?? '',
    );
  }
}

class EmployeeModel {
  final String id;
  String name;
  String role;
  String phone;
  String email;
  double salary;
  String salaryType; // 'monthly', 'daily', 'hourly'
  DateTime joiningDate;
  String status;
  String lastPaidMonth; // e.g. "2026-08"
  String salaryPaymentStatus; // 'pending', 'paid'
  Map<String, AttRecord> records;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
    this.email = '',
    this.salary = 0.0,
    this.salaryType = 'monthly',
    DateTime? joiningDate,
    this.status = 'active',
    this.lastPaidMonth = '',
    this.salaryPaymentStatus = 'pending',
    Map<String, AttRecord>? records,
  })  : joiningDate = joiningDate ?? DateTime.now(),
        records = records ?? {};

  bool isPaidForMonth(DateTime month) {
    final mKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    return lastPaidMonth == mKey && salaryPaymentStatus == 'paid';
  }

  AttRecord? recordFor(DateTime d) => records[dateKey(d)];

  void setRecord(DateTime d, AttRecord r) => records[dateKey(d)] = r;

  Map<AttStatus, int> monthStats(DateTime month) {
    final stats = {for (final s in AttStatus.values) s: 0};
    records.forEach((k, r) {
      final parts = k.split('-');
      if (parts.length >= 2) {
        final year = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (year == month.year && m == month.month) {
          stats[r.status] = (stats[r.status] ?? 0) + 1;
        }
      }
    });
    return stats;
  }

  /// Calculates estimated monthly payout based on attendance
  double calculateMonthlyEarnings(DateTime month) {
    final stats = monthStats(month);
    final presentCount = stats[AttStatus.present] ?? 0;
    final halfDayCount = stats[AttStatus.halfDay] ?? 0;

    if (salaryType == 'daily') {
      return (presentCount * salary) + (halfDayCount * salary * 0.5);
    } else {
      // Monthly base calculation (assuming 30 standard days)
      const standardDays = 30.0;
      final dailyRate = salary / standardDays;
      final workedDays = presentCount + (halfDayCount * 0.5);
      return workedDays * dailyRate;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        '_id': id,
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
        'salary': salary,
        'salaryType': salaryType,
        'joiningDate': joiningDate.toIso8601String(),
        'status': status,
        'lastPaidMonth': lastPaidMonth,
        'salaryPaymentStatus': salaryPaymentStatus,
        'records': records.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    final Map<String, AttRecord> recMap = {};

    if (json['attendanceHistory'] is List) {
      for (final item in json['attendanceHistory']) {
        if (item is Map) {
          final dk = item['dateKey']?.toString();
          if (dk != null && dk.isNotEmpty) {
            recMap[dk] = AttRecord.fromJson(Map<String, dynamic>.from(item));
          }
        }
      }
    }

    if (json['todayAttendance'] is Map) {
      final todayAtt = json['todayAttendance'] as Map;
      final dk = todayAtt['dateKey']?.toString();
      if (dk != null && dk.isNotEmpty) {
        recMap[dk] = AttRecord.fromJson(Map<String, dynamic>.from(todayAtt));
      }
    }

    if (json['records'] is Map) {
      (json['records'] as Map).forEach((k, v) {
        if (v is Map) {
          recMap[k.toString()] =
              AttRecord.fromJson(Map<String, dynamic>.from(v));
        }
      });
    }

    return EmployeeModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] ?? '',
      role: json['role'] ?? 'Staff',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      salary: (json['salary'] as num?)?.toDouble() ?? 0.0,
      salaryType: json['salaryType'] ?? 'monthly',
      joiningDate: json['joiningDate'] != null
          ? DateTime.tryParse(json['joiningDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] ?? 'active',
      lastPaidMonth: json['lastPaidMonth'] ?? '',
      salaryPaymentStatus: json['salaryPaymentStatus'] ?? 'pending',
      records: recMap,
    );
  }
}
