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

// Detecta si el Service Worker corre en Safari/WebKit (iOS PWA).
// En Safari, el SDK compat de Firebase NO auto-muestra notificaciones
// aunque el payload traiga un objeto 'notification' — a diferencia de
// Chrome/Firefox donde el SDK sí las gestiona automáticamente.
// Fuente: https://firebase.google.com/docs/cloud-messaging/js/receive
function isWebKitSW() {
  // self.navigator.userAgent está disponible en SW desde Safari 16+
  try {
    return /safari/i.test(self.navigator.userAgent) && !/chrome/i.test(self.navigator.userAgent);
  } catch (_) {
    return false;
  }
}

// Recibe mensajes en background.
// - Chrome/Firefox: si el payload tiene 'notification', el SDK lo muestra automáticamente.
//   Si llamamos también a showNotification la notificación aparece duplicada → salimos.
// - Safari/iOS PWA: el SDK NO auto-muestra nada, así que siempre llamamos showNotification.
messaging.onBackgroundMessage(function(payload) {
  console.log('[Corpus SW] Notificación en background:', payload);

  const safariMode = isWebKitSW();

  if (payload.notification && !safariMode) {
    // Chrome/Firefox: el SDK ya gestiona el notification payload — evitamos duplicado.
    console.log('[Corpus SW] Payload con notification autogestionado por Firebase SDK (no-Safari). Omitiendo duplicado.');
    return;
  }

  // Safari (o payload data-only): mostramos la notificación manualmente.
  const title = payload.notification?.title ?? payload.data?.title ?? 'Corpus';
  const options = {
    body: payload.notification?.body ?? payload.data?.body ?? '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data ?? {},
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
