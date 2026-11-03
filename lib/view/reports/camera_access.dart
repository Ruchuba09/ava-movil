import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureCameraPermission(BuildContext context) async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return true;
  }

  PermissionStatus status;
  try {
    status = await Permission.camera.request();
  } on PlatformException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo solicitar el permiso de cámara: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    }
    return false;
  }
  if (status.isGranted) return true;
  if (!context.mounted) return false;

  final openSettings = status.isPermanentlyDenied || status.isRestricted;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.no_photography_outlined),
      title: const Text('Se requiere acceso a la cámara'),
      content: Text(
        openSettings
            ? 'El permiso de cámara está bloqueado. Habilítalo en los ajustes '
                'de la aplicación para tomar evidencia o escanear códigos QR.'
            : 'Permite el acceso a la cámara para tomar evidencia o escanear '
                'códigos QR.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cerrar'),
        ),
        if (openSettings)
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final opened = await openAppSettings();
                if (!opened && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('No se pudieron abrir los ajustes de la app.'),
                    ),
                  );
                }
              } on PlatformException catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No se pudieron abrir los ajustes: '
                        '${error.message ?? error.code}',
                      ),
                    ),
                  );
                }
              }
            },
            child: const Text('Abrir ajustes'),
          ),
      ],
    ),
  );
  return false;
}
