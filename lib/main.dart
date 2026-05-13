import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/face_register_page.dart';
import 'pages/address_register_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as dev;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:presensi/config.dart';

late List<CameraDescription> cameras;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
  Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    dev.log("Menangani pesan background: ${message.messageId}", name: "FCM_BACK");
  }

  Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString('user_data');

    if (userDataString == null) return;

    final userData = jsonDecode(userDataString);

    try {
      await http.post(
        Uri.parse('${AppConfig.apiUrl}/save-fcm-token'),
        headers: {'Accept': 'application/json'},
        body: {
          'id_user': userData['id_user'],
          'fcm_token': newToken,
        },
      );

      dev.log("FCM token updated", name: "FCM");
    } catch (e) {
      dev.log("FCM refresh error: $e", name: "FCM");
    }
  });


    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      dev.log("Notif masuk: ${message.data}");

      showLocalNotification(
        message.data['title'],
        message.data['body'],
      );
    });

    await initializeDateFormatting('id_ID', null);

    cameras = await availableCameras();

    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');

    runApp(MyApp(isLoggedIn: token != null));
  }

  void showLocalNotification(String? title, String? body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      notificationDetails,
    );
  }

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  Widget _getInitialPage() {
    if (!isLoggedIn) return const LoginPage();

    return FutureBuilder(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final prefs = snapshot.data as SharedPreferences;
        final userDataStr = prefs.getString('user_data');
        if (userDataStr == null) return const LoginPage();

        final userData = jsonDecode(userDataStr);
        
        final embedding = userData['embedding_vector'];
        bool hasFace = (embedding != null && embedding.toString() != "[]" && embedding.toString() != "null");
        if (!hasFace) return const FaceRegisterPage();

        final lat = userData['latitude_rumah'];
        bool hasLocation = (lat != null && lat.toString() != "0" && lat.toString() != "null");
        if (!hasLocation) return const AddressRegisterPage();

        return const DashboardPage();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Presensi App',
      theme: ThemeData(
        primaryColor: const Color(0xFF1E293B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF1E293B),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
      ),
      locale: const Locale('id', 'ID'), 
      home: _getInitialPage(),
      // home: isLoggedIn ? const DashboardPage() : const LoginPage(),
    );
  }
}