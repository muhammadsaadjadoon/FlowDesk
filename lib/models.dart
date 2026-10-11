class Member {
  Member({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'intern',
    this.active = false,
    this.title = '',
    this.phone = '',
    this.bio = '',
    this.photo = '',
  });
  final String id, name, email, role, title, phone, bio, photo;
  final bool active;
  bool get isAdmin => role == 'admin';
  factory Member.fromMap(String id, Map<String, dynamic> d) => Member(
    id: id,
    name: d['name'] as String? ?? '',
    email: d['email'] as String? ?? '',
    role: d['role'] as String? ?? 'intern',
    active: d['active'] == true,
    title: d['title'] as String? ?? '',
    phone: d['phone'] as String? ?? '',
    bio: d['bio'] as String? ?? '',
    photo: d['photo'] as String? ?? '',
  );
  Map<String, dynamic> toMap() => {
    'name': name,
    'email': email,
    'role': role,
    'active': active,
    'title': title,
    'phone': phone,
    'bio': bio,
    'photo': photo,
  };
}

const statuses = ['todo', 'doing', 'review', 'done'];
const statusNames = {
  'todo': 'To do',
  'doing': 'In progress',
  'review': 'In review',
  'done': 'Completed',
};
const priorities = ['low', 'medium', 'high'];

class DeskTask {
  DeskTask({
    required this.id,
    required this.title,
    required this.description,
    required this.assigneeId,
    required this.createdBy,
    required this.due,
    required this.createdAt,
    required this.updatedAt,
    this.status = 'todo',
    this.priority = 'medium',
    this.category = 'Development',
    this.progress = 0,
    this.reviewNote = '',
  });
  final String id,
      title,
      description,
      assigneeId,
      createdBy,
      status,
      priority,
      category,
      reviewNote;
  final DateTime due, createdAt, updatedAt;
  final int progress;
  bool overdueAt(DateTime now) =>
      status != 'done' &&
      DateTime(
        due.year,
        due.month,
        due.day,
      ).isBefore(DateTime(now.year, now.month, now.day));
  bool get overdue => overdueAt(DateTime.now());
  factory DeskTask.fromMap(String id, Map<String, dynamic> d) => DeskTask(
    id: id,
    title: d['title'] as String,
    description: d['description'] as String,
    assigneeId: d['assigneeId'] as String,
    createdBy: d['createdBy'] as String,
    due: DateTime.parse(d['due'] as String),
    createdAt: DateTime.parse(d['createdAt'] as String),
    updatedAt: DateTime.parse(d['updatedAt'] as String),
    status: d['status'] as String,
    priority: d['priority'] as String,
    category: d['category'] as String,
    progress: (d['progress'] as num).toInt(),
    reviewNote: d['reviewNote'] as String? ?? '',
  );
  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'assigneeId': assigneeId,
    'createdBy': createdBy,
    'due': due.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'status': status,
    'priority': priority,
    'category': category,
    'progress': progress,
    'reviewNote': reviewNote,
  };
  DeskTask update(Map<String, dynamic> fields) =>
      DeskTask.fromMap(id, {...toMap(), ...fields});
}

class TaskStats {
  TaskStats(List<DeskTask> tasks)
    : total = tasks.length,
      completed = tasks.where((t) => t.status == 'done').length,
      inProgress = tasks.where((t) => t.status == 'doing').length,
      review = tasks.where((t) => t.status == 'review').length,
      overdue = tasks.where((t) => t.overdue).length,
      average = tasks.isEmpty
          ? 0
          : tasks.fold<int>(0, (sum, t) => sum + t.progress) / tasks.length;
  final int total, completed, inProgress, review, overdue;
  final double average;
  double get completionRate => total == 0 ? 0 : completed / total;
}

String dayLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String csvCell(String s) {
  // Neutralize spreadsheet formula injection, then escape commas/quotes/newlines.
  if (RegExp(r'^[=+@\-\t\r]').hasMatch(s)) {
    s = "'$s";
  }
  return '"${s.replaceAll('"', '""')}"';
}

String taskCsv(List<DeskTask> tasks, Map<String, String> names) => [
  'Title,Assignee,Status,Priority,Progress,Due',
  ...tasks.map(
    (t) => [
      t.title,
      names[t.assigneeId] ?? t.assigneeId,
      statusNames[t.status] ?? t.status,
      t.priority,
      '${t.progress}',
      dayLabel(t.due),
    ].map(csvCell).join(','),
  ),
].join('\r\n');
