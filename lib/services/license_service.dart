import 'package:cloud_firestore/cloud_firestore.dart';

class LicenseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Obtener datos del negocio
  static Future<Map<String, dynamic>?> obtenerNegocio(String negocioId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('negocios')
          .doc(negocioId)
          .get();

      if (!doc.exists) return null;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      return null;
    }
  }

  /// Verificar si la licencia esta activa
  static Future<bool> estaActiva(String negocioId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('negocios')
          .doc(negocioId)
          .get();

      if (!doc.exists) return false;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['estado'] == 'bloqueada') return false;

      dynamic licenciaFin = data['licencia_fin'];
      if (licenciaFin == null) return true;

      DateTime fechaFin = (licenciaFin as Timestamp).toDate();
      return fechaFin.isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  /// Obtener dias restantes de licencia
  static Future<int?> diasRestantes(String negocioId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('negocios')
          .doc(negocioId)
          .get();

      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      dynamic licenciaFin = data['licencia_fin'];

      if (licenciaFin == null) return -1;

      DateTime fechaFin = (licenciaFin as Timestamp).toDate();
      int dias = fechaFin.difference(DateTime.now()).inDays;
      return dias > 0 ? dias : 0;
    } catch (e) {
      return null;
    }
  }

  /// Extender licencia (solo Super Admin desde Firebase Console o panel web)
  static Future<bool> extenderLicencia(String negocioId, DateTime nuevaFecha) async {
    try {
      await _firestore.collection('negocios').doc(negocioId).update({
        'licencia_fin': Timestamp.fromDate(nuevaFecha),
        'estado': 'activa',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Activar licencia sin limite
  static Future<bool> activarSinLimite(String negocioId) async {
    try {
      await _firestore.collection('negocios').doc(negocioId).update({
        'licencia_fin': null,
        'estado': 'activa',
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Bloquear negocio
  static Future<bool> bloquearNegocio(String negocioId) async {
    try {
      await _firestore.collection('negocios').doc(negocioId).update({
        'estado': 'bloqueada',
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
