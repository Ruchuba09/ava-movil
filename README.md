# App Móvil - Flutter

## Entorno de desarrollo

Flutter 3.44 o superior
Dart 3.12 o superior
DevTools 2.54.2

---

## Requisitos

- PC con **Windows / macOS / Linux**
- VS Code
- Dispositivo móvil:
  - Android (emulador AndroidStudio o físico)
  - iOS (emulador Simulator o físico, solo en macOS)

> ⚠️ Nota:  
> En emuladores no siempre es posible usar cámara o fotos.

---

## Extensiones VS Code

- Flutter
- Dart
- Error Lens

---

## Instalación

1. Instalar Flutter SDK  
   https://docs.flutter.dev/get-started/install

2. Verificar instalación Flutter

```bash
flutter doctor
```

3. Configurar dispositivo Android (físico)
   - Conectar el celular por USB
   - Activar Opciones de desarrollador
   - Activar Depuración USB
   - Aceptar permisos en el dispositivo

4. Verificar que el dispositivo esté disponible:

```bash
flutter devices
```

5. Instalar dependencias

```bash
flutter pub get
```

6. Ejecutar la app

```bash
flutter run
```

---

## Comandos

### Ejecutar la app

```bash
flutter run
```

### Publicar Android

Los APK/AAB de release no se firman con la clave debug. Guarda las propiedades
de firma en `android/key.properties` (archivo ignorado por Git) y conserva el
keystore fuera del repositorio:

```properties
storeFile=C:/ruta-segura/ava-upload-key.jks
storePassword=...
keyAlias=...
keyPassword=...
```

La ruta de `storeFile` puede ser absoluta o relativa a `android/`. Sin las
cuatro propiedades, las tareas `assembleRelease` y `bundleRelease` fallan en
lugar de producir una publicación con firma debug. No compartas ni subas el
keystore o sus contraseñas.

### Publicar Windows

Instala el Windows SDK (incluido con Visual Studio Build Tools) y un certificado
Authenticode de firma de código emitido por una autoridad de confianza.
Importa el certificado y su clave privada al almacén **Usuario actual > Personal**
de la cuenta que compila, y configura su huella SHA-1 como
`AVA_CODESIGN_THUMBPRINT`. Después, desde PowerShell ejecuta:

```powershell
.\windows\build_signed_release.ps1
```

El script compila en release, firma el ejecutable principal con SHA-256 y una
marca de tiempo, y verifica la firma. Requiere `signtool.exe` en `PATH`. No
incluyas certificados ni claves privadas en el repositorio. La firma identifica
al editor y mejora la confianza de distribución, pero no garantiza por sí sola
que SmartScreen elimine todos los avisos; ante una detección concreta, envía a
Microsoft el archivo exacto y el nombre de detección para su análisis.

### Modo debug

Mientras la app está corriendo:

- **`r`** → Hot Reload (mantiene estado)
- **`R`** → Hot Restart (reinicia la app)

### Dependencias

Instalar dependencias:

```bash
flutter pub get
```

Actualizar dependencias:

```bash
flutter pub upgrade
```

### Limpieza

```bash
flutter clean
```

---

## Estructura del repositorio

### Carpetas principales

- `android/` → Configuración específica de Android
- `ios/` → Configuración específica de iOS
- `assets/` → Imágenes, logos, tipografías y recursos estáticos
- `lib/` → Código principal de la aplicación

#### Dentro de `lib/`

- `constants/` → Constantes globales
- `controller/` → Lógica de negocio (consultas, acciones CRUD, etc.)
- `database/` → Configuración y creación de base de datos
- `dev/` → Funciones/utilidades para desarrollo
- `models/` → Modelos de datos
- `styles/` → Estilos (botones, inputs, modales, etc.)
- `utils/` → Funciones auxiliares
- `view/` → Vistas (UI de la aplicación)
- `main.dart` → Entrada de la aplicación
- `routes.dart` → Definición de rutas/navegación

### Archivos de configuración

- `pubspec.yaml` → Dependencias y configuración del proyecto
- `pubspec.lock` → Versiones exactas de dependencias

### Notas

- La mayor parte del desarrollo es dentro de `lib/`
- Separar lógica (`controller`) de UI (`view`)
- Definir constantes reutilizables en `constants/` (evitar valores “hardcodeados”)
- Recomendable tener una función para **eliminar la base de datos en desarrollo**. Alternativas:
  - Desinstalar e instalar la app
  - Manejar versionamiento de base de datos (`onUpgrade`)
- Evitar duplicar lógica → usar `utils/` o funciones reutilizables

### Base local y sincronización

- SQLite es la persistencia local de la app; la web se conectará al servidor mediante la API, no al archivo SQLite del dispositivo.
- La tabla `sincronizacion` funciona como cola de salida: las escrituras locales y su entrada de sincronización deben guardarse dentro de la misma transacción.
- Los cambios de esquema requieren incrementar `AvaMovilDatabase.version` y agregar una migración aditiva en `onUpgrade`; no borrar la base de datos de usuarios para aplicar cambios.
- `SyncQueue` registra cambios y reintentos; el servicio que los envíe a la API y resuelva conflictos se implementará cuando se defina el contrato.
- No incluir contraseñas, tokens ni otros secretos en las cargas de la cola.
- La URL base se inyecta al ejecutar/compilar, por ejemplo `flutter run --dart-define=API_BASE_URL=https://api.example.com/api/`. En producción solo se acepta HTTPS.
- La app móvil es un cliente público: no guardar claves compartidas del servidor ni secretos de API dentro de ella. La autenticación debe entregar credenciales/tokens de usuario según el contrato del backend.

---

## Dependencias

### Red

- `http` → Realizar peticiones HTTP simples
- `dio` → Cliente HTTP avanzado (interceptores, descargas, etc.)

### Base de datos / almacenamiento

- `sqflite` → Base de datos SQLite local
- `path` → Manejo de rutas de archivos
- `path_provider` → Obtener rutas del sistema (documents, temp, etc.)
- `shared_preferences` → Almacenamiento clave-valor simple

### Manejo de estado

- `provider` → Gestión de estado de la aplicación

### Cámara / imágenes

- `camera` → Acceso a cámara del dispositivo
- `image_picker` → Seleccionar imágenes desde galería o cámara
- `flutter_image_compress` → Comprimir imágenes
- `cached_network_image` → Cargar imágenes desde internet con caché

### PDFs

- `pdf` → Crear archivos PDF
- `pdfx` → Visualizar PDFs
- `html_to_pdf` → Convertir HTML a PDF
- `syncfusion_flutter_pdfviewer` → Visor de PDF avanzado

### Firma

- `syncfusion_flutter_signaturepad` → Captura de firmas digitales

### Seguridad / utilidades

- `crypto` → Funciones criptográficas (hash)
- `bcrypt` → Encriptación de contraseñas
- `uuid` → Generación de identificadores únicos

### Conectividad / dispositivo

- `connectivity_plus` → Detectar conexión a internet
- `permission_handler` → Manejo de permisos del sistema
- `geolocator` → Obtener ubicación GPS
- `flutter_udid` → Obtener identificador único del dispositivo
- `package_info_plus` → Información de la app (versión, build)

### Notificaciones / background

- `flutter_local_notifications` → Notificaciones locales
- `flutter_background_service` → Ejecutar tareas en segundo plano

### Interacción / UX

- `flutter_keyboard_visibility` → Detectar teclado visible
- `idle_detector_wrapper` → Detectar inactividad del usuario
- `responsive_sizer` → Adaptar UI a distintos tamaños de pantalla

### UI / diseño

- `flutter_svg` → Soporte para imágenes SVG
- `font_awesome_flutter` → Íconos FontAwesome
- `line_icons` → Íconos Line
- `google_nav_bar` → Barra de navegación estilo Google
- `flutter_floating_bottom_bar` → Barra inferior flotante
- `smooth_page_indicator` → Indicadores de páginas
- `carousel_slider` → Carruseles de imágenes
- `gap` → Espaciado entre widgets

### Componentes UI

- `rounded_loading_button_plus` → Botón con estado de carga
- `drop_down_list` → Dropdown personalizado
- `super_cupertino_navigation_bar` → Navbar estilo iOS
- `cupertino_modal_sheet` → Modales estilo iOS

### Animaciones / feedback

- `animate_do` → Animaciones predefinidas
- `fluttertoast` → Mostrar mensajes tipo toast
- `toastification` → Notificaciones visuales avanzadas
- `overlay_support` → Overlays (notificaciones en pantalla)
- `transparent_image` → Imagen placeholder transparente

### Otros

- `url_launcher` → Abrir enlaces externos
- `validate_rut` → Validar RUT chileno
- `intl` → Formato de fechas, números, etc.
- `flutter_cache_manager` → Manejo de caché de archivos
- `mobile_scanner` → Escaneo de códigos QR
