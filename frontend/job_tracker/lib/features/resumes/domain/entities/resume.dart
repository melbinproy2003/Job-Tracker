/// Domain entity for resumes. Independent of API/Drift models.
class Resume {
  const Resume({required this.id, this.name});

  final String id;
  final String? name;
}
