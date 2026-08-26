import 'package:flutter/material.dart';
import 'package:test_bill/controller/auth_controller.dart';
import 'package:test_bill/controller/bill_controller.dart';
import 'package:test_bill/controller/product_controller.dart';
import 'package:test_bill/controller/table_controller.dart';
import 'package:test_bill/view/login/login_screen.dart';
import 'package:get/get.dart';

void main() {
  Get.lazyPut(() => ProductController());
  Get.lazyPut(() => AuthController());
  Get.lazyPut(() => TableController());
  Get.lazyPut(() => BillController());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}
