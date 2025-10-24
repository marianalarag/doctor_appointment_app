// citas_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'agendar_cita.dart';

class CitasPage extends StatefulWidget {
  const CitasPage({super.key});

  @override
  State<CitasPage> createState() => _CitasPageState();
}

class _CitasPageState extends State<CitasPage> {
  final FirebaseService _service = FirebaseService();
  final user = FirebaseAuth.instance.currentUser;
  int _filtroSeleccionado = 0; // 0: Próximas, 1: Pasadas, 2: Todas

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Usuario no autenticado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Citas'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filtros
          _buildFiltros(),
          const SizedBox(height: 8),

          // Lista de citas
          Expanded(
            child: _buildListaCitas(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () async {
          final created = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AgendarCitaPage())
          );
          if (created == true) setState(() {});
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFiltros() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: const Text('Próximas'),
              selected: _filtroSeleccionado == 0,
              onSelected: (selected) {
                setState(() {
                  _filtroSeleccionado = 0;
                });
              },
              selectedColor: Colors.teal,
              labelStyle: TextStyle(
                color: _filtroSeleccionado == 0 ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: const Text('Pasadas'),
              selected: _filtroSeleccionado == 1,
              onSelected: (selected) {
                setState(() {
                  _filtroSeleccionado = 1;
                });
              },
              selectedColor: Colors.blueGrey,
              labelStyle: TextStyle(
                color: _filtroSeleccionado == 1 ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: _filtroSeleccionado == 2,
              onSelected: (selected) {
                setState(() {
                  _filtroSeleccionado = 2;
                });
              },
              selectedColor: Colors.grey,
              labelStyle: TextStyle(
                color: _filtroSeleccionado == 2 ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaCitas() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _obtenerStreamSegunFiltro(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final citas = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: citas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final cita = citas[index];
            final fecha = (cita['fecha'] as Timestamp).toDate();
            final docId = cita['doc_id'] as String;

            return _buildCitaCard(cita, fecha, docId);
          },
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _obtenerStreamSegunFiltro() {
    final ahora = DateTime.now();

    switch (_filtroSeleccionado) {
      case 0: // Próximas
        return _service.obtenerProximasCitasUsuario(user!.uid);
      case 1: // Pasadas
        return _service.obtenerCitasDelUsuarioStream(user!.uid)
            .map((snapshot) {
          final citasPasadas = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data != null) {
              final Map<String, dynamic> citaData;
              if (data is Map<String, dynamic>) {
                citaData = Map<String, dynamic>.from(data);
              } else {
                citaData = Map<String, dynamic>.from(data as Map);
              }

              final fecha = citaData['fecha'];
              if (fecha is Timestamp) {
                final fechaCita = fecha.toDate();
                if (fechaCita.isBefore(ahora)) {
                  citaData['doc_id'] = doc.id;
                  citasPasadas.add(citaData);
                }
              }
            }
          }

          // Ordenar por fecha más reciente primero
          citasPasadas.sort((a, b) {
            final fechaA = a['fecha'] as Timestamp;
            final fechaB = b['fecha'] as Timestamp;
            return fechaB.compareTo(fechaA);
          });

          return citasPasadas;
        });
      case 2: // Todas
      default:
        return _service.obtenerCitasDelUsuarioStream(user!.uid)
            .map((snapshot) {
          final todasLasCitas = <Map<String, dynamic>>[];
          for (final doc in snapshot.docs) {
            final data = doc.data();
            if (data != null) {
              final Map<String, dynamic> citaData;
              if (data is Map<String, dynamic>) {
                citaData = Map<String, dynamic>.from(data);
              } else {
                citaData = Map<String, dynamic>.from(data as Map);
              }
              citaData['doc_id'] = doc.id;
              todasLasCitas.add(citaData);
            }
          }

          // Ordenar por fecha
          todasLasCitas.sort((a, b) {
            final fechaA = a['fecha'] as Timestamp;
            final fechaB = b['fecha'] as Timestamp;
            return fechaA.compareTo(fechaB);
          });

          return todasLasCitas;
        });
    }
  }

  Widget _buildCitaCard(Map<String, dynamic> cita, DateTime fecha, String docId) {
    final esPasada = fecha.isBefore(DateTime.now());

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: esPasada ? Colors.grey[50] : Colors.white,
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: _getColorEspecialidad(cita['id_medico']).withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Icon(
            esPasada ? Icons.history : Icons.medical_services,
            color: _getColorEspecialidad(cita['id_medico']),
            size: 24,
          ),
        ),
        title: Text(
          "Dr. ${cita['id_medico']}",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: esPasada ? Colors.grey : Colors.black,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Fecha: ${_formatearFecha(fecha)}",
              style: TextStyle(
                fontSize: 14,
                color: esPasada ? Colors.grey : null,
              ),
            ),
            Text(
              "Hora: ${cita['hora']}",
              style: TextStyle(
                fontSize: 14,
                color: esPasada ? Colors.grey : null,
              ),
            ),
            Text(
              "Motivo: ${cita['motivo']}",
              style: TextStyle(
                fontSize: 12,
                color: esPasada ? Colors.grey : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Chip(
                  label: Text(
                    cita['estado'] ?? 'pendiente',
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                  backgroundColor: _getColorEstado(cita['estado']),
                ),
                if (esPasada) ...[
                  const SizedBox(width: 4),
                  Chip(
                    label: const Text(
                      'COMPLETADA',
                      style: TextStyle(fontSize: 8, color: Colors.white),
                    ),
                    backgroundColor: Colors.blueGrey,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: !esPasada ? PopupMenuButton<String>(
          onSelected: (value) => _manejarAccionCita(value, docId, cita),
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'view', child: Text('Ver Detalles')),
            PopupMenuItem(value: 'delete', child: Text('Cancelar Cita')),
          ],
        ) : null,
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar las citas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
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

  Widget _buildEmptyState() {
    String mensaje = '';
    String icono = '';

    switch (_filtroSeleccionado) {
      case 0:
        mensaje = 'No tienes citas próximas';
        icono = '📅';
        break;
      case 1:
        mensaje = 'No tienes citas pasadas';
        icono = '🕒';
        break;
      case 2:
        mensaje = 'No tienes citas programadas';
        icono = '📋';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icono,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (_filtroSeleccionado == 0)
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgendarCitaPage()),
                  );
                },
                child: const Text('Agendar primera cita'),
              ),
          ],
        ),
      ),
    );
  }

  void _manejarAccionCita(String accion, String docId, Map<String, dynamic> cita) async {
    switch (accion) {
      case 'edit':
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AgendarCitaPage(docId: docId)),
        );
        if (changed == true) setState(() {});
        break;

      case 'view':
        _mostrarDetallesCita(cita);
        break;

      case 'delete':
        _confirmarEliminacionCita(docId);
        break;
    }
  }

  void _mostrarDetallesCita(Map<String, dynamic> cita) {
    final fecha = (cita['fecha'] as Timestamp).toDate();
    final esPasada = fecha.isBefore(DateTime.now());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalles de la Cita'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetalleItem('Médico:', 'Dr. ${cita['id_medico']}'),
              _buildDetalleItem('Paciente:', cita['nombre_paciente'] ?? 'Usuario'),
              _buildDetalleItem('Fecha:', _formatearFecha(fecha)),
              _buildDetalleItem('Hora:', cita['hora']),
              _buildDetalleItem('Motivo:', cita['motivo']),
              _buildDetalleItem('Estado:', cita['estado'] ?? 'pendiente'),
              if (esPasada)
                _buildDetalleItem('Estado:', 'COMPLETADA', color: Colors.blueGrey),
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

  Widget _buildDetalleItem(String titulo, String valor, {Color? color}) {
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
            child: Text(
              valor,
              style: color != null ? TextStyle(color: color, fontWeight: FontWeight.bold) : null,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmarEliminacionCita(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Cancelación'),
        content: const Text('¿Estás seguro de que quieres cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mantener Cita'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancelar Cita'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await _service.eliminarCita(docId: docId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita cancelada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cancelar cita: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}