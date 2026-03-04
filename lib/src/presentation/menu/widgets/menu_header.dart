import 'package:flutter/material.dart';

class MenuHeader extends StatelessWidget {
  const MenuHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        SizedBox(height: 20),
        Text(
          "안전 작업 하십쇼!",
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
        SizedBox(height: 8),
        Text(
          "TUBE MASTER PRO\n작업 메뉴",
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            height: 1.3,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(height: 40),
      ],
    );
  }
}
