import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class DeskStore extends ChangeNotifier {
  DeskStore({required this.demo, required this.preferences});
  final bool demo;
  final SharedPreferences preferences;
  Member? me;
  List<Member> members = [];
  List<DeskTask> tasks = [];
  String? problem;
  bool loading = false;
  bool dark = false;
  bool _closed = false;
  int _session = 0;
  StreamSubscription<User?>? _auth;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasks, _members;
  FirebaseFirestore get db => FirebaseFirestore.instance;
  void announce() {
    if (!_closed) {
      notifyListeners();
    }
  }

  Future<void> init() async {
    dark = preferences.getBool('dark') ?? false;
    if (demo) {
      await _loadDemo();
      return;
    }
    _auth = FirebaseAuth.instance.authStateChanges().listen((u) {
      unawaited(_connect(u));
    });
  }

  Future<void> _connect(User? u) async {
    final session = ++_session;
    await _profile?.cancel();
    await _tasks?.cancel();
    await _members?.cancel();
    if (_closed || session != _session) {
      return;
    }
    me = null;
    tasks = [];
    members = [];
    problem = null;
    loading = u != null;
    announce();
    if (u == null) {
      return;
    }
    try {
      final ref = db.collection('users').doc(u.uid);
      await ensureProfile(u);
      if (_closed || session != _session) {
        return;
      }
      _profile = ref.snapshots().listen(
        (d) {
          if (_closed || session != _session) {
            return;
          }
          final raw = d.data();
          if (raw == null) {
            problem = 'Your profile is missing. Contact your administrator.';
            loading = false;
            announce();
            return;
          }
          final previous = me;
          me = Member.fromMap(d.id, raw);
          loading = false;
          if (previous == null ||
              previous.role != me!.role ||
              previous.active != me!.active) {
            unawaited(_watch(session));
          }
          announce();
        },
        onError: (Object e) {
          loading = false;
          problem = readableError(e);
          announce();
        },
      );
    } catch (e) {
      if (session == _session && !_closed) {
        loading = false;
        problem = readableError(e);
        announce();
      }
    }
  }

  Future<void> ensureProfile(User u, {String? name}) async {
    final ref = db.collection('users').doc(u.uid);
    await db
        .runTransaction((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists) {
            tx.set(
              ref,
              Member(
                id: u.uid,
                name: name ?? u.displayName ?? 'New member',
                email: u.email ?? '',
              ).toMap(),
            );
          } else if (name != null) {
            tx.update(ref, {'name': name});
          }
        })
        .timeout(const Duration(seconds: 20));
  }

  Future<void> _watch(int session) async {
    await _tasks?.cancel();
    await _members?.cancel();
    if (_closed || session != _session) {
      return;
    }
    tasks = [];
    members = [];
    final current = me;
    if (current == null || !current.active) {
      announce();
      return;
    }
    Query<Map<String, dynamic>> q = db.collection('tasks');
    if (!current.isAdmin) {
      q = q.where('assigneeId', isEqualTo: current.id);
    }
    _tasks = q.snapshots().listen(
      (s) {
        if (_closed || session != _session) {
          return;
        }
        final result = <DeskTask>[];
        for (final d in s.docs) {
          try {
            result.add(DeskTask.fromMap(d.id, d.data()));
          } catch (_) {
            problem =
                'A task record could not be read. Ask your admin to check it.';
          }
        }
        tasks = result;
        announce();
      },
      onError: (Object e) {
        if (session == _session) {
          problem = readableError(e);
          announce();
        }
      },
    );
    if (current.isAdmin) {
      _members = db
          .collection('users')
          .snapshots()
          .listen(
            (s) {
              if (session != _session || _closed) {
                return;
              }
              members = s.docs
                  .map((d) => Member.fromMap(d.id, d.data()))
                  .toList();
              announce();
            },
            onError: (Object e) {
              problem = readableError(e);
              announce();
            },
          );
    } else {
      members = [current];
    }
  }

  Future<void> _loadDemo() async {
    final saved = preferences.getString('demo_workspace');
    try {
      if (saved != null) {
        final d = jsonDecode(saved) as Map<String, dynamic>;
        members = (d['members'] as List)
            .map(
              (m) => Member.fromMap(
                m['id'] as String,
                Map<String, dynamic>.from(m as Map),
              ),
            )
            .toList();
        tasks = (d['tasks'] as List)
            .map(
              (m) => DeskTask.fromMap(
                m['id'] as String,
                Map<String, dynamic>.from(m as Map),
              ),
            )
            .toList();
      }
    } catch (_) {
      problem =
          'Demo backup could not be read. A fresh sample workspace was loaded.';
    }
    if (members.isEmpty) {
      members = [
        Member(
          id: 'admin',
          name: 'Workspace Admin',
          email: 'admin@example.com',
          role: 'admin',
          active: true,
          title: 'Internship coordinator',
        ),
        Member(
          id: 'intern',
          name: 'Saadi',
          email: 'intern@example.com',
          active: true,
          title: 'Flutter intern',
        ),
        Member(
          id: 'design',
          name: 'Ayesha',
          email: 'design@example.com',
          active: true,
          title: 'Design intern',
        ),
      ];
      final now = DateTime.now();
      tasks = List.generate(
        6,
        (i) => DeskTask(
          id: 'sample-$i',
          title: [
            'Build responsive onboarding',
            'Prepare weekly progress report',
            'Review Firebase security rules',
            'Design dashboard components',
            'Fix mobile layout issues',
            'Test task assignment flow',
          ][i],
          description:
              'Sample assignment. Replace this task with your actual internship work.',
          assigneeId: i == 3 ? 'design' : 'intern',
          createdBy: 'admin',
          due: now.add(Duration(days: i - 1)),
          createdAt: now.subtract(const Duration(days: 3)),
          updatedAt: now,
          status: ['doing', 'todo', 'review', 'doing', 'done', 'todo'][i],
          progress: [45, 0, 90, 60, 100, 0][i],
          priority: i == 0 ? 'high' : 'medium',
        ),
      );
    }
    me = members.firstWhere(
      (m) => m.id == (preferences.getString('demo_user') ?? 'intern'),
      orElse: () => members.first,
    );
    announce();
  }

  Future<void> _persist() async {
    if (!demo) {
      return;
    }
    final ok = await preferences.setString(
      'demo_workspace',
      jsonEncode({
        'members': members.map((m) => {'id': m.id, ...m.toMap()}).toList(),
        'tasks': tasks.map((t) => {'id': t.id, ...t.toMap()}).toList(),
      }),
    );
    if (!ok) {
      throw StateError('Device storage could not save the demo workspace.');
    }
  }

  Future<void> switchDemo() async {
    if (!demo) {
      return;
    }
    me = members.firstWhere((m) => m.id == (me!.isAdmin ? 'intern' : 'admin'));
    await preferences.setString('demo_user', me!.id);
    announce();
  }

  Future<void> theme(bool value) async {
    dark = value;
    await preferences.setBool('dark', value);
    announce();
  }

  Future<void> saveTask(DeskTask task, {bool isNew = false}) async {
    final current = me;
    if (current == null || !current.active) {
      throw StateError('An active workspace membership is required.');
    }
    if (!current.isAdmin && task.assigneeId != current.id) {
      throw StateError('You can only update your assigned tasks.');
    }
    if (task.title.trim().length < 3 ||
        task.title.length > 120 ||
        task.description.trim().isEmpty ||
        task.description.length > 4000 ||
        !statuses.contains(task.status) ||
        !priorities.contains(task.priority) ||
        task.progress < 0 ||
        task.progress > 100 ||
        (task.status == 'done' && task.progress != 100) ||
        (task.status == 'todo' && task.progress != 0)) {
      throw StateError('Task fields are invalid.');
    }
    if (isNew &&
        (task.createdBy != current.id ||
            (!current.isAdmin && task.assigneeId != current.id))) {
      throw StateError('Assignment is not allowed.');
    }
    if (!isNew && !current.isAdmin) {
      final existing = tasks.where((t) => t.id == task.id).toList();
      if (existing.isEmpty) {
        throw StateError('Task no longer exists.');
      }
      final original = existing.first;
      if (original.createdBy != task.createdBy ||
          original.createdAt != task.createdAt ||
          original.assigneeId != task.assigneeId) {
        throw StateError('Assignment identity cannot change.');
      }
      if (original.createdBy != current.id) {
        final before = original.toMap(), after = task.toMap();
        if (after.keys.any(
              (k) =>
                  !['status', 'progress', 'updatedAt'].contains(k) &&
                  after[k] != before[k],
            ) ||
            (task.status == 'done' && original.status != 'done')) {
          throw StateError(
            'Only your progress and work stage can change. Submit for admin review.',
          );
        }
      }
    }
    if (demo) {
      final previous = List<DeskTask>.of(tasks);
      if (isNew) {
        tasks.add(task);
      } else {
        final i = tasks.indexWhere((t) => t.id == task.id);
        if (i < 0) {
          throw StateError('Task no longer exists.');
        }
        tasks[i] = task;
      }
      try {
        await _persist();
      } catch (_) {
        tasks = previous;
        rethrow;
      }
      announce();
      return;
    }
    final ref = db.collection('tasks').doc(task.id);
    if (isNew) {
      await ref.set(task.toMap()).timeout(const Duration(seconds: 20));
    } else {
      await ref.update(task.toMap()).timeout(const Duration(seconds: 20));
    }
  }

  Future<void> removeTask(DeskTask t) async {
    if (me == null ||
        !(me!.isAdmin || (t.createdBy == me!.id && t.assigneeId == me!.id))) {
      throw StateError(
        'Only an admin or the personal-task owner can delete this task.',
      );
    }
    if (demo) {
      final old = List<DeskTask>.of(tasks);
      tasks.removeWhere((x) => x.id == t.id);
      try {
        await _persist();
      } catch (_) {
        tasks = old;
        rethrow;
      }
      announce();
    } else {
      await db
          .collection('tasks')
          .doc(t.id)
          .delete()
          .timeout(const Duration(seconds: 20));
    }
  }

  Future<void> profile(Map<String, dynamic> fields) async {
    final current = me;
    if (current == null) {
      return;
    }
    if (demo) {
      final i = members.indexWhere((m) => m.id == current.id);
      final old = members[i];
      members[i] = Member.fromMap(current.id, {...current.toMap(), ...fields});
      try {
        await _persist();
      } catch (_) {
        members[i] = old;
        rethrow;
      }
      me = members[i];
      announce();
    } else {
      await db
          .collection('users')
          .doc(current.id)
          .update(fields)
          .timeout(const Duration(seconds: 20));
    }
  }

  Future<void> activate(Member m, bool value) async {
    if (me?.isAdmin != true || m.id == me!.id) {
      throw StateError('Administrator permission required.');
    }
    if (demo) {
      final i = members.indexWhere((x) => x.id == m.id);
      members[i] = Member.fromMap(m.id, {...m.toMap(), 'active': value});
      await _persist();
      announce();
    } else {
      await db
          .collection('users')
          .doc(m.id)
          .update({'active': value})
          .timeout(const Duration(seconds: 20));
    }
  }

  Future<void> retry() async {
    problem = null;
    if (!demo) {
      await _connect(FirebaseAuth.instance.currentUser);
    }
    announce();
  }

  Future<void> signOut() async {
    if (!demo) {
      await FirebaseAuth.instance.signOut();
    }
  }

  String memberName(String id) {
    for (final m in members) {
      if (m.id == id) {
        return m.name;
      }
    }
    return id == me?.id ? me!.name : 'Assigned intern';
  }

  static String newId() => const Uuid().v4();
  @override
  void dispose() {
    _closed = true;
    _session++;
    unawaited(_auth?.cancel());
    unawaited(_profile?.cancel());
    unawaited(_tasks?.cancel());
    unawaited(_members?.cancel());
    super.dispose();
  }
}

String readableError(Object e) {
  if (e is TimeoutException) {
    return 'Cloud confirmation is taking longer than expected. The write may still sync. Check the record before retrying.';
  }
  if (e is FirebaseAuthException) {
    return switch (e.code) {
      'invalid-credential' => 'Email or password is incorrect.',
      'email-already-in-use' => 'This email already has an account.',
      'weak-password' => 'Choose a stronger password.',
      'too-many-requests' => 'Too many attempts. Wait before trying again.',
      'network-request-failed' => 'Check your internet connection.',
      'invalid-email' => 'Enter a valid email address.',
      _ => 'Account action failed (${e.code}). Try again.',
    };
  }
  if (e is FirebaseException) {
    return switch (e.code) {
      'permission-denied' =>
        'Access denied. Check account approval and deployed Firestore rules.',
      'unavailable' =>
        'Cloud service is unavailable. Check your connection and retry.',
      _ => 'Cloud action failed (${e.code}).',
    };
  }
  if (e is StateError) {
    return e.message.toString();
  }
  return 'The action could not be completed. Please retry.';
}
