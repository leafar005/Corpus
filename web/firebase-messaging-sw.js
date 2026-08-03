// firebase-messaging-sw.js
// Service Worker para notificaciones push en background (PWA / iOS Safari)
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

const messaging = firebase.messaging();

// Recibe mensajes en background.
// NOTA: Si el payload contiene 'notification', el SDK de Firebase Web Push
// ya muestra automáticamente la notificación en el navegador/PWA.
// Si llamamos a self.registration.showNotification cuando payload.notification existe,
// la notificación aparece duplicada.
messaging.onBackgroundMessage(function(payload) {
  console.log('[Corpus SW] Notificación en background:', payload);

  if (payload.notification) {
    console.log('[Corpus SW] Payload con notification autogestionado por Firebase SDK. Omitiendo duplicado.');
    return;
  }

  const title = payload.data?.title ?? 'Corpus';
  const options = {
    body: payload.data?.body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data ?? {},
    // Vibración y comportamiento al hacer tap
    vibrate: [200, 100, 200],
  };

  self.registration.showNotification(title, options);
});

// Al hacer clic en la notificación, enfocar la ventana de la PWA
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // Si la PWA ya está abierta, la enfocamos
      for (const client of clientList) {
        if ('focus' in client) return client.focus();
      }
      // Si no está abierta, la abrimos
      if (clients.openWindow) return clients.openWindow('/');
    })
  );
});
