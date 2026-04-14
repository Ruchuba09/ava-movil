import 'package:flutter/services.dart';

class RutFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String rut = newValue.text.trim();

    // Si el RUT comienza con 0, eliminarlo
    if (rut.startsWith('0')) rut = rut.substring(1);

    // Eliminar cualquier guion o punto del RUT
    rut = rut.replaceAll(RegExp(r'[.-]'), '');

    // Limitar a un máximo de 9 caracteres
    if (rut.length > 9) rut = rut.substring(0, 9);

    // Validar que 'k' o 'K' esté en la posición correcta o eliminarla
    if ((rut.contains('k') || rut.contains('K')) &&
        !(rut.length > 7 && (rut[7].toLowerCase() == 'k' || (rut.length > 8 && rut[8].toLowerCase() == 'k')))) {
      rut = rut.replaceAll(RegExp(r'[kK]'), '');
    }

    // Si 'k' está presente y hay caracteres adicionales, eliminarlos
    int kIndex = rut.toLowerCase().indexOf('k');
    if (kIndex != -1 && rut.length > kIndex + 1) {
      rut = rut.substring(0, kIndex + 1);
    }

    // Eliminar caracteres que no son dígitos o 'k'
    rut = rut.replaceAll(RegExp(r'[^0-9kK]'), '');

    // Formatear el RUT en el formato correcto: 12.345.678-9
    if (rut.length > 1) {
      rut = '${rut.substring(0, rut.length - 1)}-${rut[rut.length - 1]}';
      rut = rut.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.');
    }

    return newValue.copyWith(
      text: rut.toUpperCase(),
      selection: TextSelection.collapsed(offset: rut.length),
    );
  }
}
