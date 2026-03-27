import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../constants/app_styles.dart';
import '../../../services/firestore_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/user_card_model.dart';

class MobileCalendarScreen extends ConsumerStatefulWidget {
  const MobileCalendarScreen({super.key});

  @override
  ConsumerState<MobileCalendarScreen> createState() => _MobileCalendarScreenState();
}

class _MobileCalendarScreenState extends ConsumerState<MobileCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final userCardsAsync = user != null 
        ? ref.watch(userCardsStreamProvider(user.uid))
        : const AsyncValue<List<UserCard>>.data([]);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'LỊCH THANH TOÁN',
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.2),
        ),
      ),
      body: userCardsAsync.when(
        data: (cards) => _buildBody(cards),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }

  Widget _buildBody(List<UserCard> cards) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.only(bottom: 24, left: 16, right: 16, top: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10)],
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            rowHeight: 52, // Tăng chiều cao row để tránh cắt chữ
            daysOfWeekHeight: 30, // Tăng chiều cao phần header thứ
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              markerDecoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              cellMargin: const EdgeInsets.all(4),
              defaultTextStyle: GoogleFonts.inter(fontSize: 14),
              weekendTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.red.shade300),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
              weekendStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade400),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              headerPadding: const EdgeInsets.only(bottom: 16),
            ),
            eventLoader: (day) => _getEventsForDay(day, cards),
          ),
        ),
        Expanded(
          child: _buildEventList(_selectedDay ?? _focusedDay, cards),
        ),
      ],
    );
  }

  List<dynamic> _getEventsForDay(DateTime day, List<UserCard> cards) {
    List<dynamic> events = [];
    for (var card in cards) {
      if (day.day == card.dueDay) events.add('Hạn thanh toán: ${card.cardName}');
      if (day.day == card.statementDay) events.add('Ngày sao kê: ${card.cardName}');
    }
    return events;
  }

  Widget _buildEventList(DateTime day, List<UserCard> cards) {
    final events = _getEventsForDay(day, cards);
    if (events.isEmpty) {
      return Center(
        child: Text('Không có sự kiện trong ngày này', style: GoogleFonts.inter(color: AppColors.textLight)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final isDue = events[index].toString().contains('Hạn thanh toán');
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDue ? Colors.red.shade100 : const Color(0xFFF3F4F6)),
          ),
          child: Row(
            children: [
              Icon(
                isDue ? Icons.warning_amber_rounded : Icons.description_outlined,
                color: isDue ? Colors.red : AppColors.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(events[index], style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
