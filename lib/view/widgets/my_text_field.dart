import 'package:flutter/material.dart';

class MyTextField extends StatelessWidget {
  final String hintText;
  final double height;
  final double width;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final bool hide;
  final ValueChanged<String>? onSubmitted;
  const MyTextField({
    super.key,
    required this.hintText,
    required this.height,
    required this.width,
    required this.keyboardType,
    required this.controller,
    this.hide=false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.black),
      ),
      child: TextField(
        
        controller:controller,
      obscureText: hide,
        decoration: InputDecoration(
          hintText: hintText,
          border: InputBorder.none,

          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
        
        ),
        
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
    
      ),
    );
  }
}