import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/controller/employee_controller.dart';
import 'package:test_bill/controller/product_controller.dart';
import 'package:test_bill/controller/table_controller.dart';
import 'package:test_bill/controller/transaction_controller.dart';
import 'package:test_bill/service/api_service.dart';
import 'package:test_bill/view/home_page.dart';
import 'package:test_bill/view/login/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  Get.put(ProductController(), permanent: true);
  Get.put(AuthController(), permanent: true);
  Get.put(TableController(), permanent: true);
  Get.put(BillController(), permanent: true);
  Get.put(TransactionController(), permanent: true);
  Get.put(EmployeeController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ApiService.instance.isLoggedIn;
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? const HomePage() : const LoginPage(),
    );
  }
}
