import 'package:flutter/material.dart';
import '../services/pin_auth_service.dart';
import '../services/session_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _cargando = true);
    String? negocioId = SessionService.negocioId();
    if (negocioId != null) {
      _usuarios = await PinAuthService.obtenerUsuarios(negocioId);
    }
    setState(() => _cargando = false);
  }

  void _mostrarDialogoCrear() {
    final nombreCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    String rolSeleccionado = 'CAJERO';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crear usuario'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Correo electronico',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: juan@gmail.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: rolSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'CAJERO', child: Text('Cajero')),
                  DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => rolSeleccionado = v);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(
                  labelText: 'PIN (4 a 6 digitos)',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: 1234',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              if (emailCtrl.text.trim().isEmpty) return;
              if (pinCtrl.text.length < 4) return;

              String? negocioId = SessionService.negocioId();
              if (negocioId == null) return;

              Navigator.pop(ctx);

              Map<String, dynamic> resultado = await PinAuthService.crearUsuario(
                nombre: nombreCtrl.text.trim(),
                email: emailCtrl.text.trim(),
                pin: pinCtrl.text,
                rol: rolSeleccionado,
                negocioId: negocioId,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resultado['mensaje']),
                  backgroundColor: resultado['exito'] ? Colors.green : Colors.red,
                ),
              );

              _cargarUsuarios();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCambiarPin(Map<String, dynamic> usuario) {
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cambiar PIN - ${usuario['nombre']}'),
        content: TextField(
          controller: pinCtrl,
          decoration: const InputDecoration(
            labelText: 'Nuevo PIN (4 a 6 digitos)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinCtrl.text.length < 4) return;
              Navigator.pop(ctx);

              String? negocioId = SessionService.negocioId();
              if (negocioId == null) return;

              Map<String, dynamic> resultado = await PinAuthService.cambiarPin(
                usuario['uid'],
                pinCtrl.text,
                negocioId,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(resultado['mensaje']),
                  backgroundColor: resultado['exito'] ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditar(Map<String, dynamic> usuario) {
    final nombreCtrl = TextEditingController(text: usuario['nombre'] ?? '');
    String rolSeleccionado = usuario['rol'] ?? 'CAJERO';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar - ${usuario['nombre']}'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: rolSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Rol',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'CAJERO', child: Text('Cajero')),
                  DropdownMenuItem(value: 'ADMIN', child: Text('Administrador')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => rolSeleccionado = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nombreCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);

              bool ok = await PinAuthService.editarUsuario(
                usuario['uid'],
                nombreCtrl.text.trim(),
                rolSeleccionado,
              );

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Usuario actualizado' : 'Error al actualizar'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ),
              );

              _cargarUsuarios();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmarDesactivar(Map<String, dynamic> usuario) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text('Deseas desactivar a ${usuario['nombre']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              bool ok = await PinAuthService.desactivarUsuario(usuario['uid']);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? 'Usuario desactivado' : 'Error'),
                  backgroundColor: ok ? Colors.orange : Colors.red,
                ),
              );
              _cargarUsuarios();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Usuarios'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoCrear,
        backgroundColor: Colors.green.shade700,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _usuarios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No hay usuarios',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toca + para crear el primer usuario',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _usuarios.length,
                  itemBuilder: (ctx, i) {
                    Map<String, dynamic> u = _usuarios[i];
                    bool esAdmin = u['rol'] == 'ADMIN';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: esAdmin
                              ? Colors.green.shade100
                              : Colors.blue.shade100,
                          child: Icon(
                            esAdmin ? Icons.admin_panel_settings : Icons.person,
                            color: esAdmin ? Colors.green.shade700 : Colors.blue,
                          ),
                        ),
                        title: Text(
                          u['nombre'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${u['email'] ?? ''}  •  ${esAdmin ? 'Admin' : 'Cajero'}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(Icons.key, size: 20),
                                  SizedBox(width: 8),
                                  Text('Cambiar PIN'),
                                ],
                              ),
                            ),
                            if (!esAdmin)
                              const PopupMenuItem(
                                value: 'desactivar',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_off, size: 20, color: Colors.orange),
                                    SizedBox(width: 8),
                                    Text('Desactivar',
                                        style: TextStyle(color: Colors.orange)),
                                  ],
                                ),
                              ),
                          ],
                          onSelected: (valor) {
                            if (valor == 'editar') _mostrarDialogoEditar(u);
                            if (valor == 'pin') _mostrarDialogoCambiarPin(u);
                            if (valor == 'desactivar') _confirmarDesactivar(u);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
