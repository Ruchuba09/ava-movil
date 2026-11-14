import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/conectividad.dart';
import 'package:avamovil/services/offline_auth.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _restaurandoSesion = true;

  final OfflineStore _offlineStore = OfflineStore();
  final OfflineAuthService _offlineAuth = OfflineAuthService();

  @override
  void initState() {
    super.initState();
    _restaurarSesion();
  }

  /// Si la app se cerró con la sesión abierta, entra directo con los datos
  /// guardados, haya o no conexión.
  Future<void> _restaurarSesion() async {
    try {
      final login = await _offlineAuth.restaurarSesion();
      if (login != null && mounted) {
        _openHome(
          profile: login.profile,
          accessToken: login.accessToken ?? '',
          userKey: login.userKey,
        );
        return;
      }
    } catch (error) {
      debugPrint('No se pudo restaurar la sesión abierta: $error');
    }
    if (mounted) setState(() => _restaurandoSesion = false);
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openHome({
    required Map<String, dynamic> profile,
    required String accessToken,
    required String userKey,
  }) {
    DemoData.instance.setAuthenticatedUser(
      profile,
      fallbackEmail: profile['email'] as String? ?? userKey,
    );
    _offlineAuth.abrirSesion(userKey).catchError((Object error) {
      debugPrint('No se pudo recordar la sesión abierta: $error');
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HomeScreen(accessToken: accessToken, userKey: userKey),
      ),
    );
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    final identifier = LoginIdentifier.parse(_identifierController.text)!;
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      // Sin red se valida directo en el dispositivo, sin esperar un timeout.
      Conectividad.instance.exigirConexion();
      await _loginOnline(identifier, password);
    } catch (error) {
      if (!mounted) return;
      if (OfflineAuthService.esFallaDeConexion(error)) {
        debugPrint('Laravel no disponible, se intenta sin conexión: $error');
        await _loginOffline(identifier, password);
      } else if (error is ApiException) {
        _showMessage(
          error.statusCode == 422 || error.statusCode == 401
              ? 'RUT/correo o contraseña incorrectos.'
              : error.statusCode == 429
              ? 'Demasiados intentos. Espera un momento e inténtalo de nuevo.'
              : 'Error del servidor (${error.statusCode}).',
        );
      } else if (error is FormatException) {
        _showMessage('No se pudo identificar tu perfil: ${error.message}');
      } else {
        debugPrint('Error durante el login: $error');
        _showMessage('No se pudo iniciar sesión. Inténtalo de nuevo.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginOnline(LoginIdentifier identifier, String password) async {
    final servicio = ApiService();
    final String token;
    final Map<String, dynamic> profile;
    try {
      token = await servicio.iniciarSesion(
        rut: identifier.valor,
        password: password,
      );
      final servicioAutenticado = ApiService(accessToken: token);
      try {
        profile = await servicioAutenticado.obtenerUsuarioAutenticado();
      } finally {
        servicioAutenticado.close();
      }
    } finally {
      servicio.close();
    }

    final fallbackEmail = identifier.esCorreo ? identifier.valor : '';
    final offlineProfile = _offlineStore.profileForOffline(
      profile,
      fallbackEmail: fallbackEmail,
    );
    final userKey = OfflineStore.userKeyFor(offlineProfile);
    try {
      await OfflineSessionStore().clear();
      await _offlineStore.saveJson(
        userKey: userKey,
        key: OfflineStore.profileKey,
        value: offlineProfile,
      );
      await _offlineAuth.guardarLoginOnline(
        userKey: userKey,
        profile: offlineProfile,
        password: password,
        accessToken: token,
      );
    } catch (error) {
      debugPrint('No se pudo guardar el acceso sin conexión: $error');
      if (mounted) {
        _showMessage(
          'Sesión iniciada, pero no se pudo guardar el acceso sin conexión.',
        );
      }
    }

    if (!mounted) return;
    _openHome(profile: profile, accessToken: token, userKey: userKey);
  }

  Future<void> _loginOffline(
    LoginIdentifier identifier,
    String password,
  ) async {
    try {
      final login = await _offlineAuth.autenticar(
        identificador: identifier,
        password: password,
      );
      if (!mounted) return;
      _showMessage(
        'Sin conexión con el servidor. Entraste con los datos guardados '
        'en este dispositivo.',
      );
      _openHome(
        profile: login.profile,
        accessToken: login.accessToken ?? '',
        userKey: login.userKey,
      );
    } on OfflineAuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (error) {
      debugPrint('Error en el login sin conexión: $error');
      if (mounted) {
        _showMessage(
          'No hay conexión con el servidor y no se pudo validar el acceso '
          'guardado en este dispositivo.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_restaurandoSesion) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/logos/negro.png',
                color: isDark ? verde5Color : Colors.black,
                colorBlendMode: BlendMode.srcIn,
                height: 88,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 48),
              const Text(
                'Iniciar Sesión',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _identifierController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'RUT o correo electrónico',
                        hintText: '12.345.678-9 o nombre@empresa.cl',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black12 : Colors.white,
                      ),
                      validator: LoginIdentifier.validar,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black12 : Colors.white,
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Ingrese su contraseña'
                          : null,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde6Color,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Ingresar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
