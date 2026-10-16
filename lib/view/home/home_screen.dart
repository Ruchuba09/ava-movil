import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/auth/login_screen.dart';
import 'package:avamovil/view/reports/reports_screen.dart';
import 'package:avamovil/view/reports/new_report_screen.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
import 'package:avamovil/view/reports/report_qr_scanner_screen.dart';
import 'package:avamovil/view/permissions/permissions_screen.dart';
import 'package:avamovil/controller/theme_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _showPermissions = false;

  static const List<Widget> _widgetOptions = <Widget>[
    NewReportScreen(),
    ReportsScreen(onlyCurrentTeam: true),
    ReportsScreen(onlyCurrentUser: true),
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
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        notification['emergencyAlertId'] != null
                            ? Icons.sos
                            : notification['read'] == true
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                        color: notification['emergencyAlertId'] != null
                            ? Colors.red
                            : verde6Color,
                      ),
                      title: Text(notification['title'] as String),
                      subtitle: Text(notification['message'] as String),
                      onTap: () {
                        demoData.markNotificationRead(notification);
                        final emergencyAlertId =
                            notification['emergencyAlertId'];
                        if (emergencyAlertId != null) {
                          final alert = demoData.emergencyAlerts.firstWhere(
                              (item) => item['id'] == emergencyAlertId);
                          Navigator.pop(dialogContext);
                          _showEmergencyAlertDetails(alert);
                          return;
                        }
                        final report = demoData.reports.firstWhere(
                            (item) => item['id'] == notification['reportId']);
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
              child: const Text('Cerrar'))
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
              const Text('Trazabilidad',
                  style: TextStyle(fontWeight: FontWeight.bold)),
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

  void _triggerEmergencyAlert() {
    try {
      final alert = DemoData.instance.triggerEmergencyAlert();
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alerta registrada para ${alert['recipient']}.'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } on StateError catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  void _signOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final demoData = DemoData.instance;
    final currentUser = demoData.currentUser;
    final workers = demoData.currentUserWorkers;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 56,
        leading: Builder(
          builder: (context) => Row(
            children: [
              IconButton(
                tooltip: 'Abrir menú',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu),
              ),
            ],
          ),
        ),
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              isDark ? 'assets/logos/verde.svg' : 'assets/logos/negro.svg',
              width: 72,
              height: 30,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 10),
            _EmergencyHoldButton(onTriggered: _triggerEmergencyAlert),
          ],
        ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Escanear QR de Tarjeta PARE',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const ReportQrScannerScreen(),
                    ),
                  ),
                ),
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
                            Text(currentUser['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(currentUser['email'] as String,
                                style: Theme.of(context).textTheme.bodySmall),
                            Text(currentUser['role'] as String,
                                style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                        value: 'logout',
                        child: ListTile(
                            leading: Icon(Icons.logout),
                            title: Text('Cerrar sesión'))),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: verde5Color,
                      child: Text(
                          (currentUser['name'] as String).substring(0, 1),
                          style: const TextStyle(
                              color: Colors.black, fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: Drawer(
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
                        SvgPicture.asset(
                          isDark
                              ? 'assets/logos/verde.svg'
                              : 'assets/logos/negro.svg',
                          width: 72,
                          height: 30,
                          fit: BoxFit.contain,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentUser['name'] as String,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              currentUser['email'] as String,
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                            Text(currentUser['role'] as String,
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: const Text('Reportes de la cuadrilla'),
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
                  ExpansionTile(
                    leading: const Icon(Icons.people_outline),
                    title: Text('Visualización y equipo (${workers.length})'),
                    children: [
                      ListTile(
                        contentPadding:
                            const EdgeInsets.only(left: 56, right: 16),
                        leading: const Icon(Icons.visibility_outlined),
                        title: const Text('Visualización de cuadrilla'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _showPermissions = true);
                        },
                      ),
                      ...workers.map((worker) => ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.only(left: 56, right: 16),
                            leading: const Icon(Icons.person_outline, size: 18),
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
                          )),
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
                              (themeController.themeMode == ThemeMode.system &&
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
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Cerrar sesión'),
                    onTap: _signOut,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _showPermissions
          ? const PermissionsScreen()
          : _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              color: Colors.black.withValues(alpha: .1),
            )
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
              tabs: const [
                GButton(
                  icon: Icons.add_box,
                  text: 'Crear Tarjeta',
                ),
                GButton(
                  icon: Icons.list_alt,
                  text: 'Reportes cuadrilla',
                ),
                GButton(
                  icon: Icons.person_outline,
                  text: 'Mis Reportes',
                ),
              ],
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

class _EmergencyHoldButton extends StatefulWidget {
  final VoidCallback onTriggered;

  const _EmergencyHoldButton({required this.onTriggered});

  @override
  State<_EmergencyHoldButton> createState() => _EmergencyHoldButtonState();
}

class _EmergencyHoldButtonState extends State<_EmergencyHoldButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _holdController;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener(_onHoldStatusChanged);
  }

  void _onHoldStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || !_isHolding) return;
    _isHolding = false;
    widget.onTriggered();
    _holdController.value = 0;
  }

  void _startHold(PointerDownEvent _) {
    if (_isHolding) return;
    _isHolding = true;
    _holdController.forward(from: 0);
  }

  void _cancelHold(PointerEvent _) {
    if (!_isHolding) return;
    _isHolding = false;
    _holdController.stop();
    _holdController.value = 0;
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Mantén presionado 3 segundos para avisar a tu encargado',
        child: Semantics(
          label:
              'SOS. Mantén presionado tres segundos para avisar a tu encargado',
          button: true,
          child: Listener(
            onPointerDown: _startHold,
            onPointerUp: _cancelHold,
            onPointerCancel: _cancelHold,
            child: SizedBox(
              width: 76,
              height: 48,
              child: AnimatedBuilder(
                animation: _holdController,
                builder: (context, child) => Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFC62828),
                          width: 2,
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            color: Color(0xFFC62828),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _holdController.value,
                          minHeight: 3,
                          backgroundColor:
                              const Color(0xFFC62828).withValues(alpha: 0.15),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFC62828)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
