import 'package:flutter/material.dart';

class LoadingFooter extends StatelessWidget {
  const LoadingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 40),
      child: Text(
        "Ver 1.0.0\nProfessional Bending Tool",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white24, fontSize: 12),
      ),
    );
  }
}
