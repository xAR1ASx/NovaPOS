import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'password_service.dart';

class PinAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<File> _sesionFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}novapos_sesion.json');
  }

  /// Guardar sesion verificada en el dispositivo
  static Future<void> guardarSesion(String email, String uid) async {
    final file = await _sesionFile();
    await file.writeAsString(jsonEncode({
      'sesion_verificada': true,
      'usuario_email': email,
      'usuario_uid': uid,
    }));
  }

  /// Verificar si ya hay sesion verificada en este dispositivo
  static Future<bool> haySesion() async {
    try {
      final file = await _sesionFile();
      if (!await file.exists()) return false;
      String contenido = await file.readAsString();
      Map<String, dynamic> datos = jsonDecode(contenido);
      return datos['sesion_verificada'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Obtener email guardado
  static Future<String?> emailGuardado() async {
    try {
      final file = await _sesionFile();
      if (!await file.exists()) return null;
      String contenido = await file.readAsString();
      Map<String, dynamic> datos = jsonDecode(contenido);
      return datos['usuario_email'];
    } catch (e) {
      return null;
    }
  }

  /// Limpiar sesion guardada
  static Future<void> limpiarSesion() async {
    try {
      final file = await _sesionFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {}
  }

  /// Login con PIN: hashea el PIN y busca en Firestore
  static Future<Map<String, dynamic>?> loginConPin(String pin) async {
    try {
      String pinHash = PasswordService.hashPassword(pin);

      QuerySnapshot snapshot = await _firestore
          .collection('usuarios')
          .where('pin_hash', isEqualTo: pinHash)
          .where('esta_activo', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      DocumentSnapshot doc = snapshot.docs.first;
      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      userData['uid'] = doc.id;

      return userData;
    } catch (e) {
      return null;
    }
  }

  /// Login con email + PIN (primera vez en el dispositivo)
  static Future<Map<String, dynamic>?> loginConEmailPin(String email, String pin) async {
    try {
      String pinHash = PasswordService.hashPassword(pin);

      QuerySnapshot snapshot = await _firestore
          .collection('usuarios')
          .where('email', isEqualTo: email.trim())
          .where('pin_hash', isEqualTo: pinHash)
          .where('esta_activo', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      DocumentSnapshot doc = snapshot.docs.first;
      Map<String, dynamic> userData = doc.data() as Map<String, dynamic>;
      userData['uid'] = doc.id;

      return userData;
    } catch (e) {
      return null;
    }
  }

  /// Verificar si el negocio tiene licencia valida
  static Future<Map<String, dynamic>> verificarLicencia(String negocioId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('negocios')
          .doc(negocioId)
          .get();

      if (!doc.exists) {
        return {'valida': false, 'mensaje': 'Negocio no encontrado'};
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      if (data['estado'] == 'bloqueada') {
        return {'valida': false, 'mensaje': 'Licencia bloqueada. Contacte al administrador.'};
      }

      dynamic licenciaFin = data['licencia_fin'];

      if (licenciaFin == null) {
        return {'valida': true, 'mensaje': 'Licencia sin limite'};
      }

      DateTime fechaFin = (licenciaFin as Timestamp).toDate();
      if (fechaFin.isAfter(DateTime.now())) {
        int diasRestantes = fechaFin.difference(DateTime.now()).inDays;
        return {'valida': true, 'mensaje': 'Licencia valida ($diasRestantes dias restantes)'};
      }

      return {'valida': false, 'mensaje': 'Licencia vencida. Contacte al administrador.'};
    } catch (e) {
      return {'valida': false, 'mensaje': 'Error verificando licencia: $e'};
    }
  }

  /// Verificar si ya existe un negocio configurado (para saber si mostrar wizard)
  static Future<bool> existeNegocioConfigurado() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('negocios').limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Crear negocio + admin (wizard de instalacion)
  static Future<Map<String, dynamic>> crearNegocioAdmin({
    required String nombreNegocio,
    required String nit,
    required String direccion,
    required String emailAdmin,
    required String passwordAdmin,
    required String nombreAdmin,
    String? licenciaFin,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: emailAdmin,
        password: passwordAdmin,
      );

      String uid = cred.user!.uid;

      DocumentReference negocioRef = await _firestore.collection('negocios').add({
        'nombre': nombreNegocio,
        'nit': nit,
        'direccion': direccion,
        'estado': 'activa',
        'licencia_fin': licenciaFin,
        'created_at': FieldValue.serverTimestamp(),
        'created_by': uid,
      });

      String pinHash = PasswordService.hashPassword(passwordAdmin);

      await _firestore.collection('usuarios').doc(uid).set({
        'email': emailAdmin,
        'pin_hash': pinHash,
        'nombre': nombreAdmin,
        'rol': 'ADMIN',
        'negocio_id': negocioRef.id,
        'esta_activo': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'negocioId': negocioRef.id,
        'userId': uid,
        'mensaje': 'Negocio y administrador creados correctamente',
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  /// Verificar si un PIN ya esta en uso dentro de un negocio
  static Future<bool> pinEnUso(String pin, String negocioId, {String? excluirUid}) async {
    String pinHash = PasswordService.hashPassword(pin);
    QuerySnapshot snapshot = await _firestore
        .collection('usuarios')
        .where('pin_hash', isEqualTo: pinHash)
        .where('negocio_id', isEqualTo: negocioId)
        .where('esta_activo', isEqualTo: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;
    if (excluirUid != null && snapshot.docs.first.id == excluirUid) return false;
    return true;
  }

  /// Crear usuario (cajero o admin) desde la app
  static Future<Map<String, dynamic>> crearUsuario({
    required String nombre,
    required String email,
    required String pin,
    required String rol,
    required String negocioId,
  }) async {
    try {
      if (await pinEnUso(pin, negocioId)) {
        return {
          'exito': false,
          'mensaje': 'Ese PIN ya esta en uso por otro usuario',
        };
      }

      String pinHash = PasswordService.hashPassword(pin);

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: pin,
      );

      String uid = cred.user!.uid;

      await _firestore.collection('usuarios').doc(uid).set({
        'email': email,
        'pin_hash': pinHash,
        'nombre': nombre,
        'rol': rol,
        'negocio_id': negocioId,
        'esta_activo': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      return {
        'exito': true,
        'userId': uid,
        'mensaje': 'Usuario $nombre creado correctamente',
      };
    } catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error: $e',
      };
    }
  }

  /// Obtener usuarios de un negocio
  static Future<List<Map<String, dynamic>>> obtenerUsuarios(String negocioId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('usuarios')
          .where('negocio_id', isEqualTo: negocioId)
          .where('esta_activo', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['uid'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Desactivar usuario
  static Future<bool> desactivarUsuario(String uid) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'esta_activo': false,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cambiar PIN de un usuario
  static Future<Map<String, dynamic>> cambiarPin(String uid, String nuevoPin, String negocioId) async {
    try {
      if (await pinEnUso(nuevoPin, negocioId, excluirUid: uid)) {
        return {
          'exito': false,
          'mensaje': 'Ese PIN ya esta en uso por otro usuario',
        };
      }

      String pinHash = PasswordService.hashPassword(nuevoPin);
      await _firestore.collection('usuarios').doc(uid).update({
        'pin_hash': pinHash,
      });
      return {'exito': true, 'mensaje': 'PIN actualizado'};
    } catch (e) {
      return {'exito': false, 'mensaje': 'Error al cambiar PIN'};
    }
  }

  /// Editar nombre y rol de un usuario
  static Future<bool> editarUsuario(String uid, String nombre, String rol) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'nombre': nombre,
        'rol': rol,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
