# Refactorización móvil e integración con SmartQuote

Fecha: 05/10/2026. Alcance: aplicación Flutter; sin cambios en backend, frontend web, esquema de base de datos, historias del informe ni commits.

La auditoría original `AUDITORIA-MOVIL-PARIDAD-WEB.md` conserva el estado previo. Este documento registra la implementación posterior, no reemplaza las evidencias de investigación ni certifica todos los escenarios en producción.

## Arquitectura

`lib` se organiza por `identity_access`, `supply_requests`, `quotation_intake`, `evaluation_simulation` y `purchase_ordering`, con `domain`, `application`, `infrastructure` y `presentation` donde corresponde. `shared` contiene transporte, contratos y componentes genéricos; `app` compone las dependencias y coordina la navegación entre contextos.

Los puertos de repositorio se definen en dominio y sus adaptadores REST en infraestructura. La sesión depende de `SessionTransport`, no de Dio. El caso de uso de aprobación obtiene nuevamente el resultado vigente; la exportación obtiene nuevamente la orden aprobada. Los cálculos, la extracción por IA, la autorización definitiva, la persistencia y los eventos de auditoría permanecen en el servidor. No se recrean agregados del backend como otro motor de negocio en Dart.

Se sustituyeron los archivos de la implementación anterior de tres pantallas y token fijo; sus responsabilidades están cubiertas por los contextos nuevos. No se modificaron las carpetas personales del IDE.

## Trazabilidad respecto de las historias existentes

“Implementado” significa recorrido y contrato móvil incorporados y comprobados por las pruebas indicadas abajo; no equivale a validar cada escenario real de negocio con todos los datos y servicios externos.

| Historia | Implementación móvil / límite |
| --- | --- |
| US01 — Presencia digital | Acceso a la Landing Page pública desde el acceso. La Landing sigue siendo un producto separado; sus contenidos no se sustituyen por pantallas móviles. |
| US02 — Solicitud | Formulario con múltiples ítems/requisitos, cantidades decimales, operadores reales, obligatoriedad editable y validación. Detalle y adjuntos PDF/PNG/JPEG con versión vigente. |
| US03 — Seguimiento | Paginación/filtro, detalle, historial de estados y notificaciones propias con lectura y navegación. Compras realiza transiciones reales con motivo y versión. |
| US04 — Cotizaciones | Carga de PDF vinculada a la solicitud; datos de proveedor opcionales, revisión posterior de los extraídos y listado recuperado del servidor. |
| TS01 — Extracción REST | Procesamiento real mediante la API existente, consulta de resultado, evidencia y errores. No se introduce extracción ficticia en Flutter. |
| US05 — Verificación | Campos obligatorios pendientes, valores originales, confianza, página/texto de origen, corrección con motivo, historial, especificaciones con evidencia y asignación explícita de líneas a ítems. |
| US06 — Criterios | Filtros obligatorios por ID del requisito, pesos mediante deslizadores y ponderación técnica adicional. Suma de pesos de 100 %, umbrales y nuevas versiones. |
| US07 — Simulación | Ejecución en backend, ranking, exclusiones, aportes por criterio, importes originales/comparados e historial persistido. No recalcula el ranking en el dispositivo. |
| US08 — Orden | Solo el jefe aprueba una oferta elegible de una simulación vigente con condiciones/destino. Recuperación desde la solicitud, sin enlaces manuales. Respeta idempotencia del servidor y bloquea aprobación con criterios locales sin guardar. |
| SP01 — Investigación IA | Es evidencia de investigación, no una funcionalidad móvil. Este trabajo no acredita corpus, precisión ni conclusiones del spike. |
| US09 — Registro/acceso | Correo/contraseña, política de contraseña, configuración inicial y cuentas pendientes; el jefe consulta y aprueba registros. Sin inserción manual de JWT. |
| TS02 — JWT/permisos | JWT en memoria, cookie de renovación, renovación concurrente coordinada, salida y limpieza por cambio de cuenta. Los permisos proceden de la respuesta del servidor. |
| US10 — Carga múltiple | Selección de hasta 20 PDF, máximo 15 MB por archivo, dos trabajadores, progreso de envío real y actividad de IA. Resultado/reintento por documento, duplicados y aislamiento de archivos inválidos; se pueden consultar documentos ya listos mientras otros se procesan. |
| SP02 — Investigación asincronía | La cola local de dos trabajadores no acredita una investigación de colas durables. No se inventa `batchId` ni servidor de trabajos inexistente. |
| TS03 — Tipo de cambio | Revisión de implementación existente; visualización del `exchangeRate` que devuelve el backend y propagación de 503. Sin nueva integración, tasa manual o credenciales SUNAT en Flutter. |
| US13 — PDF corporativo | PDF real descargable/compartible desde una orden aprobada, datos corporativos proporcionados por el jefe, moneda original y trazabilidad. Fuentes locales para no descargar tipografía al exportar. |
| TS04 — JSON de órdenes | Consumo de detalle, recuperación por solicitud/simulación y recursos completos; errores 401/403/404/409 no se convierten todos en “sin orden”. |
| US14 — Auditoría | Historial de solicitudes y bitácora de solicitud/orden de solo lectura para el jefe. Inmutabilidad y registro de eventos dependen del backend. |
| US15 — Proveedor | Registrar entrega, evaluar plazo/calidad 1–5 y consultar promedios, cantidad, período e historial individual con orden, autor, fecha y observaciones. El backend actualizado incluye `evaluations` en la misma consulta de desempeño. |
| US16 — Métricas | Fechas, tiempo promedio, ahorro comparativo, tamaño de muestras y definiciones devueltas por servidor. Un dato ausente se muestra como no disponible, no como cero. |

## Roles y flujo de prueba

1. **Producción:** iniciar sesión → Nueva solicitud → completar fecha futura, ítems y requisitos → Registrar solicitud → abrir detalle → adjuntar sustento si corresponde → consultar historial/notificaciones.
2. **Analista:** iniciar sesión → abrir esa solicitud → Iniciar recepción de cotizaciones → Cotizaciones → seleccionar PDF vigentes → esperar carga/extracción → abrir cada cotización → resolver campos sustentados en el PDF → revisar asignación de líneas → confirmar.
3. **Analista o jefe:** con al menos dos cotizaciones verificadas, pasar a evaluación → Simulación → ajustar pesos/umbrales → Guardar y simular → consultar alternativas elegibles, excluidas e historial.
4. **Jefe:** abrir la misma solicitud → Orden → seleccionar simulación vigente y oferta elegible → Aprobar y emitir orden → completar condiciones y destino → Guardar → Exportar PDF corporativo → completar datos reales de la empresa compradora.
5. **Compras:** registrar entrega solo si ocurrió realmente → calificarla → consultar proveedor por RUC.
6. **Jefe:** consultar auditoría y métricas; revisar/aprobar cuentas pendientes desde el menú.

Cerrar sesión para cambiar de usuario. Cambiar de rol en una pantalla no concede permisos. Los UUID y las versiones se obtienen de los recursos de la API, no se rellenan manualmente.

### Datos de solicitud para una prueba sencilla

| Campo | Valor |
| --- | --- |
| Fecha requerida | Una fecha futura, compatible con las cotizaciones de la prueba |
| Prioridad | Normal |
| Descripción | Alimento balanceado de crecimiento para pollos de engorde |
| Cantidad / unidad | 1000 / kg |
| Requisito obligatorio | Proteína mínima · Mayor o igual que · 20 · % |
| Requisito opcional | Humedad máxima · Menor o igual que · 12 · % |

Las cotizaciones deben cubrir esas cantidades/unidades y especificaciones. No modificar campos ausentes ni fechas vencidas para fabricar una aprobación. Si el requisito está en el PDF y no fue extraído, añadir la especificación con su página y texto de evidencia.

## Revisión SUNAT: sin implementación nueva

El backend ya contiene `SunatExchangeRateProvider` en `EvaluationSimulation/Infrastructure/ExchangeRates`, detrás de `IExchangeRateProvider`. La simulación consulta la tasa de venta USD/PEN aplicable, conserva los importes originales y devuelve `sourceCurrency`, `targetCurrency`, `rate`, `rateType`, `publishedOn`, `source` y `retrievedAt`.

No existe ni se necesita un endpoint móvil separado de conversión: se invoca al ejecutar la simulación habitual. Si la fuente/tasa vigente falla, el backend devuelve un error y no se utiliza una tasa de reemplazo en Flutter. El móvil solo muestra la trazabilidad ya incluida en el resultado. No se consumió SUNAT ni se incurrió en llamadas OpenAI durante esta verificación.

## Verificación realizada

- Análisis estático sin incidencias y compilación Flutter Web de distribución.
- Compilación APK Android de depuración, ubicada en `build/app/outputs/flutter-apk/app-debug.apk`.
- 32 pruebas automatizadas aprobadas: dominio/formularios, contratos REST de los cinco contextos, cola de documentos, widgets, generación PDF e historial de US15 con límite de 500 caracteres. La prueba de API real se omite en una ejecución ordinaria.
- Prueba de transporte HTTP real contra un servidor efímero de prueba: JWT, multipart, cookie de renovación, 401 con un solo reintento, 422 sin repetición y cierre de sesión.
- Consulta de Swagger publicado en Azure: las rutas usadas por el cliente existen.
- Prueba de integración de lectura contra el backend Azure con las cuentas existentes de producción, analista y jefe: inicio de sesión, identidad, solicitudes y consultas adicionales según rol, seguida de cierre de sesión. Consulta solamente la primera solicitud disponible para cada cuenta; no constituye un recorrido completo de escritura/IA.
- En el contenedor local existente, producción pasó; el analista obtuvo **403 al consultar la orden por solicitud**. El código backend local actual y Azure permiten esa consulta para compras. Esto indica una diferencia con el contenedor en ejecución, posiblemente una imagen anterior; no se relajó la seguridad ni se ocultó el 403.

Pruebas ordinarias:

```powershell
flutter analyze
flutter test
```

La prueba contra un backend real se omite normalmente. Para activarla, sin guardar contraseña en archivos ni en Git:

```powershell
$env:SMARTQUOTE_SMOKE_API = 'https://smartquote-api-h8czffe5b4dtg6d7.chilecentral-01.azurewebsites.net'
$env:SMARTQUOTE_SMOKE_EMAIL = Read-Host 'Correo de una cuenta existente'
$taskPassword = Read-Host 'Contraseña' -AsSecureString
$env:SMARTQUOTE_SMOKE_PASSWORD = [System.Net.NetworkCredential]::new('', $taskPassword).Password
try {
    flutter test test/live_backend_test.dart
} finally {
    Remove-Item Env:SMARTQUOTE_SMOKE_PASSWORD
    Remove-Item Env:SMARTQUOTE_SMOKE_EMAIL
    Remove-Item Env:SMARTQUOTE_SMOKE_API
    Remove-Variable taskPassword
}
```

Repetir con cada rol. El test inicia/cierra una sesión real y lee recursos; no registra solicitudes, no carga PDF ni invoca extracción o simulación. Un fallo conserva el método/ruta y estado HTTP, no imprime credenciales.

## Límites y pendientes para no confundir implementación con certificación

- Realizar todavía el recorrido completo de escritura/IA y compartir PDF en un dispositivo Android físico con datos válidos. La compilación de la APK no acredita ese uso en dispositivo.
- US15: desplegar el backend actualizado para recibir `evaluations` en `GET /api/v1/suppliers/{taxIdentifier}/performance`. Con una API anterior se indica que el historial individual no está disponible. Las observaciones admiten hasta 500 caracteres, igual que en web y backend. El servidor conserva el rechazo 409 de una segunda evaluación de la misma orden.
- La API no permite descargar los adjuntos/archivos originales mediante los endpoints actuales: se muestran metadatos y evidencia extraída. No se presenta un visor remoto ficticio.
- El PDF se genera desde la orden persistida al exportar; el backend no guarda el archivo PDF corporativo ni los datos corporativos proporcionados en este cliente.
- La sesión nativa y la cola se mantienen en memoria; cerrar/reiniciar la aplicación exige ingresar nuevamente. Las solicitudes, cotizaciones, simulaciones y órdenes sí se recuperan de la API. No hay cola durable ni garantía de continuar extracción en segundo plano al cerrar Android.
- Con 20 PDF grandes aumenta la memoria de selección. La concurrencia de dos documentos limita llamadas de este cliente, no el consumo global del servidor.
- Las métricas conservan las definiciones del backend, incluida la selección de estado de órdenes; no se alteraron fórmulas ni población desde Dart.
- Distribución comercial: todavía debe configurarse identificador de aplicación y firma de release propios. Se conserva la configuración de firma de desarrollo original.
