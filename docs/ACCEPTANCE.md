# Flow Desk acceptance checklist

## Demo mode

Launch with `--dart-define=DEMO=true`.

1. Overview shows seeded, clearly labelled demo records.
2. Create a personal task; enter title, acceptance criteria, due date and priority.
3. Find it using search and change status/progress.
4. Restart the app: the task and profile changes remain on the same device.
5. Switch demo role to administrator, assign/reassign and review tasks.
6. Open each Kanban column, reports and account screen.
7. Add/remove a small profile photo and save name, title, phone and bio.
8. Toggle dark mode and copy/share a CSV report.

## Live Firebase mode

Deploy the supplied rules first. Use two real Firebase accounts.

1. New signup is pending and cannot read tasks.
2. Bootstrap the first admin in the Firebase Console.
3. Admin approves an intern in Reports → Team performance.
4. Admin assigns a task; it appears on the intern device without a restart.
5. Intern changes progress and submits for review; admin sees the update.
6. Intern cannot approve/delete/reassign the admin-created task.
7. Admin adds a review note and marks completion (100%).
8. Reports recalculate for both roles; other interns cannot read that task.
9. Profile photo and details survive sign-out and subsequent sign-in.
10. Disable an intern and verify task access is removed.
11. Disconnect/reconnect internet and verify cloud warnings and pending changes.
12. Confirm password-reset and verification emails arrive, allowing for provider delivery delays.

## Layout/platform checks

- Narrow phone portrait and landscape, keyboard open in task/profile forms.
- Wide desktop navigation rail.
- Horizontal board scrolling on mobile.
- Android native share sheet and web share/copy fallback.
- Photo picker cancellation, oversized image, interrupted Android activity.
- Validate iOS on a real device/macOS toolchain if submitting an iOS build.

Automated tests supplement these checks. They do not prove live project configuration, real email delivery or production device behavior.
