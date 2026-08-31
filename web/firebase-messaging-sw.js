// firebase-messaging-sw.js
// Service Worker para notificaciones push en background (PWA / iOS Safari / Firefox).
// Se ejecuta cuando la app web NO está en primer plano.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAGjsQRsHKWe2C6HSn1IqVlqn91O2e6IVE",
  authDomain: "corpus-games.firebaseapp.com",
  projectId: "corpus-games",
  storageBucket: "corpus-games.firebasestorage.app",
  messagingSenderId: "1081828301308",
  appId: "1:1081828301308:web:bb9580b5efd664baacba79"
});

// IMPORTANTE — por qué esto ya NO usa messaging.onBackgroundMessage():
// ese hook del SDK de Firebase no se dispara de forma fiable en iOS Safari
// (documentado en https://github.com/firebase/firebase-js-sdk/issues/8444
// y https://github.com/firebase/firebase-js-sdk/issues/8002). Cuando no se
// dispara, el push llega al dispositivo pero no genera notificación visible
// — eso cuenta para Safari como "silent push", y tras varios seguidos
// revoca el permiso de push del sitio sin avisar
// (https://github.com/firebase/firebase-js-sdk/issues/8010). Usando el
// evento nativo 'push' del Service Worker en su lugar, nos saltamos por
// completo esa capa del SDK y el comportamiento es consistente en Chrome,
// Firefox y Safari 16.4+.

self.addEventListener('push', function (event) {
  let payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (e) {
    console.error('[Corpus SW] Payload de push no es JSON válido:', e);
  }

  const notification = payload.notification || {};
  const data = payload.data || {};
  
  const title = notification.title || data.title || 'Corpus';
  const options = {
    body: notification.body || data.body || '',
    icon: notification.icon || '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data,
    vibrate: [200, 100, 200],
  };

  // event.waitUntil es imprescindible: si el navegador cierra el Service
  // Worker antes de que showNotification termine, es exactamente el
  // escenario de "silent push" que hace que Safari acabe revocando el
  // permiso. Con waitUntil, el SW se mantiene vivo hasta que la promesa
  // resuelve.
  event.waitUntil(self.registration.showNotification(title, options));
});

// Al hacer clic en la notificación, enfocar la ventana de la PWA (o abrirla).
self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
      for (const client of clientList) {
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});
