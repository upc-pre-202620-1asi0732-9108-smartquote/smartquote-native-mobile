# smartquote-native-mobile
Código fuente de la aplicación móvil nativa de SmartQuote.

El proyecto Flutter está en [SmartquoteApp-mobile/smartquote_mobile](SmartquoteApp-mobile/smartquote_mobile/README.md).

Para ejecutarlo:

```powershell
Set-Location E:\smartquote-native-mobile\SmartquoteApp-mobile\smartquote_mobile
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=https://smartquote-api-h8czffe5b4dtg6d7.chilecentral-01.azurewebsites.net
```

Iniciar sesión con la cuenta del backend, sin pegar JWT. Si el puerto 5173 está ocupado, seguir la indicación de puerto/CORS del README del proyecto.

[Cambios, historias cubiertas, flujo por rol y límites](SmartquoteApp-mobile/smartquote_mobile/docs/REFACTORIZACION-MOVIL.md).

La auditoría en esta raíz describe el estado anterior a la refactorización. SUNAT permanece en el backend; no se incluyen claves externas en la aplicación.
