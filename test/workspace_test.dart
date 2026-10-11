import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flow_desk/main.dart';
import 'package:flow_desk/store.dart';

void main() {
  testWidgets('phone navigates each workspace page without layout exception', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = DeskStore(
      demo: true,
      preferences: await SharedPreferences.getInstance(),
    );
    try {
      await store.init();
      await tester.pumpWidget(FlowDesk(store: store));
      await tester.pumpAndSettle();
      expect(find.textContaining('LOCAL DEMO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (var i = 1; i < 5; i++) {
        await tester.tap(find.byType(NavigationDestination).at(i));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
  testWidgets(
    'create task dialog closes without leaving controllers or timers',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = DeskStore(
        demo: true,
        preferences: await SharedPreferences.getInstance(),
      );
      try {
        await store.init();
        await tester.pumpWidget(FlowDesk(store: store));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Create a task'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField).first,
          'New internship task',
        );
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(store.tasks.length, 6);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
      }
    },
  );
  testWidgets('desktop uses navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = DeskStore(
      demo: true,
      preferences: await SharedPreferences.getInstance(),
    );
    try {
      await store.init();
      await tester.pumpWidget(FlowDesk(store: store));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    }
  });
}
