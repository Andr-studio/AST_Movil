# Sistema de Notificaciones Push - AST Móvil

## Descripción General

El sistema de notificaciones push de AST Móvil utiliza **Firebase Cloud Messaging (FCM)** para enviar notificaciones en tiempo real a los usuarios de la aplicación. Este sistema está completamente integrado con el flujo de trabajo de la aplicación y notifica a los usuarios sobre eventos importantes del sistema.

## Arquitectura

### Componentes Principales

1. **NotificationService** (`lib/services/notification_service.dart`)
   - Servicio principal para gestionar notificaciones
   - Maneja inicialización de FCM
   - Gestiona tokens de dispositivos
   - Envía notificaciones a usuarios específicos
   - Almacena historial en Firestore

2. **AppNotification** (`lib/models/notification_model.dart`)
   - Modelo de datos para notificaciones
   - Define tipos de notificaciones
   - Helpers para crear notificaciones comunes

3. **AuthProvider** (actualizado)
   - Actualiza FCM token al hacer login
   - Elimina FCM token al hacer logout

4. **Servicios Integrados**
   - `ast_service.dart`: Notifica al supervisor cuando se crea un nuevo AST
   - `aprobacion_service.dart`: Notifica al técnico cuando su AST es aprobado/rechazado
   - `reasignacion_service.dart`: Notifica a técnicos, supervisores y admins sobre reasignaciones
   - `tecnico_service.dart`: Notifica al supervisor cuando crea un técnico

## Tipos de Notificaciones

### Para Técnicos

| Tipo | Título | Cuándo se Envía |
|------|--------|-----------------|
| `ast_aprobado` | ✅ AST Aprobado | Cuando el supervisor aprueba un AST |
| `ast_rechazado` | ❌ AST Rechazado | Cuando el supervisor rechaza un AST |
| `reasignado` | 🔄 Reasignación de Supervisor | Cuando el admin reasigna al técnico a otro supervisor |

### Para Supervisores

| Tipo | Título | Cuándo se Envía |
|------|--------|-----------------|
| `nuevo_ast` | 📋 Nuevo AST Pendiente | Cuando un técnico genera un nuevo AST |
| `tecnico_creado` | 👷 Nuevo Técnico Creado | Cuando el supervisor crea un técnico |
| `tecnico_reasignado` | 🔄 Técnico Reasignado a Ti | Cuando recibe un técnico por reasignación |

### Para Administradores

| Tipo | Título | Cuándo se Envía |
|------|--------|-----------------|
| `reasignacion_completada` | ✅ Reasignación Completada | Cuando se completa una reasignación |

## Flujo de Funcionamiento

### 1. Inicialización

```dart
// En main.dart
void main() async {
  // ...
  final notificationService = NotificationService();
  await notificationService.initialize();
  // ...
}
```

### 2. Login de Usuario

```dart
// En AuthProvider
await _notificationService.updateUserToken(_currentUser!.uid);
```

- Se obtiene el token FCM del dispositivo
- Se almacena en Firestore en el campo `fcmToken` del usuario
- Se configura listener para actualizar token si cambia

### 3. Envío de Notificación

```dart
await _notificationService.sendNotificationToUser(
  userId: 'uid_del_usuario',
  title: 'Título de la notificación',
  body: 'Cuerpo del mensaje',
  data: {
    'type': 'tipo_de_notificacion',
    'astId': 'id_del_ast',
    // ... otros datos relevantes
  },
);
```

### 4. Recepción de Notificación

**Foreground (app abierta):**
- Se muestra automáticamente en la barra de notificaciones
- Se emite a través de `notificationStream` para reacciones de UI

**Background (app en segundo plano):**
- Se muestra en la barra de notificaciones
- Al tocarla, se abre la app y se ejecuta `onMessageOpenedApp`

**Terminated (app cerrada):**
- Se muestra en la barra de notificaciones
- Al tocarla, se abre la app y se ejecuta `getInitialMessage`

### 5. Almacenamiento en Firestore

Todas las notificaciones se almacenan en la colección `notificaciones`:

```javascript
{
  userId: "uid_del_usuario",
  title: "Título",
  body: "Mensaje",
  type: "tipo_notificacion",
  data: { ... },
  delivered: true/false,
  read: false,
  timestamp: Timestamp,
  readAt: null
}
```

## Estructura de Firestore

### Colección: `notificaciones`

| Campo | Tipo | Descripción |
|-------|------|-------------|
| `userId` | String | ID del usuario destinatario |
| `title` | String | Título de la notificación |
| `body` | String | Cuerpo del mensaje |
| `type` | String | Tipo de notificación (ver tipos arriba) |
| `data` | Map | Datos adicionales (astId, supervisorUid, etc.) |
| `delivered` | Boolean | Si la notificación push fue entregada exitosamente |
| `read` | Boolean | Si el usuario ha leído la notificación |
| `timestamp` | Timestamp | Fecha y hora de creación |
| `readAt` | Timestamp | Fecha y hora de lectura (null si no leída) |

### Campo en `usuarios`: `fcmToken`

- Se actualiza automáticamente al hacer login
- Se elimina al hacer logout
- Se refresca automáticamente si FCM genera un nuevo token

## Permisos Necesarios

### Android

En `AndroidManifest.xml`:

```xml
<!-- Permisos de Notificaciones Push (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### iOS

En `Info.plist` (se configura automáticamente con Firebase):
- Firebase solicita permisos automáticamente al inicializar

## Casos de Uso

### 1. Flujo de Aprobación de AST

```
1. Técnico genera AST
   └─> Notificación al Supervisor: "📋 Nuevo AST Pendiente"

2a. Supervisor aprueba AST
    └─> Notificación al Técnico: "✅ AST Aprobado"

2b. Supervisor rechaza AST
    └─> Notificación al Técnico: "❌ AST Rechazado" + motivo
```

### 2. Flujo de Reasignación

```
1. Admin reasigna técnico
   ├─> Notificación al Técnico: "🔄 Reasignación de Supervisor"
   ├─> Notificación al Nuevo Supervisor: "🔄 Técnico Reasignado a Ti"
   └─> Notificación al Admin: "✅ Reasignación Completada"
```

### 3. Flujo de Creación de Técnico

```
1. Supervisor crea técnico
   └─> Notificación al Supervisor: "👷 Nuevo Técnico Creado"
```

## Métodos Principales

### NotificationService

```dart
// Inicializar servicio
await notificationService.initialize();

// Obtener token del dispositivo
String? token = await notificationService.getDeviceToken();

// Actualizar token del usuario
await notificationService.updateUserToken(userId);

// Enviar notificación
await notificationService.sendNotificationToUser(
  userId: 'uid',
  title: 'Título',
  body: 'Mensaje',
  data: {...},
);

// Marcar como leída
await notificationService.markAsRead(notificationId);

// Stream de notificaciones no leídas
Stream<List<AppNotification>> stream =
  notificationService.getUnreadNotifications(userId);

// Eliminar token (logout)
await notificationService.removeUserToken(userId);
```

## Consideraciones de Producción

### 1. Envío de Notificaciones desde Backend

⚠️ **IMPORTANTE**: En producción, el envío de notificaciones debe hacerse desde Cloud Functions de Firebase, no desde el cliente.

**Razones:**
- No se debe exponer la Server Key de FCM en el cliente
- Mayor seguridad y control
- Mejor rendimiento para envíos masivos

**Implementación Recomendada:**

```javascript
// Cloud Function (Firebase)
exports.sendNotificationOnASTApproval = functions.firestore
  .document('ast/{astId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    if (oldData.estado === 'pendiente' && newData.estado === 'aprobado') {
      const message = {
        notification: {
          title: '✅ AST Aprobado',
          body: `El AST ${newData.numeroMTA} ha sido aprobado`
        },
        data: {
          type: 'ast_aprobado',
          astId: context.params.astId,
          numeroMTA: newData.numeroMTA
        },
        token: newData.fcmToken // Token del técnico
      };

      await admin.messaging().send(message);
    }
  });
```

### 2. Gestión de Tokens Expirados

El servicio maneja automáticamente:
- Tokens que fallan al enviar (se marca `delivered: false`)
- Refresco automático de tokens
- Actualización en login

### 3. Privacidad y Seguridad

- Los tokens FCM son únicos por dispositivo
- Se eliminan al hacer logout
- Las notificaciones solo van a usuarios autorizados
- El historial es privado por usuario

## Testing

### Test Manual

1. **Login**: Verificar que se actualiza el token
2. **Crear AST**: Verificar que el supervisor recibe notificación
3. **Aprobar AST**: Verificar que el técnico recibe notificación
4. **Rechazar AST**: Verificar que el técnico recibe notificación con motivo
5. **Reasignar**: Verificar que técnico, supervisor y admin reciben notificaciones
6. **Logout**: Verificar que se elimina el token

### Logs de Debug

El servicio incluye logs detallados:
```
✅ Permisos de notificación otorgados
📱 FCM Token obtenido: abcd1234...
✅ Token FCM actualizado para usuario: uid123
📤 Enviando notificación FCM...
✅ Notificación FCM simulada exitosamente
💾 Notificación guardada en Firestore
```

## Próximas Mejoras

- [ ] UI para ver historial de notificaciones
- [ ] Contador de notificaciones no leídas en badge
- [ ] Sonidos personalizados por tipo de notificación
- [ ] Notificaciones agrupadas
- [ ] Preferencias de notificación por usuario
- [ ] Cloud Functions para envío desde backend
- [ ] Notificaciones programadas (recordatorios)

## Soporte

Para más información sobre Firebase Cloud Messaging:
- [Documentación Oficial FCM](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Messaging](https://firebase.flutter.dev/docs/messaging/overview)

---

**Fase 7 completada** - Sistema de Notificaciones Push implementado y funcional.
