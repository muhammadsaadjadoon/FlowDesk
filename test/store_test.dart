import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_desk/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('demo changes persist across store recreation', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final a = DeskStore(demo: true, preferences: prefs);
    await a.init();
    await a.profile({'name': 'Updated intern'});
    final task = a.tasks.first;
    await a.saveTask(task.update({'status': 'doing', 'progress': 65}));
    a.dispose();
    final b = DeskStore(demo: true, preferences: prefs);
    await b.init();
    expect(b.me!.name, 'Updated intern');
    expect(b.tasks.first.progress, 65);
    b.dispose();
  });
  test('demo switch changes role without creating a cloud admin', () async {
    SharedPreferences.setMockInitialValues({});
    final s = DeskStore(
      demo: true,
      preferences: await SharedPreferences.getInstance(),
    );
    await s.init();
    expect(s.me!.isAdmin, false);
    await s.switchDemo();
    expect(s.me!.isAdmin, true);
    s.dispose();
  });
  test('intern cannot delete administrator assignment', () async {
    SharedPreferences.setMockInitialValues({});
    final s = DeskStore(
      demo: true,
      preferences: await SharedPreferences.getInstance(),
    );
    await s.init();
    await expectLater(s.removeTask(s.tasks.first), throwsStateError);
    s.dispose();
  });
}
