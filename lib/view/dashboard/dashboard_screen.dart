import 'package:flutter/material.dart';
import 'package:avamovil/styles/colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Panel Estadístico',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Resumen de hallazgos y reportes (Tarjeta PARE).',
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 24),
          _buildFilterCard(context, isDark),
          const SizedBox(height: 24),
          _buildMainChartCard(context, isDark),
          const SizedBox(height: 24),
          _buildStatsCards(context, isDark),
        ],
      ),
    );
  }

  Widget _buildFilterCard(BuildContext context, bool isDark) {
    return Card(
      elevation: 2,
      color: isDark ? gris2Color : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'PROYECTO',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: isDark ? Colors.black12 : verde1Color,
              ),
              value: 'Todos los proyectos',
              items: ['Todos los proyectos', 'Mantenimiento Planta Pacifico', 'Montaje Planta Norte']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (val) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainChartCard(BuildContext context, bool isDark) {
    return Card(
      elevation: 2,
      color: isDark ? gris2Color : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Frecuencia por Condición (Tarjeta PARE)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Exportar'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBar(3, '1. Cond. Inseguras'),
                  _buildBar(3, '2. Herramientas'),
                  _buildBar(2, '3. Falta EPP'),
                  _buildBar(2, '4. Capacitación'),
                  _buildBar(2, '5. Procedimientos'),
                  _buildBar(1, '10. Otros'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(int value, String label) {
    const int maxVal = 4;
    final double heightFactor = value / maxVal;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 150 * heightFactor,
          decoration: BoxDecoration(
            color: verde6Color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 50,
          child: Text(
            label.substring(0, label.indexOf('.') > 0 ? label.indexOf('.') + 1 : label.length),
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCards(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Card(
            elevation: 2,
            color: isDark ? gris2Color : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: const [
                  Text('TOTAL REPORTES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('13', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Card(
            elevation: 2,
            color: isDark ? gris2Color : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: const [
                  Text('CONDICIÓN MÁS CRÍTICA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text('3', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

