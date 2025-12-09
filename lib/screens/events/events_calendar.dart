import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:events_manager/utils/common_utils.dart';
import 'appointment_data_source.dart';

class EventsCalendar extends ConsumerWidget {
  final CalendarView currentView;
  final DateTime? selectedDate;
  final List<Appointment> appointments;
  final Function(CalendarTapDetails) onTap;

  const EventsCalendar({
    super.key,
    required this.currentView,
    required this.selectedDate,
    required this.appointments,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SfCalendar(
      key: ValueKey(currentView),
      view: currentView,
      initialDisplayDate: selectedDate,
      initialSelectedDate: selectedDate,
      dataSource: AppointmentDataSource(appointments),
      onTap: onTap,
      showDatePickerButton: false,
      showNavigationArrow: true,
      allowViewNavigation: true,
      appointmentBuilder: (context, details) {
        // For month view's agenda section specifically
        // This is the only place where we want to show the detailed card
        if (currentView == CalendarView.month && details.bounds.height > 30) {
          return _buildAgendaAppointment(context, details, ref);
        }

        // For all other cases, use the appropriate view-specific builder
        if (currentView == CalendarView.day) {
          return _buildDayViewAppointment(context, details, ref);
        } else {
          return _buildMonthViewAppointment(context, details, ref);
        }
      },
      monthViewSettings: MonthViewSettings(
        appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
        showAgenda: true,
        agendaViewHeight: 200,
        numberOfWeeksInView: 6,
        appointmentDisplayCount: 3,
        showTrailingAndLeadingDates: true,
        dayFormat: 'EEE',
        monthCellStyle: MonthCellStyle(
          textStyle: const TextStyle(
            color: Color(0xFFAEE7FF),
            fontSize: 14,
          ),
          trailingDatesTextStyle: TextStyle(
            color: const Color(0xFFAEE7FF).withValues(alpha:0.5),
            fontSize: 14,
          ),
          leadingDatesTextStyle: TextStyle(
            color: const Color(0xFFAEE7FF).withValues(alpha:0.5),
            fontSize: 14,
          ),
          backgroundColor: const Color(0xFF07181F),
          todayBackgroundColor: const Color(0xFF07181F),
          // ignore: deprecated_member_use
          todayTextStyle: const TextStyle(
            color: Color(0xFFAEE7FF),
            fontSize: 14,
          ),
        ),
        agendaStyle: const AgendaStyle(
          backgroundColor: Color(0xFF06151C),
          dayTextStyle: TextStyle(
            color: Color(0xFFAEE7FF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          dateTextStyle: TextStyle(
            color: Color(0xFFAEE7FF),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          appointmentTextStyle: TextStyle(
            color: Color(0xFFAEE7FF),
            fontSize: 12,
          ),
        ),
        agendaItemHeight: 70,
      ),
      timeSlotViewSettings: const TimeSlotViewSettings(
        timeFormat: 'h:mm a',
        dayFormat: 'EEE',
        timeRulerSize: 70,
        timeTextStyle: TextStyle(
          color: Color(0xFFAEE7FF),
          fontSize: 12,
        ),
      ),
      headerStyle: const CalendarHeaderStyle(
        textStyle: TextStyle(
          color: Color(0xFFAEE7FF),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Color(0xFF0F2026),
      ),
      viewHeaderStyle: const ViewHeaderStyle(
        dayTextStyle: TextStyle(
          color: Color(0xFF71C2E4),
          fontSize: 12,
        ),
        dateTextStyle: TextStyle(
          color: Color(0xFFAEE7FF),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        backgroundColor: Color(0xFF0F2026),
      ),
      cellBorderColor: const Color(0xFF17323D),
      backgroundColor: const Color(0xFF07181F),
      todayHighlightColor: Colors.transparent,
      selectionDecoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF71C2E4),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Extract club logo URL from notes field
  String _extractClubLogo(Appointment appointment) {
    if (appointment.notes != null && appointment.notes!.contains('|')) {
      final parts = appointment.notes!.split('|');
      if (parts.length > 1) {
        return parts.last;
      }
    }
    return '';
  }

  // For month view cells, show only club icon
  Widget _buildMonthViewAppointment(BuildContext context, CalendarAppointmentDetails details, WidgetRef ref) {
    final appointment = details.appointments.first;
    final clubLogoUrl = _extractClubLogo(appointment);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F2027),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      margin: const EdgeInsets.only(top: 1, left: 1, right: 1, bottom: 1),
      child: Center(
        child: clubLogoUrl.isNotEmpty
            ? Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: getCachedNetworkImageProvider(
                      imageUrl: clubLogoUrl,
                      imageType: ImageType.club,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : Text(
                appointment.subject.isNotEmpty ? appointment.subject[0] : '?',
                style: const TextStyle(
                  color: Color(0xFFAEE7FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
      ),
    );
  }

  // For day view, show only title and logo
  Widget _buildDayViewAppointment(BuildContext context, CalendarAppointmentDetails details, WidgetRef ref) {
    final appointment = details.appointments.first;
    final clubLogoUrl = _extractClubLogo(appointment);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F2027),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      margin: const EdgeInsets.only(top: 1, left: 1, right: 1, bottom: 1),
      child: Row(
        children: [
          if (clubLogoUrl.isNotEmpty)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: getCachedNetworkImageProvider(
                    imageUrl: clubLogoUrl,
                    imageType: ImageType.club,
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Expanded(
            child: Text(
              appointment.subject,
              style: const TextStyle(
                color: Color(0xFFAEE7FF),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // For agenda view, show detailed card
  Widget _buildAgendaAppointment(BuildContext context, CalendarAppointmentDetails details, WidgetRef ref) {
    final appointment = details.appointments.first;
    final clubLogoUrl = _extractClubLogo(appointment);

    // Extract description from notes field
    String description = appointment.notes ?? '';
    if (description.contains('|')) {
      final parts = description.split('|');
      if (parts.length > 1) {
        description = parts.first;
      }
    }

    // Format time range
    final startTime = DateFormat('h:mm a').format(appointment.startTime);
    final endTime = DateFormat('h:mm a').format(appointment.endTime);
    final timeRange = '$startTime - $endTime';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2027),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (clubLogoUrl.isNotEmpty)
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(right: 8, top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: getCachedNetworkImageProvider(
                      imageUrl: clubLogoUrl,
                      imageType: ImageType.club,
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.subject,
                    style: const TextStyle(
                      color: Color(0xFFAEE7FF),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF173240),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          timeRange,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (appointment.location != null && appointment.location!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF173240),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFFAEE7FF),
                                size: 10,
                              ),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  appointment.location!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
