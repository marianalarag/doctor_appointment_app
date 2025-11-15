// dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Agregar esta importación
import 'dashboard_bloc.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardBloc()..add(LoadDashboardData()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard Médico'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state is DashboardLoading) {
              return _buildLoadingState();
            } else if (state is DashboardError) {
              return _buildErrorState(context, state.message); // Pasar context aquí
            } else if (state is DashboardLoaded) {
              return _buildDashboardContent(context, state); // Pasar context aquí
            } else {
              return _buildInitialState();
            }
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.teal),
          SizedBox(height: 16),
          Text('Cargando dashboard...'),
        ],
      ),
    );
  }

  // Agregar context como parámetro
  Widget _buildErrorState(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $message', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.read<DashboardBloc>().add(LoadDashboardData()),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return const Center(
      child: Text('Presiona cargar para ver los datos'),
    );
  }

  // Agregar context como parámetro
  Widget _buildDashboardContent(BuildContext context, DashboardLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nombre del médico
          _buildMedicoHeader(state.medicoNombre),
          const SizedBox(height: 24),

          // Grid de métricas
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildMetricCard(
                icon: Icons.calendar_today,
                title: 'Total Citas',
                value: state.totalCitas.toString(),
                color: Colors.blue,
              ),
              _buildMetricCard(
                icon: Icons.pending_actions,
                title: 'Citas Pendientes',
                value: state.citasPendientes.toString(),
                color: Colors.orange,
              ),
              _buildMetricCard(
                icon: Icons.people,
                title: 'Total Pacientes',
                value: state.totalPacientes.toString(),
                color: Colors.green,
              ),
              _buildMetricCard(
                icon: Icons.today,
                title: 'Citas Hoy',
                value: state.citasHoy.toString(),
                color: Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Próximas citas
          _buildProximasCitas(state.proximasCitas),

          // Botón de recarga
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                context.read<DashboardBloc>().add(RefreshDashboardData());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar Datos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicoHeader(String medicoNombre) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.teal, width: 2),
              ),
              child: const Icon(Icons.medical_services, color: Colors.teal, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dr. $medicoNombre',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Panel de Control Médico',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProximasCitas(List<Map<String, dynamic>> citas) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.schedule, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Próximas Citas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (citas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No hay citas próximas',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...citas.map((cita) => _buildCitaItem(cita)),
          ],
        ),
      ),
    );
  }

  Widget _buildCitaItem(Map<String, dynamic> cita) {
    // Verificar si fecha_hora existe y es un Timestamp
    final dynamic fechaHora = cita['fecha_hora'];
    DateTime fecha;

    if (fechaHora is Timestamp) {
      fecha = fechaHora.toDate();
    } else if (fechaHora is DateTime) {
      fecha = fechaHora;
    } else {
      // Si no hay fecha válida, usar fecha actual
      fecha = DateTime.now();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.teal, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Paciente: ${cita['paciente_id'] ?? 'No especificado'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(fecha)} - ${cita['hora'] ?? 'Sin hora'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (cita['motivo'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Motivo: ${cita['motivo']}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(cita['estado']),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              cita['estado'] ?? 'pendiente',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmada':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'cancelada':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}