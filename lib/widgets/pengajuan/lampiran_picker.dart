import 'dart:io';
import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class LampiranPicker extends StatelessWidget {
  final File? file;
  final VoidCallback onTap;

  const LampiranPicker({
    super.key,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Lampiran (Opsional)",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.attachment, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    file == null
                        ? "Pilih Foto/Dokumen"
                        : file!.path.split('/').last,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: file == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}