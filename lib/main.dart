import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'firebase_options.dart';
import 'models.dart';
import 'brand.dart';
import 'store.dart';
import 'forms.dart';

const navy = Color(0xff152d43),
    teal = Color(0xff00b8af),
    mint = Color(0xffb5fff0);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const demo = bool.fromEnvironment('DEMO', defaultValue: false);
  try {
    if (!demo) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final store = DeskStore(
      demo: demo,
      preferences: await SharedPreferences.getInstance(),
    );
    await store.init();
    runApp(FlowDesk(store: store));
  } catch (_) {
    runApp(const MaterialApp(home: SetupPage()));
  }
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandMark(size: 92),
              const SizedBox(height: 20),
              const Text(
                'Connect your workspace',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              const Text(
                'Firebase setup is missing or initialization failed. Run flutterfire configure, enable Email/Password sign-in and create Firestore. See README for the exact steps. For a local preview, launch with --dart-define=DEMO=true.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

ThemeData deskTheme(bool dark) {
  final scheme = ColorScheme.fromSeed(
    seedColor: teal,
    brightness: dark ? Brightness.dark : Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xff0c1825)
        : const Color(0xfff3f7fa),
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: dark ? const Color(0xff0c1825) : const Color(0xfff3f7fa),
      toolbarHeight: 72,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      elevation: 0,
      backgroundColor: dark ? const Color(0xff18293a) : Colors.white,
      indicatorColor: dark ? const Color(0xff175367) : const Color(0xffd7f5ef),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xff18293a) : Colors.white,
      indicatorColor: dark ? const Color(0xff175367) : const Color(0xffd7f5ef),
    ),
    dividerTheme: DividerThemeData(
      color: dark ? const Color(0xff294052) : const Color(0xffe5edf2),
      thickness: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xff18293a) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff203447) : const Color(0xfff3f6f9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: teal, width: 1.5),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: dark ? const Color(0xff294052) : const Color(0xffe5edf2),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class FlowDesk extends StatelessWidget {
  const FlowDesk({super.key, required this.store});
  final DeskStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (_, _) => MaterialApp(
      title: 'Flow Desk',
      debugShowCheckedModeBanner: false,
      theme: deskTheme(false),
      darkTheme: deskTheme(true),
      themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
      home: DeskShell(store: store),
    ),
  );
}

class DeskShell extends StatefulWidget {
  const DeskShell({super.key, required this.store});
  final DeskStore store;
  @override
  State<DeskShell> createState() => _DeskShellState();
}

class _DeskShellState extends State<DeskShell> {
  int page = 0;
  String search = '', filter = 'all', priority = 'all', sort = 'due';
  bool busy = false;
  DeskStore get store => widget.store;
  final searchController = TextEditingController();
  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void notice(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> action(Future<void> Function() f) async {
    if (busy) {
      return;
    }
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Action needs attention'),
            content: Text(readableError(e)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  List<DeskTask> get visible {
    final uid = store.me?.id;
    final list = store.tasks
        .where(
          (t) =>
              (store.me?.isAdmin == true || t.assigneeId == uid) &&
              (filter == 'all' || t.status == filter) &&
              (priority == 'all' || t.priority == priority) &&
              (search.isEmpty ||
                  '${t.title} ${t.description} ${t.category}'
                      .toLowerCase()
                      .contains(search.toLowerCase())),
        )
        .toList();
    list.sort(
      (a, b) => switch (sort) {
        'priority' =>
          priorities
              .indexOf(b.priority)
              .compareTo(priorities.indexOf(a.priority)),
        'updated' => b.updatedAt.compareTo(a.updatedAt),
        _ => a.due.compareTo(b.due),
      },
    );
    return list;
  }

  Future<void> edit([DeskTask? task]) async {
    if (busy) {
      return;
    }
    final owner = store.me!.id;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskForm(
        store: store,
        task: task,
        onSave: (t) async {
          if (store.me?.id != owner) {
            throw StateError('Session changed.');
          }
          await store.saveTask(t, isNew: task == null);
        },
      ),
    );
  }

  Future<void> remove(DeskTask t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this task?'),
        content: Text('“${t.title}” will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await action(() => store.removeTask(t));
    }
  }

  Widget card(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(22), child: child),
  );
  Widget heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
  Widget taskCard(DeskTask t) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => edit(t),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.category,
                    style: const TextStyle(
                      color: teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Chip(
                  label: Text(t.priority.toUpperCase()),
                  visualDensity: VisualDensity.compact,
                ),
                if (store.me!.isAdmin || t.createdBy == store.me!.id)
                  IconButton(
                    tooltip: 'Delete task',
                    onPressed: () => remove(t),
                    icon: const Icon(Icons.delete_outline, size: 19),
                  ),
              ],
            ),
            Text(
              t.title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(t.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: t.progress / 100,
              borderRadius: BorderRadius.circular(6),
              minHeight: 6,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text('${t.progress}% • ${statusNames[t.status]}'),
                Text(
                  'Due ${dayLabel(t.due)}',
                  style: TextStyle(
                    color: t.overdue
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                if (store.me!.isAdmin) Text(store.memberName(t.assigneeId)),
              ],
            ),
            if (t.reviewNote.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Review: ${t.reviewNote}'),
            ],
          ],
        ),
      ),
    ),
  );
  Widget stat(String label, String value, IconData icon) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: teal.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: teal, size: 22),
        ),
        const SizedBox(height: 18),
        Text(
          value,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
  Widget overview() {
    final all = store.tasks
        .where((t) => store.me!.isAdmin || t.assigneeId == store.me!.id)
        .toList();
    final stats = TaskStats(all);
    final next = List<DeskTask>.of(all.where((t) => t.status != 'done'))
      ..sort((a, b) => a.due.compareTo(b.due));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [navy, Color(0xff175367)]),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${store.me!.isAdmin ? 'TEAM WORKSPACE' : 'YOUR DAILY WORKSPACE'} • ${dayLabel(DateTime.now())}',
                style: const TextStyle(
                  color: mint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Make space for\nyour next milestone.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Welcome back, ${store.me!.name}. ${store.me!.isAdmin ? 'Assign clearly. Review progress. Help your team move forward.' : 'Organize your assignments and keep your progress visible.'}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => edit(),
                icon: const Icon(Icons.add),
                label: Text(
                  store.me!.isAdmin ? 'Assign a task' : 'Create a task',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 800
                ? 4
                : constraints.maxWidth >= 320
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: stat(
                    'Total tasks',
                    '${stats.total}',
                    Icons.layers_outlined,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: stat(
                    'In progress',
                    '${stats.inProgress}',
                    Icons.timelapse,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: stat(
                    'Completed',
                    '${stats.completed}',
                    Icons.task_alt,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: stat('Overdue', '${stats.overdue}', Icons.event_busy),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        heading('Your next priorities', 'Active tasks sorted by due date.'),
        if (next.isEmpty)
          empty(
            'You’re all caught up.',
            'Create your next task when you’re ready.',
          ),
        ...next.take(5).map(taskCard),
      ],
    );
  }

  Widget empty(String title, String subtitle) => card(
    Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline, size: 48, color: teal),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
  Widget filters() => LayoutBuilder(
    builder: (context, constraints) {
      final filterWidth = constraints.maxWidth < 600
          ? constraints.maxWidth
          : 220.0;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: constraints.maxWidth < 600 ? constraints.maxWidth : 280,
            child: TextField(
              controller: searchController,
              onChanged: (v) => setState(() => search = v),
              decoration: const InputDecoration(
                hintText: 'Search tasks',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            width: filterWidth,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: filter,
              decoration: const InputDecoration(labelText: 'Status'),
              items: ['all', ...statuses]
                  .map(
                    (x) => DropdownMenuItem(
                      value: x,
                      child: Text(statusNames[x] ?? 'All statuses'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => filter = v!),
            ),
          ),
          SizedBox(
            width: filterWidth,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: ['all', ...priorities]
                  .map(
                    (x) => DropdownMenuItem(
                      value: x,
                      child: Text(x == 'all' ? 'All priorities' : x),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => priority = v!),
            ),
          ),
          SizedBox(
            width: filterWidth,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: sort,
              decoration: const InputDecoration(labelText: 'Sort by'),
              items: const [
                DropdownMenuItem(value: 'due', child: Text('Due date')),
                DropdownMenuItem(value: 'priority', child: Text('Priority')),
                DropdownMenuItem(
                  value: 'updated',
                  child: Text('Recent updates'),
                ),
              ],
              onChanged: (v) => setState(() => sort = v!),
            ),
          ),
        ],
      );
    },
  );
  Widget taskList() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'A clear plan. A focused day.',
        'Search, organize and update your assignments.',
      ),
      filters(),
      const SizedBox(height: 20),
      Text(
        '${visible.length} tasks',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      if (visible.isEmpty)
        empty(
          'No tasks match your view.',
          'Change filters or create a new assignment.',
        ),
      ...visible.map(taskCard),
    ],
  );
  Widget board() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'See the flow of work.',
        'Tap a task to update its stage. On a phone, swipe across the board.',
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: statuses.map((s) {
            final list =
                store.tasks
                    .where(
                      (t) =>
                          (store.me!.isAdmin || t.assigneeId == store.me!.id) &&
                          t.status == s,
                    )
                    .toList()
                  ..sort((a, b) => a.due.compareTo(b.due));
            return Container(
              width: 282,
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${statusNames[s]}  ·  ${list.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (list.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('Nothing here yet.'),
                    ),
                  ...list.map(taskCard),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    ],
  );
  Widget reports() {
    final all = store.tasks
        .where((t) => store.me!.isAdmin || t.assigneeId == store.me!.id)
        .toList();
    final st = TaskStats(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Progress you can understand.',
          'Live totals based on the tasks you can access.',
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            stat(
              'Completion rate',
              '${(st.completionRate * 100).round()}%',
              Icons.donut_large,
            ),
            stat('Average progress', '${st.average.round()}%', Icons.insights),
            stat('Awaiting review', '${st.review}', Icons.fact_check_outlined),
          ],
        ),
        const SizedBox(height: 20),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status distribution',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 16),
              ...statuses.map((s) {
                final count = all.where((t) => t.status == s).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(statusNames[s]!)),
                          Text('$count'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: all.isEmpty ? 0 : count / all.length,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => action(
                      () => SharePlus.instance
                          .share(
                            ShareParams(
                              text: taskCsv(all, {
                                for (final m in store.members) m.id: m.name,
                              }),
                              subject: 'Flow Desk progress report',
                            ),
                          )
                          .then((_) {}),
                    ),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share CSV report'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => action(() async {
                      await Clipboard.setData(
                        ClipboardData(
                          text: taskCsv(all, {
                            for (final m in store.members) m.id: m.name,
                          }),
                        ),
                      );
                      notice('CSV report copied.');
                    }),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy CSV'),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (store.me!.isAdmin) ...[
          const SizedBox(height: 24),
          heading(
            'Team performance',
            'Approve new accounts and review each intern’s assignments.',
          ),
          ...store.members.map((m) {
            final stats = TaskStats(
              store.tasks.where((t) => t.assigneeId == m.id).toList(),
            );
            return card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileAvatar(member: m, radius: 23),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(m.email, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      if (m.id != store.me!.id)
                        Switch(
                          value: m.active,
                          onChanged: busy
                              ? null
                              : (v) => action(() => store.activate(m, v)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${m.role.toUpperCase()} • ${m.active ? 'Active' : 'Awaiting approval'}',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${stats.completed}/${stats.total} completed • ${stats.overdue} overdue • ${stats.review} awaiting review',
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: stats.completionRate,
                    minHeight: 6,
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = store.me;
    if (store.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (me == null) {
      return AuthPage(store: store);
    }
    if (!me.active) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flow Desk')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user_outlined, size: 70, color: teal),
                const SizedBox(height: 20),
                const Text(
                  'Your workspace invitation is pending',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your account is ready. Ask your administrator to approve your membership. This screen updates automatically.',
                ),
                if (store.problem != null) Text(store.problem!),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => action(store.retry),
                  child: const Text('Refresh'),
                ),
                TextButton(
                  onPressed: () =>
                      action(store.demo ? store.switchDemo : store.signOut),
                  child: Text(store.demo ? 'Switch demo role' : 'Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final titles = ['Overview', 'Tasks', 'Board', 'Reports', 'Account'];
    final icons = [
      Icons.space_dashboard_outlined,
      Icons.checklist,
      Icons.view_kanban_outlined,
      Icons.insights_outlined,
      Icons.person_outline,
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const BrandMark(size: 38),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    'Flow Desk',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            actions: [
              if (store.demo)
                IconButton(
                  tooltip: 'Switch demo intern/admin',
                  onPressed: () => action(store.switchDemo),
                  icon: const Icon(Icons.swap_horiz),
                ),
              IconButton(
                tooltip: 'Toggle appearance',
                onPressed: () => action(() => store.theme(!store.dark)),
                icon: Icon(
                  store.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: page,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  onDestinationSelected: (i) => setState(() => page = i),
                  destinations: List.generate(
                    5,
                    (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      label: titles[i],
                    ),
                  ),
                ),
          floatingActionButton: page == 1 || page == 2
              ? FloatingActionButton.extended(
                  onPressed: () => edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('New task'),
                )
              : null,
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  extended: true,
                  selectedIndex: page,
                  onDestinationSelected: (i) => setState(() => page = i),
                  destinations: List.generate(
                    5,
                    (i) => NavigationRailDestination(
                      icon: Icon(icons[i]),
                      label: Text(titles[i]),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    if (store.demo)
                      Container(
                        width: double.infinity,
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'LOCAL DEMO • ${me.isAdmin ? 'Admin' : 'Intern'} view • Changes saved on this device. No cloud sync.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    if (busy) const LinearProgressIndicator(),
                    if (store.problem != null)
                      MaterialBanner(
                        content: Text(store.problem!),
                        actions: [
                          TextButton(
                            onPressed: () => action(store.retry),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1240),
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 32 : 18,
                              24,
                              wide ? 32 : 18,
                              110,
                            ),
                            children: [
                              switch (page) {
                                0 => overview(),
                                1 => taskList(),
                                2 => board(),
                                3 => reports(),
                                _ => ProfilePage(
                                  key: ValueKey(me.id),
                                  store: store,
                                ),
                              },
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
