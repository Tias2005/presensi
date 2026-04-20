import 'package:flutter/material.dart';
import '../../shared/theme.dart';
import 'profile_text_field.dart';
import 'section_header.dart';

class SecuritySection extends StatelessWidget {
  final TextEditingController passLamaController;
  final TextEditingController passBaruController;
  final VoidCallback onUpdateFace;

  const SecuritySection({
    super.key,
    required this.passLamaController,
    required this.passBaruController,
    required this.onUpdateFace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: "Keamanan & Wajah", color: Colors.orange),
        const SizedBox(height: 15),

        ProfileTextField(
          "Password Lama",
          passLamaController,
          Icons.lock_outline,
          isPass: true,
        ),
        ProfileTextField(
          "Password Baru",
          passBaruController,
          Icons.lock_reset,
          isPass: true,
        ),

        const SizedBox(height: 5),

        OutlinedButton.icon(
          onPressed: onUpdateFace,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.face_retouching_natural),
          label: const Text("UPDATE SCAN WAJAH (FOTO PROFIL)"),
        ),
      ],
    );
  }
}