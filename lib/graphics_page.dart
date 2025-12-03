import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_bloc.dart';

class GraphicsPage extends StatefulWidget {
  const GraphicsPage({super.key});

  @override
  State<GraphicsPage> createState() => _GraphicsPageState();
}

class _GraphicsPageState extends State<GraphicsPage> {
  int _currentChartIndex = 0;
  final List<String> _chartTitles = [
    'Citas por Mes',
    'Estado de Citas',
    'Mis Pacientes'  // Cambiado de "Pacientes por Médico" a "Mis Pacientes"
  ];

  // Agregar Firestore y Auth
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Variables para datos reales
  List<Map<String, dynamic>> _citasPorMes = [];
  List<Map<String, dynamic>> _estadosCitas = [];
  List<Map<String, dynamic>> _misPacientes = [];
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Cargar datos reales de Firestore
      _cargarDatosReales();
      context.read<DashboardBloc>().add(LoadDashboardData());
    });
  }

  Future<void> _cargarDatosReales() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingData = true;
    });

    try {
      // 1. OBTENER CITAS REALES DEL DOCTOR ACTUAL
      final citasSnapshot = await _firestore
          .collection('citas')
          .where('id_medico', isEqualTo: user.uid)  // ← SOLO CITAS DEL DOCTOR ACTUAL
          .get();

      final citasReales = citasSnapshot.docs;

      print('Citas reales encontradas para gráficas: ${citasReales.length}');

      // 2. CALCULAR DATOS REALES PARA GRÁFICAS
      _calcularCitasPorMes(citasReales);
      _calcularEstadosCitas(citasReales);
      _calcularMisPacientes(citasReales);

      setState(() {
        _isLoadingData = false;
      });

    } catch (e) {
      print('Error cargando datos para gráficas: $e');
      setState(() {
        _isLoadingData = false;
      });
    }
  }

  void _calcularCitasPorMes(List<QueryDocumentSnapshot<Map<String, dynamic>>> citas) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

    // Inicializar contadores para cada mes
    final contadorMeses = List<int>.filled(12, 0);

    for (final doc in citas) {
      final data = doc.data();
      final fechaField = data['fecha'];

      if (fechaField is Timestamp) {
        final fechaCita = fechaField.toDate();
        final mesIndex = fechaCita.month - 1; // Los meses van de 1-12

        if (mesIndex >= 0 && mesIndex < 12) {
          contadorMeses[mesIndex]++;
        }
      }
    }

    // Crear datos para la gráfica
    _citasPorMes = meses.asMap().entries.map((entry) {
      final index = entry.key;
      final mes = entry.value;
      return {
        'month': mes,
        'appointments': contadorMeses[index],
      };
    }).toList();

    print('Citas por mes calculadas: $_citasPorMes');
  }

  void _calcularEstadosCitas(List<QueryDocumentSnapshot<Map<String, dynamic>>> citas) {
    final contadorEstados = {
      'pendiente': 0,
      'confirmada': 0,
      'completada': 0,
      'cancelada': 0,
    };

    for (final doc in citas) {
      final data = doc.data();
      final estado = data['estado'] as String? ?? 'pendiente';

      if (contadorEstados.containsKey(estado)) {
        contadorEstados[estado] = (contadorEstados[estado] ?? 0) + 1;
      } else {
        contadorEstados['pendiente'] = (contadorEstados['pendiente'] ?? 0) + 1;
      }
    }

    // Solo incluir estados que tengan citas
    _estadosCitas = [
      if (contadorEstados['pendiente']! > 0)
        {'status': 'Pendientes', 'count': contadorEstados['pendiente']!, 'color': Colors.orange},
      if (contadorEstados['confirmada']! > 0)
        {'status': 'Confirmadas', 'count': contadorEstados['confirmada']!, 'color': Colors.blue},
      if (contadorEstados['completada']! > 0)
        {'status': 'Completadas', 'count': contadorEstados['completada']!, 'color': Colors.green},
      if (contadorEstados['cancelada']! > 0)
        {'status': 'Canceladas', 'count': contadorEstados['cancelada']!, 'color': Colors.red},
    ];

    print('Estados de citas calculados: $_estadosCitas');
  }

  void _calcularMisPacientes(List<QueryDocumentSnapshot<Map<String, dynamic>>> citas) {
    final pacientesMap = <String, Map<String, dynamic>>{};

    for (final doc in citas) {
      final data = doc.data();
      final pacienteId = data['id_paciente'] as String? ?? '';
      final pacienteNombre = data['nombre_paciente'] as String? ?? 'Paciente';

      if (pacienteId.isNotEmpty) {
        if (!pacientesMap.containsKey(pacienteId)) {
          pacientesMap[pacienteId] = {
            'id': pacienteId,
            'nombre': pacienteNombre,
            'citasCount': 0,
          };
        }
        pacientesMap[pacienteId]!['citasCount'] = (pacientesMap[pacienteId]!['citasCount'] as int) + 1;
      }
    }

    // Convertir a lista y ordenar por cantidad de citas
    _misPacientes = pacientesMap.values.toList();
    _misPacientes.sort((a, b) => (b['citasCount'] as int).compareTo(a['citasCount'] as int));

    // Limitar a los primeros 10 pacientes para la gráfica
    _misPacientes = _misPacientes.take(10).toList();

    print('Mis pacientes calculados: ${_misPacientes.length} pacientes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráficas y Estadísticas'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoadingData = true;
              });
              _cargarDatosReales();
              context.read<DashboardBloc>().add(RefreshDashboardData());
            },
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (_isLoadingData || state is DashboardLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 20),
                  Text('Cargando datos para gráficas...'),
                ],
              ),
            );
          }

          if (state is DashboardError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 20),
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.read<DashboardBloc>().add(LoadDashboardData());
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          if (state is DashboardLoaded) {
            return _buildGraphicsContent(state);
          }

          return const Center(
            child: Text('Cargando gráficas...'),
          );
        },
      ),
    );
  }

  Widget _buildGraphicsContent(DashboardLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de gráficas
          _buildChartSelector(),
          const SizedBox(height: 20),

          // Tarjeta de gráfica actual
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _chartTitles[_currentChartIndex],
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Verificar si hay datos para mostrar
                  if (_currentChartIndex == 0 && _citasPorMes.isEmpty ||
                      _currentChartIndex == 1 && _estadosCitas.isEmpty ||
                      _currentChartIndex == 2 && _misPacientes.isEmpty)
                    _buildEmptyDataMessage()
                  else
                    SizedBox(
                      height: 300,
                      child: _buildCurrentChart(state),
                    ),

                  const SizedBox(height: 16),
                  _buildChartLegend(state),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Resumen de datos
          _buildDataSummary(state),
        ],
      ),
    );
  }

  Widget _buildEmptyDataMessage() {
    return SizedBox(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No hay datos suficientes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _currentChartIndex == 0
                  ? 'Agenda citas para ver estadísticas por mes'
                  : _currentChartIndex == 1
                  ? 'No hay citas registradas'
                  : 'No tienes pacientes registrados',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSelector() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona una gráfica:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_chartTitles.length, (index) {
                return ChoiceChip(
                  label: Text(_chartTitles[index]),
                  selected: _currentChartIndex == index,
                  selectedColor: Colors.teal,
                  labelStyle: TextStyle(
                    color: _currentChartIndex == index ? Colors.white : Colors.black,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _currentChartIndex = index;
                    });
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentChart(DashboardLoaded state) {
    switch (_currentChartIndex) {
      case 0:
        return _buildMonthlyAppointmentsChart(state);
      case 1:
        return _buildAppointmentsStatusChart(state);
      case 2:
        return _buildMyPatientsChart(state);  // Cambiado el nombre
      default:
        return const Center(child: Text('Gráfica no disponible'));
    }
  }

  // Gráfica 1: Citas por Mes (CON DATOS REALES)
  Widget _buildMonthlyAppointmentsChart(DashboardLoaded state) {
    final maxY = _citasPorMes.isNotEmpty
        ? (_citasPorMes.map((m) => m['appointments'] as int).reduce((a, b) => a > b ? a : b) + 2).toDouble()
        : 10.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.teal.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < _citasPorMes.length) {
                return BarTooltipItem(
                  '${_citasPorMes[groupIndex]['month']}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '${_citasPorMes[groupIndex]['appointments']} ${(_citasPorMes[groupIndex]['appointments'] as int) == 1 ? 'cita' : 'citas'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                );
              }
              return BarTooltipItem('', const TextStyle());
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _citasPorMes.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _citasPorMes[index]['month'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: _citasPorMes.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (data['appointments'] as int).toDouble(),
                color: _getBarColor(index),
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Gráfica 2: Estado de Citas (CON DATOS REALES)
  Widget _buildAppointmentsStatusChart(DashboardLoaded state) {
    if (_estadosCitas.isEmpty) {
      return _buildEmptyDataMessage();
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: _estadosCitas.map((data) {
          return PieChartSectionData(
            color: data['color'] as Color,
            value: (data['count'] as int).toDouble(),
            title: '${data['count']}',
            radius: 30,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            // Interactividad
          },
        ),
      ),
    );
  }

  // Gráfica 3: MIS Pacientes (CON DATOS REALES) - MODIFICADA
  Widget _buildMyPatientsChart(DashboardLoaded state) {
    if (_misPacientes.isEmpty) {
      return _buildEmptyDataMessage();
    }

    final maxPacientes = _misPacientes.isNotEmpty
        ? (_misPacientes.map((p) => p['citasCount'] as int).reduce((a, b) => a > b ? a : b) + 2).toDouble()
        : 10.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxPacientes,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.teal.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < _misPacientes.length) {
                final paciente = _misPacientes[groupIndex];
                return BarTooltipItem(
                  '${paciente['nombre']}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '${paciente['citasCount']} ${(paciente['citasCount'] as int) == 1 ? 'cita' : 'citas'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                );
              }
              return BarTooltipItem('', const TextStyle());
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _misPacientes.length) {
                  final paciente = _misPacientes[index];
                  final nombre = paciente['nombre'] as String;
                  final iniciales = nombre.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join();

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Tooltip(
                      message: nombre,
                      child: Text(
                        iniciales,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: _misPacientes.asMap().entries.map((entry) {
          final index = entry.key;
          final paciente = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (paciente['citasCount'] as int).toDouble(),
                color: _getBarColor(index),
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartLegend(DashboardLoaded state) {
    switch (_currentChartIndex) {
      case 0:
        return Column(
          children: [
            const Text(
              'Mis Citas por Mes',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 8),
            Text(
              _citasPorMes.isEmpty
                  ? 'No tienes citas registradas por mes'
                  : 'Total de citas agendadas por mes. Datos reales de tu consultorio.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 1:
        if (_estadosCitas.isEmpty) {
          return const SizedBox();
        }
        return Column(
          children: [
            const Text(
              'Distribución de Estados',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: _estadosCitas.map((data) {
                return _buildLegendItem(
                    data['color'] as Color,
                    '${data['status']} (${data['count']})'
                );
              }).toList(),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            const Text(
              'Mis Pacientes Más Frecuentes',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 8),
            Text(
              _misPacientes.isEmpty
                  ? 'No tienes pacientes registrados'
                  : 'Pacientes ordenados por cantidad de citas. Toca las barras para ver nombres.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDataSummary(DashboardLoaded state) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen de Mis Datos',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
              children: [
                _buildSummaryItem('Total Citas', state.totalCitas.toString(), Icons.calendar_today),
                _buildSummaryItem('Citas Pendientes', state.citasPendientes.toString(), Icons.pending_actions),
                _buildSummaryItem('Mis Pacientes', state.totalPacientes.toString(), Icons.people),
                _buildSummaryItem('Citas Esta Semana', state.citasSemana.toString(), Icons.event_note),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Datos en tiempo real - Última actualización: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getBarColor(int index) {
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
    ];
    return colors[index % colors.length];
  }
}