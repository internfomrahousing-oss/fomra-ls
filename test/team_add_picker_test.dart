import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/models/employee_profile.dart';
import 'package:fomra_ls/services/app_store.dart';
import 'package:fomra_ls/services/team_hierarchy.dart';

EmployeeProfile _emp(
  String name,
  String email, {
  String designation = EmployeeDesignations.executive,
  String reportsTo = '',
  EmployeeStatus status = EmployeeStatus.active,
}) =>
    EmployeeProfile(
      id: email,
      fullName: name,
      email: email,
      designation: designation,
      reportsTo: reportsTo,
      status: status,
      joinedOn: DateTime(2025, 1, 1),
    );

void main() {
  setUp(() {
    AppStore.instance.setEmployees([
      _emp('Alice', 'alice@f.com'), // unassigned exec
      _emp('Bob', 'bob@f.com', reportsTo: 'me@f.com'), // already on my team
      _emp('Carol', 'carol@f.com', reportsTo: 'other@f.com'), // other team
      _emp('Dan', 'dan@f.com',
          status: EmployeeStatus.inactive), // inactive exec
      _emp('Rhea', 'rhea@f.com',
          designation: EmployeeDesignations.reportingManager), // an RM
    ]);
  });

  group('assignableExecutivesFor', () {
    test('offers everyone not on my team — including other teams', () {
      // carol is on other@f.com's team; she still appears so she can be
      // reassigned. Only my own members (bob) are hidden.
      AppStore.instance.setEmployees([
        _emp('Alice', 'alice@f.com'),
        _emp('Bob', 'bob@f.com', reportsTo: 'me@f.com'),
        _emp('Carol', 'carol@f.com', reportsTo: 'other@f.com'),
        _emp('Other', 'other@f.com',
            designation: EmployeeDesignations.reportingManager),
      ]);
      final emails =
          TeamHierarchy.assignableExecutivesFor('me@f.com').map((e) => e.email);
      expect(emails, containsAll(['alice@f.com', 'carol@f.com']));
      expect(emails, isNot(contains('bob@f.com')));
    });

    test('surfaces an exec orphaned by a missing manager', () {
      AppStore.instance.setEmployees([
        _emp('Nirmal', 'nirmal@f.com', reportsTo: 'sp7033@srmist.edu.in'),
      ]);
      final emails =
          TeamHierarchy.assignableExecutivesFor('me@f.com').map((e) => e.email);
      expect(emails, ['nirmal@f.com']);
    });

    test('excludes execs already on my team, inactive, and non-executives', () {
      final list = TeamHierarchy.assignableExecutivesFor('me@f.com');
      expect(list.any((e) => e.email == 'bob@f.com'), isFalse); // on my team
      expect(list.any((e) => e.email == 'dan@f.com'), isFalse); // inactive
      expect(list.any((e) => e.email == 'rhea@f.com'), isFalse); // an RM
    });
  });

  group('currentTeamLabel', () {
    test('reads Unassigned when nobody manages them', () {
      final alice = TeamHierarchy.byEmail('alice@f.com')!;
      expect(TeamHierarchy.currentTeamLabel(alice), 'Unassigned');
    });

    test('reads Unassigned when the manager no longer exists (orphaned)', () {
      AppStore.instance.setEmployees([
        _emp('Nirmal', 'nirmal@f.com', reportsTo: 'sp7033@srmist.edu.in'),
      ]);
      final nirmal = TeamHierarchy.byEmail('nirmal@f.com')!;
      expect(TeamHierarchy.currentTeamLabel(nirmal), 'Unassigned');
    });

    test('names the current manager otherwise', () {
      AppStore.instance.setEmployees([
        _emp('Manager', 'mgr@f.com',
            designation: EmployeeDesignations.reportingManager),
        _emp('Report', 'rep@f.com', reportsTo: 'mgr@f.com'),
      ]);
      final rep = TeamHierarchy.byEmail('rep@f.com')!;
      expect(TeamHierarchy.currentTeamLabel(rep), "On Manager's team");
    });
  });
}
