// firebase-messaging-sw.js
// Service Worker para notificaciones push en background (PWA / iOS Safari / Firefox).
// Usa exclusivamente listeners nativos 'push' y 'notificationclick' sin SDK Firebase Compat (OPT-30).

function resolveNotificationTargetUrl(data) {
  const payload = data || {};
  if (payload.review_id) {
    return '/actividad/resena/' + encodeURIComponent(payload.review_id);
  }
  if (payload.post_id) {
    return '/actividad/post/' + encodeURIComponent(payload.post_id);
  }
  if (payload.game_id) {
    return '/buscar/' + encodeURIComponent(payload.game_id);
  }
  if (payload.type === 'new_bundle' || payload.type === 'bundle_expiring') {
    return '/buscar';
  }
  return '/';
}

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
    data: data,
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

// Al hacer clic en la notificación, enrutar dentro de la PWA abierta (vía postMessage / navigate)
// o abrir una ventana nueva en targetUrl.
self.addEventListener('notificationclick', function (event) {
  const data = (event.notification && event.notification.data) || {};
  const targetUrl = resolveNotificationTargetUrl(data);

  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (clientList) {
      for (const client of clientList) {
        if ('focus' in client) {
          if (typeof client.postMessage === 'function') {
            try {
              client.postMessage({
                type: 'CORPUS_NOTIFICATION_CLICK',
                data: data,
                targetUrl: targetUrl,
              });
              return client.focus();
            } catch (_) {}
          }
          if ('navigate' in client && targetUrl !== '/') {
            return client.navigate(targetUrl).then(function (navigatedClient) {
              return (navigatedClient || client).focus();
            });
          }
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(targetUrl);
    })
  );
});

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { resolveNotificationTargetUrl };
}
