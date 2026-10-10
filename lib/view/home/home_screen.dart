import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:avamovil/dev/demo_data.dart';
import 'package:avamovil/styles/colors.dart';
import 'package:avamovil/view/auth/login_screen.dart';
import 'package:avamovil/view/dashboard/dashboard_screen.dart';
import 'package:avamovil/view/reports/reports_screen.dart';
import 'package:avamovil/view/reports/new_report_screen.dart';
import 'package:avamovil/view/reports/report_detail_screen.dart';
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
    DashboardScreen(),
    ReportsScreen(),
    NewReportScreen(),
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
                          notification['read'] == true
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: verde6Color),
                      title: Text(notification['title'] as String),
                      subtitle: Text(notification['message'] as String),
                      onTap: () {
                        demoData.markNotificationRead(notification);
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
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'))
        ],
      ),
    );
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
        title: SvgPicture.asset(
          isDark ? 'assets/logos/blanco.svg' : 'assets/logos/verde.svg',
          height: 32,
          fit: BoxFit.contain,
          placeholderBuilder: (context) => Text(
            'AVA',
            style: TextStyle(
              color: isDark ? verde5Color : gris2Color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: verde5Color,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    currentUser['name'] as String,
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    currentUser['email'] as String,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),
                  Text(currentUser['role'] as String,
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Inicio'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 0;
                  _showPermissions = false;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 0;
                  _showPermissions = false;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('Reportes'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _selectedIndex = 1;
                  _showPermissions = false;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Permisos'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showPermissions = true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text('Trabajadores a cargo (${workers.length})'),
              subtitle: Text(currentUser['name'] as String),
              onTap: () {
                Navigator.pop(context);
                setState(() => _showPermissions = true);
              },
            ),
            ...workers.map((worker) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 56, right: 16),
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
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: _signOut,
            ),
            const Divider(),
            Consumer<ThemeController>(
                builder: (context, themeController, child) {
              final isDark = themeController.themeMode == ThemeMode.dark ||
                  (themeController.themeMode == ThemeMode.system &&
                      MediaQuery.of(context).platformBrightness ==
                          Brightness.dark);
              return SwitchListTile(
                title: const Text('Modo Oscuro'),
                secondary: const Icon(Icons.dark_mode),
                value: isDark,
                activeThumbColor: verde6Color,
                onChanged: (value) {
                  themeController.toggleTheme(value);
                },
              );
            }),
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
                  icon: Icons.dashboard,
                  text: 'Dashboard',
                ),
                GButton(
                  icon: Icons.list_alt,
                  text: 'Reportes',
                ),
                GButton(
                  icon: Icons.add_box,
                  text: 'Nueva Tarjeta',
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
