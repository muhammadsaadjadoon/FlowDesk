import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'brand.dart';
import 'store.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.store});
  final DeskStore store;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  bool register = false, busy = false, hide = true;
  String? message;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit({bool reset = false}) async {
    if (busy) {
      return;
    }
    if (reset) {
      if (!email.text.contains('@')) {
        setState(() => message = 'Enter your account email first.');
        return;
      }
    } else if (!form.currentState!.validate()) {
      return;
    }
    final enteredName = name.text.trim();
    final enteredEmail = email.text.trim();
    final enteredPassword = password.text;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (reset) {
        await auth.sendPasswordResetEmail(email: email.text.trim());
        if (mounted) {
          setState(
            () => message =
                'If an account exists, check its inbox for reset instructions.',
          );
        }
      } else if (register) {
        final result = await auth.createUserWithEmailAndPassword(
          email: enteredEmail,
          password: enteredPassword,
        );
        await result.user!.updateDisplayName(enteredName);
        await widget.store.ensureProfile(result.user!, name: enteredName);
      } else {
        await auth.signInWithEmailAndPassword(
          email: enteredEmail,
          password: enteredPassword,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => message = readableError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: const BrandMark(size: 92)),
                      const SizedBox(height: 12),
                      const Text(
                        'Flow Desk',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        register
                            ? 'Start your internship workspace.'
                            : 'A clear desk. A focused day.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (register) ...[
                        TextFormField(
                          controller: name,
                          maxLength: 80,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                          ),
                          validator: (v) => (v ?? '').trim().length < 2
                              ? 'Enter your name.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextFormField(
                        controller: email,
                        maxLength: 254,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        validator: (v) =>
                            RegExp(
                              r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                            ).hasMatch((v ?? '').trim())
                            ? null
                            : 'Enter a valid email.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: password,
                        obscureText: hide,
                        autofillHints: [
                          register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: 'Show or hide password',
                            onPressed: () => setState(() => hide = !hide),
                            icon: Icon(
                              hide
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (v) => register
                            ? (v ?? '').length < 8
                                  ? 'Use at least 8 characters.'
                                  : null
                            : (v ?? '').isEmpty
                            ? 'Enter your password.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      if (message != null || widget.store.problem != null) ...[
                        Text(
                          message ?? widget.store.problem!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      FilledButton(
                        onPressed: busy ? null : submit,
                        child: Text(
                          busy
                              ? 'Please wait…'
                              : register
                              ? 'Create account'
                              : 'Sign in',
                        ),
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => setState(() {
                                register = !register;
                                message = null;
                              }),
                        child: Text(
                          register
                              ? 'Already registered? Sign in'
                              : 'New here? Create an account',
                        ),
                      ),
                      if (!register)
                        TextButton(
                          onPressed: busy ? null : () => submit(reset: true),
                          child: const Text('Forgot password?'),
                        ),
                      if (FirebaseAuth.instance.currentUser != null &&
                          widget.store.problem != null)
                        TextButton(
                          onPressed: busy ? null : widget.store.retry,
                          child: const Text('Retry workspace connection'),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'New accounts require administrator approval. Your role is managed by your organization.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    required this.store,
    this.task,
    required this.onSave,
  });
  final DeskStore store;
  final DeskTask? task;
  final Future<void> Function(DeskTask) onSave;
  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, description, note;
  late String assignee, status, priority, category;
  late DateTime due;
  late double progress;
  late final String taskId;
  late final DateTime createdAt;
  bool busy = false;
  String? error;
  bool get admin => widget.store.me!.isAdmin;
  bool get detailsEditable =>
      admin ||
      widget.task == null ||
      widget.task!.createdBy == widget.store.me!.id;
  bool get canFinish =>
      admin ||
      widget.task == null ||
      widget.task!.createdBy == widget.store.me!.id;
  @override
  void initState() {
    super.initState();
    final t = widget.task;
    taskId = t?.id ?? DeskStore.newId();
    createdAt = t?.createdAt ?? DateTime.now();
    title = TextEditingController(text: t?.title ?? '');
    description = TextEditingController(text: t?.description ?? '');
    note = TextEditingController(text: t?.reviewNote ?? '');
    assignee = t?.assigneeId ?? widget.store.me!.id;
    status = t?.status ?? 'todo';
    priority = t?.priority ?? 'medium';
    category = t?.category ?? 'Development';
    due = t?.due ?? DateTime.now().add(const Duration(days: 1));
    progress = (t?.progress ?? 0).toDouble();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final now = DateTime.now();
      final t = DeskTask(
        id: taskId,
        title: title.text.trim(),
        description: description.text.trim(),
        assigneeId: assignee,
        createdBy: widget.task?.createdBy ?? widget.store.me!.id,
        due: due,
        createdAt: createdAt,
        updatedAt: now,
        status: status,
        priority: priority,
        category: category,
        progress: status == 'done'
            ? 100
            : status == 'todo'
            ? 0
            : progress.round(),
        reviewNote: note.text.trim(),
      );
      await widget.onSave(t);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = readableError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = widget.store.members.where((m) => m.active).toList();
    if (!people.any((m) => m.id == assignee)) {
      people.add(
        Member(
          id: assignee,
          name: widget.store.memberName(assignee),
          email: '',
        ),
      );
    }
    final choices = statuses
        .where((s) => s != 'done' || canFinish || status == 'done')
        .toList();
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(
          widget.task == null ? 'Create a new task' : 'Task workspace',
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: title,
                    enabled: detailsEditable && !busy,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Task title'),
                    validator: (v) => (v ?? '').trim().length < 3
                        ? 'Use a clear title with at least 3 characters.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    enabled: detailsEditable && !busy,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Description / acceptance criteria',
                    ),
                    validator: (v) => (v ?? '').trim().isEmpty
                        ? 'Describe what needs to be done.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (admin)
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: assignee,
                      decoration: const InputDecoration(labelText: 'Assign to'),
                      items: people
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                m.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: busy
                          ? null
                          : (v) => setState(() => assignee = v!),
                    ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 210,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: priority,
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                          ),
                          items: priorities
                              .map(
                                (p) =>
                                    DropdownMenuItem(value: p, child: Text(p)),
                              )
                              .toList(),
                          onChanged: detailsEditable && !busy
                              ? (v) => setState(() => priority = v!)
                              : null,
                        ),
                      ),
                      SizedBox(
                        width: 210,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items:
                              {
                                    'Development',
                                    'Design',
                                    'Research',
                                    'Documentation',
                                    'Testing',
                                    'Other',
                                    category,
                                  }
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged: detailsEditable && !busy
                              ? (v) => setState(() => category = v!)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: detailsEditable && !busy
                        ? () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: due,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null && mounted) {
                              setState(() => due = picked);
                            }
                          }
                        : null,
                    icon: const Icon(Icons.calendar_month),
                    label: Text('Due ${dayLabel(due)}'),
                  ),
                  const Divider(height: 30),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Work stage'),
                    items: choices
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(statusNames[s]!),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() {
                            status = v!;
                            if (status == 'done') {
                              progress = 100;
                            }
                            if (status == 'todo') {
                              progress = 0;
                            }
                          }),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Progress  ${progress.round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: progress,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '${progress.round()}%',
                    onChanged: busy || status == 'done' || status == 'todo'
                        ? null
                        : (v) => setState(() => progress = v),
                  ),
                  if (!canFinish)
                    const Text(
                      'Submit as “In review” when ready. Your administrator confirms completion.',
                    ),
                  if (admin) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: note,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Administrator review note',
                      ),
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy ? null : save,
            child: Text(busy ? 'Saving…' : 'Save task'),
          ),
        ],
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.member, this.radius = 38});
  final Member member;
  final double radius;
  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    try {
      if (member.photo.isNotEmpty) {
        bytes = base64Decode(member.photo);
      }
    } catch (_) {
      bytes = null;
    }
    final initials = member.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xffb5fff0),
      child: bytes == null
          ? Text(
              initials.isEmpty ? 'FD' : initials,
              style: TextStyle(
                color: const Color(0xff152d43),
                fontSize: radius * .55,
                fontWeight: FontWeight.bold,
              ),
            )
          : ClipOval(
              child: Image.memory(
                bytes,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.person),
              ),
            ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.store});
  final DeskStore store;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name, title, phone, bio;
  bool busy = false;
  String? notice;
  @override
  void initState() {
    super.initState();
    final m = widget.store.me!;
    name = TextEditingController(text: m.name);
    title = TextEditingController(text: m.title);
    phone = TextEditingController(text: m.phone);
    bio = TextEditingController(text: m.bio);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      recoverPhoto();
    }
  }

  @override
  void dispose() {
    name.dispose();
    title.dispose();
    phone.dispose();
    bio.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() f, String success) async {
    if (busy) {
      return;
    }
    setState(() {
      busy = true;
      notice = null;
    });
    try {
      await f();
      if (mounted) {
        setState(() => notice = success);
      }
    } catch (e) {
      if (mounted) {
        setState(() => notice = readableError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> setPhoto(XFile file) async {
    final uid = widget.store.me?.id;
    final bytes = await file.readAsBytes();
    if (bytes.length > 145000) {
      throw StateError('Photo too large.');
    }
    if (widget.store.me?.id != uid) {
      return;
    }
    await widget.store.profile({'photo': base64Encode(bytes)});
  }

  Future<void> recoverPhoto() async {
    try {
      final r = await ImagePicker().retrieveLostData();
      if (!mounted || r.isEmpty) {
        return;
      }
      if (r.files?.isNotEmpty == true) {
        setState(
          () => notice =
              'A photo selection was recovered. Tap Change photo to choose and save it again.',
        );
      }
    } catch (_) {
      /* Recovery is optional; normal picking still works. */
    }
  }

  Future<void> photo() async {
    await run(() async {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 384,
        maxHeight: 384,
        imageQuality: 60,
        requestFullMetadata: false,
      );
      if (f != null) {
        final bytes = await f.readAsBytes();
        if (bytes.length > 145000) {
          throw StateError(
            'Choose a smaller photo (under 145 KB after resizing).',
          );
        }
        await setPhoto(f);
      }
    }, 'Photo selection complete.');
  }

  Widget section(Widget c) => Card(
    margin: const EdgeInsets.only(bottom: 18),
    child: Padding(padding: const EdgeInsets.all(24), child: c),
  );
  @override
  Widget build(BuildContext context) {
    final m = widget.store.me!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your account. Your workspace.',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        const Text('Keep your details current and manage how you work.'),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff152d43), Color(0xff175367)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xffb5fff0), width: 2),
                ),
                child: ProfileAvatar(member: m, radius: 44),
              ),
              const SizedBox(height: 16),
              Text(
                m.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                m.email,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(m.role.toUpperCase())),
                  Chip(
                    label: Text(
                      widget.store.demo ? 'Local demo' : 'Cloud workspace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: busy ? null : photo,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Change photo'),
                  ),
                  if (m.photo.isNotEmpty)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => run(
                              () => widget.store.profile({'photo': ''}),
                              'Photo removed.',
                            ),
                      child: const Text(
                        'Remove photo',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              notice!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 18),
        section(
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Personal details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: name,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      (v ?? '').trim().length < 2 ? 'Enter your name.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: title,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Role / specialization',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  maxLength: 30,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: bio,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'About you'),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          if (form.currentState!.validate()) {
                            run(
                              () => widget.store.profile({
                                'name': name.text.trim(),
                                'title': title.text.trim(),
                                'phone': phone.text.trim(),
                                'bio': bio.text.trim(),
                              }),
                              'Profile saved.',
                            );
                          }
                        },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save details'),
                ),
              ],
            ),
          ),
        ),
        section(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Preferences & security',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark appearance'),
                subtitle: const Text('A calmer workspace in low light.'),
                value: widget.store.dark,
                onChanged: busy
                    ? null
                    : (v) => run(
                        () => widget.store.theme(v),
                        'Appearance updated.',
                      ),
              ),
              if (!widget.store.demo) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Send verification email'),
                  onTap: busy
                      ? null
                      : () => run(() async {
                          await FirebaseAuth.instance.currentUser!
                              .sendEmailVerification();
                        }, 'Verification email sent.'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Reset password'),
                  onTap: busy
                      ? null
                      : () => run(
                          () => FirebaseAuth.instance.sendPasswordResetEmail(
                            email: m.email,
                          ),
                          'Password reset instructions sent.',
                        ),
                ),
              ],
              const Divider(),
              const Text(
                'Reports reflect task records, not a performance ranking. Profile photos are resized and saved with your profile. Administrators can see team profiles.',
              ),
              const SizedBox(height: 18),
              if (widget.store.demo)
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                            run(widget.store.switchDemo, 'Demo role switched.'),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Switch demo role'),
                )
              else
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Sign out?'),
                              content: const Text(
                                'Your cloud records will remain in the workspace.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await run(widget.store.signOut, 'Signed out.');
                          }
                        },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
            ],
          ),
        ),
        const Center(
          child: Text('Flow Desk • 1.0.0', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
