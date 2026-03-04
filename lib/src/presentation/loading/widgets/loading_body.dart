import 'package:flutter/material.dart';

class LoadingBody extends StatelessWidget {
  const LoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.touch_app, size: 60, color: Colors.orangeAccent),
        SizedBox(height: 20),
        Text(
          "TAP TO START",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 4.0,
          ),
        ),
      ],
    );
  }
}
