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
    await _loadDashboardDataSimplified(emit);
  }

  Future<void> _onRefreshDashboardData(
      RefreshDashboardData event,
      Emitter<DashboardState> emit,
      ) async {
    await _loadDashboardDataSimplified(emit);
  }

  Future<void> _loadDashboardDataSimplified(
      Emitter<DashboardState> emit,
      ) async {
    emit(DashboardLoading());

    try {
      final user = _auth.currentUser;
      if (user == null) {
        emit(DashboardError('Usuario no autenticado'));
        return;
      }

      // 1. Obtener nombre del médico (consulta simple)
      final userDoc = await _firestore
          .collection('usuarios')
          .doc(user.uid)
          .get();
      final medicoNombre = userDoc.data()?['nombre'] ?? 'Médico';

      // 2. Obtener TODAS las citas del médico (SOLO 1 consulta simple)
      final citasSnapshot = await _firestore
          .collection('citas')
          .where('medico_id', isEqualTo: user.uid)
          .get();

      final todasLasCitas = citasSnapshot.docs;

      // 3. Calcular TODO en memoria (evita consultas complejas que necesitan índices)
      final ahora = DateTime.now();

      // Métricas básicas
      final totalCitas = todasLasCitas.length;

      final citasPendientes = todasLasCitas
          .where((doc) => doc['estado'] == 'pendiente')
          .length;

      // Pacientes únicos
      final pacientesIds = todasLasCitas
          .map((doc) => doc['paciente_id'] as String)
          .toSet();
      final totalPacientes = pacientesIds.length;

      // Próximas citas (filtro en memoria)
      final proximasCitas = todasLasCitas
          .where((doc) {
        final fecha = (doc['fecha_hora'] as Timestamp).toDate();
        final estado = doc['estado'] as String;
        return estado == 'pendiente' && fecha.isAfter(ahora);
      })
          .take(5)
          .map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      })
          .toList();

      // Citas de hoy (filtro en memoria)
      final citasHoy = todasLasCitas.where((doc) {
        final fecha = (doc['fecha_hora'] as Timestamp).toDate();
        return fecha.year == ahora.year &&
            fecha.month == ahora.month &&
            fecha.day == ahora.day;
      }).length;

      // Citas de esta semana (filtro en memoria)
      final startOfWeek = ahora.subtract(Duration(days: ahora.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final citasSemana = todasLasCitas.where((doc) {
        final fecha = (doc['fecha_hora'] as Timestamp).toDate();
        return fecha.isAfter(startOfWeek) && fecha.isBefore(endOfWeek);
      }).length;

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
    } catch (e) {
      emit(DashboardError('Error al cargar datos: $e'));
    }
  }
}