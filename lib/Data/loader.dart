import 'package:flutter/material.dart';

class GradientSpinner extends StatelessWidget {
  const GradientSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 56,
        height: 56,
        child: CircularProgressIndicator(
          color: Colors.redAccent,
          strokeWidth: 4,
        ),
      ),
    );
  }
}