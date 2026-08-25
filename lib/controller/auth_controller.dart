import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/service/api_service.dart';

class AuthController extends GetxController {
  final ApiService _api = ApiService.instance;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<Map<String, dynamic>> currentUser = Rxn<Map<String, dynamic>>();

  bool get isLoggedIn => _api.isLoggedIn;

  @override
  void onInit() {
    super.onInit();
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

  Future<void> _loadProfile() async {
    try {
      currentUser.value = await _api.getProfile();
    } on ApiException {
      // Token is stale/invalid — drop it so the login screen shows again.
      _api.clearToken();
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
      currentUser.value = (data['user'] is Map)
          ? Map<String, dynamic>.from(data['user'])
          : data;
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
    final name = "grillo";
    final email = "grillo@gmail.com";
    final password = "123456";
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      errorMessage.value = 'Fill in all fields';
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
