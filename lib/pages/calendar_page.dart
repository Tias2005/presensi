import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/theme.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isLoading = true;

  Map<DateTime, String> _holidayMap = {};
  // Map<DateTime, String> _presenceMap = {};
  Map<int, bool> _workDayConfig = {}; 

  @override
  void initState() {
    super.initState();
    _fetchCalendarData();
  }

  Future<void> _fetchCalendarData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonDecode(prefs.getString('user_data') ?? '{}');
    final userId = userData['id_user'];

    try {
      final response = await http.get(Uri.parse(
          "http://192.168.229.178:8000/api/presensi/calendar/$userId?month=${_focusedDay.month}&year=${_focusedDay.year}"));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final List holidays = result['data']['holidays'];
        final List jadwal = result['data']['jadwal'];

        setState(() {
          _holidayMap = {
            for (var item in holidays)
              _normalizeDate(DateTime.parse(item['tanggal_libur'])): item['nama_libur']
          };

          _workDayConfig = {
            for (var item in jadwal)
              item['hari_ke']: (item['is_hari_kerja'] == true || item['is_hari_kerja'] == 1 || item['is_hari_kerja'] == "true")
          };
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch: $e");
      setState(() => _isLoading = false);
    }
  }

  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Kalender & Hari Libur", 
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              _buildCalendarCard(),
              _buildLegendSection(),
              if (_selectedDay != null) _buildSelectedDayDetail(),
            ],
          ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: TableCalendar(
        locale: 'id_ID',
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
          _fetchCalendarData();
        },
        calendarStyle: const CalendarStyle(
          selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(color: Color.fromARGB(255, 201, 208, 215), shape: BoxShape.circle),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            DateTime cleanDay = _normalizeDate(day);
            int dayIndex = day.weekday == 7 ? 0 : day.weekday;
            bool isWorkDay = _workDayConfig[dayIndex] ?? true;

            if (_holidayMap.containsKey(cleanDay) || !isWorkDay) {
              return _calendarBox(day.day.toString(), Colors.red.shade50, Colors.red);
            }
            return _calendarBox(day.day.toString(), AppColors.primary.withValues(alpha: 0.05), AppColors.primary);
          },
        ),
      ),
    );
  }

  Widget _calendarBox(String text, Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.all(5),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSelectedDayDetail() {
    DateTime cleanSelected = _normalizeDate(_selectedDay!);
    String statusText = "";
    Color statusColor = AppColors.grey;

    int dayIndex = _selectedDay!.weekday == 7 ? 0 : _selectedDay!.weekday;
    bool isWorkDay = _workDayConfig[dayIndex] ?? true;

    if (_holidayMap.containsKey(cleanSelected)) {
      statusText = "Libur Nasional: ${_holidayMap[cleanSelected]}";
      statusColor = Colors.red;
    } 
    else {
      if (isWorkDay) {
        statusText = "Jadwal: Masuk Kerja";
        statusColor = AppColors.primary;
      } else {
        statusText = "Jadwal: Libur Kerja";
        statusColor = Colors.red;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: statusColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDay!), 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendSection() {
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(Colors.red, "Libur"),
          const SizedBox(width: 30),
          _legendItem(AppColors.primary, "Masuk"),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}