# 💰 App de Auditoría y Ahorro Financiero Familiar en Tiempo Real

Aplicación móvil y multiplataforma en **Flutter** para auditar y controlar en tiempo real los ingresos y gastos familiares compartidos entre múltiples dispositivos, con adjuntos fotográficos de comprobantes en **Firebase Storage** y persistencia offline en **Cloud Firestore**.

---

## ⚡ Comandos para Instalar y Ejecutar

### 1. Instalar las dependencias del proyecto
Abre tu terminal en la raíz del proyecto y ejecuta:

```bash
flutter pub get
```

### 2. Configurar Firebase con FlutterFire CLI
Si aún no tienes la herramienta de Firebase instalada:

```bash
# Activar FlutterFire CLI globalmente
dart pub global activate flutterfire_cli

# Iniciar sesión en Firebase (si no lo has hecho)
firebase login

# Vincular automáticamente tu proyecto de Firebase
flutterfire configure
```
> Esto actualizará automáticamente `lib/firebase_options.dart` y generará la configuración para Android, iOS y Web.

### 3. Ejecutar la aplicación
```bash
# Ejecutar en el emulador o dispositivo conectado
flutter run
```

---

## 🔒 Reglas de Seguridad de Firebase

### 1. Cloud Firestore (`firestore.rules`)
Ve a **Firebase Console > Firestore Database > Reglas** y pega lo siguiente:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /financial_records/{document=**} {
      // Permite lectura y escritura de los registros compartidos
      allow read, write: if true; 
    }
  }
}
```

### 2. Firebase Storage (`storage.rules`)
Ve a **Firebase Console > Storage > Reglas** y pega lo siguiente:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /receipts/{allPaths=**} {
      // Permite lectura y subida de comprobantes
      allow read, write: if true;
    }
  }
}
```

---

## 📱 Permisos del Sistema (Cámara y Galería)

### Android (`android/app/src/main/AndroidManifest.xml`)
Asegúrate de tener estos permisos dentro de `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### iOS (`ios/Runner/Info.plist`)
Agrega las claves de descripción para la cámara y la galería:

```xml
<key>NSCameraUsageDescription</key>
<string>Necesitamos acceso a la cámara para capturar fotos de recibos y facturas.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Necesitamos acceso a la galería para seleccionar comprobantes de pago.</string>
```

---

## 🌟 Características Implementadas

| Requisito | Implementación |
| :--- | :--- |
| **Lista en Tiempo Real** | `StreamBuilder` con consulta optimizada `.limit(15)` e incremento dinámico al scrollear. |
| **Caché de Imágenes** | `cached_network_image` con placeholders de carga y tratamiento de errores. |
| **Compresión de Fotos** | `flutter_image_compress` comprime los comprobantes a JPEG 75% antes de subirlos, ahorrando más del 70% de espacio y datos. |
| **Persistencia Local** | `FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true)` para consultar registros sin conexión. |
| **Auditoría Financiera** | Balance total neto, total de ingresos, total de egresos, filtrado por categorías y detalles del responsable. |
