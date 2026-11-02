import 'package:flutter/material.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/services/api_service.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isRestoringOfflineSession = true;
  OfflineSession? _offlineSession;
  Map<String, dynamic>? _offlineProfile;
  String? _offlineSessionError;

  final OfflineStore _offlineStore = OfflineStore();
  final OfflineSessionStore _offlineSessionStore = OfflineSessionStore();

  @override
  void initState() {
    super.initState();
    _restoreOfflineSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _restoreOfflineSession() async {
    try {
      final session = await _offlineSessionStore.read();
      if (session == null) return;

      final cachedProfile = await _offlineStore.readJson(
        userKey: session.userKey,
        key: OfflineStore.profileKey,
      );
      if (cachedProfile is! Map) {
        throw const FormatException(
          'No hay un perfil sincronizado para la última sesión.',
        );
      }

      _offlineSession = session;
      _offlineProfile = Map<String, dynamic>.from(cachedProfile);
    } catch (error) {
      debugPrint('No se pudo restaurar la sesión offline: $error');
      _offlineSessionError = error.toString();
    } finally {
      if (mounted) {
        setState(() => _isRestoringOfflineSession = false);
      }
    }
  }

  void _continueOffline() {
    final session = _offlineSession;
    final profile = _offlineProfile;
    if (session == null || profile == null) return;

    DemoData.instance.setAuthenticatedUser(
      profile,
      fallbackEmail: profile['email'] as String? ?? session.userKey,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          accessToken: session.accessToken,
          userKey: session.userKey,
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final servicio = ApiService();

    try {
      final token = await servicio.iniciarSesion(
        rut: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final profile = await servicio.obtenerUsuarioAutenticado();

      if (!mounted) return;

      final offlineProfile = _offlineStore.profileForOffline(
        profile,
        fallbackEmail: _emailController.text.trim(),
      );
      final userKey = OfflineStore.userKeyFor(offlineProfile);
      try {
        await _offlineSessionStore.clear();
        await _offlineStore.saveJson(
          userKey: userKey,
          key: OfflineStore.profileKey,
          value: offlineProfile,
        );
        await _offlineSessionStore.save(
          OfflineSession(userKey: userKey, accessToken: token),
        );
      } catch (error) {
        debugPrint('No se pudo persistir la sesión para uso offline: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sesión iniciada, pero no se pudo guardar el acceso offline.',
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      DemoData.instance.setAuthenticatedUser(
        profile,
        fallbackEmail: _emailController.text.trim(),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              HomeScreen(accessToken: token, userKey: userKey),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;

      final mensaje = error.statusCode == 422 || error.statusCode == 401
          ? 'Correo o contraseña incorrectos.'
          : 'Error del servidor (${error.statusCode}).';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensaje)));
    } on FormatException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo identificar tu perfil: $error')),
      );
    } catch (error) {
      if (!mounted) return;

      debugPrint('Error de conexión durante el login: $error');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo conectar con Laravel. '
            'Revisa la conexión y el certificado HTTPS.',
          ),
        ),
      );
    } finally {
      servicio.close();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.black12 : Colors.white,
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Ingrese su correo' : null,
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
                      validator: (value) =>
                          value!.isEmpty ? 'Ingrese su contraseña' : null,
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
                      child: const Text(
                        'Ingresar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_isRestoringOfflineSession) ...[
                      const SizedBox(height: 12),
                      const Center(child: CircularProgressIndicator()),
                    ] else if (_offlineSession != null &&
                        _offlineProfile != null) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : _continueOffline,
                        icon: const Icon(Icons.cloud_off),
                        label: Text(
                          'Continuar sin conexión como '
                          '${_offlineProfile!['name'] ?? _offlineProfile!['email'] ?? 'último usuario'}',
                        ),
                      ),
                      const Text(
                        'Se abrirán sólo los datos previamente sincronizados '
                        'en este dispositivo.',
                        textAlign: TextAlign.center,
                      ),
                    ] else if (_offlineSessionError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'No se pudo restaurar la sesión offline: '
                        '$_offlineSessionError',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
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
