import 'package:flutter/material.dart';

class AppDialog {
  static void show(
    BuildContext context, {
    required String message,
    bool isSuccess = false,
    bool barrierDismissible = false,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Icon(
          isSuccess ? Icons.check_circle : Icons.error,
          color: isSuccess ? Colors.green : Colors.red,
          size: 50,
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (onOk != null) onOk();
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }
}