import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class SubmitButton extends StatelessWidget {
  final bool isSubmitting;
  final VoidCallback onPressed;
  final String label;

  const SubmitButton({
    super.key,
    required this.isSubmitting,
    required this.onPressed,
    this.label = "Kirim Pengajuan",
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isSubmitting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isSubmitting
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}