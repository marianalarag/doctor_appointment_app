import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ESTADOS
abstract class DashboardState {}

class DashboardInitial extends DashboardState {}

class DashboardLoading extends DashboardState {}

class DashboardLoaded extends DashboardState {
  final int totalCitas;
  final int citasPendientes;
  final int totalPacientes;
  final String medicoNombre;
  final List<Map<String, dynamic>> proximasCitas;
  final int citasHoy;
  final int citasSemana;

  DashboardLoaded({
    required this.totalCitas,
    required this.citasPendientes,
    required this.totalPacientes,
    required this.medicoNombre,
    required this.proximasCitas,
    required this.citasHoy,
    required this.citasSemana,
  });
}

class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

// EVENTOS
abstract class DashboardEvent {}

class LoadDashboardData extends DashboardEvent {}

class RefreshDashboardData extends DashboardEvent {}

// BLoC
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  DashboardBloc() : super(DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<RefreshDashboardData>(_onRefreshDashboardData);
  }

  Future<void> _onLoadDashboardData(
      LoadDashboardData event,
      Emitter<DashboardState> emit,
      ) async {
    await _loadDashboardDataReal(emit);
  }

  Future<void> _onRefreshDashboardData(
      RefreshDashboardData event,
      Emitter<DashboardState> emit,
      ) async {
    await _loadDashboardDataReal(emit);
  }

  Future<void> _loadDashboardDataReal(Emitter<DashboardState> emit) async {
    emit(DashboardLoading());

    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(DashboardError('Usuario no autenticado'));
        return;
      }

      // DEBUG: Mostrar información del usuario
      print('=== DASHBOARD BLOC ===');
      print('UID del usuario: ${user.uid}');
      print('Email: ${user.email}');

      // 1. Obtener información del médico y VERIFICAR ROL
      final userDoc = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        emit(DashboardError('No se encontró el perfil del médico'));
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final role = userData['role'] ?? 'patient';

      // VERIFICAR que sea doctor
      if (role != 'doctor') {
        print('ERROR: El usuario no es doctor. Rol: $role');
        emit(DashboardError('Este usuario no tiene permisos de doctor'));
        return;
      }

      final medicoNombre = userData['nombre'] ?? 'Dr. ' + (user.email?.split('@').first ?? 'Médico');
      print('Médico: $medicoNombre (Rol: $role)');

      // 2. Obtener SOLO las citas de ESTE médico
      final citasSnapshot = await _firestore
          .collection('citas')
          .where('id_medico', isEqualTo: user.uid) // ← FILTRO POR DOCTOR ACTUAL
          .get();

      final citasDelDoctor = citasSnapshot.docs;

      // DEBUG: Información detallada
      print('Total citas encontradas para este doctor: ${citasDelDoctor.length}');

      // Mostrar primeras 3 citas para debug
      for (var i = 0; i < citasDelDoctor.length && i < 3; i++) {
        final doc = citasDelDoctor[i];
        final data = doc.data();
        print('Cita ${i + 1}:');
        print('  - ID: ${doc.id}');
        print('  - ID Médico en BD: ${data['id_medico']}');
        print('  - ID Médico esperado: ${user.uid}');
        print('  - Paciente: ${data['nombre_paciente']}');
        print('  - Fecha: ${data['fecha']}');
        print('  - Estado: ${data['estado']}');
      }

      // 3. Calcular métricas SOLO con citas del doctor actual
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);

      // Métricas básicas
      final totalCitas = citasDelDoctor.length;

      // Citas pendientes (estado 'pendiente' y fecha futura)
      final citasPendientes = citasDelDoctor
          .where((doc) {
        final data = doc.data();
        final estado = data['estado'] as String? ?? 'pendiente';
        final fechaField = data['fecha']; // ← USA 'fecha' (no 'fecha_hora')

        if (fechaField is Timestamp) {
          final fechaCita = fechaField.toDate();
          final esPendiente = estado == 'pendiente' || estado == 'confirmada';
          final esFutura = fechaCita.isAfter(ahora);
          return esPendiente && esFutura;
        }
        return false;
      })
          .length;

      // Pacientes únicos - usando el campo correcto 'id_paciente'
      final pacientesIds = <String>{};
      for (final doc in citasDelDoctor) {
        final pacienteId = doc.data()['id_paciente'] as String?;
        if (pacienteId != null && pacienteId.isNotEmpty) {
          pacientesIds.add(pacienteId);
        }
      }
      final totalPacientes = pacientesIds.length;

      // Próximas citas (5 más próximas)
      final List<Map<String, dynamic>> proximasCitas = _obtenerProximasCitas(citasDelDoctor, ahora);

      // Citas de hoy
      final citasHoy = citasDelDoctor
          .where((doc) {
        final data = doc.data();
        final fechaField = data['fecha'];

        if (fechaField is Timestamp) {
          final fechaCita = fechaField.toDate();
          final fechaCitaDia = DateTime(fechaCita.year, fechaCita.month, fechaCita.day);
          return fechaCitaDia == hoy;
        }
        return false;
      })
          .length;

      // Citas de esta semana
      final citasSemana = _contarCitasSemana(citasDelDoctor, hoy);

      print('''
RESUMEN DASHBOARD:
- Doctor: $medicoNombre
- Total citas: $totalCitas
- Citas pendientes: $citasPendientes  
- Total pacientes: $totalPacientes
- Citas hoy: $citasHoy
- Citas semana: $citasSemana
- Próximas citas: ${proximasCitas.length}
=== FIN DASHBOARD ===
      ''');

      emit(
        DashboardLoaded(
          totalCitas: totalCitas,
          citasPendientes: citasPendientes,
          totalPacientes: totalPacientes,
          medicoNombre: medicoNombre,
          proximasCitas: proximasCitas,
          citasHoy: citasHoy,
          citasSemana: citasSemana,
        ),
      );
    } catch (e, stackTrace) {
      print('ERROR CRÍTICO en DashboardBloc: $e');
      print('Stack trace: $stackTrace');
      emit(DashboardError('Error al cargar datos: ${e.toString()}'));
    }
  }

  // MÉTODO CORREGIDO para obtener próximas citas
  List<Map<String, dynamic>> _obtenerProximasCitas(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> citasDelDoctor,
      DateTime ahora,
      ) {
    // Filtrar citas pendientes/confirmadas futuras
    final citasFuturas = citasDelDoctor
        .where((doc) {
      final data = doc.data();
      final estado = data['estado'] as String? ?? 'pendiente';
      final fechaField = data['fecha'];

      if (fechaField is Timestamp) {
        final fechaCita = fechaField.toDate();
        final esPendiente = estado == 'pendiente' || estado == 'confirmada';
        final esFutura = fechaCita.isAfter(ahora);
        return esPendiente && esFutura;
      }
      return false;
    })
        .toList();

    // Ordenar por fecha (más próximas primero)
    citasFuturas.sort((a, b) {
      final fechaA = (a.data()['fecha'] as Timestamp);
      final fechaB = (b.data()['fecha'] as Timestamp);
      return fechaA.compareTo(fechaB);
    });

    // Convertir y limitar a 5
    return citasFuturas.take(5).map((doc) {
      final data = doc.data();
      final fechaCita = (data['fecha'] as Timestamp).toDate();

      return {
        'doc_id': doc.id,
        'id_paciente': data['id_paciente'] ?? '',
        'nombre_paciente': data['nombre_paciente'] ?? 'Paciente',
        'motivo': data['motivo'] ?? 'Consulta',
        'fecha': fechaCita,
        'hora': data['hora'] ?? '--:--',
        'estado': data['estado'] ?? 'pendiente',
        'id_medico': data['id_medico'] ?? '', // ← Agregado para debug
      };
    }).toList();
  }

  // MÉTODO CORREGIDO para contar citas de hoy
  int _contarCitasHoy(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> citasDelDoctor,
      DateTime hoy,
      ) {
    return citasDelDoctor.where((doc) {
      final data = doc.data();
      final fechaField = data['fecha'];

      if (fechaField is Timestamp) {
        final fechaCita = fechaField.toDate();
        final fechaCitaDia = DateTime(fechaCita.year, fechaCita.month, fechaCita.day);
        return fechaCitaDia == hoy;
      }
      return false;
    }).length;
  }

  // MÉTODO CORREGIDO para contar citas de la semana
  int _contarCitasSemana(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> citasDelDoctor,
      DateTime hoy,
      ) {
    final startOfWeek = hoy.subtract(Duration(days: hoy.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return citasDelDoctor.where((doc) {
      final data = doc.data();
      final fechaField = data['fecha'];

      if (fechaField is Timestamp) {
        final fechaCita = fechaField.toDate();
        final fechaCitaDia = DateTime(fechaCita.year, fechaCita.month, fechaCita.day);
        return fechaCitaDia.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            fechaCitaDia.isBefore(endOfWeek.add(const Duration(days: 1)));
      }
      return false;
    }).length;
  }

  // Método auxiliar para formatear fecha
  String _formatearFecha(DateTime fecha) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
  }
}