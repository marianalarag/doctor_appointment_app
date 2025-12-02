import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
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
    'Pacientes por Médico'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardBloc>().add(LoadDashboardData());
    });
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
              context.read<DashboardBloc>().add(RefreshDashboardData());
            },
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
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
        return _buildPatientsPerDoctorChart(state);
      default:
        return const Center(child: Text('Gráfica no disponible'));
    }
  }

  // Gráfica 1: Citas por Mes (Gráfica de Barras)
  Widget _buildMonthlyAppointmentsChart(DashboardLoaded state) {
    // Datos de ejemplo - en una app real estos vendrían de Firebase
    final monthlyData = [
      {'month': 'Ene', 'appointments': 12},
      {'month': 'Feb', 'appointments': 18},
      {'month': 'Mar', 'appointments': 15},
      {'month': 'Abr', 'appointments': 22},
      {'month': 'May', 'appointments': 19},
      {'month': 'Jun', 'appointments': 25},
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 30,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.teal.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${monthlyData[groupIndex]['month']}\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '${monthlyData[groupIndex]['appointments']} citas',
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              );
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
                if (index >= 0 && index < monthlyData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      monthlyData[index]['month'] as String,
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
        barGroups: monthlyData.asMap().entries.map((entry) {
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

  // Gráfica 2: Estado de Citas (Gráfica de Pie)
  Widget _buildAppointmentsStatusChart(DashboardLoaded state) {
    // Datos de ejemplo basados en el estado actual
    final statusData = [
      {'status': 'Completadas', 'count': state.totalCitas - state.citasPendientes, 'color': Colors.green},
      {'status': 'Pendientes', 'count': state.citasPendientes, 'color': Colors.orange},
      {'status': 'Canceladas', 'count': (state.totalCitas * 0.1).toInt(), 'color': Colors.red},
    ];

    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40,
        sections: statusData.map((data) {
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
            // Interactividad: mostrar tooltip al tocar
          },
        ),
      ),
    );
  }

  // Gráfica 3: Pacientes por Médico (Gráfica de Líneas)
  Widget _buildPatientsPerDoctorChart(DashboardLoaded state) {
    // Datos de ejemplo - en una app real estos vendrían de Firebase
    final doctorData = [
      {'doctor': 'Dr. García', 'patients': 45},
      {'doctor': 'Dr. López', 'patients': 38},
      {'doctor': 'Dr. Martínez', 'patients': 52},
      {'doctor': 'Dr. Rodríguez', 'patients': 29},
      {'doctor': 'Dr. Hernández', 'patients': 41},
    ];

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < doctorData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      doctorData[index]['doctor'] as String,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.teal,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
              reservedSize: 40,
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
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d), width: 1),
        ),
        minX: 0,
        maxX: doctorData.length.toDouble() - 1,
        minY: 0,
        maxY: 60,
        lineBarsData: [
          LineChartBarData(
            spots: doctorData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return FlSpot(index.toDouble(), (data['patients'] as int).toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.teal,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.teal.withOpacity(0.3),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.teal.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final doctorIndex = spot.x.toInt();
                return LineTooltipItem(
                  '${doctorData[doctorIndex]['doctor']}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '${doctorData[doctorIndex]['patients']} pacientes',
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend(DashboardLoaded state) {
    switch (_currentChartIndex) {
      case 0:
        return const Column(
          children: [
            Text(
              'Leyenda:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            SizedBox(height: 8),
            Text(
              'Cada barra representa el total de citas agendadas en un mes específico. '
                  'Toca las barras para ver detalles.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case 1:
        return Column(
          children: [
            const Text(
              'Distribución de Estados:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem(Colors.green, 'Completadas'),
                _buildLegendItem(Colors.orange, 'Pendientes'),
                _buildLegendItem(Colors.red, 'Canceladas'),
              ],
            ),
          ],
        );
      case 2:
        return const Column(
          children: [
            Text(
              'Leyenda:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
            SizedBox(height: 8),
            Text(
              'La línea muestra la cantidad de pacientes atendidos por cada médico. '
                  'Toca los puntos para ver detalles específicos.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
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
              'Resumen de Datos en Tiempo Real',
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
                _buildSummaryItem('Pacientes Únicos', state.totalPacientes.toString(), Icons.people),
                _buildSummaryItem('Citas Esta Semana', state.citasSemana.toString(), Icons.event_note),
              ],
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
      Colors.red,
    ];
    return colors[index % colors.length];
  }
}