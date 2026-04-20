import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class StatusCard extends StatelessWidget {
  final String title;
  final String time;
  final String location;
  final bool isDone;
  final bool isEnabled;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.title,
    required this.time,
    required this.location,
    required this.isDone,
    required this.isEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDone
              ? AppColors.grey.withValues(alpha: 0.1)
              : AppColors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isDone
                ? Colors.transparent
                : AppColors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.grey)),
            const SizedBox(height: 5),
            Text(
              time,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDone ? AppColors.primary : Colors.black,
              ),
            ),
            Text(
              location,
              style:
                  const TextStyle(fontSize: 11, color: AppColors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            if (isDone)
              const Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                  SizedBox(width: 5),
                  Text("Selesai",
                      style: TextStyle(
                          fontSize: 12, color: AppColors.success))
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isEnabled ? onTap : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEnabled
                        ? AppColors.primary
                        : Colors.grey[300],
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    "Scan Sekarang",
                    style: TextStyle(
                      fontSize: 10,
                      color: isEnabled
                          ? AppColors.white
                          : Colors.grey[600],
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}