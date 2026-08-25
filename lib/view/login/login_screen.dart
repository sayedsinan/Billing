import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/view/home_page.dart';
import 'package:test_bill/view/widgets/my_button.dart';
import 'package:test_bill/view/widgets/my_text_field.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _submit(
    BuildContext context,
    AuthController authController,
  ) async {
    final ok = await authController.login();
    if (ok && context.mounted) {
      Get.offAll(() => const HomePage());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      body: Row(
        children: [
          // Left Side Image
          Expanded(
            flex: 1,
            child: Image.asset(
              "assets/bill.png",
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Right Side Login Form
          Expanded(
            flex: 1,
            child: Center(
              child: Container(
                width: 350,
                padding: const EdgeInsets.all(24),
                child: Obx(
                  () => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        "Login to continue",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),

                      const SizedBox(height: 40),

                      MyTextField(
                        hintText: "Email",
                        height: 50,
                        width: 300,
                        keyboardType: TextInputType.emailAddress,
                        controller: authController.emailController,
                      ),

                      const SizedBox(height: 20),

                      MyTextField(
                        hintText: "Password",
                        height: 50,
                        width: 300,
                        keyboardType: TextInputType.text,
                        controller: authController.passwordController,
                        hide: true,
                        onSubmitted: (_) => _submit(context, authController),
                      ),

                      if (authController.errorMessage.value.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: 300,
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
                            : "Login",
                        width: 300,
                        height: 50,
                        color: Colors.blue,
                        onPressed:(){
                          authController.isLoading.value
                              ? null
                              : _submit(context, authController);
                        }
                            // ? () {}
                            // : () => _submit(context, authController),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
