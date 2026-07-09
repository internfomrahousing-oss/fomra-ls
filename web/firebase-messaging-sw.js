// Background web-push handler. firebase_messaging registers this file (it must
// live at the web root) so notifications arrive even when the tab is closed.
// Messages that carry a `notification` payload (as /api/push sends) are shown
// by the browser automatically; this file just wires up the messaging instance.

importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDZxkdxEO9HwSP0TuMZwAkISIcsAegasDs',
  authDomain: 'fomrals.firebaseapp.com',
  projectId: 'fomrals',
  storageBucket: 'fomrals.firebasestorage.app',
  messagingSenderId: '450345313339',
  appId: '1:450345313339:web:996c2ccf40b0b70f21a81e',
});

firebase.messaging();
