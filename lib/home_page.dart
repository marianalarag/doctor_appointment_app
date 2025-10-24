import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agendar_cita.dart';
import 'messages_page.dart';
import 'settings_page.dart';
import 'firebase_service.dart';
import 'calendario_page.dart';
import 'citas_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _service = FirebaseService();
  final user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  final List<String> especialistas = [
    'Cardiólogo',
    'Dermatólogo',
    'Ginecólogo',
    'Pediatra',
    'Psicólogo',
  ];

  // Lista de páginas disponibles
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    // Inicializar las páginas
    _pages.addAll([
      _buildHomeContent(),
      const MessagesPage(),
      const CalendarioPage(),
      const SettingsPage(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0 ? _buildAppBar() : null,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Inicio",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: "Mensajes",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: "Calendario",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Configuración",
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Sistema de Citas Médicas'),
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.calendar_month),
          onPressed: () {
            setState(() {
              _currentIndex = 2; // Navegar a Calendario
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.list_alt),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CitasPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con información del usuario
          _buildUserHeader(),
          const SizedBox(height: 20),

          // Botones principales
          _buildActionButtons(),
          const SizedBox(height: 30),

          // Especialistas
          _buildEspecialistas(),
          const SizedBox(height: 30),

          // Tips rápidos
          _buildTipsRapidos(),
          const SizedBox(height: 30),

          // Próximas citas
          _buildProximasCitas(),
        ],
      ),
    );
  }

  Widget _buildUserHeader() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _service.obtenerUsuarioActual(),
      builder: (context, snapshot) {
        final usuario = snapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "¡Hola, ${usuario?['nombre'] ?? user?.email ?? "Usuario"}!",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            if (usuario?['telefono'] != null && usuario!['telefono'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  "Tel: ${usuario['telefono']}",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_circle),
            label: const Text("Agendar Cita"),
            onPressed: () => _abrirFormularioCita(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.medical_services),
            label: const Text("Médicos"),
            onPressed: _mostrarListaMedicos,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEspecialistas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Especialistas",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: especialistas.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Especialista seleccionado: ${especialistas[index]}'),
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text(
                      especialistas[index],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTipsRapidos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tips rápidos",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.water_drop, color: Colors.teal, size: 16),
                  SizedBox(width: 8),
                  Text("Mantente hidratado"),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.bedtime, color: Colors.teal, size: 16),
                  SizedBox(width: 8),
                  Text("Descansa adecuadamente"),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.directions_walk, color: Colors.teal, size: 16),
                  SizedBox(width: 8),
                  Text("Realiza actividad física ligera"),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.psychology, color: Colors.teal, size: 16),
                  SizedBox(width: 8),
                  Text("Evita el estrés prolongado"),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProximasCitas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Próximas Citas",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _service.obtenerProximasCitasUsuario(user!.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("No tienes citas próximas."),
                      SizedBox(height: 4),
                      Text(
                        "Agenda tu primera cita usando el botón 'Agendar Cita'",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final citas = snapshot.data!;

            return Column(
              children: [
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: citas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final cita = citas[index];
                    final fecha = (cita['fecha'] as Timestamp).toDate();
                    final docId = cita['doc_id'] as String;

                    return _buildCitaCard(cita, fecha, docId);
                  },
                ),
                if (citas.length > 3) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CitasPage()),
                      );
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Ver todas las citas'),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 16),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCitaCard(Map<String, dynamic> cita, DateTime fecha, String docId) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(25),
          ),
          child: const Icon(
            Icons.medical_services,
            color: Colors.teal,
            size: 24,
          ),
        ),
        title: Text(
          "Dr. ${cita['id_medico']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Fecha: ${_formatearFecha(fecha)}",
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              "Hora: ${cita['hora']}",
              style: const TextStyle(fontSize: 14),
            ),
            Text(
              "Motivo: ${cita['motivo']}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                cita['estado'] ?? 'pendiente',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: _getColorEstado(cita['estado']),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _manejarAccionCita(value, docId, cita),
          icon: const Icon(Icons.more_vert),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'view', child: Text('Ver Detalles')),
            PopupMenuItem(value: 'delete', child: Text('Cancelar Cita')),
          ],
        ),
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

  String _formatearFecha(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year}';
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

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detalles de la Cita'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Médico: ${cita['id_medico']}'),
            const SizedBox(height: 8),
            Text('Fecha: ${_formatearFecha(fecha)}'),
            const SizedBox(height: 8),
            Text('Hora: ${cita['hora']}'),
            const SizedBox(height: 8),
            Text('Motivo: ${cita['motivo']}'),
            const SizedBox(height: 8),
            Text('Estado: ${cita['estado'] ?? 'pendiente'}'),
          ],
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

  void _abrirFormularioCita() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgendarCitaPage()),
    );
    if (created == true) setState(() {});
  }

  void _mostrarListaMedicos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Especialistas Disponibles'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: especialistas.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.medical_services, color: Colors.teal),
                  title: Text(especialistas[index]),
                  subtitle: const Text('Especialista disponible'),
                ),
              );
            },
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
}