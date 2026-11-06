import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/auth/login_screen.dart';
import 'package:avamovil/view/reports/camera_access.dart';
import 'package:avamovil/view/reports/reports_screen.dart';
import 'package:avamovil/view/reports/new_report_screen.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:avamovil/view/reports/report_qr_scanner_screen.dart';
import 'package:avamovil/view/permissions/permissions_screen.dart';
import 'package:avamovil/controller/theme_controller.dart';
import 'package:avamovil/services/api_service.dart';
import 'package:avamovil/services/offline_reports_sync.dart';
import 'package:avamovil/services/offline_store.dart';
import 'package:avamovil/services/offline_sync_service.dart';

class HomeScreen extends StatefulWidget {
  final String accessToken;
  final String? userKey;

  const HomeScreen({super.key, required this.accessToken, this.userKey});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _showPermissions = false;
  bool _isSyncing = false;
  final OfflineStore _offlineStore = OfflineStore();

  String get _userKey =>
      widget.userKey ?? OfflineStore.userKeyFor(DemoData.instance.currentUser);

  Future<void> _comprobarProyectos() async {
    final servicio = ApiService(accessToken: widget.accessToken);

    try {
      final proyectos = await servicio.obtenerProyectos();
      await _offlineStore.saveJson(
        userKey: _userKey,
        key: OfflineStore.projectsKey,
        value: proyectos,
      );

      if (!mounted) return;

      debugPrint(
        'Proyectos reales recibidos desde Laravel: ${proyectos.length}',
      );
    } on ApiException catch (error) {
      debugPrint('Error al consultar proyectos: HTTP ${error.statusCode}');
    } catch (error) {
      debugPrint('Error de conexión con proyectos: $error');
      try {
        final cachedProjects = await _offlineStore.readJson(
          userKey: _userKey,
          key: OfflineStore.projectsKey,
        );
        if (cachedProjects != null) {
          debugPrint('Proyectos cargados desde la caché local.');
        }
      } catch (cacheError) {
        debugPrint('No se pudieron leer los proyectos locales: $cacheError');
      }
    } finally {
      servicio.close();
    }
  }

  @override
  void initState() {
    super.initState();
    _comprobarProyectos();
    _syncPendingReports().whenComplete(_descargarReportesParaSinConexion);
  }

  /// Corre en segundo plano y después de subir lo pendiente, para que la copia
  /// local ya incluya esos reportes. Usa su propio cliente: sigue aunque se
  /// cambie de pantalla.
  Future<void> _descargarReportesParaSinConexion() async {
    final demoData = DemoData.instance;
    if (!demoData.isApiSession) return;

    final userKey = _userKey;
    final servicio = ApiService(accessToken: widget.accessToken);
    try {
      await OfflineReportsSync.instance.sincronizar(
        userKey: userKey,
        clave: OfflineStore.myReportsKey,
        pedirPagina: (pagina) => servicio.obtenerMisReportes(
          pagina: pagina,
          porPagina: OfflineReportsSync.porPagina,
        ),
      );
      if (!demoData.isWorker) {
        await OfflineReportsSync.instance.sincronizar(
          userKey: userKey,
          clave: OfflineStore.teamReportsKey,
          pedirPagina: (pagina) => servicio.obtenerReportesMiCuadrilla(
            pagina: pagina,
            porPagina: OfflineReportsSync.porPagina,
          ),
        );
      }
    } catch (error) {
      debugPrint('No se pudieron guardar los reportes offline: $error');
    } finally {
      servicio.close();
    }
  }

  Future<void> _syncPendingReports() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final result = await const OfflineSyncService().synchronize(
        userKey: _userKey,
        accessToken: widget.accessToken,
      );
      if (mounted && (result.synchronized > 0 || result.failed > 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.synchronized} reporte(s) sincronizado(s); '
              '${result.failed} pendiente(s) por error.',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('No se pudieron sincronizar reportes locales: $error');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al sincronizar: $error')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  List<Widget> get _widgetOptions => [
    NewReportScreen(accessToken: widget.accessToken, userKey: _userKey),
    // Sin key, Flutter reutilizaría el estado y ambas pestañas mostrarían la misma lista.
    ReportsScreen(
      key: const ValueKey('reportes-equipo'),
      accessToken: widget.accessToken,
      userKey: _userKey,
      onlyCurrentTeam: true,
    ),
    ReportsScreen(
      key: const ValueKey('reportes-propios'),
      accessToken: widget.accessToken,
      userKey: _userKey,
      onlyCurrentUser: true,
      canCloseReports: false,
    ),
  ];

  Future<void> _showNotifications() async {
    final demoData = DemoData.instance;
    final notifications = demoData.currentUserNotifications;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Notificaciones'),
        content: SizedBox(
          width: 420,
          child: notifications.isEmpty
              ? const Text('No tienes notificaciones.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final isEmergency =
                        notification['emergencyAlertId'] != null;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      tileColor: isEmergency
                          ? Colors.red.withValues(alpha: 0.08)
                          : null,
                      shape: isEmergency
                          ? RoundedRectangleBorder(
                              side: BorderSide(
                                color: Colors.red.withValues(alpha: 0.35),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            )
                          : null,
                      leading: Icon(
                        isEmergency
                            ? Icons.sos
                            : notification['read'] == true
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: isEmergency ? Colors.red : verde6Color,
                      ),
                      title: Text(
                        notification['title'] as String,
                        style: TextStyle(
                          color: isEmergency ? Colors.red.shade800 : null,
                          fontWeight: isEmergency
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(notification['message'] as String),
                      trailing: isEmergency
                          ? Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.red.shade700,
                            )
                          : null,
                      onTap: () {
                        demoData.markNotificationRead(notification);
                        final emergencyAlertId =
                            notification['emergencyAlertId'];
                        if (emergencyAlertId != null) {
                          final alert = demoData.emergencyAlerts.firstWhere(
                            (item) => item['id'] == emergencyAlertId,
                          );
                          Navigator.pop(dialogContext);
                          _showEmergencyAlertDetails(alert);
                          return;
                        }
                        final report = demoData.reports.firstWhere(
                          (item) => item['id'] == notification['reportId'],
                        );
                        Navigator.pop(dialogContext);
                        setState(() => _selectedIndex = 1);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportDetailScreen(
                              report: report,
                              isLider: demoData.canCloseReport(report),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar reportes pendientes',
            onPressed: _isSyncing ? null : _syncPendingReports,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_outlined),
          ),
          if (notifications.any((notification) => notification['read'] == true))
            TextButton.icon(
              onPressed: () {
                demoData.deleteReadNotifications();
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar leídas'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmergencyAlertDetails(Map<String, dynamic> alert) async {
    final events = alert['activityLog'] as List<Map<String, dynamic>>;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.sos, color: Colors.red, size: 36),
        title: const Text('Alerta de emergencia'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Solicitante: ${alert['sender']}'),
              Text('Encargado: ${alert['recipient']}'),
              Text('Estado: ${alert['status']}'),
              const SizedBox(height: 16),
              const Text(
                'Trazabilidad',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...events.map((event) {
                final at = event['at'] as DateTime;
                final timestamp =
                    '${at.day.toString().padLeft(2, '0')}-${at.month.toString().padLeft(2, '0')}-${at.year} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}:${at.second.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${event['description']}\n$timestamp'),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Sin conexión no se puede revocar el token, pero la sesión local se borra.
  Future<void> _revocarToken() async {
    final servicio = ApiService(
      accessToken: widget.accessToken,
      timeout: const Duration(seconds: 5),
    );
    try {
      await servicio.cerrarSesion();
    } catch (error) {
      debugPrint('No se pudo revocar el token en Laravel: $error');
    } finally {
      servicio.close();
    }
  }

  Future<void> _signOut() async {
    await _revocarToken();
    try {
      await OfflineSessionStore().clear();
    } catch (error) {
      debugPrint('No se pudo borrar la sesión offline: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo cerrar la sesión almacenada de forma segura.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _scanReportQr() async {
    if (!DemoData.instance.canScanReportQr) return;
    if (!await ensureCameraPermission(context) || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            ReportQrScannerScreen(accessToken: widget.accessToken),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final demoData = DemoData.instance;
    final currentUser = demoData.currentUser;
    final workers = demoData.currentUserWorkers;
    final isWorker = demoData.isWorker;
    final reportListTitle = isWorker ? 'Mis Reportes' : 'Todos los reportes';
    final pages = isWorker
        ? <Widget>[
            NewReportScreen(accessToken: widget.accessToken, userKey: _userKey),
            ReportsScreen(
              accessToken: widget.accessToken,
              userKey: _userKey,
              onlyCurrentUser: true,
            ),
          ]
        : _widgetOptions;
    final tabs = isWorker
        ? const [
            GButton(icon: Icons.add_box, text: 'Crear Tarjeta'),
            GButton(icon: Icons.person_outline, text: 'Mis Reportes'),
          ]
        : const [
            GButton(icon: Icons.add_box, text: 'Crear Tarjeta'),
            GButton(icon: Icons.list_alt, text: 'Todos los reportes'),
            GButton(icon: Icons.person_outline, text: 'Mis Reportes'),
          ];

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWorker ? 0 : 56,
        leading: isWorker
            ? null
            : Builder(
                builder: (context) => IconButton(
                  tooltip: 'Abrir menú',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu),
                ),
              ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.only(left: isWorker ? 16 : 0),
              child: Image.asset(
                'assets/logos/negro.png',
                color: isDark ? verde5Color : Colors.black,
                colorBlendMode: BlendMode.srcIn,
                width: 80,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (demoData.canScanReportQr)
                  IconButton(
                    tooltip: 'Escanear QR de Tarjeta PARE',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanReportQr,
                  ),
                if (isWorker)
                  IconButton(
                    tooltip: isDark
                        ? 'Cambiar a modo claro'
                        : 'Cambiar a modo oscuro',
                    icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                    onPressed: () =>
                        context.read<ThemeController>().toggleTheme(!isDark),
                  ),
                if (!isWorker)
                  AnimatedBuilder(
                    animation: demoData,
                    builder: (context, child) => IconButton(
                      tooltip: 'Notificaciones',
                      icon: Badge(
                        isLabelVisible: demoData.unreadNotificationCount > 0,
                        label: Text('${demoData.unreadNotificationCount}'),
                        child: const Icon(Icons.notifications),
                      ),
                      onPressed: _showNotifications,
                    ),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Sesión de ${currentUser['name']}',
                  onSelected: (value) {
                    if (value == 'logout') _signOut();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: SizedBox(
                        width: 210,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              currentUser['email'] as String,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              currentUser['role'] as String,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        leading: Icon(Icons.logout),
                        title: Text('Cerrar sesión'),
                      ),
                    ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: verde5Color,
                      child: Text(
                        (currentUser['name'] as String).substring(0, 1),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: isWorker
          ? null
          : Drawer(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DrawerHeader(
                          decoration: BoxDecoration(
                            color: isDark ? gris2Color : verde5Color,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Image.asset(
                                'assets/logos/negro.png',
                                color: isDark ? verde5Color : Colors.black,
                                colorBlendMode: BlendMode.srcIn,
                                width: 80,
                                height: 30,
                                fit: BoxFit.contain,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentUser['name'] as String,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    currentUser['email'] as String,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    currentUser['role'] as String,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.list_alt),
                          title: Text(reportListTitle),
                          selected: !_showPermissions && _selectedIndex == 1,
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedIndex = 1;
                              _showPermissions = false;
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: const Text('Mis Reportes'),
                          selected: !_showPermissions && _selectedIndex == 2,
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _selectedIndex = 2;
                              _showPermissions = false;
                            });
                          },
                        ),
                        if (!demoData.isApiSession)
                          ExpansionTile(
                            leading: const Icon(Icons.people_outline),
                            title: Text(
                              'Visualización y equipo (${workers.length})',
                            ),
                            children: [
                              ListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 56,
                                  right: 16,
                                ),
                                leading: const Icon(Icons.visibility_outlined),
                                title: const Text('Visualización de cuadrilla'),
                                onTap: () {
                                  Navigator.pop(context);
                                  setState(() => _showPermissions = true);
                                },
                              ),
                              ...workers.map(
                                (worker) => ListTile(
                                  dense: true,
                                  contentPadding: const EdgeInsets.only(
                                    left: 56,
                                    right: 16,
                                  ),
                                  leading: const Icon(
                                    Icons.person_outline,
                                    size: 18,
                                  ),
                                  title: Text(worker['name'] as String),
                                  subtitle: Text(worker['role'] as String),
                                  onTap: () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            WorkerProfileScreen(worker: worker),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Consumer<ThemeController>(
                          builder: (context, themeController, child) {
                            final darkMode =
                                themeController.themeMode == ThemeMode.dark ||
                                (themeController.themeMode ==
                                        ThemeMode.system &&
                                    MediaQuery.of(context).platformBrightness ==
                                        Brightness.dark);
                            return SwitchListTile(
                              title: const Text('Modo Oscuro'),
                              secondary: const Icon(Icons.dark_mode),
                              value: darkMode,
                              activeThumbColor: verde6Color,
                              onChanged: themeController.toggleTheme,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

      body: _showPermissions && !isWorker
          ? PermissionsScreen(accessToken: widget.accessToken)
          : pages.elementAt(_selectedIndex),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withValues(alpha: .1),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
            child: GNav(
              rippleColor: Colors.grey[300]!,
              hoverColor: Colors.grey[100]!,
              gap: 6,
              activeColor: Colors.black,
              iconSize: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              duration: const Duration(milliseconds: 400),
              tabBackgroundColor: verde5Color,
              color: isDark ? Colors.white : Colors.black,
              tabs: tabs,
              selectedIndex: _selectedIndex,
              onTabChange: (index) {
                setState(() {
                  _selectedIndex = index;
                  _showPermissions = false;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}
