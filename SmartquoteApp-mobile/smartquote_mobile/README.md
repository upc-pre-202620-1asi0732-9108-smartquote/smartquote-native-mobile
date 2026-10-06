# SmartQuote Mobile

Cliente Flutter del flujo de compras avícolas: solicitudes, cotizaciones con IA, criterios/simulación, órdenes, PDF, entregas, proveedores y métricas. Acceso real mediante IAM del backend, con permisos de producción, analista y jefe.

## Ejecutar con Azure

Abrir una terminal PowerShell en esta carpeta (donde está `pubspec.yaml`):

```powershell
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=https://smartquote-api-h8czffe5b4dtg6d7.chilecentral-01.azurewebsites.net
```

Iniciar sesión con una cuenta existente del backend. No se pegan tokens. Las cuentas nuevas requieren aprobación del jefe, salvo la configuración inicial.

**Puerto:** Azure permite actualmente `http://localhost:5173`, no `5174` (preflight comprobado). Si 5173 está ocupado por la web, detener esa ejecución o pedir al administrador que agregue `http://localhost:5174` como un valor adicional de `Cors__AllowedOrigins__N` y reinicie el backend; después usar `--web-port 5174`. No reemplazar los orígenes anteriores. Android nativo no necesita CORS de navegador.

Si `flutter` no se reconoce, agregar `E:\Documentos\flutter\bin` al PATH o sustituir `flutter` por `& 'E:\Documentos\flutter\bin\flutter.bat'` en los comandos.

## Android

Con emulador o dispositivo conectado:

```powershell
flutter devices
flutter run -d ID_DEL_DISPOSITIVO --dart-define=API_BASE_URL=https://smartquote-api-h8czffe5b4dtg6d7.chilecentral-01.azurewebsites.net
```

Sustituir `ID_DEL_DISPOSITIVO` por el identificador de `flutter devices`. Para generar una APK de prueba:

```powershell
$env:GRADLE_USER_HOME = Join-Path (Get-Location) 'build\gradle-verification'
flutter build apk --debug --dart-define=API_BASE_URL=https://smartquote-api-h8czffe5b4dtg6d7.chilecentral-01.azurewebsites.net
```

Salida: `build/app/outputs/flutter-apk/app-debug.apk`. La caché Gradle separada evita la caché global dañada encontrada en este equipo; `kotlin.incremental=false` evita conflictos entre el proyecto en E: y paquetes en C:. No cambia permisos ni lógica de negocio. Para distribución definitiva faltan firma e identificador propios.

## Backend local / contingencia

Desde otra terminal, con la configuración privada del backend ya preparada:

```powershell
Set-Location E:\smartquote-web-services
docker compose up -d --build api
```

No eliminar volúmenes de PostgreSQL. La recompilación importa: el contenedor local existente devolvió un 403 al analista en la consulta de órdenes, distinto del código actual y Azure.

En esta carpeta Flutter:

```powershell
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:8080
```

En Android emulado usar `http://10.0.2.2:8080`; en un teléfono físico, la IP LAN del equipo y acceso de red al puerto 8080. HTTP está habilitado únicamente para depuración; builds de distribución requieren HTTPS. La IA real requiere internet y OpenAI configurado en el backend. `AI__Provider=Stub` es una extracción de prueba explícita, no evidencia de lectura real del PDF.

## Pruebas y guía del flujo

```powershell
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://smartquote-api-h8czffe5b4dtg6d7.chilecentral-01.azurewebsites.net
```

[Guía por rol, trazabilidad de historias, pruebas contra API real y pendientes](docs/REFACTORIZACION-MOVIL.md).

SUNAT ya se utiliza dentro de la simulación del backend. Flutter muestra la tasa/procedencia recibida; no consulta SUNAT directamente ni incluye sus credenciales.

No almacenar contraseñas, claves OpenAI/SUNAT o claves JWT en `--dart-define`. `API_BASE_URL` y, opcionalmente, `LANDING_PAGE_URL`, `PURCHASER_NAME`, `PURCHASER_RUC`, `PURCHASER_ADDRESS` son configuración pública. Los datos corporativos también se pueden introducir al exportar; no se completan con datos ficticios.
