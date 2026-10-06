# Auditoría de la aplicación móvil: integración y paridad con SmartQuote Web

Fecha: 05/10/2026. Alcance: análisis; no se implementan cambios.

## 1. Dictamen y alcance de la revisión

La aplicación Flutter de esta carpeta **no tiene actualmente paridad funcional con la aplicación web y no permite completar el recorrido solicitud → cotizaciones → simulación → orden de compra**. Tiene una base de solicitudes y notificaciones, pero también presenta bloqueos en el consumo de la API existente. No basta con agregar las vistas del analista y del jefe: primero deben corregirse la autenticación, los contratos del formulario y el seguimiento de solicitudes.

Fuentes contrastadas:

| Referencia usada en este documento | Ubicación |
| --- | --- |
| `M:` — Proyecto Flutter real | `E:/smartquote-native-mobile/SmartquoteApp-mobile/smartquote_mobile/` |
| `W:` — Aplicación web | `E:/smartquote-frontend-web/` |
| `B:` — Backend | `E:/smartquote-web-services/` |
| `R:` — Informe y criterios de aceptación | `E:/smartquote-report/README.md`, sección 3.2, líneas 1086–1229 |

Se encontró un único `pubspec.yaml` dentro de la carpeta móvil. Su `lib` contiene 17 archivos Dart, de los cuales dos están vacíos, y tres pantallas: listado de solicitudes, nueva solicitud y notificaciones. No se encontró una segunda implementación de autenticación o de compras dentro de este proyecto.

El backend contiene **40 operaciones HTTP en sus controladores de negocio**; el repositorio móvil implementa llamadas a **cuatro**. Esta comparación mide superficie de integración, no porcentaje de cumplimiento de historias. Las cuatro rutas existen: no es correcto afirmar que las rutas de notificaciones estén mal escritas. El problema es la autenticación, la información que se envía o muestra y la ausencia del resto del recorrido.

La revisión comprende todos los archivos Dart de `lib`, la prueba existente, configuración Android, repositorios HTTP y flujos relevantes de Vue, controladores y recursos de la API, y reglas de aplicación/dominio necesarias para contrastar los escenarios. No es una auditoría exhaustiva adicional de todo el backend.

### Límites de las conclusiones

- Los hallazgos describen **el código local actual**. No se ha demostrado que coincida con un APK previo o con la versión desplegada en Azure.
- No se crearon usuarios, solicitudes, cotizaciones ni órdenes; tampoco se consumieron OpenAI o SUNAT para esta revisión.
- No se ejecutó una demostración completa en dispositivo. La existencia de un endpoint o de una validación en código no certifica su ejecución exitosa en producción.
- Se ejecutó `flutter analyze --no-pub`: terminó con código 1 y 384 incidencias, principalmente por paquetes no resueltos, incluidos Flutter, Dio y Provider. No existe una resolución local utilizable de paquetes en esta copia. **Ese número no equivale a 384 defectos independientes del código**. No se restauraron dependencias ni se compiló un APK.
- El SDK instalado es Flutter 3.47.4 / Dart 3.13.3; satisface la restricción Dart `^3.13.3` declarada en este proyecto. No hay fundamento para recomendar cambiar esa versión por este resultado del análisis.
- Existe además un defecto independiente de la restauración: `M:test/widget_test.dart:16` instancia `MyApp`, pero `M:lib/main.dart:19` define `SmartQuoteApp`. La prueba sigue siendo la plantilla de contador, no una prueba de SmartQuote.

## 2. Paridad por rol: qué debería poder hacer cada usuario

Paridad no significa dar permisos de jefe a todos los usuarios. Significa ofrecer en móvil las mismas operaciones autorizadas por el backend, manteniendo su control de acceso.

| Rol real de la API | Capacidades que debe ofrecer móvil | Situación actual |
| --- | --- | --- |
| `ProductionSpecialist` | Registrar solicitudes propias, adjuntar sustento, consultar detalle/estado/historial y notificaciones propias. | Hay listado, formulario y notificaciones; no hay sesión real, adjuntos ni detalle/historial. |
| `PurchaseAnalyst` | Consultar solicitudes, gestionar estados autorizados, cargar/procesar/verificar cotizaciones, configurar criterios, simular, consultar órdenes y registrar entregas/evaluaciones de proveedores. | No existen estos recorridos de compras. |
| `PurchaseManager` | Operaciones de compras, aprobar/generar órdenes, exportarlas, consultar auditoría y métricas, aprobar registros de cuentas pendientes. | No existe experiencia de jefe de compras. |
| Visitante | Acceder a información pública y a los destinos de contacto/acceso. | US01 corresponde a la Landing Page; no exige replicarla como otro módulo de compras móvil. |

La autorización actual se establece en `B:src/SmartQuote.Shared/Application/Security/SmartQuoteRoles.cs:5`. Crear solicitudes y adjuntar sustento exige `ProductionSpecialist`; aprobar/generar órdenes exige `PurchaseManager`. Notificaciones son exclusivas de producción. Ocultar botones en Flutter es necesario para usabilidad, pero **no reemplaza la autorización del servidor**.

La propia web tiene una restricción de presentación adicional: muestra la pestaña de órdenes solo al jefe, aunque la API permite consultar órdenes, registrar entregas y calificarlas también al analista. Para cumplir US15, móvil no debe copiar esa limitación.

## 3. Hallazgos concretos de integración

### M01 — Bloqueo de autenticación y ausencia de IAM

Prioridad: **P0 — bloqueante**. Historias: **US09, TS02**; afecta todo el recorrido privado.

Evidencia: `M:lib/core/network/auth_interceptor.dart:12` usa literalmente `ACÁ VA TU TOKE`. `M:lib/main.dart:43` abre directamente el listado. No existen llamadas de inicio de sesión, registro, renovación, cierre de sesión o consulta del usuario.

Consecuencia: contra la API protegida actual ese texto no es un JWT válido. No hay un flujo que obtenga la identidad y los permisos del usuario. Pegar otro token manualmente solo ocultaría el defecto y no cumpliría US09.

Cambio necesario:

1. Implementar IAM móvil consumiendo el contrato existente: correo y contraseña para iniciar sesión; `accessToken`, `expiresIn` y `user.roles` para construir la sesión.
2. Agregar registro con política de contraseña y mensajes por campo. Mostrar correctamente el estado `Pending`: las cuentas nuevas, salvo la configuración inicial, requieren aprobación antes de iniciar sesión.
3. Ofrecer al jefe la consulta y aprobación de registros pendientes, como ya hace la web. No permitir que seleccionar una vista o un rol en el cliente conceda privilegios.
4. Proteger navegación y acciones por los roles reales; limpiar datos de los módulos al salir o cambiar de cuenta.
5. Implementar renovación y cierre de sesión, distinguiendo sesión vencida de permisos insuficientes.

Detalle importante: `B:src/SmartQuote.Modules.IdentityAccess/Interfaces/REST/AuthController.cs:93` obtiene la renovación desde la cookie `smartquote_refresh`. **El JSON del login no devuelve un `refreshToken`**. En Android, el adaptador HTTP debe conservar y reenviar esa cookie, incluida su rotación; si se persiste, debe protegerse mediante almacenamiento seguro de plataforma. En Flutter Web debe usarse el mecanismo de credenciales del navegador, no intentar leer una cookie `HttpOnly`. No basta con guardar el JWT en `shared_preferences`.

La renovación debe coordinarse para no ejecutar múltiples renovaciones concurrentes ni entrar en bucles ante un 401. No deben incluirse en Flutter claves de firma JWT, claves de OpenAI ni credenciales SUNAT.

### M02 — Configuración de red y errores insuficientes

Prioridad: **P0** para configuración y errores; **P1** para procesamiento prolongado. Historias: **US02–US10, US13–US16, TS01–TS04** según operación.

Evidencia: `M:lib/core/network/dio_client.dart:7` fija el servidor Azure y establece tiempos de espera de 10 segundos. `M:lib/data/repositories_impl/smartquote_repository_impl.dart:41` convierte cualquier error de lectura en `false`; `M:lib/presentation/viewmodels/notification_viewmodel.dart:17` solo imprime el error.

Cambio necesario:

- Configurar la URL mediante `API_BASE_URL` / `--dart-define`, normalizando `/api/v1` una sola vez. Actualmente el comando de demostración con `--dart-define` **no cambia** la dirección del cliente, porque este código no lee ese valor.
- Separar error de conexión, 401, 403, validación 400/422, conflicto 409, tamaño 413, formato 415, límite 429 y servicio externo 503. Consumir `ProblemDetails.detail`, `errors`, `code` y conservar `traceId` para diagnóstico sin exponer secretos.
- Mostrar carga, error y lista vacía como estados diferentes; ofrecer actualización/reintento explícito.
- Definir tiempos por operación: extraer PDF no tiene la misma duración que consultar un listado. La web actualmente admite hasta 180 segundos en su cliente; copiar 10 segundos en el futuro recorrido de IA generaría fallos prematuros.
- No reintentar automáticamente un POST de creación de solicitud tras un tiempo de espera ambiguo: la operación pudo persistirse. Usar reintentos controlados y las garantías de idempotencia concretas de cada endpoint.
- Comprobar el permiso de red en Android: está declarado en el manifiesto de `debug`, pero no en `M:android/app/src/main/AndroidManifest.xml`. Debe quedar incluido en el manifiesto combinado de `release`.

Para contingencia, Android emulado no usa el `localhost` de Windows como su propio servidor; se necesita una dirección accesible desde el emulador o el dispositivo. Los permisos HTTP de desarrollo deben limitarse a esa configuración, sin deshabilitar validación TLS para Azure. CORS afecta Flutter Web en navegador, no es la explicación general de las peticiones de una app Android nativa.

### M03 — El formulario no respeta el contrato de solicitudes

Prioridad: **P0**. Historia: **US02**, con efecto posterior en **US06/US07**.

Evidencias:

- `M:lib/presentation/screens/new_request_screen.dart:101`: prioridades `Normal`, `Alta`, `Urgente`.
- `M:lib/presentation/screens/new_request_screen.dart:163`: operadores `Igual a`, `Mayor a`, `Menor a`.
- `M:lib/presentation/viewmodels/new_request_viewmodel.dart:46`: se envían esas etiquetas directamente, sin traducción a valores del contrato.
- `B:src/SmartQuote.Modules.SupplyRequests/Interfaces/REST/Transform/EnumResourceParser.cs:9`: el servidor analiza nombres reales de enumeraciones, no las etiquetas de la pantalla.

| Etiqueta visible recomendada | Valor JSON requerido |
| --- | --- |
| Normal | `Normal` |
| Alta | `High` |
| Emergencia | `Emergency` |
| Igual a | `Equals` |
| Mayor o igual que | `GreaterThanOrEqual` |
| Menor o igual que | `LessThanOrEqual` |
| Contiene | `Contains` |

No es correcto simplemente traducir “Mayor a” como `GreaterThanOrEqual`: son operadores distintos. La pantalla debe comunicar la condición inclusiva que la API realmente admite. Con las opciones actuales, **todos los operadores seleccionables son incompatibles**; aun con un token correcto, la API actual puede rechazar el formulario con 422.

Otros cambios necesarios:

- Cantidad: hoy `int.tryParse(...) ?? 1` convierte silenciosamente `2.5` o un texto inválido en `1` (`new_request_screen.dart:136`). La API espera `decimal`; aceptar cantidades decimales positivas sin sustituir entradas inválidas.
- Validar descripción sin espacios vacíos, unidad, nombre y valor de cada requisito; al menos un requisito obligatorio por ítem y nombres de requisitos no duplicados. Para comparaciones numéricas, validar valor numérico coherente.
- Hacer funcional la selección obligatorio/opcional: `new_request_screen.dart:171` tiene un callback vacío y todos los requisitos quedan obligatorios.
- Permitir retirar ítems/requisitos agregados por error, manteniendo los mínimos del dominio.
- Mantener el borrador ante un error, sin desmontar el formulario y perder lo escrito; inicializar un borrador nuevo por creación, en vez de conservar el formulario compartido entre solicitudes.
- Usar fecha vigente: la antigua muestra `25/09/2026` ya está en el pasado al momento de esta auditoría. Las demostraciones deben escoger una fecha futura.

### M04 — La solicitud creada no se puede seguir ni administrar

Prioridad: **P1**, inmediatamente después de P0. Historias: **US02, US03** y prerrequisito operativo de **US04–US08**.

Evidencia: el repositorio devuelve solo `bool` al crear (`M:lib/data/repositories_impl/smartquote_repository_impl.dart:53`), descarta el recurso 201; `M:lib/data/models/purchase_request_model.dart:12` conserva solo ID, fecha requerida, prioridad y estado. “Abrir” tiene `onPressed: () {}` (`M:lib/presentation/screens/request_list_screen.dart:97`). El listado consulta siempre página 1 de 20 elementos.

Cambio necesario:

- Devolver una solicitud tipada con su `requestId`, `version`, solicitante y estado; navegar a su detalle y actualizar el listado.
- Incorporar modelos para ítems, requisitos, adjuntos, `updatedAt`, `nextResponsibleArea` e historial. No confundir fecha requerida con última actualización.
- Consumir detalle e historial y recuperar información desde el servidor cada vez que corresponda; filtrar/paginar con los metadatos reales del listado.
- Incorporar sustento como `multipart/form-data`, con `file` y `expectedVersion`; mostrar nombre, tipo, autor y fecha devueltos por la API. Conservar la solicitud creada si falla solo el adjunto, y permitir reintentarlo.
- Para compras, gestionar las transiciones permitidas con motivo y versión: `Submitted → UnderReview → QuotationCollection → Evaluation`. Respetar las alternativas de rechazo/cancelación existentes. No saltar estados ni dar estas acciones a producción.
- No editar ni establecer `Approved`/`Ordered` para fabricar una aprobación: la emisión de la orden y su actualización del ciclo de vida se realizan con el servicio de órdenes.
- Frente a un 409, recargar la entidad y solicitar confirmación con la información vigente; no repetir con una versión adivinada.

La UI web agrupa el inicio de revisión y recepción de cotizaciones en una acción, pero realiza las transiciones reales en la API. Puede reproducirse esa simplificación en móvil sin eliminar trazabilidad.

### M05 — Notificaciones incompletas y fallos silenciosos

Prioridad: **P1**. Historia: **US03**.

Las rutas y los nombres JSON `notificationId` / `purchaseRequestId` son correctos. Sin embargo, falta modelar `readAt`, no se muestra `message`, no se abre el detalle y los errores se ocultan. El botón de lectura aparece incluso para notificaciones ya leídas.

Cambio necesario: incorporar `readAt`, mostrar el mensaje/motivo, distinguir leída/no leída, permitir navegar a la solicitud, actualizar después del 204 y propagar los errores. El filtro `unreadOnly` ya existe; usarlo si se ofrece esa opción. Restringir esta vista al especialista, como exige el backend.

No hace falta inventar notificaciones push para cumplir esta historia: la consulta y actualización de las notificaciones existentes cubren ese mecanismo. Tampoco debe prometerse actualización en tiempo real sin implementar un mecanismo real.

### M06 — Gestión de cotizaciones y extracción ausentes

Prioridad: **P1**. Historias: **US04, US10, TS01**; usa el resultado de **SP01/SP02**.

No existen pantalla, entidades ni repositorio móviles para cotizaciones.

Cambio necesario:

- Desde una solicitud en recepción de cotizaciones, seleccionar uno o varios PDF, cargar mediante formulario multipart y conservar `quotationId` por documento.
- Validar extensión/tamaño antes de enviar, sin reemplazar la validación del servidor. La API limita cada cotización a 15 MB; su endpoint de lote admite 1–20 archivos.
- Admitir la extracción de datos del proveedor cuando no se conocen inicialmente; mostrar los datos extraídos para revisión. Los tres metadatos de proveedor del endpoint son opcionales. No reutilizar un mismo proveedor manual para documentos de diferentes proveedores.
- Procesar después de cargar y consultar resultados. Mostrar proveedor, moneda, vigencia, partidas, cantidad, unidad, precio, entrega, especificaciones, confianza y evidencia de origen.
- Mostrar resultado individual: pendiente de carga, cargando, procesando, requiere revisión, verificada, rechazada/error y duplicada cuando la respuesta identifique un documento existente. No indicar “verificada” por el simple éxito del procesamiento.
- Conservar documentos válidos cuando otro falla y permitir reintentos por archivo. Un duplicado devuelve la cotización existente, no siempre un 201 nuevo.
- Usar concurrencia limitada, inicialmente no superior a la de la web (dos trabajadores), ajustable tras medir el backend. Ese límite del cliente no garantiza un límite global entre varios usuarios.
- Usar progreso de envío para la carga y un indicador de actividad para IA. No mostrar un porcentaje ni un tiempo restante de extracción como si fueran medidos: el endpoint actual no entrega ese progreso.

**Diferencia importante de contratos:** `/quotations/batch` registra documentos y devuelve 207 con resultado por archivo; no ejecuta por sí mismo toda la extracción, no devuelve un `batchId` y no crea una cola persistente de trabajos. La web actual logra carga múltiple llamando a los endpoints individuales y luego a `process` con dos trabajadores. Ambas estrategias pueden utilizarse; después deben consultarse las cotizaciones/resultados reales. Una cola durable solo se justificaría tras SP02, no es un requisito para igualar el recorrido actual.

### M07 — Verificación y corrección de cotizaciones ausentes

Prioridad: **P1**. Historia: **US05** y soporte de **US07**.

Cambio necesario: revisión de campos no resueltos/obligatorios, consulta de confianza y texto/página de origen, corrección con valor y motivo, historial de correcciones, asignación de líneas a ítems y confirmación explícita del analista.

La confirmación debe enviar `lineMappings[{lineId, requestedItemId}]` y `expectedVersion`; los IDs deben proceder de los recursos actuales. No generar UUID nuevos, ni usar IDs de otro documento. Después de cada corrección o especificación adicional se debe recuperar la nueva versión.

Si falta una especificación que sí existe en el PDF, utilizar el endpoint de especificaciones con nombre, valor, unidad, página, referencia al texto y motivo. Puede proponerse la asignación si solo hay un ítem o hay una coincidencia inequívoca, pero debe permitir confirmación/corrección humana.

No llenar campos ausentes con valores de demostración ni aprobar automáticamente información obligatoria no resuelta. La UI debe explicar el 422 y los pendientes; la autoridad para verificar y para admitir una cotización en evaluación sigue siendo el backend.

### M08 — Criterios, simulación, tipo de cambio e historial ausentes

Prioridad: **P1**. Historias: **US06, US07, TS03**.

Cambio necesario:

- Crear/consultar la configuración actual por solicitud y crear una nueva versión cuando cambie; conservar los resultados anteriores.
- Ofrecer ajuste de ponderaciones con controles amigables y suma visible de 100 %. No limitar la configuración al control de precio/plazo si se pretende cumplir literalmente el criterio de ponderación técnica de US06.
- Conservar el enlace de criterios técnicos a `requirementId` mediante `targetField`, usando el contrato de categoría/modo/operador/valor/unidad de la API.
- Mantener requisitos obligatorios como filtros excluyentes aunque se configure precio bajo; no eliminarlos para acelerar la demostración.
- Ejecutar con dos o más cotizaciones verificadas y la solicitud en `Evaluation`; comunicar cuáles faltan o no son aptas en vez de mostrar un fallo genérico.
- Mostrar ranking, puntuación, aportes por criterio, exclusiones, recomendación, `criteriaVersion`, fecha e `isCurrent`. La IA extrae información; el cálculo comparativo actual lo ejecuta el motor del backend, no un prompt del cliente.
- Recuperar historial con `/purchase-requests/{requestId}/simulations`; seleccionar un resultado y consultar su detalle. No depender de pegar un enlace o guardar manualmente un `simulationRunId`.
- Para USD, usar `comparisonTotal`/`comparisonCurrency` para comparar y conservar `originalTotal`/`originalCurrency`. Mostrar tasa, tipo de tasa, fuente, fecha de publicación y hora de consulta de `exchangeRate`.
- Si SUNAT falla o no hay tasa vigente, presentar el 503 y no reemplazarlo por una tasa local o antigua. SUNAT se consume exclusivamente desde el backend.
- Ante resultados obsoletos, impedir aprobación desde la UI y pedir nueva simulación; el servidor vuelve a validar vigencia e idempotencia.

### M09 — Órdenes, recuperación y exportación ausentes

Prioridad: **P1** para emisión/consulta; **P2** para exportación. Historias: **US08, US13, TS04**.

Cambio necesario: selección de una alternativa elegible desde una simulación vigente, destino y condiciones de entrega, aprobación explícita del jefe, emisión y visualización de la orden persistida con todos sus datos. Aceptar 201 al crear y 200 al recuperar la misma aprobación.

Recuperar la orden por solicitud o por simulación, además del endpoint por ID; no guardar toda la decisión solo en memoria ni exigir una URL especial al usuario. La aprobación ya avanza el ciclo de la solicitud en el backend. Al reabrir, consumir la orden guardada, no reconstruirla desde cotizaciones que puedan haber cambiado.

Para US13 no se puede portar `window.print()` a Android. Debe existir una exportación PDF real y descargable/compartible, construida desde la orden aprobada persistida y con datos corporativos. Puede hacerse con un adaptador nativo o centralizarse en backend para un documento único entre clientes. **No hay actualmente un endpoint PDF en los controladores revisados**; esa segunda opción sí requiere una ampliación acotada del backend dentro de US13. No es una historia nueva ni un nuevo bounded context.

TS04 es responsabilidad de la API y sus consumidores externos: móvil debe deserializar el contrato JSON existente y gestionar 401/403/404, no implementar otro servicio de integración ni fabricar una orden local.

### M10 — Entregas y desempeño de proveedores ausentes

Prioridad: **P2**, después de órdenes. Historia: **US15**.

Cambio necesario: permitir al personal de compras consultar una orden emitida, registrar su entrega real, calificar plazo/calidad dentro de la escala 1–5 y enviar observaciones. La API registra autor/fecha; exige `Delivered` y rechaza una segunda evaluación.

No marcar “entregada” automáticamente al emitir una orden solo para habilitar la calificación. Consultar desempeño por RUC, con promedio, número de evaluaciones y período; representar cero muestras como sin información, no como mala calificación.

El historial individual de evaluaciones no está expuesto actualmente por el recurso de desempeño; completar ese punto requiere también el ajuste compartido descrito en la sección 6.

### M11 — Auditoría y métricas ausentes

Prioridad: **P2**. Historias: **US14, US16**.

Cambio necesario: vistas del jefe para bitácora de solicitud/orden y métricas por `from`/`to`. Mostrar entidad, acción, responsable, momento y motivo; solo lectura de auditoría. No confundirla con el historial de estados de US03.

Mostrar período, definiciones, moneda, estado incluido y tamaños de muestra de las métricas. Mantener `null` como indicador no disponible; no convertirlo a cero ni calcular ahorro ficticio en Flutter. Los cálculos deben seguir en el backend y mostrar que el ahorro actual es comparativo estimado, no un ahorro financiero realizado.

### M12 — Base de arquitectura, pruebas y comportamiento nativo

Prioridad: transversal. Historias: las cubiertas por cada módulo, especialmente **TS02, US02/US03, US10**.

La base actual sí separa entidades, interfaz de repositorio e implementación, y los modelos de vista reciben un repositorio abstracto. No sería correcto describirla como ausencia total de separación o de inversión de dependencias. El problema al ampliar es el único `SmartQuoteRepository` con DTO genérico `Map<String, dynamic>` y dependencias globales: no representa los cinco contextos ni permite probar adecuadamente el cliente HTTP.

Organización recomendada, sin trasladar al cliente las reglas autoritativas del servidor:

```text
lib/
  app/                         # Composición, sesión y navegación por permisos
  shared/                      # HTTP, errores, configuración, almacenamiento, UI común
  identity_access/
  supply_requests/
  quotation_intake/
  evaluation_simulation/
  purchase_ordering/
    domain/                    # Modelos/contratos propios, sin Dio ni widgets
    application/               # Casos de uso; depende de abstracciones
    infrastructure/            # DTO, mapeadores, HTTP y adaptadores nativos
    presentation/              # Vistas y sus estados/modelos de vista
```

Las cuatro subcarpetas se aplican a cada contexto, no solo a `purchase_ordering`. Mantener Provider es viable: no es obligatorio cambiar a Bloc para cumplir las historias o Clean Architecture. Compartir utilidades técnicas, no un modelo de negocio universal ni acceso directo de un contexto al almacenamiento de otro.

El cliente no debe reimplementar el algoritmo de ranking, las decisiones de compra ni la conversión SUNAT. Sus validaciones previas mejoran usabilidad; la API conserva la autoridad sobre reglas, versiones y permisos.

También se necesita:

- Sustituir el test de contador por pruebas de contratos, casos de uso, navegación por rol y formularios. Inyectar el cliente HTTP/repositorios para usar dobles controlados en pruebas sin llamar a Azure.
- Evitar filas con cuatro campos, checkbox y texto comprimidos en pantallas pequeñas (`new_request_screen.dart:155`). Ofrecer disposición vertical/adaptativa; no confundir una pantalla que se ve amplia en Chrome con una vista usable en Android.
- Mantener borradores ante cambios de orientación/error, comprobar desmontaje de vistas tras operaciones asíncronas y cancelar/ignorar actualizaciones que ya no correspondan al usuario/solicitud activa.
- Añadir selección de archivos, manejo de cookies de sesión y exportación/compartición mediante adaptadores adecuados a cada plataforma, no API exclusivas del navegador.
- Validar Android `release`, no únicamente `flutter run -d chrome`. Revisar además firma y nombre de aplicación antes de distribuir un APK final; la configuración actual conserva firma de depuración para release.

## 4. Revisión historia por historia y escenario por escenario

Estados: **ausente** = no hay recorrido móvil; **parcial/bloqueada** = existe parte de la presentación/consumo pero no satisface el escenario completo; **servicio sin consumidor móvil** = lógica contractual del backend, no nueva lógica que Flutter deba implementar; **otro entregable** = no corresponde implementarlo como pantalla móvil.

No se agregan US11/US12: no están definidas en la sección 3.2 revisada.

| Historia | Estado actual móvil | Escenario 1 | Escenario 2 | Escenario 3 | Cambio necesario |
| --- | --- | --- | --- | --- | --- |
| **US01 — Propuesta de valor** | Otro entregable | La información pública corresponde a la Landing Page. | Inglés predeterminado/español para contenido público se verifica en la Landing, no se deduce del formulario Flutter. | Mantener destino válido de acceso/contacto; móvil puede ofrecer un enlace público, sin duplicar la Landing. | No contabilizar su ausencia como fallo de compras móvil. No se auditó el repositorio Landing en este encargo. |
| **US02 — Registrar solicitud** | Parcial/bloqueada | Hay formulario, pero autenticación/operadores lo bloquean; cantidad y obligatoriedad no son confiables; se descarta el recurso creado. | Solo descripción posee validador en la vista; faltan errores útiles por campo y validaciones de requisitos/unidades/cantidad. | No hay selección/carga de sustento ni modelo de sus metadatos. | M01–M04: contrato correcto, borrador tipado, validaciones, adjuntos y navegación al detalle real. |
| **US03 — Seguimiento** | Parcial/bloqueada | Listado muestra estado, pero no última actualización ni siguiente área; no se puede abrir detalle. | Hay llamadas de notificación, pero no cambio de estado para compras ni mensaje/motivo visible; no hay sesión. | No consume `/history` ni presenta responsable/justificación. | M04/M05: detalle, historial, transiciones autorizadas y notificaciones completas. |
| **US04 — Incorporar cotizaciones** | Ausente | No carga ni asociación solicitud/proveedor. | No validación de archivos ni resultados individuales. | No recupera ni identifica cotización duplicada. | M06: PDF individual/múltiple; identidad por respuesta; conservar válidos y tratar 200/201. |
| **TS01 — Extracción RESTful** | Servicio sin consumidor móvil | No consume carga/procesamiento/resultado ni modela los datos de extracción. | No presenta evidencia, confianza ni campos no resueltos. | No comunica errores de documento/API de forma estructurada. | M02/M06/M07: consumir extracción existente; nunca llevar OpenAI ni sus secretos al dispositivo. Verificar el agente mediante pruebas separadas del servidor. |
| **US05 — Verificar extracción** | Ausente | No confirmación ni visualización de verificador/fecha. | No corrección con motivo/valor original/autor/fecha. | No presenta pendientes críticos ni bloqueo de evaluación. | M07: revisión, corrección, evidencia, asignaciones y versiones actualizadas. |
| **US06 — Criterios** | Ausente | No configura ni consulta criterios; debe contemplar precio/plazo y ponderación técnica, además de filtros obligatorios. | No valida suma/rangos ni comunica rechazo. | No crea versiones ni marca resultados desactualizados. | M08; no copiar la limitación actual de la web al editor de precio/plazo. |
| **US07 — Simulación** | Ausente | No ejecución, ranking ni contribuciones por criterio. | No muestra exclusiones técnicas. | No conserva/consulta resultados vinculados a versiones/fingerprint. | M08: simulación en servidor, consulta de historial y resultados vigentes. La repetibilidad se comprueba con pruebas del motor/API, no con un cálculo Dart. |
| **US08 — Aprobar/generar orden** | Ausente | No alternativa vigente, aprobación ni orden real. | No comunica obsolescencia ni exige reevaluación. | No usa el resultado idempotente 200 ni recupera orden existente. | M09: recorrido del jefe con datos persistidos; no conceder esa acción al analista sin cambiar la política del servidor. |
| **SP01 — Investigación IA** | Otro entregable | Revisar evidencia de 15 PDF y tres estructuras; no se demuestra con cuatro PDF de una demo móvil. | Requiere mediciones documentadas de precisión/tiempos/fallos. | Requiere informe/prototipo/conclusiones/umbrales y privacidad. | Revisar/cerrar evidencia de investigación donde corresponda. No crear una pantalla ni declarar completado el spike por existir un conector. No se certifica su cumplimiento aquí. |
| **US09 — Registro/login** | Ausente | No registro, política de contraseña, activación ni manejo de cuenta pendiente. | No correo duplicado/contraseña inválida por campo. | No inicio de sesión ni errores claros. | M01: consumir IAM real, estado de cuenta y aprobación de pendientes como la web. |
| **TS02 — JWT/RBAC** | Servicio sin consumidor móvil; integración bloqueada | No obtiene token del login. | Envía token de ejemplo y no gestiona 401. | No roles ni distinción 403; muestra acciones sin permisos. | M01/M02: sesión, renovación/cierre, navegación autorizada. La emisión/verificación de JWT permanece en servidor. |
| **US10 — Carga masiva** | Ausente | No selección múltiple ni estados individuales. | No resultado por archivo válido/inválido/duplicado. | No consulta de resultados mientras otros se procesan. | M06: trabajadores limitados o lote + procesamiento por documento; no bloquear la consulta de otros documentos por un único indicador global. |
| **SP02 — Investigación asincronía** | Otro entregable | Una llamada HTTP asíncrona o dos Futures no comparan arquitectura síncrona/colas. | Requiere evidencia de interrupción/reintentos sin duplicación. | Requiere mediciones y recomendación de límites/costos/arquitectura. | Cerrar investigación con evidencia, no implementar obligatoriamente una cola nueva en móvil. No se certifica su cumplimiento aquí. |
| **TS03 — Tipo de cambio** | Servicio sin consumidor móvil | No ejecuta simulaciones USD/PEN ni presenta originales/convertidos. | No consume `exchangeRate` ni muestra procedencia/fechas. | No maneja el 503 de tasa ausente/no vigente. | M08/M02: consumir el resultado del backend; no tasa manual, secreto SUNAT ni sustitución silenciosa en Flutter. |
| **US13 — PDF corporativo** | Ausente; limitación compartida | No exportación nativa ni datos corporativos configurados. | No restricción de exportación por estado/vigencia de aprobación. | No documento recuperable coherente con la orden persistida. | M09 y sección 6: PDF real desde orden aprobada; decidir adaptador móvil o servicio central compartido. |
| **TS04 — JSON de órdenes** | Servicio sin consumidor móvil | No modelo/consumo de detalle de orden. | No gestión contextual de 401/403/404. | No pruebas de deserialización conforme al recurso/OpenAPI. | M09/M02: DTO de orden íntegro y pruebas de contrato. No inventar otro endpoint externo desde móvil. |
| **US14 — Auditoría inmutable** | Ausente | Eventos los genera el servidor al confirmar operaciones; móvil todavía no realiza esas operaciones. | No consulta de bitácora de solicitudes/órdenes. | No vista de solo lectura por permisos. | M11: consultar API de auditoría; no escribir ni editar eventos desde Flutter. La inmutabilidad se verifica también en servidor/persistencia. |
| **US15 — Desempeño proveedor** | Ausente; escenario 3 limitado también en API/web | No registro de entrega/evaluación. | No validación de estado/escala ni manejo de evaluación duplicada. | No promedio ni historial; la API actual entrega solo el agregado. | M10 y sección 6: consumo por personal de compras y exposición del historial individual existente. |
| **US16 — Métricas** | Ausente | No indicadores ni definiciones. | No filtros de fechas/volumen de muestras. | No estado no disponible para indicadores sin respaldo. | M11: consumir métricas existentes; revisar efecto de órdenes Delivered indicado en sección 6. |

## 5. Inventario de endpoints a consumir para la paridad

Todas las rutas siguientes llevan el prefijo `/api/v1`. Roles: **público** = sin sesión; **autenticado** = JWT válido; **producción** = `ProductionSpecialist`; **compras** = `PurchaseAnalyst` o `PurchaseManager`; **jefe** = `PurchaseManager`. Producción solo accede a sus propias solicitudes según las comprobaciones del servicio.

Los códigos indicados son de éxito; las restricciones/errores deben tratarse según el recurso y `ProblemDetails`. No debe exigirse 200 para todas las operaciones: 201, 204 y 207 también son resultados válidos.

| Área / historia | Método y ruta | Entrada relevante | Éxito / resultado | Rol | Móvil actual |
| --- | --- | --- | --- | --- | --- |
| IAM / US09 | `GET /iam/auth/registration-status` | Sin cuerpo | 200, `initialSetupRequired` | Público | Ausente |
| IAM / US09 | `POST /iam/auth/register` | `email`, `displayName`, `password`, `role` | 201, cuenta/estado/roles | Público | Ausente |
| IAM / US09–TS02 | `POST /iam/auth/login` | `email`, `password` | 200, sesión + cookie de renovación | Público | Ausente |
| IAM / TS02 | `POST /iam/auth/refresh` | Cookie `smartquote_refresh`, no refresh token JSON | 200, JWT nuevo + cookie rotada | Cookie de sesión | Ausente |
| IAM / TS02 | `POST /iam/auth/logout` | Cookie de sesión | 204 | Público con sesión a revocar | Ausente |
| IAM / TS02 | `GET /iam/auth/me` | JWT | 200, identidad/roles | Autenticado | Ausente |
| IAM / paridad US09 | `GET /iam/registration-requests` | JWT | 200, registros pendientes | Jefe | Ausente |
| IAM / paridad US09 | `POST /iam/registration-requests/{userId}/approve` | `role` | 200, usuario habilitado | Jefe | Ausente |
| Solicitudes / US02 | `POST /purchase-requests` | `requiredDate`, `priority`, `items[]` y requisitos | 201, solicitud completa | Producción | Implementado con contrato incorrecto |
| Solicitudes / US03 | `GET /purchase-requests` | `status?`, `page`, `pageSize` | 200, `items` + paginación | Autenticado | Página 1 fija, modelo incompleto |
| Solicitudes / US02–03 | `GET /purchase-requests/{requestId}` | ID real | 200, detalle/versiones/adjuntos | Autenticado | Ausente |
| Solicitudes / US03 | `GET /purchase-requests/{requestId}/history` | ID real | 200, historial con `entries` | Autenticado | Ausente |
| Solicitudes / US03 | `PUT /purchase-requests/{requestId}/status` | `nextStatus`, `reason`, `expectedVersion` | 204 | Compras | Ausente |
| Sustento / US02 | `POST /purchase-requests/{requestId}/attachments` | Multipart `file`, `expectedVersion` | 204; después consultar detalle | Producción | Ausente |
| Notificaciones / US03 | `GET /notifications` | `unreadOnly?` | 200, arreglo con `readAt` y `message` | Producción | Ruta/modelo parcial |
| Notificaciones / US03 | `PUT /notifications/{notificationId}/read` | Sin cuerpo | 204 | Producción | Llamada existente; falla silenciosa |
| Cotizaciones / US04 | `POST /purchase-requests/{requestId}/quotations` | Multipart `file`, `supplierId?`, `supplierBusinessName?`, `supplierTaxIdentifier?` | 201 nueva / 200 existente | Compras | Ausente |
| Cotizaciones / US10 | `POST /purchase-requests/{requestId}/quotations/batch` | Multipart `files[]` y metadatos opcionales | 207, resultado por archivo | Compras | Ausente |
| Cotizaciones / US04–05 | `GET /purchase-requests/{requestId}/quotations` | ID de solicitud | 200, cotizaciones completas | Compras | Ausente |
| IA / TS01 | `POST /quotations/{quotationId}/process` | Sin cuerpo | 200, extracción/estado | Compras | Ausente |
| Revisión / US05–TS01 | `GET /quotations/{quotationId}` | ID de cotización | 200, líneas/campos/evidencias | Compras | Ausente |
| Revisión / US05 | `PUT /quotations/{quotationId}/fields/{fieldId}` | `value`, `reason`, `expectedVersion` | 204 | Compras | Ausente |
| Revisión / US05 | `POST /quotations/{quotationId}/lines/{lineId}/specifications` | `name`, `value`, `unitOfMeasure`, `sourcePageNumber`, `sourceTextReference`, `reason`, `expectedVersion` | 204 | Compras | Ausente |
| Verificación / US05 | `POST /quotations/{quotationId}/confirm` | `lineMappings[]`, `expectedVersion` | 204 | Compras | Ausente |
| Criterios / US06 | `POST /evaluation-scenarios` | `requestId`, `criteria[]` | 201, escenario | Compras | Ausente |
| Criterios / US06 | `POST /evaluation-scenarios/{scenarioId}/versions` | `criteria[]` | 201, nueva versión | Compras | Ausente |
| Criterios / US06 | `GET /evaluation-scenarios/{scenarioId}` | ID de escenario | 200, definición/version | Compras | Ausente |
| Criterios / US06 | `GET /purchase-requests/{requestId}/evaluation-scenario` | ID de solicitud | 200, escenario actual | Compras | Ausente |
| Simulación / US07–TS03 | `POST /evaluation-scenarios/{scenarioId}/simulations` | Sin cuerpo | 201 nueva / 200 repetida | Compras | Ausente |
| Simulación / US07–TS03 | `GET /simulations/{simulationRunId}` | ID de ejecución | 200, resultado y tasa | Compras | Ausente |
| Historial / US07 | `GET /purchase-requests/{requestId}/simulations` | ID de solicitud | 200, ejecuciones persistidas | Compras | Ausente |
| Orden / US08 | `POST /simulations/{runId}/quotations/{quotationId}/purchase-orders` | `deliveryConditions`, `deliveryDestination` | 201 nueva / 200 existente | Jefe | Ausente |
| Orden / TS04 | `GET /purchase-orders/{purchaseOrderId}` | ID de orden | 200, contrato JSON completo | Compras | Ausente |
| Recuperación / US08 | `GET /simulations/{runId}/purchase-order` | ID de ejecución | 200, orden | Compras | Ausente |
| Recuperación / US08 | `GET /purchase-requests/{requestId}/purchase-order` | ID de solicitud | 200, orden; 404 si no existe | Compras | Ausente |
| Entrega / US15 | `POST /purchase-orders/{purchaseOrderId}/delivery` | Sin cuerpo | 200, orden Delivered | Compras | Ausente |
| Evaluación / US15 | `POST /purchase-orders/{purchaseOrderId}/delivery-evaluation` | `onTimeScore`, `qualityScore`, `observations?` | 201, evaluación | Compras | Ausente |
| Proveedor / US15 | `GET /suppliers/{taxIdentifier}/performance` | RUC | 200, promedios/muestras/período | Compras | Ausente |
| Auditoría / US14 | `GET /audit/{entityType}/{entityId}` | `PurchaseRequest` o `PurchaseOrder`, ID | 200, eventos | Jefe | Ausente |
| Analítica / US16 | `GET /purchasing-metrics` | `from`, `to`, fechas `YYYY-MM-DD` | 200, métricas/definiciones/muestras | Jefe | Ausente |

Se debe aceptar un 404 esperado cuando todavía no hay escenario u orden y mostrar “aún no registrado”, no inutilizar todo el detalle. No debe tratarse cualquier 404 como opcional: una solicitud inexistente sí es un error de navegación/recurso.

## 6. Pendientes compartidos: igualar la web no asegura cumplir las historias

### 6.1 US06: ponderación técnica no configurable desde la web

`W:src/evaluation-simulation/domain/evaluation-scenario.entity.js:21` genera filtros técnicos obligatorios y dos criterios ponderados: precio y plazo. `W:src/evaluation-simulation/presentation/comparison-panel.vue:35` ajusta precio y su complemento de plazo; no hay editor para configurar criterios técnicos ponderados.

US06 escenario 1 menciona explícitamente ponderación de cumplimiento técnico. El backend admite criterios técnicos y ponderados. Antes de cerrar conformidad, ofrecer su configuración en móvil —sin convertir los requisitos obligatorios en opcionales— y, para paridad entre productos, también en web. Mantener el control simple precio/plazo cuando no hay ponderaciones técnicas adicionales; si las hay, repartir el saldo restante o ajustar los tres pesos, no forzar siempre `plazo = 100 - precio`.

### 6.2 US13: impresión web no es toda la exportación corporativa

`W:src/purchase-ordering/presentation/order-panel.vue:95` llama a `window.print()`. Permite guardar un PDF mediante el diálogo del navegador, pero no se encontró generación PDF en el backend, configuración corporativa completa ni registro de un documento generado recuperable. Esto no demuestra por sí solo todos los escenarios de US13.

Recomendación: centralizar documento/planteamiento corporativo desde el recurso aprobado, o usar adaptadores de exportación equivalentes en ambos clientes con una fuente corporativa definida. Si se decide conservar un PDF oficial generado, especificar su relación con la orden y su versión. No inventar en Flutter un endpoint `/pdf` que todavía no existe.

### 6.3 US15: acceso del analista y falta de historial individual

`W:src/supply-requests/presentation/pages/request-detail.vue:181` restringe la pestaña de órdenes al jefe; allí se encuentran entrega y calificación. `B:src/SmartQuote.Modules.PurchaseOrdering/Interfaces/REST/PurchaseOrdersController.cs:54` y `:67` permiten ambas al personal de compras. Por tanto, el analista no alcanza desde la web el registro descrito en su historia.

Además, `B:src/SmartQuote.Modules.PurchaseOrdering/Interfaces/REST/Resources/SupplierPerformanceResource.cs:3` solo expone promedios, cantidad y fechas extremas. La pantalla web reproduce ese resumen; no recibe las evaluaciones individuales con orden, observación, autor y momento, exigidas por “historial” en el escenario 3.

Recomendación: permitir al analista consultar órdenes y evaluar entregas sin autorizar emisión; exponer las evaluaciones persistidas del proveedor mediante una consulta del mismo contexto, idealmente paginada, manteniendo el resumen existente compatible. Este sería un ajuste de API acotado para completar US15, no una nueva historia ni otro contexto.

### 6.4 US03: datos existentes pero no presentados íntegramente en web

El detalle web presenta `updatedAt`, pero no muestra `nextResponsibleArea` en el archivo revisado. Las notificaciones web no muestran `message`, aunque la API lo devuelve. Al implementar móvil, mostrar también siguiente área y motivo; igualar solo el estado visible de la web dejaría incompleta la experiencia de seguimiento.

### 6.5 US16: órdenes entregadas desaparecen del conjunto de métricas actual

`B:src/SmartQuote.API/Analytics/PurchasingMetricsController.cs:45` filtra exclusivamente órdenes `Issued`. Al registrar entrega mediante US15, la orden pasa a `Delivered` y deja de participar en esos indicadores. El contrato sí declara expresamente ese estado incluido, por lo que no debe ocultarse al usuario.

Recomendación: acordar si el indicador mide todas las órdenes emitidas en el período —incluidas las posteriormente entregadas— o únicamente las todavía emitidas. Para medir eficiencia histórica del proceso, lo primero resulta más coherente; necesitaría ajustar filtro y definición en backend, no calcular otro total en Flutter. No se declara fallo de ejecución sin una prueba de datos: el filtro y su efecto se desprenden del código.

### 6.6 Spikes y servicios: no afirmar cumplimiento por tener pantallas

SP01 y SP02 requieren evidencias de investigación y mediciones. TS01/TS02/TS03/TS04 requieren contratos y comportamiento del servidor. La app debe integrarlos correctamente, pero una pantalla móvil no prueba precisión de extracción, inmutabilidad, protección de acceso, repetibilidad o estabilidad del contrato. Deben verificarse por separado con pruebas del backend y evidencias, sin duplicar esos mecanismos en Flutter.

## 7. Orden recomendado de los cambios, sin implementación todavía

| Orden | Bloque | Historias | Resultado comprobable para terminar el bloque |
| --- | --- | --- | --- |
| 1 | Preparación del proyecto + configuración/red/errores + IAM (M01/M02/M12) | US09, TS02; base transversal | Login/registro/renovación/logout reales, tres roles diferenciados; URL configurable; errores claros; prueba de plantilla corregida y dependencias verificadas. |
| 2 | Solicitudes completas + seguimiento/notificaciones (M03–M05) | US02, US03 | Producción crea solicitud válida, adjunta sustento y consulta detalle/historial; compras hace las transiciones autorizadas. |
| 3 | Cotizaciones, carga múltiple, IA y verificación (M06/M07) | US04, US05, US10, TS01 | Múltiples PDF con estados individuales, extracción real, corrección trazable y dos cotizaciones verificadas asociadas correctamente. |
| 4 | Criterios, simulaciones persistidas y conversión (M08) | US06, US07, TS03 | Ranking reproducible, exclusiones, cambios de versiones e historial; trazabilidad USD/PEN y error de fuente externa. |
| 5 | Orden persistida + contrato JSON + PDF (M09) | US08, TS04, US13 | Jefe emite una sola orden, se recupera tras volver a iniciar sesión y se exporta documento coherente. Resolver decisión de PDF compartida antes de implementarlo. |
| 6 | Entregas/proveedores + bitácora/métricas (M10/M11) | US15, US14, US16 | Analista califica entregas; historial de proveedor disponible; jefe consulta auditoría/métricas reales con períodos/muestras. |
| 7 | Validación final en Android y Flutter Web | Todas las aplicables | Recorrido completo sin datos simulados en producción, sin cambios de permisos, sin secretos cliente y con errores controlados. Evidencias de spikes separadas. |

La arquitectura por contextos y los dobles de prueba se preparan desde el primer bloque. No se propone esperar hasta el final para ordenar una implementación nueva monolítica en un repositorio genérico.

La mayor parte del trabajo es **consumo y presentación móvil**, no reescritura del backend. Los posibles ajustes del servidor se concentran en PDF corporativo, historial de evaluaciones y definición de métricas; deben decidirse explícitamente. No hace falta crear nuevas historias para cubrir estos requisitos ya existentes.

## 8. Verificaciones necesarias antes de afirmar paridad

Estas son pruebas pendientes/recomendadas, no resultados obtenidos durante esta auditoría.

| Grupo | Comprobaciones mínimas |
| --- | --- |
| IAM / US09–TS02 | Registro válido/contraseña insegura/correo repetido; pendiente no accede; jefe aprueba; login válido e inválido; 401/403; renovar cookie en Android y navegador; logout no restaura la sesión revocada; otro usuario no ve datos de la sesión anterior. |
| Solicitudes / US02 | Crear con decimales; probar los cuatro operadores y prioridades reales; impedir incompletos y falta de requisito obligatorio; requisito opcional funcional; PDF/imagen permitido e inválido; mostrar ID, solicitante, estado y metadatos del adjunto; errores no borran el formulario. |
| Seguimiento / US03 | Detalle/última actualización/siguiente área; historial ordenado; transición autorizada y motivo; producción no cambia estado ni accede a solicitud ajena; notificación leída/mensaje; paginación más allá de 20 registros. |
| PDF/IA / US04–US10–TS01 | Lote de varios proveedores; válido/dañado/formato incorrecto/duplicado; fuente externa lenta/caída; resultado por archivo; confianza/origen/no resueltos; reintentar uno sin duplicar los demás; datos disponibles tras salir/volver. |
| Verificación / US05 | Corregir precio y motivo, conservar original/autor/fecha; completar especificación con evidencia; asignar líneas a ítems reales; recargar versión; bloquear confirmación/evaluación con pendientes; 409 de edición concurrente. |
| Criterios / US06 | Suma 100/rango inválido; criterios técnicos ponderados y obligatorios; cambio crea versión y conserva simulación previa; UI no ofrece aprobación de resultado desactualizado. |
| Simulación / US07–TS03 | Una oferta no basta; dos verificadas y solicitud Evaluation; oferta técnicamente inválida no gana por precio; repetición con mismas entradas; recuperación por solicitud; PEN/USD con originales, convertidos y tasa; SUNAT sin tasa vigente produce error, no tasa inventada. |
| Órdenes / US08–TS04 | Emisión por jefe; analista/producción sin autorización reciben 403; repetir devuelve misma orden; datos modificados requieren nueva evaluación; consulta por ID/solicitud/simulación; 404 controlado; recurso coincide con OpenAPI y datos aprobados. |
| PDF / US13 | Solo orden aprobada vigente; documento corporativo legible; descarga/compartición Android; campos y valores iguales a la versión aprobada, incluso si posteriormente se modifica otro dato del sistema. |
| Auditoría / US14 | Creación/transición/aprobación/cancelación generan eventos correctos; consulta cronológica y responsable; solo permisos actuales; cliente no ofrece edición/eliminación. Validar protección también en servidor. |
| Proveedores / US15 | Entrega real antes de evaluar; escala válida/invalidada; rechazo de evaluación duplicada; analista puede acceder; historial individual, promedios, período y muestra; proveedor sin evaluaciones no obtiene una calificación inventada. |
| Métricas / US16 | Períodos válidos/inválidos; cantidades de muestra y definiciones visibles; valores nulos como no disponibles; importe en PEN; comprobar efecto de registrar entrega sobre indicadores y aplicar la definición de negocio acordada. |
| Investigación / SP01–SP02 | Evidencias de corpus/PoC/precisión/tiempo y comparación síncrona-asíncrona, reintentos y recomendación documentada; no usar el éxito de la demo como sustituto. |
| Plataforma | APK Android release con red; emulador/dispositivo contra backend accesible; Flutter Web con credenciales/CORS correctos; formularios/pantallas pequeñas, orientación, tiempos de espera e interrupciones sin perder datos ni duplicar operaciones. |

Después de restaurar dependencias, ejecutar `flutter analyze`, `flutter test` y verificar una compilación Android release en el proyecto real. Las pruebas de extremo a extremo deben usar una base de datos de pruebas y usuarios autorizados, no alterar los datos de exposición/producción para validar casos negativos.

## 9. Referencias clave de código para la implementación posterior

Las rutas usan los prefijos de la sección 1. Los números corresponden al código revisado y pueden cambiar después de editarlo.

| Tema | Evidencia |
| --- | --- |
| Token de ejemplo y sesión ausente | `M:lib/core/network/auth_interceptor.dart:12`; `M:lib/main.dart:43` |
| Cuatro llamadas existentes | `M:lib/data/repositories_impl/smartquote_repository_impl.dart:10` |
| Contrato móvil de solicitudes | `M:lib/presentation/viewmodels/new_request_viewmodel.dart:43` |
| Prioridades, cantidad, operador, obligatoriedad | `M:lib/presentation/screens/new_request_screen.dart:101`, `:136`, `:163`, `:171` |
| Detalle sin implementar | `M:lib/presentation/screens/request_list_screen.dart:97` |
| Modelo incompleto de solicitud | `M:lib/data/models/purchase_request_model.dart:12` |
| Notificaciones: fallo silencioso | `M:lib/presentation/viewmodels/notification_viewmodel.dart:17` |
| Cookie de renovación real | `B:src/SmartQuote.Modules.IdentityAccess/Interfaces/REST/AuthController.cs:93` |
| Contrato completo de solicitudes | `B:src/SmartQuote.Modules.SupplyRequests/Interfaces/REST/Resources/PurchaseRequestResource.cs:3` |
| Endpoints/formularios/versiones de solicitudes | `B:src/SmartQuote.Modules.SupplyRequests/Interfaces/REST/PurchaseRequestsController.cs:21` |
| Contrato de notificaciones | `B:src/SmartQuote.Modules.SupplyRequests/Interfaces/REST/Resources/RequestNotificationResource.cs:3` |
| Cotizaciones y lote | `B:src/SmartQuote.Modules.QuotationIntake/Interfaces/REST/PoultryQuotesController.cs:17`; `:51` |
| Extracción con evidencias/correcciones | `B:src/SmartQuote.Modules.QuotationIntake/Interfaces/REST/Resource/PoultryQuoteResource.cs:3` |
| Carga/procesamiento web con dos trabajadores | `W:src/quotation-intake/presentation/quotation-panel.vue:108` |
| Simulaciones/consulta por solicitud | `B:src/SmartQuote.Modules.EvaluationSimulation/Interfaces/REST/SimulationsController.cs:65`; `:92` |
| Resultado y trazabilidad de tasa | `B:src/SmartQuote.Modules.EvaluationSimulation/Interfaces/REST/Resources/SimulationResultResource.cs:3` |
| Validaciones/consulta SUNAT | `B:src/SmartQuote.Modules.EvaluationSimulation/Infrastructure/ExchangeRates/SunatExchangeRateProvider.cs:19` |
| Recuperación y acciones de órdenes | `B:src/SmartQuote.Modules.PurchaseOrdering/Interfaces/REST/PurchaseOrdersController.cs:16` |
| Impresión actual de la web | `W:src/purchase-ordering/presentation/order-panel.vue:95` |
| Resumen sin historial de proveedor | `B:src/SmartQuote.Modules.PurchaseOrdering/Interfaces/REST/Resources/SupplierPerformanceResource.cs:3` |
| Métricas y estado incluido | `B:src/SmartQuote.API/Analytics/PurchasingMetricsController.cs:45` |
| Errores estructurados | `B:src/SmartQuote.Shared/Interfaces/Middleware/ExceptionHandlingMiddleware.cs:14` |
| Test no adaptado al proyecto | `M:test/widget_test.dart:16` |

## 10. Referencias técnicas externas consultadas

- [Flutter: acceso a Internet y permiso Android](https://docs.flutter.dev/cookbook/networking/fetch-data): confirma la declaración del permiso de red en Android y la representación explícita de estados de carga/error/datos.
- [Flutter: recomendaciones de arquitectura](https://docs.flutter.dev/app-architecture/recommendations): referencia para separar responsabilidades y facilitar pruebas; no obliga a abandonar Provider ni a copiar el dominio del servidor al cliente.
- [Dio Cookie Manager: documentación del mantenedor](https://pub.dev/packages/dio_cookie_manager): referencia para estudiar el manejo de cookies del adaptador nativo. Una persistencia de cookies no implica por sí sola almacenamiento seguro; debe evaluarse protección de datos y comportamiento por plataforma.

## Conclusión

El backend ofrece ya la mayor parte de los contratos necesarios; la app móvil actual no los integra. La ruta adecuada es completar cinco módulos móviles sobre esos contratos y corregir primero los bloqueos existentes, conservando permisos, reglas e información persistida. La paridad debe demostrarse por escenarios de las historias, no por cantidad de pantallas ni por reutilizar un token manual.

Esta auditoría no modifica Flutter, Vue, C#, historias del reporte ni configuraciones de despliegue. El único archivo añadido es este documento.
