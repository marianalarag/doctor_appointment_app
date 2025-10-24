import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_service.dart';
import 'agendar_cita.dart';

class CalendarioPage extends StatefulWidget {
  const CalendarioPage({super.key});

  @override
  State<CalendarioPage> createState() => _CalendarioPageState();
}

class _CalendarioPageState extends State<CalendarioPage> {
  final FirebaseService _service = FirebaseService();
  final user = FirebaseAuth.instance.currentUser;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendario de Citas'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header del calendario
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatearMesAnio(_focusedDay),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.today),
                    onPressed: () {
                      setState(() {
                        _focusedDay = DateTime.now();
                        _selectedDay = DateTime.now();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // Selector de día
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _seleccionarDia,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[50],
                      foregroundColor: Colors.teal,
                    ),
                    child: Text(
                      _selectedDay == null
                          ? 'Seleccionar día'
                          : 'Día: ${_formatearFecha(_selectedDay!)}',
                    ),
                  ),
                ),
                if (_selectedDay != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedDay = null;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Lista de citas
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _service.obtenerTodasLasCitas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay citas programadas',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                final citas = snapshot.data!.docs;
                final citasFiltradas = _selectedDay == null
                    ? citas
                    : _filtrarCitasPorDia(citas, _selectedDay!);

                if (citasFiltradas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _selectedDay == null
                              ? 'No hay citas programadas'
                              : 'No hay citas para el ${_formatearFecha(_selectedDay!)}',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: citasFiltradas.length,
                  itemBuilder: (context, index) {
                    final doc = citasFiltradas[index];
                    final cita = doc.data() as Map<String, dynamic>;

                    // Usar 'fecha' en lugar de 'fecha_hora'
                    final fecha = (cita['fecha'] as Timestamp).toDate();
                    final docId = doc.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getColorEspecialidad(cita['id_medico']),
                          child: Text(
                            '${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                        title: Text(
                          'Dr. ${cita['id_medico']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paciente: ${cita['nombre_paciente'] ?? 'Usuario'}'),
                            Text('Fecha: ${_formatearFechaHora(fecha)}'),
                            Text('Motivo: ${cita['motivo']}'),
                          ],
                        ),
                        trailing: Chip(
                          label: Text(
                            cita['estado'] ?? 'pendiente',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          backgroundColor: _getColorEstado(cita['estado']),
                        ),
                        onTap: () {
                          _mostrarDetallesCita(cita, fecha);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AgendarCitaPage()),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Future<void> _seleccionarDia() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      setState(() {
        _selectedDay = picked;
      });
    }
  }

  List<QueryDocumentSnapshot<Object?>> _filtrarCitasPorDia(
      List<QueryDocumentSnapshot<Object?>> citas, DateTime dia) {
    return citas.where((citaDoc) {
      final cita = citaDoc.data() as Map<String, dynamic>;
      final fecha = (cita['fecha'] as Timestamp).toDate(); // Usando 'fecha'
      return fecha.year == dia.year &&
          fecha.month == dia.month &&
          fecha.day == dia.day;
    }).toList();
  }

  void _mostrarDetallesCita(Map<String, dynamic> cita, DateTime fecha) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalles de la Cita'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoItem('Médico:', 'Dr. ${cita['id_medico']}'),
              _buildInfoItem('Paciente:', cita['nombre_paciente'] ?? 'Usuario'),
              _buildInfoItem('Fecha:', _formatearFecha(fecha)),
              _buildInfoItem('Hora:', _formatearHora(fecha)),
              _buildInfoItem('Motivo:', cita['motivo']),
              _buildInfoItem('Estado:', cita['estado'] ?? 'pendiente'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(valor),
          ),
        ],
      ),
    );
  }

  Color _getColorEstado(String? estado) {
    switch (estado) {
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

  Color _getColorEspecialidad(String? especialidad) {
    final colores = {
      'Cardiólogo': Colors.red,
      'Dermatólogo': Colors.blue,
      'Ginecólogo': Colors.pink,
      'Pediatra': Colors.green,
      'Psicólogo': Colors.purple,
    };
    return colores[especialidad] ?? Colors.teal;
  }

  String _formatearMesAnio(DateTime fecha) {
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  String _formatearHora(DateTime fecha) {
    return '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _formatearFechaHora(DateTime fecha) {
    return '${_formatearFecha(fecha)} ${_formatearHora(fecha)}';
  }
}