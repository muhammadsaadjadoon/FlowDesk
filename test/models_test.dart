import 'package:flutter_test/flutter_test.dart';
import 'package:flow_desk/models.dart';

DeskTask sample({String status = 'todo', int progress = 0}) => DeskTask(
  id: 'one',
  title: 'Task',
  description: 'Description',
  assigneeId: 'i',
  createdBy: 'a',
  due: DateTime(2026, 10, 10),
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
  status: status,
  progress: progress,
);
void main() {
  test('task serialization preserves assignment and due date', () {
    final t = DeskTask.fromMap('one', sample().toMap());
    expect(t.assigneeId, 'i');
    expect(t.due, DateTime(2026, 10, 10));
  });
  test('task is overdue after due day, not during due day', () {
    expect(sample().overdueAt(DateTime(2026, 10, 10, 23)), false);
    expect(sample().overdueAt(DateTime(2026, 10, 11)), true);
    expect(
      sample(status: 'done', progress: 100).overdueAt(DateTime(2026, 10, 11)),
      false,
    );
  });
  test('empty report does not divide by zero', () {
    final s = TaskStats([]);
    expect(s.completionRate, 0);
    expect(s.average, 0);
  });
  test('report measures completion and mean progress', () {
    final s = TaskStats([
      sample(status: 'doing', progress: 50),
      sample(status: 'done', progress: 100),
    ]);
    expect(s.completionRate, .5);
    expect(s.average, 75);
  });
  test('CSV escapes quotes and prevents formula interpretation', () {
    expect(csvCell('=1+1'), '"\'=1+1"');
    expect(csvCell('A "quote"'), '"A ""quote"""');
  });
  test('profile serialization includes photo and membership', () {
    final u = Member.fromMap(
      'i',
      Member(id: 'i', name: 'Saadi', email: 'a@b.com', photo: 'abc').toMap(),
    );
    expect(u.active, false);
    expect(u.isAdmin, false);
    expect(u.photo, 'abc');
  });
}
