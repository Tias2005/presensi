import 'package:flutter/material.dart';
import '../../shared/theme.dart';

class StepModeWidget extends StatelessWidget {
  final int? selectedModeId;
  final bool isCheckOut;
  final Function(int) onModeSelected;

  const StepModeWidget({
    super.key,
    required this.selectedModeId,
    required this.isCheckOut,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _modeCard(context, 1, "WFO (Office)", "Kerja dari Kantor", Icons.business),
        _modeCard(context, 2, "WFH (Home)", "Kerja dari Rumah", Icons.home),
        _modeCard(context, 3, "WFA (Anywhere)", "Kerja dari Mana Saja", Icons.public),
      ],
    );
  }

  Widget _modeCard(BuildContext context, int id, String title, String sub, IconData icon) {
    final bool disabled = isCheckOut && selectedModeId != id;

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: disabled ? Colors.grey : AppColors.primary, size: 30),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: disabled ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Text(sub),
        enabled: !disabled,
        onTap: disabled ? null : () => onModeSelected(id),
      ),
    );
  }
}