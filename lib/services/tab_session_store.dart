// Per-tab session storage facade.
//
// On web this resolves to sessionStorage (isolated per browser tab); on other
// platforms it falls back to SharedPreferences. Used for the login-identity
// keys so two tabs can hold two different accounts at once.
export 'tab_session_store_io.dart'
    if (dart.library.html) 'tab_session_store_web.dart';
