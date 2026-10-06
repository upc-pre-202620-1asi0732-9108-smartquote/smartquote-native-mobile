import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/services.dart';
import '../../shared/presentation/operation_state.dart';
import '../../shared/presentation/ui.dart';
import '../domain/session.dart';

class AccessPage extends StatefulWidget {
  const AccessPage({super.key, required this.services});
  final Services services;
  @override
  State<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends OperationState<AccessPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _password = TextEditingController(),
      _name = TextEditingController();
  bool register = false, obscure = true, initialSetup = false;
  String role = 'ProductionSpecialist';
  String? message;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    if (busy) return;
    setState(() {
      register = !register;
      error = null;
      message = null;
    });
    if (register) {
      await perform(() async {
        initialSetup = await widget.services.auth.repository.initialSetup();
        if (initialSetup) role = 'PurchaseManager';
      });
    }
  }

  Future<void> submit() async {
    if (!_form.currentState!.validate()) return;
    await perform(() async {
      if (!register) {
        await widget.services.auth.login(_email.text, _password.text);
      } else {
        final result = await widget.services.auth.repository.register({
          'email': _email.text.trim(),
          'displayName': _name.text.trim(),
          'password': _password.text,
          'role': role,
        });
        if (!mounted) return;
        setState(() {
          message = result['status'] == 'Pending'
              ? 'Registro recibido. El jefe de compras debe aprobar tu cuenta antes de iniciar sesión.'
              : 'Cuenta creada. Ya puedes iniciar sesión.';
          register = false;
          _password.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.insights,
                  size: 58,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'SmartQuote',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  register
                      ? 'Crea tu cuenta de trabajo'
                      : 'Compras avícolas con respaldo técnico',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (message != null)
                  InfoCard(title: 'Cuenta', children: [Text(message!)]),
                ErrorNotice(error),
                if (register) ...[
                  TextFormField(
                    controller: _name,
                    maxLength: 150,
                    decoration: fieldDecoration('Nombres y apellidos'),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Ingresa al menos dos caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: fieldDecoration('Correo electrónico'),
                  validator: (v) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Ingresa un correo válido.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  obscureText: obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: [
                    register
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  decoration: fieldDecoration('Contraseña').copyWith(
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(
                        obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    if (!busy) submit();
                  },
                  validator: (v) => register
                      ? passwordError(v ?? '', _email.text.trim())
                      : requiredValue(v),
                ),
                if (register) ...[
                  const SizedBox(height: 16),
                  Text(
                    initialSetup
                        ? 'Configuración inicial: la primera cuenta será el jefe de compras.'
                        : 'El rol solicitado se valida por el jefe de compras.',
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('role-$initialSetup'),
                    initialValue: role,
                    isExpanded: true,
                    decoration: fieldDecoration('Rol solicitado'),
                    items:
                        (initialSetup
                                ? {'PurchaseManager': roles['PurchaseManager']!}
                                : roles)
                            .entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                    onChanged: busy ? null : (v) => setState(() => role = v!),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Contraseña: 12–128 caracteres, mayúscula, minúscula, número y símbolo; sin tu correo.',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Conectando…'
                        : register
                        ? 'Solicitar registro'
                        : 'Iniciar sesión',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : toggle,
                  child: Text(
                    register ? 'Ya tengo una cuenta' : 'Crear una cuenta',
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await perform(() async {
                            final uri = Uri.parse(
                              const String.fromEnvironment(
                                'LANDING_PAGE_URL',
                                defaultValue: 'https://upc-pre-202620-1asi0732-9108-smartquote.github.io/smartquote-landing-page/',
                              ),
                            );
                            if (uri.scheme != 'https' ||
                                !await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                )) {
                              throw StateError(
                                'No se pudo abrir el sitio público de SmartQuote.',
                              );
                            }
                          });
                        },
                  child: const Text('Conocer SmartQuote'),
                ),
                SelectableText(
                  'Servidor: ${widget.services.auth.client.baseUrl}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Text(
                  'La sesión y los permisos se validan en el servidor. No se guardan contraseñas ni tokens en disco.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
