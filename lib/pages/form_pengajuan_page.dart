import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../shared/theme.dart';

class FormPengajuanPage extends StatefulWidget {
  final String tipe; 
  final int idKategori;

  const FormPengajuanPage({super.key, required this.tipe, required this.idKategori});

  @override
  State<FormPengajuanPage> createState() => _FormPengajuanPageState();
}

class _FormPengajuanPageState extends State<FormPengajuanPage> {
  final TextEditingController _alasanController = TextEditingController();
  DateTime? _tglMulai;
  DateTime? _tglSelesai;
  TimeOfDay? _jamMulai;
  TimeOfDay? _jamSelesai;
  File? _imageFile;
  bool _isSubmitting = false;

Future<void> _pickFile() async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
  );

  if (result != null && result.files.single.path != null) {
    setState(() {
      _imageFile = File(result.files.single.path!);
    });
  }
}

  Future<void> _selectDate(BuildContext context, bool isMulai) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly, 
    );

    if (picked != null && mounted) {
      setState(() {
        if (isMulai) {
          _tglMulai = picked;
        } else {
          _tglSelesai = picked;
        }
      });
    }
  }

Future<void> _submitForm() async {
  if (_tglMulai == null || _alasanController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mohon isi tanggal dan alasan")),
    );
    return;
  }

  if (widget.tipe == "Lembur" && (_jamMulai == null || _jamSelesai == null)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Mohon isi jam mulai dan jam selesai lembur")),
    );
    return;
  }

  setState(() => _isSubmitting = true);

  final scaffoldMessenger = ScaffoldMessenger.of(context);
  
  final prefs = await SharedPreferences.getInstance();
  final userDataString = prefs.getString('user_data');
  
  if (userDataString == null) {
    if (mounted) setState(() => _isSubmitting = false);
    return;
  }
  
  final userData = jsonDecode(userDataString);

  try {
    var request = http.MultipartRequest(
      'POST', 
      Uri.parse("http://192.168.229.178:8000/api/pengajuan/store")
    );

    request.fields['id_user'] = userData['id_user'].toString();
    request.fields['id_kategori_pengajuan'] = widget.idKategori.toString();
    request.fields['alasan'] = _alasanController.text;
    
    String tglMulaiStr = DateFormat('yyyy-MM-dd').format(_tglMulai!);
    request.fields['tanggal_mulai'] = tglMulaiStr;

    if (widget.tipe == "Lembur") {
      request.fields['tanggal_selesai'] = tglMulaiStr;
      
      request.fields['jam_mulai'] = "${_jamMulai!.hour.toString().padLeft(2, '0')}:${_jamMulai!.minute.toString().padLeft(2, '0')}";
      request.fields['jam_selesai'] = "${_jamSelesai!.hour.toString().padLeft(2, '0')}:${_jamSelesai!.minute.toString().padLeft(2, '0')}";
    } else {
      if (_tglSelesai != null) {
        request.fields['tanggal_selesai'] = DateFormat('yyyy-MM-dd').format(_tglSelesai!);
      }
    }

    if (_imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('lampiran', _imageFile!.path));
    }

    var response = await request.send();

    if (!mounted) return;

    if (response.statusCode == 200) {
      _showSuccessDialog();
    } else {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Gagal mengirim pengajuan (Error: ${response.statusCode})")),
      );
    }
  } catch (e) {
    debugPrint("Error submit: $e");
    if (mounted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text("Terjadi kesalahan koneksi ke server")),
      );
    }
  } finally {
    if (mounted) setState(() => _isSubmitting = false);
  }
}

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Icon(Icons.check_circle, color: Colors.green, size: 60),
        content: const Text("Pengajuan Berhasil Dikirim", textAlign: TextAlign.center),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("Form ${widget.tipe}", style: const TextStyle(color: AppColors.primary, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Detail ${widget.tipe}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            
            _buildDatePicker(
              label: widget.tipe == "Lembur" ? "Tanggal Lembur" : "Tanggal Mulai",
              selectedDate: _tglMulai,
              onTap: () => _selectDate(context, true),
            ),

            if (widget.tipe != "Lembur") ...[
              const SizedBox(height: 15),
              _buildDatePicker(
                label: "Tanggal Selesai",
                selectedDate: _tglSelesai,
                onTap: () => _selectDate(context, false),
              ),
            ],

            if (widget.tipe == "Lembur") ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTimePicker("Jam Mulai", _jamMulai, (t) => setState(() => _jamMulai = t))),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTimePicker("Jam Selesai", _jamSelesai, (t) => setState(() => _jamSelesai = t))),
                ],
              ),
            ],

            const SizedBox(height: 15),
            const Text("Alasan", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _alasanController, 
              maxLines: 3, 
              decoration: InputDecoration(
                hintText: "Tuliskan alasan pengajuan...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 15),
            const Text("Lampiran (Opsional)", style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickFile,
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
                        _imageFile == null ? "Pilih Foto/Dokumen" : _imageFile!.path.split('/').last,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _imageFile == null ? Colors.grey : Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Kirim Pengajuan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker({required String label, DateTime? selectedDate, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300), 
              borderRadius: BorderRadius.circular(8)
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(selectedDate == null ? "Pilih Tanggal" : DateFormat('dd/MM/yyyy').format(selectedDate)),
                const Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay? time, Function(TimeOfDay) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
            if (t != null && mounted) onSelected(t);
          },
          child: Container(
            padding: const EdgeInsets.all(15),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300), 
              borderRadius: BorderRadius.circular(8)
            ),
            child: Text(time == null ? "-- : --" : "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}", textAlign: TextAlign.center),
          ),
        ),
      ],
    );
  }
}