import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../shared/theme.dart';
import '../config.dart';
import '../widgets/app_dialog.dart';

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
  
  int? _sisaCuti;

  @override
  void initState() {
    super.initState();
    if (widget.tipe == "Cuti") {
      _fetchSisaCuti();
    }
  }

  Future<void> _fetchSisaCuti() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString('user_data');
      if (userDataString == null) return;
      
      final userData = jsonDecode(userDataString);
      final response = await http.get(
        Uri.parse("${AppConfig.apiUrl}/jatah-cuti/karyawan/${userData['id_user']}"),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        setState(() {
          _sisaCuti = result['data']['sisa'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error fetch sisa cuti: $e");
    }
  }

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
      AppDialog.show(
        context,
        message: "Mohon isi tanggal dan alasan",
      );
      return;
    }

    if (widget.tipe == "Lembur" && (_jamMulai == null || _jamSelesai == null)) {
      AppDialog.show(
        context,
        message: "Mohon isi jam mulai dan jam selesai lembur",
      );
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

      request.fields['id_user'] = userData['id_user'].toString();
      request.fields['id_kategori_pengajuan'] = widget.idKategori.toString();
      request.fields['alasan'] = _alasanController.text;

      String tglMulaiStr = DateFormat('yyyy-MM-dd').format(_tglMulai!);
      request.fields['tanggal_mulai'] = tglMulaiStr;

      if (widget.tipe == "Lembur") {
        request.fields['tanggal_selesai'] = tglMulaiStr;
        request.fields['jam_mulai'] =
            "${_jamMulai!.hour.toString().padLeft(2, '0')}:${_jamMulai!.minute.toString().padLeft(2, '0')}";
        request.fields['jam_selesai'] =
            "${_jamSelesai!.hour.toString().padLeft(2, '0')}:${_jamSelesai!.minute.toString().padLeft(2, '0')}";
      } else {
        if (_tglSelesai != null) {
          request.fields['tanggal_selesai'] =
              DateFormat('yyyy-MM-dd').format(_tglSelesai!);
        }
      }

      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('lampiran', _imageFile!.path),
        );
      }

      var response = await request.send();
      if (!mounted) return;

      if (response.statusCode == 200) {
        AppDialog.show(
          context,
          message: "Pengajuan Berhasil Dikirim",
          isSuccess: true,
          onOk: () {
            // Navigator.pop(context);
            Navigator.pop(context, true);
          },
        );
      } else {
        final respBody = await response.stream.bytesToString();

        if (!mounted) return;

        final decodedResp = jsonDecode(respBody);

        AppDialog.show(
          context,
          message: decodedResp['message'] ?? "Gagal mengirim pengajuan",
        );
      }
    } catch (e) {
      if (!mounted) return;

      AppDialog.show(
        context,
        message: "Terjadi kesalahan koneksi ke server",
      );
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
          )
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
                    color: Colors.black87
                  )
                ),
              ],
            ),
            
            if (widget.tipe == "Cuti") ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      "Sisa Jatah Cuti: ${_sisaCuti ?? '-'} Hari",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold, 
                        color: AppColors.primary
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 25),
            
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