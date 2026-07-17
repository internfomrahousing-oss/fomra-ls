import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/models/employee_profile.dart';
import 'package:fomra_ls/services/auth_service.dart';
import 'package:fomra_ls/widgets/impersonation_banner.dart';

EmployeeProfile _emp(String name, String email,
        {String designation = EmployeeDesignations.executive}) =>
    EmployeeProfile(
      id: email,
      fullName: name,
      email: email,
      designation: designation,
      joinedOn: DateTime(2025, 1, 1),
    );

void main() {
  final auth = AuthService.instance;

  tearDown(() => auth.stopImpersonation());

  group('the impersonation overlay', () {
    test('starts off inactive', () {
      expect(auth.isImpersonating, isFalse);
      expect(auth.impersonatedUser, isNull);
    });

    test('accessing a user makes the app see them, not management', () {
      final sara = _emp('Sara', 'sara@f.com',
          designation: EmployeeDesignations.reportingManager);
      auth.startImpersonation(sara);

      expect(auth.isImpersonating, isTrue);
      expect(auth.currentUser?.email, 'sara@f.com');
      expect(auth.currentUser?.fullName, 'Sara');
      expect(auth.currentUser?.role, 'employee');
      expect(auth.isManagement, isFalse);
      expect(auth.isEmployee, isTrue);
      expect(auth.loginPortal, LoginPortal.employee);
      expect(auth.impersonationStart, isNotNull);
    });

    test('nested access is refused — the first user stays', () {
      auth.startImpersonation(_emp('First', 'first@f.com'));
      auth.startImpersonation(_emp('Second', 'second@f.com'));
      expect(auth.currentUser?.email, 'first@f.com');
    });

    test('returning restores management', () {
      auth.startImpersonation(_emp('Sara', 'sara@f.com'));
      auth.stopImpersonation();
      expect(auth.isImpersonating, isFalse);
      expect(auth.impersonatedUser, isNull);
      expect(auth.impersonation.value, isNull);
    });

    test('the notifier fires so the UI can react', () {
      final seen = <String?>[];
      void listener() => seen.add(auth.impersonation.value?.email);
      auth.impersonation.addListener(listener);
      addTearDown(() => auth.impersonation.removeListener(listener));

      auth.startImpersonation(_emp('Sara', 'sara@f.com'));
      auth.stopImpersonation();
      expect(seen, ['sara@f.com', null]);
    });
  });

  group('the persistent banner', () {
    testWidgets('shows who you are accessing as, and hides otherwise',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ImpersonationBanner()),
      ));
      // Nothing while not impersonating.
      expect(find.textContaining('accessing the application as'), findsNothing);

      auth.startImpersonation(_emp('Sara Ravindran', 'sara@f.com'));
      await tester.pump();
      expect(
        find.text('You are accessing the application as Sara Ravindran.'),
        findsOneWidget,
      );
      expect(find.text('Return to Management'), findsOneWidget);

      auth.stopImpersonation();
      await tester.pump();
      expect(find.textContaining('accessing the application as'), findsNothing);
    });
  });
}
