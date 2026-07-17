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
    test('offers every active exec not already on my team', () {
      final list = TeamHierarchy.assignableExecutivesFor('me@f.com');
      final emails = list.map((e) => e.email).toSet();
      expect(emails, {'alice@f.com', 'carol@f.com'});
    });

    test('excludes execs already on my team', () {
      final list = TeamHierarchy.assignableExecutivesFor('me@f.com');
      expect(list.any((e) => e.email == 'bob@f.com'), isFalse);
    });

    test('excludes inactive employees and non-executives', () {
      final list = TeamHierarchy.assignableExecutivesFor('me@f.com');
      expect(list.any((e) => e.email == 'dan@f.com'), isFalse);
      expect(list.any((e) => e.email == 'rhea@f.com'), isFalse);
    });

    test('an unassigned exec is offered to a fresh manager', () {
      final list = TeamHierarchy.assignableExecutivesFor('brand-new@f.com');
      // Everyone active + executive (alice unassigned, bob & carol on teams).
      expect(list.map((e) => e.email).toSet(),
          {'alice@f.com', 'bob@f.com', 'carol@f.com'});
    });
  });

  group('currentTeamLabel', () {
    test('reads Unassigned when nobody manages them', () {
      final alice = TeamHierarchy.byEmail('alice@f.com')!;
      expect(TeamHierarchy.currentTeamLabel(alice), 'Unassigned');
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
