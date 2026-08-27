import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/service/api_service.dart';
import 'package:test_bill/theme/colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GetStorage _box = GetStorage();
  final BillController _billController = Get.find<BillController>();

  final TextEditingController _shopNameCtrl = TextEditingController();
  final TextEditingController _shopPhoneCtrl = TextEditingController();
  final TextEditingController _shopAddressCtrl = TextEditingController();
  final TextEditingController _footerNoteCtrl = TextEditingController();

  List<String> _printers = [];
  bool _loadingPrinters = false;
  String? _selectedPrinter;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _shopNameCtrl.text = _box.read<String>('shop_name') ?? 'Grillo Billing';
    _shopPhoneCtrl.text = _box.read<String>('shop_phone') ?? '+91 98765 43210';
    _shopAddressCtrl.text = _box.read<String>('shop_address') ?? 'Main Street, City';
    _footerNoteCtrl.text = _box.read<String>('footer_note') ?? 'Thank you, visit again!';
    _loadPrinters();
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _shopPhoneCtrl.dispose();
    _shopAddressCtrl.dispose();
    _footerNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    setState(() => _loadingPrinters = true);
    try {
      final list = await _billController.availablePrinters();
      await _billController.loadSavedPrinter();
      setState(() {
        _printers = list;
        _selectedPrinter = _billController.selectedPrinter.value.isNotEmpty
            ? _billController.selectedPrinter.value
            : (list.isNotEmpty ? list.first : null);
      });
    } catch (_) {
      // Ignore printer detection exceptions on unsupported environments
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    await _box.write('shop_name', _shopNameCtrl.text.trim());
    await _box.write('shop_phone', _shopPhoneCtrl.text.trim());
    await _box.write('shop_address', _shopAddressCtrl.text.trim());
    await _box.write('footer_note', _footerNoteCtrl.text.trim());

    if (_selectedPrinter != null) {
      await _billController.setPrinter(_selectedPrinter!);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully'),
          backgroundColor: kGreen,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgGray,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header
            Row(
              children: [
                const Icon(Icons.settings_rounded, size: 28, color: kBlue),
                const SizedBox(width: 12),
                const Text(
                  'System Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kTextDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _saveSettings,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kWhite),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store Details Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.store_rounded, color: kBlue, size: 20),
                            SizedBox(width: 8),
                            Text('Store & Receipt Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextDark)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildField('Business / Store Name', _shopNameCtrl, 'e.g. Grillo Restaurant'),
                        const SizedBox(height: 14),
                        _buildField('Phone Number', _shopPhoneCtrl, 'e.g. +91 98765 43210'),
                        const SizedBox(height: 14),
                        _buildField('Store Address', _shopAddressCtrl, 'e.g. Main Street, Downtown'),
                        const SizedBox(height: 14),
                        _buildField('Receipt Footer Note', _footerNoteCtrl, 'e.g. Thank you, visit again!'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                 // Printer & Server Config Card
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: kWhite,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.print_rounded, color: kOrange, size: 20),
                                const SizedBox(width: 8),
                                const Text('Thermal Printer Setup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextDark)),
                                const Spacer(),
                                IconButton(
                                  onPressed: _loadingPrinters ? null : _loadPrinters,
                                  icon: const Icon(Icons.refresh_rounded, size: 18, color: kBlue),
                                  tooltip: 'Scan printers',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Active Printer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextGray)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: kBgGray,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: _loadingPrinters
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: kOrange)),
                                    )
                                  : DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: _printers.contains(_selectedPrinter) ? _selectedPrinter : null,
                                        hint: const Text('Select connected thermal printer', style: TextStyle(fontSize: 13, color: kTextGray)),
                                        items: _printers
                                            .map((p) => DropdownMenuItem(
                                                  value: p,
                                                  child: Text(p, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
                                                ))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedPrinter = val);
                                        },
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _printers.isEmpty
                                  ? 'No active printers detected on Windows. Connect USB/BT printer.'
                                  : '${_printers.length} printer(s) available on system.',
                              style: TextStyle(fontSize: 11, color: _printers.isEmpty ? kRed : kGreen, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextGray)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: kTextGray, fontSize: 13),
            filled: true,
            fillColor: kBgGray,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
