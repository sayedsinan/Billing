import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/view/home_page.dart';
import 'package:test_bill/view/mobile/waiter_mobile_page.dart';
import 'package:test_bill/view/widgets/my_button.dart';
import 'package:test_bill/view/widgets/my_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Mode selection for desktop: 'admin' or 'waiter'
  String _selectedMode = 'admin';

  Future<void> _submit(
    BuildContext context,
    AuthController authController,
    bool isMobile,
  ) async {
    final mode = isMobile ? 'waiter' : _selectedMode;
    authController.targetMode.value = mode;

    final ok = await authController.login();

    if (ok && context.mounted) {
      if (mode == 'admin') {
        Get.offAll(() => const HomePage());
      } else {
        Get.offAll(() => const WaiterMobilePage());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();
    final isMobile = MediaQuery.of(context).size.width < 700;

    final formWidget = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: isMobile ? double.infinity : 350,
          constraints: const BoxConstraints(maxWidth: 400),
          child: Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMobile) ...[
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.table_restaurant,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  isMobile ? "Waiter Order Station Login" : "Login to continue",
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),

                const SizedBox(height: 25),

                // On Desktop/Windows show Panel Selection; On Mobile hide dropdown (locked to Waiter)
                if (!isMobile) ...[
                  Container(
                    width: 300,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedMode,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'admin',
                            child: Row(
                              children: [
                                Icon(Icons.admin_panel_settings, size: 20, color: Colors.blue),
                                SizedBox(width: 10),
                                Text('Admin Panel Login'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'waiter',
                            child: Row(
                              children: [
                                Icon(Icons.table_restaurant, size: 20, color: Colors.green),
                                SizedBox(width: 10),
                                Text('Waiter Order Login'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMode = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                MyTextField(
                  hintText: "Email",
                  height: 50,
                  width: isMobile ? double.infinity : 300,
                  keyboardType: TextInputType.emailAddress,
                  controller: authController.emailController,
                ),

                const SizedBox(height: 20),

                MyTextField(
                  hintText: "Password",
                  height: 50,
                  width: isMobile ? double.infinity : 300,
                  keyboardType: TextInputType.text,
                  controller: authController.passwordController,
                  hide: true,
                  onSubmitted: (_) => _submit(context, authController, isMobile),
                ),

                if (authController.errorMessage.value.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: isMobile ? double.infinity : 300,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authController.errorMessage.value,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 30),

                MyButton(
                  text: authController.isLoading.value
                      ? "Logging in..."
                      : (isMobile ? "Login as Waiter" : "Login"),
                  width: isMobile ? double.infinity : 300,
                  height: 50,
                  color: isMobile ? Colors.green : Colors.blue,
                  onPressed: () {
                    if (!authController.isLoading.value) {
                      _submit(context, authController, isMobile);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: isMobile
          ? SafeArea(child: formWidget)
          : Row(
              children: [
                // Left Side Image for Desktop
                Expanded(
                  flex: 1,
                  child: Image.asset(
                    "assets/bill.png",
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                // Right Side Form for Desktop
                Expanded(
                  flex: 1,
                  child: formWidget,
                ),
              ],
            ),
    );
  }
}
