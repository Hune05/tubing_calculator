import 'package:flutter/material.dart';

class LoadingHeader extends StatelessWidget {
  const LoadingHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 100),
      child: Column(
        children: [
          Icon(Icons.plumbing, size: 80, color: Colors.orangeAccent),
          SizedBox(height: 20),
          Text(
            "TUBE BENDING PRO",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
