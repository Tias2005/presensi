import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/theme.dart';
import '../config.dart';
import 'package:intl/intl.dart';
import '../widgets/app_refresh_wrapper.dart';
import '../widgets/app_dialog.dart';

class NotificationPage extends StatefulWidget {
  final String userId;
  const NotificationPage({super.key, required this.userId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List _notifications = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  void _showNotifDetail(Map<String, dynamic> notif) {
    if (notif['status_baca'] == 0) {
      _markAsRead(notif['id_notifikasi']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Text(
                notif['judul'] ?? "Detail Notifikasi",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.parse(notif['created_at']).toLocal()),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Divider(height: 32),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  notif['pesan'],
                  style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
                ),
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Tutup", style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse("${AppConfig.apiUrl}/notifications/${widget.userId}"),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = jsonDecode(response.body)['data'];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      dev.log("Exception: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    await http.put(
      Uri.parse("${AppConfig.apiUrl}/notifications/read/$id"),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    _fetchNotifications();
  }

  Future<void> _deleteNotification(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final response = await http.delete(
      Uri.parse("${AppConfig.apiUrl}/notifications/$id"),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      _fetchNotifications();
    }
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Notifikasi"),
        content: Text("Apakah Anda yakin ingin menghapus $count notifikasi ini?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tidak"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context); 
              for (var id in _selectedIds) {
                await _deleteNotification(id);
              }
              if (!mounted) return; 
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });
              AppDialog.show(
                context,
                message: "$count notifikasi telah berhasil dihapus",
                isSuccess: true,
              );
            },
            child: const Text("Ya", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleSelection(int id) {
    setState(() {
      _isSelectionMode = true;

      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _notifications.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds =
            _notifications.map<int>((e) => e['id_notifikasi'] as int).toSet();
        _isSelectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, 
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: _isSelectionMode
              ? Text(
                  "${_selectedIds.length} dipilih dari ${_notifications.length}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const Text(
                  "Notifikasi",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          actions: _isSelectionMode
              ? [
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed:
                        _selectedIds.isEmpty ? null : () => _deleteSelected(),
                  )
                ]
              : [],
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 10),
                      Text("Tidak ada notifikasi", style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                )
              : AppRefreshWrapper(
                  color: AppColors.primary,
                  onRefresh: _fetchNotifications,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    children: [

                      if (_isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selectedIds.length == _notifications.length,
                                onChanged: (_) => _selectAll(),
                              ),
                              const Text(
                                "Pilih Semua",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),

                      ...List.generate(_notifications.length, (index) {
                        final notif = _notifications[index];
                        bool isUnread = notif['status_baca'] == 0;

                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          tileColor: isUnread
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.white,

                          leading: _isSelectionMode
                              ? Checkbox(
                                  value: _selectedIds.contains(notif['id_notifikasi']),
                                  onChanged: (_) =>
                                      _toggleSelection(notif['id_notifikasi']),
                                )
                              : CircleAvatar(
                                  radius: 22,
                                  backgroundColor:
                                      isUnread ? AppColors.primary : Colors.grey[200],
                                  child: Icon(
                                    isUnread
                                        ? Icons.notifications_active
                                        : Icons.notifications_none,
                                    color: isUnread
                                        ? Colors.white
                                        : Colors.grey[500],
                                    size: 20,
                                  ),
                                ),

                          title: Text(
                            notif['judul'] ?? "Info Presensi",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  isUnread ? FontWeight.bold : FontWeight.w500,
                              color: isUnread
                                  ? Colors.black87
                                  : Colors.grey[700],
                            ),
                          ),

                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(notif['created_at']).toLocal()),
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey[500]),
                            ),
                          ),

                          trailing: !_isSelectionMode && isUnread
                              ? Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,

                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(notif['id_notifikasi']);
                            } else {
                              _showNotifDetail(notif);
                            }
                          },

                          onLongPress: () =>
                              _toggleSelection(notif['id_notifikasi']),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}