import 'dart:io';
import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class LampiranPicker extends StatelessWidget {
  final List<File> files;
  final VoidCallback onTap;
  final Function(int index) onRemove;

  const LampiranPicker({
    super.key,
    required this.files,
    required this.onTap,
    required this.onRemove,
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
        Text(
          "Maksimal 5 file • Total 10 MB",
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
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
            child: const Row(
              children: [
                Icon(Icons.attachment, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Pilih Foto/Dokumen",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Icon(Icons.add_circle, color: AppColors.primary),
              ],
            ),
          ),
        ),

        if (files.isNotEmpty) ...[
          const SizedBox(height: 12),

          ...List.generate(files.length, (index) {
            final file = files[index];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      file.path.split('/').last,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  IconButton(
                    onPressed: () => onRemove(index),
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}