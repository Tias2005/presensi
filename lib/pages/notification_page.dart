import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/theme.dart';
import '../config.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  final String userId;
  const NotificationPage({super.key, required this.userId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  List _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
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
        setState(() {
          _notifications = jsonDecode(response.body)['data'];
          _isLoading = false;
        });
      } else {
        dev.log("Error: ${response.body}");
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifikasi", style: TextStyle(color: AppColors.primary)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: AppColors.primary),
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text("Tidak ada notifikasi"))
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      bool isUnread = notif['status_baca'] == 0;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        tileColor: isUnread 
                            ? AppColors.primary.withValues(alpha: 0.05) 
                            : Colors.white,
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: isUnread 
                              ? AppColors.primary 
                              : Colors.grey[400],
                          child: const Icon(
                            Icons.notifications,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          notif['pesan'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isUnread 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            DateFormat('dd MMM yyyy, HH:mm')
                                .format(DateTime.parse(notif['created_at'])),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        onTap: () => _markAsRead(notif['id_notifikasi']),
                      );

                    },
                  ),
                ),
    );
  }
}