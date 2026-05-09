import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../shared/theme.dart';
import '../config.dart';
import '../widgets/app_dialog.dart';
import '../widgets/pengajuan/sisa_cuti_info.dart';
import '../widgets/pengajuan/date_picker_field.dart';
import '../widgets/pengajuan/time_picker_field.dart';
import '../widgets/pengajuan/lampiran_picker.dart';
import '../widgets/pengajuan/submit_button.dart';
// import 'dart:math';

class FormPengajuanPage extends StatefulWidget {
  final String tipe;
  final int idKategori;

  const FormPengajuanPage({
    super.key,
    required this.tipe,
    required this.idKategori,
  });

  @override
  State<FormPengajuanPage> createState() => _FormPengajuanPageState();
}

class _FormPengajuanPageState extends State<FormPengajuanPage> {
  final TextEditingController _alasanController = TextEditingController();
  DateTime? _tglMulai;
  DateTime? _tglSelesai;
  TimeOfDay? _jamMulai;
  TimeOfDay? _jamSelesai;
  final List<File> _lampiranFiles = [];
  static const int _maxFiles = 5;
  static const int _maxTotalSize = 10 * 1024 * 1024; // 10 MB
  bool _isSubmitting = false;
  int? _sisaCuti;

  @override
  void initState() {
    super.initState();
    if (widget.tipe == "Cuti") _fetchSisaCuti();
  }

  Future<void> _fetchSisaCuti() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;

      final userData = jsonDecode(userDataString);
      final response = await http.get(
        Uri.parse(
            "${AppConfig.apiUrl}/jatah-cuti/karyawan/${userData['id_user']}"),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() => _sisaCuti = result['data']['sisa'] ?? 0);
      }
    } catch (e) {
      debugPrint("Error fetch sisa cuti: $e");
    }
  }

  Future<void> _pickFile() async {
    if (_lampiranFiles.length >= _maxFiles) {
      AppDialog.show(
        context,
        message: "Maksimal $_maxFiles lampiran",
      );
      return;
    }

    final remaining = _maxFiles - _lampiranFiles.length;

    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result == null) return;

    final pickedFiles = result.files
        .where((f) => f.path != null)
        .take(remaining)
        .map((f) => File(f.path!))
        .toList();

    final combinedFiles = [
      ..._lampiranFiles,
      ...pickedFiles,
    ];

    final totalSize = _getTotalFileSize(combinedFiles);

    if (totalSize > _maxTotalSize) {
      if (!mounted) return;

      AppDialog.show(
        context,
        message: "Total ukuran lampiran maksimal 10 MB",
      );
      return;
    }

    setState(() {
      _lampiranFiles.addAll(pickedFiles);
    });

    if (result.files.length > remaining && mounted) {
      AppDialog.show(
        context,
        message:
            "Hanya $remaining file yang ditambahkan (maksimal $_maxFiles file)",
      );
    }
  }

  void _removeFile(int index) {
    setState(() {
      _lampiranFiles.removeAt(index);
    });
  }

  int _getTotalFileSize(List<File> files) {
    int total = 0;

    for (final file in files) {
      total += file.lengthSync();
    }

    return total;
  }

  Future<void> _selectDate(bool isMulai) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null && mounted) {
      setState(() => isMulai ? _tglMulai = picked : _tglSelesai = picked);
    }
  }

  Future<void> _submitForm() async {
    if (_tglMulai == null || _alasanController.text.isEmpty) {
      AppDialog.show(context, message: "Mohon isi tanggal dan alasan");
      return;
    }
    if (widget.tipe == "Lembur" && (_jamMulai == null || _jamSelesai == null)) {
      AppDialog.show(
          context, message: "Mohon isi jam mulai dan jam selesai lembur");
      return;
    }

    setState(() => _isSubmitting = true);

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final userDataString = prefs.getString('user_data');
    if (userDataString == null) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    final userData = jsonDecode(userDataString);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse("${AppConfig.apiUrl}/pengajuan/store"),
      );
      request.headers['Accept'] = 'application/json';

      final tglMulaiStr = DateFormat('yyyy-MM-dd').format(_tglMulai!);

      request.fields['id_user'] = userData['id_user'].toString();
      request.fields['id_kategori_pengajuan'] = widget.idKategori.toString();
      request.fields['alasan'] = _alasanController.text;
      request.fields['tanggal_mulai'] = tglMulaiStr;

      if (widget.tipe == "Lembur") {
        request.fields['tanggal_selesai'] = tglMulaiStr;
        request.fields['jam_mulai'] =
            "${_jamMulai!.hour.toString().padLeft(2, '0')}:${_jamMulai!.minute.toString().padLeft(2, '0')}";
        request.fields['jam_selesai'] =
            "${_jamSelesai!.hour.toString().padLeft(2, '0')}:${_jamSelesai!.minute.toString().padLeft(2, '0')}";
      } else if (_tglSelesai != null) {
        request.fields['tanggal_selesai'] =
            DateFormat('yyyy-MM-dd').format(_tglSelesai!);
      }

      for (final file in _lampiranFiles) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'lampiran[]', 
            file.path,
          ),
        );
      }

      final response = await request.send();
      if (!mounted) return;

      if (response.statusCode == 200) {
        AppDialog.show(
          context,
          message: "Pengajuan Berhasil Dikirim",
          isSuccess: true,
          onOk: () => Navigator.pop(context, true),
        );
      } else {
        final respBody = await response.stream.bytesToString();
        if (!mounted) return;
        final decoded = jsonDecode(respBody);
        AppDialog.show(
            context, message: decoded['message'] ?? "Gagal mengirim pengajuan");
      }
    } catch (e) {
      if (!mounted) return;
      AppDialog.show(context, message: "Terjadi kesalahan koneksi ke server");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Form ${widget.tipe}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 5,
                  height: 25,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Detail ${widget.tipe}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),

            if (widget.tipe == "Cuti") ...[
              const SizedBox(height: 15),
              SisaCutiInfo(sisaCuti: _sisaCuti),
            ],

            const SizedBox(height: 25),

            DatePickerField(
              label: widget.tipe == "Lembur" ? "Tanggal Lembur" : "Tanggal Mulai",
              selectedDate: _tglMulai,
              onTap: () => _selectDate(true),
            ),

            if (widget.tipe != "Lembur") ...[
              const SizedBox(height: 15),
              DatePickerField(
                label: "Tanggal Selesai",
                selectedDate: _tglSelesai,
                onTap: () => _selectDate(false),
              ),
            ],

            if (widget.tipe == "Lembur") ...[
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TimePickerField(
                      label: "Jam Mulai",
                      time: _jamMulai,
                      onSelected: (t) => setState(() => _jamMulai = t),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: TimePickerField(
                      label: "Jam Selesai",
                      time: _jamSelesai,
                      onSelected: (t) => setState(() => _jamSelesai = t),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 15),
            const Text("Alasan",
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: _alasanController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Tuliskan alasan pengajuan...",
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 15),
            LampiranPicker(
              files: _lampiranFiles,
              onTap: _pickFile,
              onRemove: _removeFile,
            ),

            const SizedBox(height: 30),
            SubmitButton(
              isSubmitting: _isSubmitting,
              onPressed: _submitForm,
            ),
          ],
        ),
      ),
    );
  }
}