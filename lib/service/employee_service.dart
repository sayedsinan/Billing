import 'package:test_bill/models/employee_model.dart';
import 'package:test_bill/service/api_service.dart';

class EmployeeService {
  EmployeeService._internal();
  static final EmployeeService instance = EmployeeService._internal();
  factory EmployeeService() => instance;

  final ApiService _api = ApiService.instance;

  /// Fetches employees and attendance records from backend
  Future<List<EmployeeModel>> fetchEmployees({
    String? search,
    String? dateKey,
  }) async {
    final rawList = await _api.getEmployees(search: search, dateKey: dateKey);
    final List<EmployeeModel> employees = [];
    for (final item in rawList) {
      if (item is Map) {
        employees.add(
          EmployeeModel.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }
    return employees;
  }

  /// Creates a new employee
  Future<EmployeeModel> createEmployee({
    required String name,
    required String role,
    String? phone,
    String? email,
    double? salary,
    String? salaryType,
  }) async {
    final res = await _api.createEmployee(
      name: name,
      role: role,
      phone: phone,
      email: email,
      salary: salary,
      salaryType: salaryType,
    );
    return EmployeeModel.fromJson(res);
  }

  /// Updates an employee
  Future<EmployeeModel> updateEmployee(
    String id,
    Map<String, dynamic> body,
  ) async {
    final res = await _api.updateEmployee(id, body);
    return EmployeeModel.fromJson(res);
  }

  /// Deletes an employee
  Future<void> deleteEmployee(String id) async {
    await _api.deleteEmployee(id);
  }

  /// Marks attendance for an employee
  Future<AttRecord> markAttendance({
    required String employeeId,
    required String dateKey,
    required String status,
    String? checkIn,
    String? checkOut,
    String? note,
  }) async {
    final res = await _api.markAttendance(
      employeeId: employeeId,
      dateKey: dateKey,
      status: status,
      checkIn: checkIn,
      checkOut: checkOut,
      note: note,
    );
    return AttRecord.fromJson(res);
  }

  /// Marks salary as paid/pending for a given month
  Future<EmployeeModel> paySalary({
    required String employeeId,
    required String monthKey,
    required String status,
  }) async {
    final res = await _api.paySalary(
      employeeId: employeeId,
      monthKey: monthKey,
      status: status,
    );
    return EmployeeModel.fromJson(res);
  }
}
