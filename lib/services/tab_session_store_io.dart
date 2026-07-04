import 'package:shared_preferences/shared_preferences.dart';

// Non-web (mobile/desktop) implementation. There are no browser tabs here, so
// session state is stored in SharedPreferences exactly as before.

Future<String?> tabGetString(String key) async =>
    (await SharedPreferences.getInstance()).getString(key);

Future<void> tabSetString(String key, String value) async =>
    (await SharedPreferences.getInstance()).setString(key, value);

Future<void> tabRemove(String key) async =>
    (await SharedPreferences.getInstance()).remove(key);
