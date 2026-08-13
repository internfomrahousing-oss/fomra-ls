import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/models/employee_profile.dart';
import 'package:fomra_ls/models/land_lead.dart';
import 'package:fomra_ls/services/app_store.dart';
import 'package:fomra_ls/services/lead_visibility.dart';
import 'package:fomra_ls/services/view_scope.dart';

EmployeeProfile _emp(
  String name,
  String email, {
  String designation = EmployeeDesignations.executive,
  String reportsTo = '',
}) =>
    EmployeeProfile(
      id: email,
      fullName: name,
      email: email,
      designation: designation,
      reportsTo: reportsTo,
      joinedOn: DateTime(2025, 1, 1),
    );

// head@f.com
//   └── rm@f.com ────── exec1@f.com, exec2@f.com
//   └── rm2@f.com ───── exec3@f.com
// otherRm@f.com (a different reporting line) ── exec4@f.com
// lonelyRm@f.com (nobody assigned)
const _head = 'head@f.com';
const _rm = 'rm@f.com';
const _rm2 = 'rm2@f.com';
const _otherRm = 'otherrm@f.com';
const _lonelyRm = 'lonelyrm@f.com';

void _seedRoster() {
  AppStore.instance.setEmployees([
    _emp('Head One', _head, designation: EmployeeDesignations.head),
    _emp('RM One', _rm,
        designation: EmployeeDesignations.reportingManager, reportsTo: _head),
    _emp('RM Two', _rm2,
        designation: EmployeeDesignations.reportingManager, reportsTo: _head),
    _emp('Exec One', 'exec1@f.com', reportsTo: _rm),
    _emp('Exec Two', 'exec2@f.com', reportsTo: _rm),
    _emp('Exec Three', 'exec3@f.com', reportsTo: _rm2),
    _emp('Other RM', _otherRm,
        designation: EmployeeDesignations.reportingManager),
    _emp('Exec Four', 'exec4@f.com', reportsTo: _otherRm),
    _emp('Lonely RM', _lonelyRm,
        designation: EmployeeDesignations.reportingManager),
  ]);
}

Set<String>? _names({
  required String me,
  required String email,
  bool isManagement = false,
}) =>
    LeadVisibility.namesFor(isManagement: isManagement, me: me, email: email);

void main() {
  setUp(() {
    _seedRoster();
    ViewScope.instance.reset(); // back to the Team default
  });

  group('Team view', () {
    test('a Reporting Manager sees only their assigned Executives', () {
      expect(_names(me: 'RM One', email: _rm), {'exec one', 'exec two'});
    });

    test('Team excludes the Reporting Manager\'s own sites', () {
      expect(_names(me: 'RM One', email: _rm), isNot(contains('rm one')));
    });

    test("a Reporting Manager does not see another manager's line", () {
      final names = _names(me: 'RM One', email: _rm)!;
      expect(names, isNot(contains('exec three')));
      expect(names, isNot(contains('exec four')));
      expect(names, isNot(contains('other rm')));
    });

    test('a Head sees every Reporting Manager and Executive under them', () {
      expect(
        _names(me: 'Head One', email: _head),
        {'rm one', 'rm two', 'exec one', 'exec two', 'exec three'},
      );
    });

    test("Team excludes the Head's own sites", () {
      expect(_names(me: 'Head One', email: _head), isNot(contains('head one')));
    });

    test('a Head does not see an unrelated reporting line', () {
      final names = _names(me: 'Head One', email: _head)!;
      expect(names, isNot(contains('other rm')));
      expect(names, isNot(contains('exec four')));
    });

    test('an Executive is unaffected by the team scope', () {
      expect(_names(me: 'Exec One', email: 'exec1@f.com'), {'exec one'});
    });

    test('a manager with nobody assigned sees nothing in Team view', () {
      expect(_names(me: 'Lonely RM', email: _lonelyRm), isEmpty);
    });
  });

  group('Individual view', () {
    setUp(() async {
      await ViewScope.instance.set(TeamViewScope.individual);
    });

    test('a Reporting Manager sees only themselves', () {
      expect(_names(me: 'RM One', email: _rm), {'rm one'});
    });

    test('a Head sees only themselves', () {
      expect(_names(me: 'Head One', email: _head), {'head one'});
    });
  });

  group('unrestricted cases', () {
    test('management sees everything', () {
      expect(
        _names(me: 'Anyone', email: 'x@f.com', isManagement: true),
        isNull,
      );
    });

    test('an unidentified user falls back to unrestricted', () {
      expect(_names(me: '', email: ''), isNull);
    });

    test('a manager missing from the roster sees only themselves', () {
      expect(_names(me: 'Ghost', email: 'ghost@f.com'), {'ghost'});
    });
  });

  group('ViewScope', () {
    test('defaults to Team', () {
      expect(ViewScope.instance.isTeam, isTrue);
    });

    test('set() notifies listeners so scoped screens rebuild', () async {
      var notified = 0;
      void listener() => notified++;
      ViewScope.instance.addListener(listener);
      addTearDown(() => ViewScope.instance.removeListener(listener));

      await ViewScope.instance.set(TeamViewScope.individual);
      expect(notified, 1);

      // Setting the same value again shouldn't churn the whole app.
      await ViewScope.instance.set(TeamViewScope.individual);
      expect(notified, 1);
    });
  });

  group('allows()/scope() — reassignment visibility', () {
    LandLead lead({required String createdBy, String assignedTo = ''}) =>
        LandLead(
          leadId: 'L1',
          inputSource: InputSource.broker,
          location: '',
          gpsCoordinates: '',
          village: '',
          taluk: '',
          district: '',
          pincode: '',
          surveyNumber: '',
          landExtent: '',
          ownerName: '',
          contactDetails: '',
          landType: LandType.other,
          roadWidth: '',
          accessDetails: '',
          notes: '',
          addedOn: DateTime(2026, 1, 1),
          createdByName: createdBy,
          assignedToName: assignedTo,
        );

    setUp(() {
      AppStore.instance.setEmployees([_emp('Devaraj', 'devaraj@f.com')]);
    });

    test(
        'the original creator keeps visibility after the lead is reassigned '
        'away from them — the actual bug this locks in', () {
      final l = lead(createdBy: 'Devaraj', assignedTo: 'Saurabh');
      final names = LeadVisibility.namesFor(
          isManagement: false, me: 'Devaraj', email: 'devaraj@f.com');
      expect(names, {'devaraj'});
      expect(LeadVisibility.leadMatchesNames(l, names!), isTrue,
          reason: 'Devaraj created this lead — reassigning it away must not '
              'erase his own visibility into his prior work on it.');
    });

    test('the new assignee gains visibility even though someone else created it',
        () {
      final l = lead(createdBy: 'Devaraj', assignedTo: 'Saurabh');
      final names = LeadVisibility.namesFor(
          isManagement: false, me: 'Saurabh', email: 'saurabh@f.com');
      expect(names, {'saurabh'});
      expect(LeadVisibility.leadMatchesNames(l, names!), isTrue);
    });

    test('an unrelated executive still cannot see a lead that is neither '
        'theirs nor assigned to them', () {
      final l = lead(createdBy: 'Devaraj', assignedTo: 'Saurabh');
      final names = LeadVisibility.namesFor(
          isManagement: false, me: 'Someone Else', email: 'other@f.com');
      expect(LeadVisibility.leadMatchesNames(l, names!), isFalse);
    });
  });
}
