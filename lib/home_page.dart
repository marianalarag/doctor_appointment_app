import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agendar_cita.dart';
import 'messages_page.dart';
import 'settings_page.dart';
import 'firebase_service.dart';
import 'calendario_page.dart';
import 'citas_page.dart';
import 'doctor_home_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseService _service = FirebaseService();
  final User? user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  String userName = 'Usuario';
  String userEmail = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _doctoresDisponibles = [];

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _cargarDoctoresDisponibles();
    _pages = [
      _buildHomeContent(),
      const MessagesPage(),
      const CalendarioPage(),
      const SettingsPage(),
    ];
  }

  Future<void> _loadUserData() async {
    if (user == null) {
      if (mounted) {
        setState(() {
          userName = 'Usuario';
          userEmail = '';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final userData = await _service.obtenerUsuarioActual();

      String nombreUsuario = 'Usuario';
      String emailUsuario = user?.email ?? '';

      if (userData != null) {
        if (userData['nombre'] != null && userData['nombre'].toString().isNotEmpty) {
          nombreUsuario = userData['nombre'].toString();
        } else if (userData['email'] != null) {
          nombreUsuario = userData['email'].toString().split('@').first;
        } else if (user?.email != null) {
          nombreUsuario = user!.email!.split('@').first;
        }

        if (userData['email'] != null) {
          emailUsuario = userData['email'].toString();
        }
      } else if (user?.email != null) {
        nombreUsuario = user!.email!.split('@').first;
        emailUsuario = user!.email!;
      }

      if (mounted) {
        setState(() {
          userName = nombreUsuario;
          userEmail = emailUsuario;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          userName = user?.email?.split('@').first ?? 'Usuario';
          userEmail = user?.email ?? '';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cargarDoctoresDisponibles() async {
    try {
      final doctores = await _service.obtenerMedicos();
      if (mounted) {
        setState(() {
          _doctoresDisponibles = doctores;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _doctoresDisponibles = [];
        });
      }
    }
  }

  Future<void> _recargarDatos() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    await _loadUserData();
    await _cargarDoctoresDisponibles();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white),
              SizedBox(width: 8),
              Text('Datos actualizados correctamente'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user!.uid)
          .snapshots()
          : null,
      builder: (context, userSnapshot) {
        if (_isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 20),
                  Text('Cargando tu perfil...'),
                ],
              ),
            ),
          );
        }

        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final role = userData?['role'] ?? 'patient';

        if (role == 'doctor') {
          return const DoctorHomePage();
        }

        return Scaffold(
          appBar: _currentIndex == 0 ? _buildAppBar() : null,
          body: RefreshIndicator(
            onRefresh: _recargarDatos,
            color: Colors.teal,
            backgroundColor: Colors.white,
            child: _pages[_currentIndex],
          ),
          bottomNavigationBar: _buildBottomNavigationBar(),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Sistema de Citas Médicas'),
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
        IconButton(
          icon: const Icon(Icons.calendar_month),
          onPressed: () {
            setState(() {
              _currentIndex = 2;
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
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 20),
          _buildActionButtons(),
          const SizedBox(height: 25),
          _buildEspecialistas(),
          const SizedBox(height: 25),
          _buildTipsRapidos(),
          const SizedBox(height: 25),
          _buildProximasCitasCompact(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade50, Colors.teal.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.teal, width: 2),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.teal,
                  size: 40,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PACIENTE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "¡Hola, $userName!",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.teal,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (userEmail.isNotEmpty) ...[
            Text(
              userEmail,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          const Text(
            'Sistema de agendamiento de citas médicas',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Acciones Rápidas",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.add_circle,
                title: 'Agendar Cita',
                subtitle: 'Nueva consulta',
                color: Colors.teal,
                onTap: _abrirFormularioCita,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                icon: Icons.medical_services,
                title: 'Médicos',
                subtitle: 'Especialistas',
                color: Colors.blue,
                onTap: _mostrarListaMedicos,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          height: 90,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEspecialistas() {
    // Lista de 5 especialistas estáticos/de ejemplo
    final especialistasEjemplo = [
      {
        'nombre': 'Dra. Ana García',
        'especialidad': 'Cardióloga',
        'icono': Icons.favorite,
        'color': Colors.red,
      },
      {
        'nombre': 'Dr. Carlos López',
        'especialidad': 'Dermatólogo',
        'icono': Icons.face,
        'color': Colors.blue,
      },
      {
        'nombre': 'Dra. María Rodríguez',
        'especialidad': 'Pediatra',
        'icono': Icons.child_care,
        'color': Colors.green,
      },
      {
        'nombre': 'Dr. Juan Pérez',
        'especialidad': 'Ginecólogo',
        'icono': Icons.woman,
        'color': Colors.pink,
      },
      {
        'nombre': 'Dra. Sofía Martínez',
        'especialidad': 'Psicóloga',
        'icono': Icons.psychology,
        'color': Colors.purple,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Especialistas Disponibles",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 10), // Reducido de 12
        SizedBox(
          height: 100, // Reducido de 120
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: especialistasEjemplo.length,
            itemBuilder: (context, index) {
              final especialista = especialistasEjemplo[index];
              return _buildSpecialistCardEjemplo(especialista);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpecialistCardEjemplo(Map<String, dynamic> especialista) {
    return Container(
      width: 100, // Reducido de 130
      margin: const EdgeInsets.only(right: 8), // Reducido de 12
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Reducido de 16
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.1),
            blurRadius: 5, // Reducido de 8
            offset: const Offset(0, 2), // Reducido de 3
          ),
        ],
        border: Border.all(color: Colors.teal.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(especialista['icono'] as IconData, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Especialista: ${especialista['especialidad']}'),
                ],
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.teal,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8), // Reducido de 12
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32, // Reducido de 40
                height: 32, // Reducido de 40
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (especialista['color'] as Color).withOpacity(0.2),
                      (especialista['color'] as Color).withOpacity(0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  especialista['icono'] as IconData,
                  color: especialista['color'] as Color,
                  size: 16, // Reducido de 20
                ),
              ),
              const SizedBox(height: 6), // Reducido de 8
              Text(
                especialista['especialidad'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10, // Reducido de 12
                  fontWeight: FontWeight.w600,
                  color: Colors.teal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialistCardAvanzada(Map<String, dynamic> especialista) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar con inicial
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: (especialista['color'] as Color).withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Center(
              child: CircleAvatar(
                radius: 25,
                backgroundColor: especialista['color'] as Color,
                child: Text(
                  especialista['inicial'] as String,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Información
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  especialista['especialidad'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  especialista['nombre'] as String,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    especialista['experiencia'] as String,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDoctoresPorEspecialidad(String especialidad, List<Map<String, dynamic>> doctores) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              _getIconoEspecialidad(especialidad),
              color: Colors.teal,
            ),
            const SizedBox(width: 12),
            Text('$especialidad'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: doctores.isEmpty
              ? const Center(
            child: Text('No hay doctores en esta especialidad'),
          )
              : ListView.builder(
            shrinkWrap: true,
            itemCount: doctores.length,
            itemBuilder: (context, index) {
              final doctor = doctores[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    child: Text(
                      doctor['nombre']?.toString().substring(0, 1) ?? 'D',
                      style: const TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    doctor['nombre']?.toString() ?? 'Doctor',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${doctor['especialidad'] ?? 'Especialista'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirFormularioCitaConDoctor(doctor);
                  },
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

  Widget _buildTipsRapidos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tips de Salud",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 12),
        Container(
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
          child: Column(
            children: [
              _buildTipItem(Icons.water_drop, "Bebe al menos 8 vasos de agua al día"),
              const SizedBox(height: 10),
              _buildTipItem(Icons.bedtime, "Duerme entre 7-9 horas diarias"),
              const SizedBox(height: 10),
              _buildTipItem(Icons.directions_walk, "Camina al menos 30 minutos al día"),
              const SizedBox(height: 10),
              _buildTipItem(Icons.psychology, "Practica meditación o mindfulness"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.teal, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildProximasCitasCompact() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Próximas Citas",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(height: 12),

        // CAMBIADO: Usar Stream en lugar de Future
        StreamBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('proximas_citas_${user?.uid}_${DateTime.now().millisecondsSinceEpoch}'),
          stream: user != null
              ? _service.obtenerProximasCitasUsuarioStream(user!.uid) // CAMBIADO A Stream
              : null,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingCardCompact();
            }

            if (snapshot.hasError) {
              print('Error cargando citas: ${snapshot.error}');
              return _buildErrorCardCompact('Error al cargar citas');
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyCardCompact();
            }

            final citas = snapshot.data!;
            return Column(
              children: [
                ...citas.take(2).map((cita) {
                  final fechaTimestamp = cita['fecha'];
                  DateTime fecha;
                  if (fechaTimestamp is Timestamp) {
                    fecha = fechaTimestamp.toDate();
                  } else {
                    fecha = DateTime.now();
                  }
                  final docId = cita['doc_id']?.toString() ?? '';
                  return _buildCitaCardCompact(cita, fecha, docId);
                }),
                if (citas.length > 2) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CitasPage()),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: Text('Ver todas las citas (${citas.length})'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.teal,
                      ),
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

  Widget _buildCitaCardCompact(Map<String, dynamic> cita, DateTime fecha, String docId) {
    // MODIFICADO: Usar nombre_medico que ya viene del servicio
    final nombreMedico = cita['nombre_medico'] ?? 'Dr. No especificado';

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade300, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.medical_services,
            color: Colors.white,
            size: 22,
          ),
        ),
        title: Text(
          nombreMedico, // AHORA MUESTRA NOMBRE REAL, NO CÓDIGO
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatearFecha(fecha),
                  style: const TextStyle(fontSize: 11),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.access_time, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  cita['hora']?.toString() ?? '--:--',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Chip(
              label: Text(
                cita['estado']?.toString() ?? 'pendiente',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _getColorEstado(cita['estado']?.toString()),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _manejarAccionCita(value, docId, cita),
          icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.blue),
                  SizedBox(width: 6),
                  Text('Editar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 16, color: Colors.teal),
                  SizedBox(width: 6),
                  Text('Ver Detalles'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 16, color: Colors.red),
                  SizedBox(width: 6),
                  Text('Cancelar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCardCompact() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(color: Colors.teal, strokeWidth: 2),
              SizedBox(height: 12),
              Text('Cargando citas...', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCardCompact(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 24),
            const SizedBox(height: 8),
            Text(
              'Error al cargar',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 4),
            Text(
              message.length > 50 ? '${message.substring(0, 50)}...' : message,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCardCompact() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(Icons.calendar_today, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              "No tienes citas próximas",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              "Usa 'Agendar Cita' para programar una",
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
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
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }

  void _manejarAccionCita(String accion, String docId, Map<String, dynamic> cita) async {
    switch (accion) {
      case 'edit':
        final changed = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AgendarCitaPage(docId: docId)),
        );
        if (changed == true && mounted) setState(() {});
        break;

      case 'view':
        _mostrarDetallesCita(cita);
        break;

      case 'delete':
        await _confirmarEliminacionCita(docId);
        break;
    }
  }

  void _mostrarDetallesCita(Map<String, dynamic> cita) {
    final fechaTimestamp = cita['fecha'];
    DateTime fecha;
    if (fechaTimestamp is Timestamp) {
      fecha = fechaTimestamp.toDate();
    } else {
      fecha = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medical_services, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            const Text('Detalles de la Cita'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetalleItem(Icons.person, 'Médico', cita['nombre_medico'] ?? 'Dr. No especificado'),
            const Divider(height: 20),
            _buildDetalleItem(Icons.calendar_today, 'Fecha', _formatearFecha(fecha)),
            const Divider(height: 20),
            _buildDetalleItem(Icons.access_time, 'Hora', cita['hora']?.toString() ?? '--:--'),
            const Divider(height: 20),
            _buildDetalleItem(Icons.description, 'Motivo', cita['motivo']?.toString() ?? 'Consulta'),
            const Divider(height: 20),
            _buildDetalleItem(Icons.info, 'Estado', cita['estado']?.toString() ?? 'pendiente'),
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

  Widget _buildDetalleItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.teal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<bool> _confirmarEliminacionCita(String docId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('Confirmar Cancelación'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de que quieres cancelar esta cita?'),
            SizedBox(height: 12),
            Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, mantener'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sí, cancelar cita'),
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
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Cita cancelada exitosamente'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Error: $e')),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  void _abrirFormularioCita() async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AgendarCitaPage()),
    );
    if (created == true && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Cita agendada exitosamente'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _mostrarListaMedicos() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.medical_services, color: Colors.teal),
            SizedBox(width: 12),
            Text('Médicos Disponibles'),
          ],
        ),
        content: _doctoresDisponibles.isEmpty
            ? const Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medical_services_outlined, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No hay médicos disponibles',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        )
            : SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _doctoresDisponibles.length,
            itemBuilder: (context, index) {
              final doctor = _doctoresDisponibles[index];
              final nombre = doctor['nombre'] ?? 'Médico';
              final especialidad = doctor['especialidad'] ?? 'Especialista';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getIconoEspecialidad(especialidad),
                      color: Colors.teal,
                    ),
                  ),
                  title: Text(
                    nombre,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    especialidad,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(context);
                    _abrirFormularioCitaConDoctor(doctor);
                  },
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

  void _abrirFormularioCitaConDoctor(Map<String, dynamic> doctor) async {
    final created = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgendarCitaPage(doctorSeleccionado: doctor),
      ),
    );
    if (created == true && mounted) {
      if (mounted) {
        setState(() {
          _currentIndex = _currentIndex;
        });
      }
      await _recargarDatos();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Cita agendada exitosamente'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  IconData _getIconoEspecialidad(String especialidad) {
    switch (especialidad) {
      case 'Cardiólogo':
        return Icons.favorite;
      case 'Dermatólogo':
        return Icons.face;
      case 'Ginecólogo':
        return Icons.woman;
      case 'Pediatra':
        return Icons.child_care;
      case 'Psicólogo':
        return Icons.psychology;
      default:
        return Icons.medical_services;
    }
  }
}