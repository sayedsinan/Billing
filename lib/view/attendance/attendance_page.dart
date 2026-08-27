import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/employee_controller.dart';
import 'package:test_bill/models/employee_model.dart';
import 'package:test_bill/theme/colors.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final EmployeeController _controller;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<EmployeeController>()) {
      _controller = Get.put(EmployeeController());
    } else {
      _controller = Get.find<EmployeeController>();
    }
  }

  void _openAddEmployeeDialog(BuildContext context) {
    _showEmployeeFormDialog(context, null);
  }

  void _openEditEmployeeDialog(BuildContext context, EmployeeModel emp) {
    _showEmployeeFormDialog(context, emp);
  }

  void _showEmployeeFormDialog(BuildContext context, EmployeeModel? emp) {
    final isEdit = emp != null;
    final nameCtrl = TextEditingController(text: emp?.name ?? '');
    final roleCtrl = TextEditingController(text: emp?.role ?? '');
    final phoneCtrl = TextEditingController(text: emp?.phone ?? '');
    final emailCtrl = TextEditingController(text: emp?.email ?? '');
    final salaryCtrl = TextEditingController(
        text: emp?.salary != null && emp!.salary > 0 ? emp.salary.toStringAsFixed(0) : '');
    String salaryType = emp?.salaryType ?? 'monthly';
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(isEdit ? Icons.edit_note_rounded : Icons.person_add_rounded, color: kBlue, size: 24),
              const SizedBox(width: 10),
              Text(isEdit ? 'Edit Employee Details' : 'Add New Employee',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildInput('Full Name *', nameCtrl, 'e.g. Anil Kumar')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInput('Role / Designation *', roleCtrl, 'e.g. Waiter, Chef, Manager')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInput('Phone Number', phoneCtrl, 'e.g. 9876543210', isPhone: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInput('Email Address', emailCtrl, 'e.g. employee@shop.com')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildInput('Salary (₹) *', salaryCtrl, 'e.g. 18000', isNumber: true)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Salary Basis',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextGray)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(10)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: salaryType,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'monthly', child: Text('Monthly Salary', style: TextStyle(fontSize: 13))),
                                  DropdownMenuItem(
                                      value: 'daily', child: Text('Daily Wage', style: TextStyle(fontSize: 13))),
                                ],
                                onChanged: (val) {
                                  if (val != null) setDState(() => salaryType = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: kWhite, elevation: 0),
              onPressed: isSaving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final role = roleCtrl.text.trim();
                      final salary = double.tryParse(salaryCtrl.text.trim()) ?? 0.0;

                      if (name.isEmpty || role.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter name and role'), backgroundColor: kRed),
                        );
                        return;
                      }

                      setDState(() => isSaving = true);

                      if (isEdit) {
                        emp.name = name;
                        emp.role = role;
                        emp.phone = phoneCtrl.text.trim();
                        emp.email = emailCtrl.text.trim();
                        emp.salary = salary;
                        emp.salaryType = salaryType;
                        await _controller.editEmployee(emp);
                      } else {
                        await _controller.addEmployee(
                          name: name,
                          role: role,
                          phone: phoneCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          salary: salary,
                          salaryType: salaryType,
                        );
                      }

                      if (mounted) {
                        Navigator.pop(dCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEdit ? 'Employee updated successfully!' : 'Employee added successfully!'),
                            backgroundColor: kGreen,
                          ),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: kWhite))
                  : Text(isEdit ? 'Save Changes' : 'Add Employee'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEmployee(BuildContext context, EmployeeModel emp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Employee?'),
        content: Text('Are you sure you want to remove "${emp.name}" (${emp.role})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRed, foregroundColor: kWhite, elevation: 0),
            onPressed: () async {
              Navigator.pop(ctx);
              await _controller.deleteEmployee(emp);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${emp.name} deleted'), backgroundColor: kRed),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openEmployeeProfileDialog(BuildContext context, EmployeeModel emp) {
    showDialog(
      context: context,
      builder: (dCtx) => _EmployeeProfileDialog(
        employee: emp,
        selectedDate: _controller.selectedDate.value,
        controller: _controller,
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, String hint,
      {bool isNumber = false, bool isPhone = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextGray)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber
              ? TextInputType.number
              : isPhone
                  ? TextInputType.phone
                  : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kTextGray, fontSize: 12.5),
            filled: true,
            fillColor: kBgGray,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgGray,
      body: Obx(() {
        final filteredList = _controller.filteredEmployees;
        final loading = _controller.isLoading.value;
        final totalCount = _controller.employees.length;
        final presentCount = _controller.countOf(AttStatus.present);
        final absentCount = _controller.countOf(AttStatus.absent);
        final totalPaid = _controller.totalPaidPayroll;
        final totalPending = _controller.totalPendingPayroll;
        final paidCount = _controller.paidEmployeesCount;
        final pendingCount = _controller.pendingEmployeesCount;
        final selectedDateStr = _fmtDate(_controller.selectedDate.value);
        final isToday = dateKey(_controller.selectedDate.value) == dateKey(DateTime.now());

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Action Bar
              Row(
                children: [
                  const Icon(Icons.badge_outlined, size: 28, color: kBlue),
                  const SizedBox(width: 12),
                  const Text('Employee & Attendance Management',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kTextDark, letterSpacing: -0.3)),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: kWhite,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _openAddEmployeeDialog(context),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => _controller.loadEmployees(),
                    icon: const Icon(Icons.refresh_rounded, color: kTextGray),
                    tooltip: 'Refresh data',
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Summary Cards Strip (Staff, Present, Absent, Paid Payroll, Pending Payroll)
              Row(
                children: [
                  _SummaryCard(title: 'Total Staff', amount: '$totalCount', sub: 'Registered employees', color: kBlue, icon: Icons.groups_rounded),
                  const SizedBox(width: 14),
                  _SummaryCard(title: 'Present Today', amount: '$presentCount', sub: 'Active today', color: kGreen, icon: Icons.check_circle_rounded),
                  const SizedBox(width: 14),
                  _SummaryCard(title: 'Absent Today', amount: '$absentCount', sub: 'Not attended', color: kRed, icon: Icons.cancel_rounded),
                  const SizedBox(width: 14),
                  _SummaryCard(title: 'Paid Salary', amount: '₹${totalPaid.toStringAsFixed(0)}', sub: '$paidCount Employees Paid', color: kGreen, icon: Icons.verified_rounded),
                  const SizedBox(width: 14),
                  _SummaryCard(title: 'Pending Salary', amount: '₹${totalPending.toStringAsFixed(0)}', sub: '$pendingCount Employees Pending', color: kOrange, icon: Icons.pending_actions_rounded),
                ],
              ),
              const SizedBox(height: 20),

              // Controls Toolbar: Date Switcher, Search, Status Filter
              Row(
                children: [
                  // Date Switcher
                  Container(
                    height: 42,
                    decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(11)),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _controller.shiftDate(-1),
                          icon: const Icon(Icons.chevron_left_rounded, color: kTextGray, size: 20),
                        ),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _controller.selectedDate.value,
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) _controller.setDate(picked);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: kBlue),
                                const SizedBox(width: 6),
                                Text(
                                  isToday ? 'Today, $selectedDateStr' : selectedDateStr,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: kTextDark),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _controller.shiftDate(1),
                          icon: const Icon(Icons.chevron_right_rounded, color: kTextGray, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Search Bar
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(11)),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by employee name, role, or phone...',
                          hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
                        ),
                        onChanged: (v) => _controller.searchQuery.value = v,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Status Filter Chips
                  Wrap(
                    spacing: 6,
                    children: [
                      _FilterChip(label: 'ALL', active: _controller.statusFilter.value == null, onTap: () => _controller.statusFilter.value = null),
                      _FilterChip(label: 'PRESENT', active: _controller.statusFilter.value == AttStatus.present, onTap: () => _controller.statusFilter.value = AttStatus.present, color: kGreen),
                      _FilterChip(label: 'ABSENT', active: _controller.statusFilter.value == AttStatus.absent, onTap: () => _controller.statusFilter.value = AttStatus.absent, color: kRed),
                      _FilterChip(label: 'HALF DAY', active: _controller.statusFilter.value == AttStatus.halfDay, onTap: () => _controller.statusFilter.value = AttStatus.halfDay, color: kOrange),
                      _FilterChip(label: 'LEAVE', active: _controller.statusFilter.value == AttStatus.leave, onTap: () => _controller.statusFilter.value = AttStatus.leave, color: kPurple),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Employee Table Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(color: kWhite, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text('EMPLOYEE', style: TextStyle(color: kTextGray, fontSize: 11.5, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text('ROLE', style: TextStyle(color: kTextGray, fontSize: 11.5, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text('PHONE', style: TextStyle(color: kTextGray, fontSize: 11.5, fontWeight: FontWeight.w700))),
                    Expanded(flex: 2, child: Text('SALARY', style: TextStyle(color: kTextGray, fontSize: 11.5, fontWeight: FontWeight.w700))),
                    Expanded(flex: 3, child: Text('PAYMENT STATUS', style: TextStyle(color: kTextGray, fontSize: 11.5, fontWeight: FontWeight.w700))),
                    Expanded(flex: 4, child: Text('MARK ATTENDANCE', style: TextStyle(color: kTextGray, fontSize: 11.5, fontWeight: FontWeight.w700))),
                    SizedBox(width: 80, child: Text('ACTIONS', style: TextStyle(color: kTextGray, fontSize: 11.5, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                  ],
                ),
              ),
              const Divider(height: 1, color: kBgGray),

              // Employee Table Body
              Expanded(
                child: loading && filteredList.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: kBlue))
                    : filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.badge_outlined, size: 48, color: kTextGray),
                                const SizedBox(height: 12),
                                const Text('No employees found.', style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700, fontSize: 16)),
                                const SizedBox(height: 4),
                                const Text('Click "Add Employee" above to register staff in the database.', style: TextStyle(color: kTextGray, fontSize: 13)),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: kWhite),
                                  onPressed: () => _openAddEmployeeDialog(context),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Add First Employee'),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (ctx, i) {
                              final emp = filteredList[i];
                              final rec = emp.recordFor(_controller.selectedDate.value);
                              final isPaid = emp.isPaidForMonth(_controller.selectedDate.value);
                              final monthlyEarnings = emp.calculateMonthlyEarnings(_controller.selectedDate.value);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: kWhite,
                                  boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))],
                                ),
                                child: Row(
                                  children: [
                                    // Employee Avatar & Name
                                    Expanded(
                                      flex: 3,
                                      child: InkWell(
                                        onTap: () => _openEmployeeProfileDialog(context, emp),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: kBlue.withOpacity(0.12),
                                              child: Text(
                                                emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'E',
                                                style: const TextStyle(color: kBlue, fontWeight: FontWeight.w700, fontSize: 13),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Flexible(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: kTextDark), overflow: TextOverflow.ellipsis),
                                                  if (emp.email.isNotEmpty)
                                                    Text(emp.email, style: const TextStyle(fontSize: 10.5, color: kTextGray), overflow: TextOverflow.ellipsis),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Role
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(6)),
                                        child: Text(emp.role, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark)),
                                      ),
                                    ),

                                    // Phone
                                    Expanded(
                                      flex: 2,
                                      child: Text(emp.phone.isNotEmpty ? emp.phone : '—', style: const TextStyle(fontSize: 12.5, color: kTextDark)),
                                    ),

                                    // Salary & Earnings
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('₹${monthlyEarnings.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: kTextDark)),
                                          Text('Base: ₹${emp.salary.toStringAsFixed(0)} (${emp.salaryType})', style: const TextStyle(fontSize: 9.5, color: kTextGray)),
                                        ],
                                      ),
                                    ),

                                    // Salary Payment Status Toggle Button
                                    Expanded(
                                      flex: 3,
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _controller.toggleSalaryPaid(emp),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: isPaid ? kGreen.withOpacity(0.12) : kOrange.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: isPaid ? kGreen : kOrange),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(isPaid ? Icons.check_circle_rounded : Icons.pending_rounded, size: 14, color: isPaid ? kGreen : kOrange),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isPaid ? 'PAID' : 'MARK PAID',
                                                    style: TextStyle(
                                                      color: isPaid ? kGreen : kOrange,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Attendance Action Buttons
                                    Expanded(
                                      flex: 4,
                                      child: Wrap(
                                        spacing: 6,
                                        children: [
                                          _AttButton(
                                            label: 'Present',
                                            active: rec?.status == AttStatus.present,
                                            color: kGreen,
                                            onTap: () => _controller.markAttendance(emp, AttStatus.present, checkIn: '09:00'),
                                          ),
                                          _AttButton(
                                            label: 'Absent',
                                            active: rec?.status == AttStatus.absent,
                                            color: kRed,
                                            onTap: () => _controller.markAttendance(emp, AttStatus.absent),
                                          ),
                                          _AttButton(
                                            label: 'Half Day',
                                            active: rec?.status == AttStatus.halfDay,
                                            color: kOrange,
                                            onTap: () => _controller.markAttendance(emp, AttStatus.halfDay, checkIn: '09:00', checkOut: '13:30'),
                                          ),
                                          _AttButton(
                                            label: 'Leave',
                                            active: rec?.status == AttStatus.leave,
                                            color: kPurple,
                                            onTap: () => _controller.markAttendance(emp, AttStatus.leave),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Action Buttons (Edit / Delete)
                                    SizedBox(
                                      width: 80,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            onPressed: () => _openEditEmployeeDialog(context, emp),
                                            icon: const Icon(Icons.edit_outlined, size: 18, color: kBlue),
                                            tooltip: 'Edit Details & Salary',
                                          ),
                                          IconButton(
                                            onPressed: () => _confirmDeleteEmployee(context, emp),
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kRed),
                                            tooltip: 'Delete Employee',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _SummaryCard extends StatelessWidget {
  final String title, amount, sub;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextGray)),
                  const SizedBox(height: 2),
                  Text(amount, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kTextDark)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({required this.label, required this.active, required this.onTap, this.color = kBlue});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color : kWhite,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kWhite : kTextDark,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _AttButton extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _AttButton({required this.label, required this.active, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? color : kBgGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color : Colors.transparent),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? kWhite : kTextDark,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmployeeProfileDialog extends StatelessWidget {
  final EmployeeModel employee;
  final DateTime selectedDate;
  final EmployeeController controller;

  const _EmployeeProfileDialog({
    required this.employee,
    required this.selectedDate,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final stats = employee.monthStats(selectedDate);
    final earnings = employee.calculateMonthlyEarnings(selectedDate);
    final isPaid = employee.isPaidForMonth(selectedDate);
    final sortedDates = employee.records.keys.toList()..sort((a, b) => b.compareTo(a));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(color: kBlue, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(
                children: [
                  const Icon(Icons.badge_rounded, color: kWhite, size: 24),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.name, style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('${employee.role} · Base Salary: ₹${employee.salary.toStringAsFixed(0)} (${employee.salaryType})', style: TextStyle(color: kWhite.withOpacity(0.85), fontSize: 11.5)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kWhite)),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Monthly Salary Calculation Card + Pay Button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: kBgGray, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ESTIMATED MONTHLY EARNINGS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextGray)),
                              const SizedBox(height: 4),
                              Text('₹${earnings.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kGreen)),
                              const SizedBox(height: 2),
                              Text(
                                'Based on ${stats[AttStatus.present] ?? 0} Present, ${stats[AttStatus.halfDay] ?? 0} Half Days',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextDark),
                              ),
                            ],
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPaid ? kGreen : kOrange,
                              foregroundColor: kWhite,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              controller.toggleSalaryPaid(employee);
                              Navigator.pop(context);
                            },
                            icon: Icon(isPaid ? Icons.check_circle_rounded : Icons.payments_rounded, size: 18),
                            label: Text(isPaid ? 'Salary Paid' : 'Mark Salary Paid'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monthly Attendance Stats
                    const Text('Attendance Summary (This Month)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: kTextDark)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _StatBox(label: 'Present', value: '${stats[AttStatus.present] ?? 0}', color: kGreen),
                        const SizedBox(width: 8),
                        _StatBox(label: 'Absent', value: '${stats[AttStatus.absent] ?? 0}', color: kRed),
                        const SizedBox(width: 8),
                        _StatBox(label: 'Half Day', value: '${stats[AttStatus.halfDay] ?? 0}', color: kOrange),
                        const SizedBox(width: 8),
                        _StatBox(label: 'Leave', value: '${stats[AttStatus.leave] ?? 0}', color: kPurple),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Attendance History List
                    const Text('Recent Attendance Logs', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: kTextDark)),
                    const SizedBox(height: 10),
                    if (sortedDates.isEmpty)
                      const Text('No attendance logs recorded yet for this employee.', style: TextStyle(color: kTextGray, fontSize: 12.5))
                    else
                      Column(
                        children: sortedDates.take(15).map((dateKey) {
                          final r = employee.records[dateKey]!;
                          final color = _statusColor(r.status);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBgGray)),
                            child: Row(
                              children: [
                                Text(dateKey, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: kTextDark)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                  child: Text(r.status.name.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(AttStatus s) {
    switch (s) {
      case AttStatus.present:
        return kGreen;
      case AttStatus.absent:
        return kRed;
      case AttStatus.halfDay:
        return kOrange;
      case AttStatus.leave:
        return kPurple;
      case AttStatus.holiday:
        return kTextGray;
    }
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;

  const _StatBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}