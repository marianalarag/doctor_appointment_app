import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'login_page.dart';
import 'messages_page.dart';
import 'graphics_page.dart';

class DoctorHomePage extends StatefulWidget {
  const DoctorHomePage({super.key});

  @override
  State<DoctorHomePage> createState() => _DoctorHomePageState();
}

class _DoctorHomePageState extends State<DoctorHomePage> {
  final FirebaseService _service = FirebaseService();
  final User? _user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  // Lista de páginas para el médico
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildDoctorHomeContent(),
      _buildPacientesPage(),
      _buildCitasPage(),
      const SettingsPage(),
      const GraphicsPage()
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _pages[_currentIndex],
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Panel Médico'),
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar datos',
          onPressed: _recargarDatos,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _manejarMenuAppBar(value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Mi Perfil'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'graphics',
              child: Row(
                children: [
                  Icon(Icons.bar_chart, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Estadísticas'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Configuración'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'test_data',
              child: Row(
                children: [
                  Icon(Icons.data_usage, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Crear Datos Prueba'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cerrar Sesión'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  BottomNavigationBar _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      selectedItemColor: Colors.teal,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      elevation: 8,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "Inicio",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: "Pacientes",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: "Citas",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: "Configuración",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: "Estadísticas",
        ),
      ],
    );
  }

  void _manejarMenuAppBar(String value) {
    switch (value) {
      case 'profile':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
        break;
      case 'graphics':
        setState(() => _currentIndex = 4);
        break;
      case 'settings':
        setState(() => _currentIndex = 3);
        break;
      case 'test_data':
        _mostrarDialogoDatosPrueba();
        break;
      case 'logout':
        _cerrarSesion();
        break;
    }
  }

  void _mostrarDialogoDatosPrueba() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Datos de Prueba'),
        content: const Text('¿Quieres crear datos de prueba para las gráficas?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _agregarCitasDePrueba();
            },
            child: const Text('Crear Datos'),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarCitasDePrueba() async {
    try {
      final user = _user;
      if (user == null) return;

      final pacientesSnapshot = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('role', isEqualTo: 'patient')
          .limit(3)
          .get();

      if (pacientesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay pacientes. Crea algunos pacientes primero.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final pacientes = pacientesSnapshot.docs;
      final ahora = DateTime.now();

      for (int i = 0; i < 15; i++) {
        final pacienteIndex = i % pacientes.length;
        final paciente = pacientes[pacienteIndex];
        final pacienteData = paciente.data();

        final mesesAtras = i % 6;
        final diasVariacion = i % 30;
        final fecha = DateTime(ahora.year, ahora.month - mesesAtras, 1 + diasVariacion);

        final estados = ['pendiente', 'confirmada', 'completada', 'cancelada'];
        final estado = estados[i % estados.length];

        final horas = ['09:00', '10:30', '14:00', '16:30', '18:00'];
        final hora = horas[i % horas.length];

        final motivos = [
          'Consulta general',
          'Control rutinario',
          'Seguimiento tratamiento',
          'Revisión de resultados',
          'Consulta especializada'
        ];
        final motivo = motivos[i % motivos.length];

        await FirebaseFirestore.instance.collection('citas').add({
          'medico_id': user.uid,
          'paciente_id': paciente.id,
          'paciente_nombre': pacienteData['nombre'] ?? 'Paciente ${i + 1}',
          'paciente_email': pacienteData['email'] ?? 'paciente${i + 1}@ejemplo.com',
          'paciente_telefono': pacienteData['telefono'] ?? '555-000${i + 1}',
          'fecha': Timestamp.fromDate(fecha),
          'hora': hora,
          'motivo': motivo,
          'estado': estado,
          'observaciones': 'Cita de prueba generada automáticamente',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('15 citas de prueba creadas exitosamente'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al crear citas: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
            child: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _recargarDatos() async {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Datos actualizados'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildDoctorHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDoctorHeader(),
          const SizedBox(height: 20),

          Card(
            elevation: 3,
            child: ListTile(
              leading: const Icon(Icons.bar_chart, color: Colors.teal),
              title: const Text('Estadísticas y Gráficas'),
              subtitle: const Text('Ver análisis visual de tus citas'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                setState(() => _currentIndex = 4);
              },
            ),
          ),

          const SizedBox(height: 20),
          _buildEstadisticasRapidas(),
          const SizedBox(height: 20),
          _buildCitasProximas(),
        ],
      ),
    );
  }

  Widget _buildDoctorHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(_user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        final nombre = userData?['nombre'] ?? 'Doctor';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade50, Colors.teal.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.teal, width: 2),
                ),
                child: const Icon(
                  Icons.medical_services,
                  color: Colors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Dr. $nombre",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Bienvenido a su consultorio",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEstadisticasRapidas() {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _service.obtenerEstadisticasMedico(_user!.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              'Citas Hoy',
              stats['citasHoy'].toString(),
              Icons.today,
              Colors.blue.shade400,
            ),
            _buildStatCard(
              'Pendientes',
              stats['citasPendientes'].toString(),
              Icons.pending_actions,
              Colors.orange.shade400,
            ),
            _buildStatCard(
              'Total Citas',
              stats['totalCitas'].toString(),
              Icons.calendar_today,
              Colors.green.shade400,
            ),
            _buildStatCard(
              'Pacientes',
              stats['totalPacientes'].toString(),
              Icons.people,
              Colors.purple.shade400,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitasProximas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Próximas Citas",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _currentIndex = 2),
              child: const Text(
                'Ver todas',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.teal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _service.obtenerCitasMedicoConPacientes(_user!.uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final ahora = DateTime.now();
            final citas = snapshot.data!
                .where((cita) {
              // CORRECCIÓN: Verificar que fecha no sea null
              final fechaField = cita['fecha'] as Timestamp?;
              if (fechaField == null) return false;

              return cita['estado'] == 'pendiente' &&
                  fechaField.toDate().isAfter(ahora);
            })
                .toList()
              ..sort((a, b) {
                // CORRECCIÓN: Manejar fechas null
                final fechaA = (a['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
                final fechaB = (b['fecha'] as Timestamp?)?.toDate() ?? DateTime.now();
                return fechaA.compareTo(fechaB);
              });

            if (citas.isEmpty) {
              return _buildEmptyState(
                'No hay citas próximas',
                'Las próximas citas aparecerán aquí',
                Icons.calendar_today,
                height: 120,
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: citas.length > 3 ? 3 : citas.length,
              itemBuilder: (context, index) {
                return _buildCitaCardMedico(citas[index]);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildCitaCardMedico(Map<String, dynamic> cita) {
    // CORRECCIÓN: Manejar fecha null
    final fechaField = cita['fecha'] as Timestamp?;

    if (fechaField == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Colors.grey, size: 18),
          ),
          title: Text(
            cita['paciente_nombre'] ?? 'Paciente',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          subtitle: const Text(
            'Fecha no disponible',
            style: TextStyle(fontSize: 11),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.visibility, size: 16),
            color: Colors.grey,
            onPressed: () => _verDetallesCita(cita),
          ),
        ),
      );
    }

    final fecha = fechaField.toDate(); // CORRECCIÓN: Usar fechaField

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.teal, size: 18),
        ),
        title: Text(
          cita['paciente_nombre'] ?? 'Paciente',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${_formatearFecha(fecha)} - ${cita['hora']}',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              cita['motivo'] ?? 'Sin motivo especificado',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.visibility, size: 16),
          color: Colors.teal,
          onPressed: () => _verDetallesCita(cita),
        ),
      ),
    );
  }

  Widget _buildPacientesPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Mis Pacientes",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.obtenerPacientesDelMedico(_user!.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final pacientes = snapshot.data!;

                if (pacientes.isEmpty) {
                  return _buildEmptyState(
                    'No hay pacientes',
                    'Los pacientes aparecerán aquí cuando agenden citas',
                    Icons.people,
                    height: 200,
                  );
                }

                return ListView.builder(
                  itemCount: pacientes.length,
                  itemBuilder: (context, index) {
                    return _buildPacienteCard(pacientes[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPacienteCard(Map<String, dynamic> paciente) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              paciente['nombre']?.toString().substring(0, 1).toUpperCase() ?? 'P',
              style: const TextStyle(
                color: Colors.teal,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        title: Text(
          paciente['nombre'] ?? 'Paciente',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (paciente['telefono'] != null && paciente['telefono'].isNotEmpty)
              Text(
                'Tel: ${paciente['telefono']}',
                style: const TextStyle(fontSize: 11),
              ),
            Text(
              'Email: ${paciente['email'] ?? ''}',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildPacienteChip('${paciente['total_citas']} citas', Colors.blue),
                const SizedBox(width: 4),
                _buildPacienteChip('${paciente['citas_pendientes']} pendientes', Colors.orange),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.medical_services, color: Colors.teal, size: 16),
          onPressed: () => _verHistorialPaciente(paciente),
        ),
      ),
    );
  }

  Widget _buildPacienteChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 8,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCitasPage() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Todas mis Citas",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _service.obtenerCitasMedicoConPacientes(_user!.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final citas = snapshot.data!;

                if (citas.isEmpty) {
                  return _buildEmptyState(
                    'No hay citas',
                    'Las citas aparecerán aquí cuando los pacientes agenden',
                    Icons.calendar_today,
                    height: 200,
                  );
                }

                return ListView.builder(
                  itemCount: citas.length,
                  itemBuilder: (context, index) {
                    return _buildCitaCompletaCard(citas[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitaCompletaCard(Map<String, dynamic> cita) {
    // CORRECCIÓN: Manejar el caso cuando 'fecha' es null
    final fechaField = cita['fecha'] as Timestamp?;

    if (fechaField == null) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error,
              color: Colors.grey,
              size: 16,
            ),
          ),
          title: const Text(
            'Cita sin fecha',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          subtitle: const Text(
            'Esta cita no tiene fecha asignada',
            style: TextStyle(fontSize: 11),
          ),
        ),
      );
    }

    final fecha = fechaField.toDate(); // CORRECCIÓN: Usar fechaField en lugar de cita['fecha']
    final ahora = DateTime.now();
    final esPasada = fecha.isBefore(ahora);

    // El resto del código sigue igual...
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _getColorEstado(cita['estado']).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getIconoEstado(cita['estado']),
            color: _getColorEstado(cita['estado']),
            size: 16,
          ),
        ),
        title: Text(
          cita['paciente_nombre'] ?? 'Paciente',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${_formatearFecha(fecha)} - ${cita['hora']}',
              style: const TextStyle(fontSize: 11),
            ),
            Text(
              'Motivo: ${cita['motivo']}',
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getColorEstado(cita['estado']),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cita['estado'] ?? 'pendiente',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: esPasada
            ? const Icon(Icons.check_circle, color: Colors.green, size: 16)
            : PopupMenuButton(
          icon: const Icon(Icons.more_vert, size: 16),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'confirmar',
              child: Text('Confirmar'),
            ),
            const PopupMenuItem(
              value: 'cancelar',
              child: Text('Cancelar'),
            ),
          ],
          onSelected: (value) => _manejarAccionCitaMedico(value, cita),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon, {double height = 150}) {
    return Container(
      height: height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  Color _getColorEstado(String? estado) {
    switch (estado) {
      case 'confirmada':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'cancelada':
        return Colors.red;
      case 'completada':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconoEstado(String? estado) {
    switch (estado) {
      case 'confirmada':
        return Icons.check_circle;
      case 'pendiente':
        return Icons.pending;
      case 'cancelada':
        return Icons.cancel;
      case 'completada':
        return Icons.verified;
      default:
        return Icons.calendar_today;
    }
  }

  void _manejarAccionCitaMedico(String accion, Map<String, dynamic> cita) {
    switch (accion) {
      case 'confirmar':
        _confirmarCita(cita);
        break;
      case 'cancelar':
        _cancelarCita(cita);
        break;
    }
  }

  void _confirmarCita(Map<String, dynamic> cita) {
    _service.cambiarEstadoCitaMedico(
      docId: cita['doc_id'],
      estado: 'confirmada',
      observaciones: 'Cita confirmada por el médico',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cita confirmada'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _cancelarCita(Map<String, dynamic> cita) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Cita'),
        content: const Text('¿Estás seguro de que quieres cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              _service.cambiarEstadoCitaMedico(
                docId: cita['doc_id'],
                estado: 'cancelada',
                observaciones: 'Cita cancelada por el médico',
              );
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cita cancelada'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
  }

  void _verDetallesCita(Map<String, dynamic> cita) {
    final fecha = (cita['fecha'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de la Cita'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetalleItem(Icons.person, 'Paciente', cita['paciente_nombre'] ?? 'Paciente'),
              const SizedBox(height: 8),
              _buildDetalleItem(Icons.phone, 'Teléfono', cita['paciente_telefono'] ?? 'No disponible'),
              const SizedBox(height: 8),
              _buildDetalleItem(Icons.email, 'Email', cita['paciente_email'] ?? 'No disponible'),
              const SizedBox(height: 8),
              _buildDetalleItem(Icons.calendar_today, 'Fecha', _formatearFecha(fecha)),
              const SizedBox(height: 8),
              _buildDetalleItem(Icons.access_time, 'Hora', cita['hora']),
              const SizedBox(height: 8),
              _buildDetalleItem(Icons.description, 'Motivo', cita['motivo']),
              const SizedBox(height: 8),
              _buildDetalleItem(Icons.info, 'Estado', cita['estado'] ?? 'pendiente'),
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

  Widget _buildDetalleItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _verHistorialPaciente(Map<String, dynamic> paciente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Paciente: ${paciente['nombre']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total de citas: ${paciente['total_citas']}'),
              Text('Citas pendientes: ${paciente['citas_pendientes']}'),
              Text('Última cita: ${paciente['ultima_cita']}'),
              if (paciente['historial_medico'] != null && paciente['historial_medico'].isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Historial Médico:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(paciente['historial_medico']),
                  ],
                ),
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
}