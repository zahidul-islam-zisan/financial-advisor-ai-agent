import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker_app/core/constants/app_value.dart';
import 'package:expense_tracker_app/core/widgets/mesh_background.dart';

void main() {
  testWidgets('App branding and MeshBackground smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MeshBackground(
          child: Scaffold(
            body: Center(
              child: Text(AppValue.appName),
            ),
          ),
        ),
      ),
    );

    // Verify that the App name is rendered correctly inside MeshBackground
    expect(find.text(AppValue.appName), findsOneWidget);
    expect(find.byType(MeshBackground), findsOneWidget);
  });
}
