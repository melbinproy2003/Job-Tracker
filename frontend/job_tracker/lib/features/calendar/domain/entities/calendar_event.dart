/// Domain entity for calendar. Independent of API/Drift models.
class CalendarEvent {
  const CalendarEvent({required this.id, this.title});

  final String id;
  final String? title;
}
