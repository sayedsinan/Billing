import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:test_bill/models/employee_model.dart';
import 'package:test_bill/service/employee_service.dart';

class EmployeeController extends GetxController {
  final EmployeeService _service = EmployeeService.instance;
  final GetStorage _box = GetStorage();
  static const String _storageKey = 'employee_list_cache';

  final RxList<EmployeeModel> employees = <EmployeeModel>[].obs;
  final RxBool isLoading = false.obs;
  final Rx<DateTime> selectedDate = DateTime.now().obs;
  final RxString searchQuery = ''.obs;
  final Rx<AttStatus?> statusFilter = Rx<AttStatus?>(null);

  @override
  void onInit() {
    super.onInit();
    loadEmployees();
  }

  String get currentDateKey => dateKey(selectedDate.value);

  /// Loads employees from API with GetStorage offline fallback
  Future<void> loadEmployees() async {
    isLoading.value = true;
    try {
      final list = await _service.fetchEmployees(
        search: searchQuery.value,
        dateKey: currentDateKey,
      );
      if (list.isNotEmpty) {
        employees.assignAll(list);
        _saveToLocalStorage();
      } else {
        _loadFromLocalStorage();
      }
    } catch (_) {
      _loadFromLocalStorage();
    } finally {
      isLoading.value = false;
    }
  }

  void _loadFromLocalStorage() {
    final raw = _box.read<List>(_storageKey);
    if (raw != null) {
      final List<EmployeeModel> cached = [];
      for (final item in raw) {
        if (item is Map) {
          cached.add(EmployeeModel.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      if (cached.isNotEmpty) {
        employees.assignAll(cached);
      }
    }
  }

  void _saveToLocalStorage() {
    final list = employees.map((e) => e.toJson()).toList();
    _box.write(_storageKey, list);
  }

  /// Toggle salary payment status for an employee for the current selected month
  Future<void> toggleSalaryPaid(EmployeeModel employee) async {
    final monthKey = '${selectedDate.value.year}-${selectedDate.value.month.toString().padLeft(2, '0')}';
    final currentPaid = employee.isPaidForMonth(selectedDate.value);
    final newStatus = currentPaid ? 'pending' : 'paid';

    employee.lastPaidMonth = monthKey;
    employee.salaryPaymentStatus = newStatus;
    employees.refresh();
    _saveToLocalStorage();

    try {
      if (employee.id.isNotEmpty && !employee.id.startsWith('EMP_')) {
        await _service.paySalary(
          employeeId: employee.id,
          monthKey: monthKey,
          status: newStatus,
        );
      }
    } catch (_) {}
  }

  /// Add a new employee
  Future<bool> addEmployee({
    required String name,
    required String role,
    String phone = '',
    String email = '',
    double salary = 0.0,
    String salaryType = 'monthly',
  }) async {
    try {
      final newEmp = await _service.createEmployee(
        name: name,
        role: role,
        phone: phone,
        email: email,
        salary: salary,
        salaryType: salaryType,
      );
      employees.add(newEmp);
      _saveToLocalStorage();
      return true;
    } catch (_) {
      // Local fallback
      final fallbackEmp = EmployeeModel(
        id: 'EMP_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        role: role,
        phone: phone,
        email: email,
        salary: salary,
        salaryType: salaryType,
      );
      employees.add(fallbackEmp);
      _saveToLocalStorage();
      return false;
    }
  }

  /// Edit existing employee details
  Future<bool> editEmployee(EmployeeModel employee) async {
    try {
      if (employee.id.isNotEmpty && !employee.id.startsWith('EMP_')) {
        await _service.updateEmployee(employee.id, {
          'name': employee.name,
          'role': employee.role,
          'phone': employee.phone,
          'email': employee.email,
          'salary': employee.salary,
          'salaryType': employee.salaryType,
        });
      }
      final idx = employees.indexWhere((e) => e.id == employee.id);
      if (idx >= 0) {
        employees[idx] = employee;
        employees.refresh();
      }
      _saveToLocalStorage();
      return true;
    } catch (_) {
      final idx = employees.indexWhere((e) => e.id == employee.id);
      if (idx >= 0) {
        employees[idx] = employee;
        employees.refresh();
      }
      _saveToLocalStorage();
      return false;
    }
  }

  /// Delete an employee
  Future<void> deleteEmployee(EmployeeModel employee) async {
    try {
      if (employee.id.isNotEmpty && !employee.id.startsWith('EMP_')) {
        await _service.deleteEmployee(employee.id);
      }
    } catch (_) {}
    employees.removeWhere((e) => e.id == employee.id);
    _saveToLocalStorage();
  }

  /// Mark attendance for an employee
  Future<void> markAttendance(
    EmployeeModel employee,
    AttStatus status, {
    String checkIn = '',
    String checkOut = '',
    String note = '',
  }) async {
    final dk = currentDateKey;

    // Update locally in real-time
    final rec = AttRecord(
      status: status,
      checkIn: checkIn,
      checkOut: checkOut,
      note: note,
    );
    employee.setRecord(selectedDate.value, rec);
    employees.refresh();
    _saveToLocalStorage();

    // Persist to backend
    try {
      if (employee.id.isNotEmpty && !employee.id.startsWith('EMP_')) {
        await _service.markAttendance(
          employeeId: employee.id,
          dateKey: dk,
          status: status.name,
          checkIn: checkIn,
          checkOut: checkOut,
          note: note,
        );
      }
    } catch (_) {}
  }

  void setDate(DateTime date) {
    selectedDate.value = date;
    loadEmployees();
  }

  void shiftDate(int days) {
    selectedDate.value = selectedDate.value.add(Duration(days: days));
    loadEmployees();
  }

  // Stats for selected date
  int countOf(AttStatus s) {
    return employees
        .where((e) => e.recordFor(selectedDate.value)?.status == s)
        .length;
  }

  double get totalMonthlyPayroll {
    return employees.fold(
        0.0, (sum, e) => sum + e.calculateMonthlyEarnings(selectedDate.value));
  }

  double get totalPaidPayroll {
    return employees
        .where((e) => e.isPaidForMonth(selectedDate.value))
        .fold(0.0, (sum, e) => sum + e.calculateMonthlyEarnings(selectedDate.value));
  }

  double get totalPendingPayroll {
    return employees
        .where((e) => !e.isPaidForMonth(selectedDate.value))
        .fold(0.0, (sum, e) => sum + e.calculateMonthlyEarnings(selectedDate.value));
  }

  int get paidEmployeesCount {
    return employees.where((e) => e.isPaidForMonth(selectedDate.value)).length;
  }

  int get pendingEmployeesCount {
    return employees.where((e) => !e.isPaidForMonth(selectedDate.value)).length;
  }

  List<EmployeeModel> get filteredEmployees {
    return employees.where((e) {
      final q = searchQuery.value.toLowerCase();
      final matchSearch = q.isEmpty ||
          e.name.toLowerCase().contains(q) ||
          e.role.toLowerCase().contains(q) ||
          e.phone.toLowerCase().contains(q);
      final rec = e.recordFor(selectedDate.value);
      final matchStatus =
          statusFilter.value == null || rec?.status == statusFilter.value;
      return matchSearch && matchStatus;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
