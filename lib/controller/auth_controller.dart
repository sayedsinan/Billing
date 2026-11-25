import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:test_bill/service/api_service.dart';

class AuthController extends GetxController {
  final ApiService _api = ApiService.instance;
  final GetStorage _box = GetStorage();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<Map<String, dynamic>> currentUser = Rxn<Map<String, dynamic>>();
  final RxString targetMode = 'admin'.obs; // 'admin' or 'waiter'

  bool get isLoggedIn => _api.isLoggedIn;

  @override
  void onInit() {
    super.onInit();
    final savedMode = _box.read<String>('target_mode');
    if (savedMode != null) {
      targetMode.value = savedMode;
    } else if (!GetPlatform.isWindows) {
      targetMode.value = 'waiter';
    }
    // If a token survived from a previous session, hydrate the profile.
    if (_api.isLoggedIn) _loadProfile();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.onClose();
  }

  static bool isLegacySeededName(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    return v == 'grillo cafe & restaurant' ||
        v == 'grillo billing' ||
        v == 'grillo';
  }

  static bool isLegacySeededPhone(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    return v == '+91 98765 43210';
  }

  static bool isLegacySeededAddress(String? value) {
    final v = (value ?? '').trim().toLowerCase();
    return v == 'main street, city centre' || v == 'main street, city';
  }

  void _syncTenantSettings(dynamic tenant) {
    final customized = _box.read<bool>('store_profile_customized') == true;

    // Clear any previously cached legacy Grillo defaults if not explicitly customized
    if (!customized) {
      if (isLegacySeededName(_box.read<String>('shop_name'))) {
        _box.write('shop_name', '');
      }
      if (isLegacySeededPhone(_box.read<String>('shop_phone'))) {
        _box.write('shop_phone', '');
      }
      if (isLegacySeededAddress(_box.read<String>('shop_address'))) {
        _box.write('shop_address', '');
      }
    }

    if (tenant is Map) {
      final t = Map<String, dynamic>.from(tenant);
      final serverName = t['name']?.toString().trim() ?? '';
      final serverPhone = t['phone']?.toString().trim() ?? '';
      final serverAddress = t['address']?.toString().trim() ?? '';

      if (customized) {
        // Keep the user's locally saved profile if server still holds legacy seeded defaults
        if (serverName.isNotEmpty && !isLegacySeededName(serverName)) {
          _box.write('shop_name', serverName);
        }
        if (serverPhone.isNotEmpty && !isLegacySeededPhone(serverPhone)) {
          _box.write('shop_phone', serverPhone);
        }
        if (serverAddress.isNotEmpty && !isLegacySeededAddress(serverAddress)) {
          _box.write('shop_address', serverAddress);
        }
      } else {
        if (serverName.isNotEmpty && !isLegacySeededName(serverName)) {
          _box.write('shop_name', serverName);
        }
        if (serverPhone.isNotEmpty && !isLegacySeededPhone(serverPhone)) {
          _box.write('shop_phone', serverPhone);
        }
        if (serverAddress.isNotEmpty && !isLegacySeededAddress(serverAddress)) {
          _box.write('shop_address', serverAddress);
        }
      }

      if (!customized && t['receiptFooter'] != null) {
        _box.write('footer_note', t['receiptFooter'].toString());
      }
      if (t['gstin'] != null) _box.write('shop_gstin', t['gstin'].toString());
      if (t['currency'] != null) _box.write('currency_symbol', t['currency'].toString());
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.getProfile();
      currentUser.value = profile;
      _syncTenantSettings(profile['tenant']);
    } on ApiException {
      // Token is stale/invalid — drop it so the login screen shows again.
      _api.clearToken();
      _box.remove('target_mode');
    }
  }

  Future<bool> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Enter your email and password';
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await _api.login(email: email, password: password);
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        errorMessage.value = 'Login failed: no token returned';
        return false;
      }
      _api.saveToken(token);
      _box.write('target_mode', targetMode.value);
      currentUser.value = (data['user'] is Map)
          ? Map<String, dynamic>.from(data['user'])
          : data;

      _syncTenantSettings(data['tenant']);

      passwordController.clear();
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> register({String? role}) async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final name = email.isNotEmpty && email.contains('@') ? email.split('@').first : email;
    if (email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Enter email and password to register';
      return false;
    }

    isLoading.value = true;
    errorMessage.value = '';
    try {
      final data = await _api.register(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      final token = data['token']?.toString();
      if (token != null && token.isNotEmpty) {
        _api.saveToken(token);
        currentUser.value = (data['user'] is Map)
            ? Map<String, dynamic>.from(data['user'])
            : data;
      }
      passwordController.clear();
      return true;
    } on ApiException catch (e) {
      errorMessage.value = e.message;
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  void logout() {
    _api.clearToken();
    currentUser.value = null;
    emailController.clear();
    passwordController.clear();
    errorMessage.value = '';
  }
}
