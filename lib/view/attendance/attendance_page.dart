import 'package:flutter/material.dart';

// ─── Colors (shared palette) ──────────────────────────────────────────────────
const kBlue = Color(0xFF2196F3);
const kDarkBlue = Color(0xFF1565C0);
const kLightBlue = Color(0xFFE3F2FD);
const kBgGray = Color(0xFFF5F7FA);
const kWhite = Colors.white;
const kTextDark = Color(0xFF1A2A3A);
const kTextGray = Color(0xFF6B7A8D);
const kGreen = Color(0xFF4CAF50);
const kOrange = Color(0xFFFF9800);
const kRed = Color(0xFFF44336);
const kPurple = Color(0xFF9C27B0);
const kDivider = Color(0xFFEEF2F7);

// ─── Models ───────────────────────────────────────────────────────────────────
enum AttStatus { present, absent, halfDay, leave, holiday }

String _dateKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Employee {
  final String id;
  String name;
  String role;
  String phone;
  // dateKey -> record
  Map<String, AttRecord> records;

  Employee({
    required this.id,
    required this.name,
    required this.role,
    this.phone = '',
    Map<String, AttRecord>? records,
  }) : records = records ?? {};

  AttRecord? recordFor(DateTime d) => records[_dateKey(d)];

  void setRecord(DateTime d, AttRecord r) => records[_dateKey(d)] = r;

  // simple stats for a given month
  Map<AttStatus, int> monthStats(DateTime month) {
    final stats = {for (final s in AttStatus.values) s: 0};
    records.forEach((k, r) {
      final parts = k.split('-');
      if (int.parse(parts[0]) == month.year && int.parse(parts[1]) == month.month) {
        stats[r.status] = (stats[r.status] ?? 0) + 1;
      }
    });
    return stats;
  }
}

class AttRecord {
  AttStatus status;
  String checkIn;
  String checkOut;
  AttRecord({required this.status, this.checkIn = '', this.checkOut = ''});
}

// ─── Sample Data ──────────────────────────────────────────────────────────────
List<Employee> _sampleEmployees() {
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));
  final list = [
    Employee(id: 'E1', name: 'Anil Kumar', role: 'Waiter', phone: '9876543210'),
    Employee(id: 'E2', name: 'Divya Menon', role: 'Cashier', phone: '8765432109'),
    Employee(id: 'E3', name: 'Rahul Nair', role: 'Chef', phone: '7654321098'),
    Employee(id: 'E4', name: 'Meera Thomas', role: 'Waiter', phone: '6543210987'),
    Employee(id: 'E5', name: 'Suresh Pillai', role: 'Cleaner', phone: '5432109876'),
    Employee(id: 'E6', name: 'Priya Raj', role: 'Manager', phone: '4321098765'),
  ];
  list[0].setRecord(today, AttRecord(status: AttStatus.present, checkIn: '09:02', checkOut: ''));
  list[1].setRecord(today, AttRecord(status: AttStatus.present, checkIn: '08:55', checkOut: ''));
  list[2].setRecord(today, AttRecord(status: AttStatus.halfDay, checkIn: '09:10', checkOut: '13:30'));
  list[3].setRecord(today, AttRecord(status: AttStatus.absent));
  list[4].setRecord(today, AttRecord(status: AttStatus.leave));
  list[5].setRecord(today, AttRecord(status: AttStatus.present, checkIn: '08:40', checkOut: ''));
  for (final e in list) {
    e.setRecord(yesterday, AttRecord(status: AttStatus.present, checkIn: '09:00', checkOut: '18:00'));
  }
  return list;
}

// ─── Attendance Page ────────────────────────────────────────────────────────────
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late List<Employee> _employees;
  DateTime _selectedDate = DateTime.now();
  String _search = '';
  AttStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _employees = _sampleEmployees();
  }

  List<Employee> get _filtered {
    return _employees.where((e) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty || e.name.toLowerCase().contains(q) || e.role.toLowerCase().contains(q);
      final rec = e.recordFor(_selectedDate);
      final matchStatus = _filterStatus == null || rec?.status == _filterStatus;
      return matchSearch && matchStatus;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  void _shiftDate(int days) => setState(() => _selectedDate = _selectedDate.add(Duration(days: days)));

  void _markStatus(Employee e, AttStatus status) {
    setState(() {
      final existing = e.recordFor(_selectedDate);
      e.setRecord(_selectedDate, AttRecord(
        status: status,
        checkIn: existing?.checkIn ?? '',
        checkOut: existing?.checkOut ?? '',
      ));
    });
  }

  void _openEmployee(Employee e) async {
    final result = await showDialog<Employee>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmployeeDialog(employee: e, selectedDate: _selectedDate),
    );
    if (result != null) {
      setState(() {
        final idx = _employees.indexWhere((x) => x.id == result.id);
        if (idx >= 0) _employees[idx] = result;
      });
    }
  }

  void _addEmployee() async {
    final result = await showDialog<Employee>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EmployeeDialog(employee: null, selectedDate: _selectedDate),
    );
    if (result != null) setState(() => _employees.add(result));
  }

  bool get _isToday => _dateKey(_selectedDate) == _dateKey(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    int countOf(AttStatus s) => _employees.where((e) => e.recordFor(_selectedDate)?.status == s).length;
    final present = countOf(AttStatus.present);
    final absent = countOf(AttStatus.absent);
    final halfDay = countOf(AttStatus.halfDay);
    final leave = countOf(AttStatus.leave);
    final unmarked = _employees.length - present - absent - halfDay - leave - countOf(AttStatus.holiday);

    return Scaffold(
      backgroundColor: kBgGray,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary cards ────────────────────────────────────────────
            Row(
              children: [
                _SummaryCard('Employees', '${_employees.length}', Icons.groups_rounded, kBlue),
                const SizedBox(width: 16),
                _SummaryCard('Present', '$present', Icons.check_circle_rounded, kGreen),
                const SizedBox(width: 16),
                _SummaryCard('Absent', '$absent', Icons.cancel_rounded, kRed),
                const SizedBox(width: 16),
                _SummaryCard('Half Day', '$halfDay', Icons.schedule_rounded, kOrange),
                const SizedBox(width: 16),
                _SummaryCard('On Leave', '$leave', Icons.beach_access_rounded, kPurple),
                if (unmarked > 0) ...[
                  const SizedBox(width: 16),
                  _SummaryCard('Unmarked', '$unmarked', Icons.help_outline_rounded, kTextGray),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // ── Toolbar ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  // Date switcher
                  IconButton(onPressed: () => _shiftDate(-1), icon: const Icon(Icons.chevron_left_rounded, color: kTextGray)),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: kLightBlue, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: kDarkBlue),
                          const SizedBox(width: 8),
                          Text(_isToday ? 'Today, ${_fmtDate(_selectedDate)}' : _fmtDate(_selectedDate),
                              style: const TextStyle(color: kDarkBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  IconButton(onPressed: () => _shiftDate(1), icon: const Icon(Icons.chevron_right_rounded, color: kTextGray)),
                  const SizedBox(width: 12),
                  // Search
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by name or role...',
                        hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: kTextGray, size: 18),
                        filled: true,
                        fillColor: kBgGray,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _FilterChip('All', _filterStatus == null, () => setState(() => _filterStatus = null)),
                  const SizedBox(width: 6),
                  _FilterChip('Present', _filterStatus == AttStatus.present, () => setState(() => _filterStatus = AttStatus.present), color: kGreen),
                  const SizedBox(width: 6),
                  _FilterChip('Absent', _filterStatus == AttStatus.absent, () => setState(() => _filterStatus = AttStatus.absent), color: kRed),
                  const SizedBox(width: 6),
                  _FilterChip('Half Day', _filterStatus == AttStatus.halfDay, () => setState(() => _filterStatus = AttStatus.halfDay), color: kOrange),
                  const SizedBox(width: 6),
                  _FilterChip('Leave', _filterStatus == AttStatus.leave, () => setState(() => _filterStatus = AttStatus.leave), color: kPurple),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue,
                      foregroundColor: kWhite,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: _addEmployee,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Table ────────────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: kWhite,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(color: kBgGray, borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
                      child: const Row(
                        children: [
                          Expanded(flex: 3, child: Text('Employee', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Role', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Check In', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 2, child: Text('Check Out', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                          Expanded(flex: 3, child: Text('Status', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                          SizedBox(width: 90, child: Text('Details', style: TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.groups_outlined, color: kTextGray, size: 48),
                                  SizedBox(height: 12),
                                  Text('No employees found', style: TextStyle(color: kTextGray, fontSize: 15)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: kDivider),
                              itemBuilder: (ctx, i) => _EmployeeRow(
                                employee: filtered[i],
                                date: _selectedDate,
                                onMark: (s) => _markStatus(filtered[i], s),
                                onOpen: () => _openEmployee(filtered[i]),
                              ),
                            ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: const BoxDecoration(color: kBgGray, borderRadius: BorderRadius.vertical(bottom: Radius.circular(14))),
                      child: Row(
                        children: [
                          Text('${filtered.length} employees', style: const TextStyle(color: kTextGray, fontSize: 12)),
                          const Spacer(),
                          Text('$present present · $absent absent · $halfDay half-day · $leave leave',
                              style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
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
}

String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

// ─── Summary Card ─────────────────────────────────────────────────────────────
Widget _SummaryCard(String label, String value, IconData icon, Color color) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: kTextGray, fontSize: 11)),
                const SizedBox(height: 3),
                Text(value, style: const TextStyle(color: kTextDark, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────
Widget _FilterChip(String label, bool active, VoidCallback onTap, {Color color = kBlue}) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.12) : kBgGray,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? color : Colors.transparent),
      ),
      child: Text(label, style: TextStyle(color: active ? color : kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}

// ─── Employee Row ──────────────────────────────────────────────────────────────
class _EmployeeRow extends StatelessWidget {
  final Employee employee;
  final DateTime date;
  final Function(AttStatus) onMark;
  final VoidCallback onOpen;

  const _EmployeeRow({required this.employee, required this.date, required this.onMark, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final rec = employee.recordFor(date);
    return InkWell(
      onTap: onOpen,
      hoverColor: kLightBlue.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: kLightBlue,
                    child: Text(employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: kDarkBlue, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(employee.name, style: const TextStyle(color: kTextDark, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(employee.role, style: const TextStyle(color: kTextGray, fontSize: 13))),
            Expanded(flex: 2, child: Text(rec?.checkIn.isNotEmpty == true ? rec!.checkIn : '—', style: const TextStyle(color: kTextGray, fontSize: 13))),
            Expanded(flex: 2, child: Text(rec?.checkOut.isNotEmpty == true ? rec!.checkOut : '—', style: const TextStyle(color: kTextGray, fontSize: 13))),
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: AttStatus.values.where((s) => s != AttStatus.holiday).map((s) {
                  final active = rec?.status == s;
                  final c = _statusColor(s);
                  return GestureDetector(
                    onTap: () => onMark(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? c.withOpacity(0.14) : kBgGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? c : Colors.transparent),
                      ),
                      child: Text(_statusLabel(s), style: TextStyle(color: active ? c : kTextGray, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(
              width: 90,
              child: IconButton(
                onPressed: onOpen,
                icon: const Icon(Icons.chevron_right_rounded, color: kTextGray),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(AttStatus s) => switch (s) {
  AttStatus.present => kGreen,
  AttStatus.absent => kRed,
  AttStatus.halfDay => kOrange,
  AttStatus.leave => kPurple,
  AttStatus.holiday => kTextGray,
};

String _statusLabel(AttStatus s) => switch (s) {
  AttStatus.present => 'Present',
  AttStatus.absent => 'Absent',
  AttStatus.halfDay => 'Half Day',
  AttStatus.leave => 'Leave',
  AttStatus.holiday => 'Holiday',
};

// ─── Employee Dialog (profile + monthly history + add new) ────────────────────
class EmployeeDialog extends StatefulWidget {
  final Employee? employee; // null = add new
  final DateTime selectedDate;
  const EmployeeDialog({super.key, required this.employee, required this.selectedDate});

  @override
  State<EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<EmployeeDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _roleCtrl;
  late TextEditingController _phoneCtrl;
  static int _idCounter = 7;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _roleCtrl = TextEditingController(text: e?.role ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty || _roleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter name and role'), backgroundColor: kRed));
      return;
    }
    if (widget.employee != null) {
      widget.employee!.name = _nameCtrl.text.trim();
      widget.employee!.role = _roleCtrl.text.trim();
      widget.employee!.phone = _phoneCtrl.text.trim();
      Navigator.pop(context, widget.employee);
    } else {
      Navigator.pop(context, Employee(id: 'E${_idCounter++}', name: _nameCtrl.text.trim(), role: _roleCtrl.text.trim(), phone: _phoneCtrl.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.employee == null;
    final stats = widget.employee?.monthStats(widget.selectedDate);
    final sortedDates = widget.employee?.records.keys.toList()?..sort((a, b) => b.compareTo(a));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(color: kBlue, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(
                children: [
                  Icon(isNew ? Icons.person_add_rounded : Icons.badge_rounded, color: kWhite),
                  const SizedBox(width: 10),
                  Text(isNew ? 'Add Employee' : widget.employee!.name,
                      style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 16)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: kWhite), padding: EdgeInsets.zero),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _Field('Name *', _nameCtrl, hint: 'e.g. Anil Kumar')),
                        const SizedBox(width: 16),
                        Expanded(child: _Field('Role *', _roleCtrl, hint: 'e.g. Waiter')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _Field('Phone', _phoneCtrl, hint: 'e.g. 9876543210', keyboardType: TextInputType.phone),

                    if (!isNew) ...[
                      const SizedBox(height: 24),
                      const Text('This Month', style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 14)),
                      const SizedBox(height: 10),
                      Row(
                        children: AttStatus.values.where((s) => s != AttStatus.holiday).map((s) {
                          final count = stats?[s] ?? 0;
                          final c = _statusColor(s);
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: Column(
                                children: [
                                  Text('$count', style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 16)),
                                  const SizedBox(height: 2),
                                  Text(_statusLabel(s), style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('Recent History', style: TextStyle(fontWeight: FontWeight.w700, color: kTextDark, fontSize: 14)),
                      const SizedBox(height: 10),
                      if (sortedDates == null || sortedDates.isEmpty)
                        const Text('No records yet', style: TextStyle(color: kTextGray, fontSize: 13))
                      else
                        ...sortedDates.take(10).map((k) {
                          final r = widget.employee!.records[k]!;
                          final c = _statusColor(r.status);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Expanded(child: Text(k, style: const TextStyle(color: kTextDark, fontSize: 13))),
                                Text(_statusLabel(r.status), style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 12)),
                                if (r.checkIn.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Text('${r.checkIn} - ${r.checkOut.isEmpty ? '...' : r.checkOut}', style: const TextStyle(color: kTextGray, fontSize: 11)),
                                ],
                              ],
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBlue, foregroundColor: kWhite, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    icon: Icon(isNew ? Icons.person_add_rounded : Icons.save_rounded, size: 18),
                    label: Text(isNew ? 'Add Employee' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Field Helper ─────────────────────────────────────────────────────────────
Widget _Field(String label, TextEditingController ctrl, {
  String hint = '',
  TextInputType keyboardType = TextInputType.text,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: kTextGray, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
          filled: true,
          fillColor: kBgGray,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBlue, width: 1.5)),
        ),
      ),
    ],
  );
}