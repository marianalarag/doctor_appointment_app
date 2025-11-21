import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';

class GraphicsPage extends StatefulWidget {
  const GraphicsPage({super.key});

  @override
  State<GraphicsPage> createState() => _GraphicsPageState();
}

class _GraphicsPageState extends State<GraphicsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _citasData = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCitasData();
  }

  Future<void> _loadCitasData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final querySnapshot = await _firestore
          .collection('citas')
          .where('medico_id', isEqualTo: user.uid)
          .get();

      final citas = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'fecha': (data['fecha'] as Timestamp).toDate(),
        };
      }).toList();

      setState(() {
        _citasData = citas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar datos: $e';
        _isLoading = false;
      });
    }
  }

  // Datos para gráfica de citas por mes
  List<BarChartGroupData> _getCitasPorMes() {
    final ahora = DateTime.now();
    final Map<int, int> citasPorMes = {};

    // Inicializar últimos 6 meses
    for (int i = 5; i >= 0; i--) {
      final mes = DateTime(ahora.year, ahora.month - i, 1);
      citasPorMes[mes.month] = 0;
    }

    // Contar citas por mes
    for (final cita in _citasData) {
      final fecha = cita['fecha'] as DateTime;
      final mes = fecha.month;
      if (citasPorMes.containsKey(mes)) {
        citasPorMes[mes] = citasPorMes[mes]! + 1;
      }
    }

    return citasPorMes.entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.toDouble(),
            color: _getColorPorMes(entry.key),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  // Datos para gráfica de estado de citas
  PieChartSectionData _getSeccionEstado(String estado, int count, Color color) {
    return PieChartSectionData(
      color: color,
      value: count.toDouble(),
      title: '$count',
      radius: 60,
      titleStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  List<PieChartSectionData> _getCitasPorEstado() {
    final Map<String, int> conteoEstados = {
      'pendiente': 0,
      'confirmada': 0,
      'completada': 0,
      'cancelada': 0,
    };

    for (final cita in _citasData) {
      final estado = cita['estado']?.toString().toLowerCase() ?? 'pendiente';
      if (conteoEstados.containsKey(estado)) {
        conteoEstados[estado] = conteoEstados[estado]! + 1;
      }
    }

    return [
      _getSeccionEstado('Pendiente', conteoEstados['pendiente']!, Colors.orange),
      _getSeccionEstado('Confirmada', conteoEstados['confirmada']!, Colors.blue),
      _getSeccionEstado('Completada', conteoEstados['completada']!, Colors.green),
      _getSeccionEstado('Cancelada', conteoEstados['cancelada']!, Colors.red),
    ];
  }

  Color _getColorPorMes(int mes) {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
    ];
    return colors[mes % colors.length];
  }

  String _getNombreMes(int mes) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return meses[mes - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas Médicas'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCitasData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : _buildGraphicsContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal),
          SizedBox(height: 16),
          Text('Cargando estadísticas...'),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCitasData,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphicsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildCitasPorMesChart(),
          const SizedBox(height: 32),
          _buildCitasPorEstadoChart(),
          const SizedBox(height: 24),
          _buildLeyendaEstados(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.analytics, size: 40, color: Colors.teal),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen Estadístico',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total de citas analizadas: ${_citasData.length}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitasPorMesChart() {
    final barGroups = _getCitasPorMes();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Citas por Mes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Distribución de citas en los últimos 6 meses',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: barGroups,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _getNombreMes(value.toInt()),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitasPorEstadoChart() {
    final sections = _getCitasPorEstado();

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado de Citas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Distribución por estado actual',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeyendaEstados() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leyenda de Estados',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            _buildLeyendaItem('Pendiente', Colors.orange),
            _buildLeyendaItem('Confirmada', Colors.blue),
            _buildLeyendaItem('Completada', Colors.green),
            _buildLeyendaItem('Cancelada', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildLeyendaItem(String texto, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(texto),
        ],
      ),
    );
  }
}