DateTime? parseApiDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  return DateTime.tryParse(v.toString())?.toLocal();
}

DateTime requireApiDateTime(dynamic v) {
  final parsed = parseApiDateTime(v);
  if (parsed == null) {
    throw FormatException('Invalid datetime: $v');
  }
  return parsed;
}

String toApiDateTime(DateTime dt) => dt.toUtc().toIso8601String();
