import 'dart:io';
import 'dart:ui' as ui;

import 'package:e_pod/models/app_user_model.dart';
import 'package:e_pod/screens/manager_sms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('seven recipients use two columns and can scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 1050));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ManagerSmsScreen(
          previewDrivers: List.generate(
            7,
            (i) => AppUserModel(
              userId: 'driver-$i',
              fullName: 'Driver $i',
              email: '',
              role: 'driver',
              phoneNumber: '0240000000',
              createdAt: '',
              updatedAt: '',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all drivers'));
    await tester.pumpAndSettle();
    final first = tester.getTopLeft(find.text('Driver 0'));
    final second = tester.getTopLeft(find.text('Driver 1'));
    expect(second.dx, greaterThan(first.dx));
    expect(second.dy, first.dy);
    final list = find.byKey(const PageStorageKey('sms-recipients'));
    final scrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    expect(
      tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
      greaterThan(0),
    );
  });

  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_SMS_PREVIEW') &&
        Platform.isWindows) {
      final font = File('C:/Windows/Fonts/segoeui.ttf');
      if (font.existsSync()) {
        await (FontLoader('PreviewFont')..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            ))
            .load();
      }
      final icons = File(
        'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      );
      if (icons.existsSync()) {
        await (FontLoader('MaterialIcons')..addFont(
              Future.value(ByteData.sublistView(icons.readAsBytesSync())),
            ))
            .load();
      }
    }
  });
  testWidgets(
    'Manager searches, prefills a saved phone and sends with a manually entered phone',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1050));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorSchemeSeed: const Color(0xFF0F5FB8),
              fontFamily: const bool.fromEnvironment('CAPTURE_SMS_PREVIEW')
                  ? 'PreviewFont'
                  : null,
            ),
            home: ManagerSmsScreen(
              previewDrivers: const [
                AppUserModel(
                  userId: 'driver-1',
                  fullName: 'Kwame Mensah',
                  email: 'kwame@example.com',
                  phoneNumber: '024 000 0000',
                  role: 'driver',
                  createdAt: '',
                  updatedAt: '',
                ),
                AppUserModel(
                  userId: 'driver-2',
                  fullName: 'Ama Boateng',
                  email: 'ama@example.com',
                  role: 'driver',
                  createdAt: '',
                  updatedAt: '',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byType(TextField).first;
      final phone = find.widgetWithText(TextField, 'Driver phone number');
      expect(find.text('Kwame Mensah'), findsNothing);
      expect(find.text('Ama Boateng'), findsNothing);
      await tester.enterText(search, 'kwame');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kwame Mensah'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(phone).controller!.text, '024 000 0000');
      final instructions = find.widgetWithText(TextField, 'Job instructions');
      expect(
        tester.widget<TextField>(instructions).controller!.text,
        'Hello Kwame Mensah,\n\n',
      );
      await tester.tap(find.text('Find Office Staff'));
      await tester.pumpAndSettle();
      expect(
        find.text('Search your department by name or phone'),
        findsOneWidget,
      );
      expect(find.text('Search driver by name or phone'), findsNothing);
      expect(find.text('Recipients (1)'), findsOneWidget);
      await tester.tap(find.text('Find Drivers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all drivers'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(phone.last).controller!.text, isEmpty);
      expect(find.textContaining('No number linked'), findsOneWidget);
      expect(find.text('Recipients (2)'), findsOneWidget);
      await tester.enterText(phone.last, '020 000 0000');
      await tester.enterText(
        find.widgetWithText(TextField, 'Job instructions'),
        'Hello Team,\n\nCollect cargo at 9 AM.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unselect all drivers'));
      await tester.pumpAndSettle();
      expect(phone, findsNothing);
      await tester.tap(find.text('Select all drivers'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Job instructions'),
            )
            .controller!
            .text,
        'Hello Team,\n\nCollect cargo at 9 AM.',
      );
      await tester.enterText(phone.last, '020 000 0000');
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('CAPTURE_SMS_PREVIEW')) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/transport-manager-sms-preview.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
      await tester.tap(find.text('Send SMS'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('SMS History'));
      await tester.pumpAndSettle();
      expect(find.text('Bulk SMS · 2 recipients'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.textContaining('Collect cargo at 9 AM.'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      await tester.tap(find.text('View').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('Kwame Mensah · 024 000 0000 · Preview'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ama Boateng · 020 000 0000 · Preview'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Collect cargo at 9 AM.'),
        ),
        findsOneWidget,
      );
      expect(find.text('Send test SMS', skipOffstage: false), findsNothing);
    },
  );
}
