import 'package:flutter/material.dart';
import 'package:avamovil/services/api_service.dart';
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

      if (!mounted) return;

      debugPrint(
        'Inicio de sesión correcto. Token recibido: ${token.isNotEmpty}',
      );

      Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => HomeScreen(
      accessToken: token,
    ),
  ),
);
    } on ApiException catch (error) {
      if (!mounted) return;

      final mensaje = error.statusCode == 422 ||
              error.statusCode == 401
          ? 'Correo o contraseña incorrectos.'
          : 'Error del servidor (${error.statusCode}).';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje)),
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
                            borderRadius: BorderRadius.circular(12)),
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
                          icon: Icon(_obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Ingresar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
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
