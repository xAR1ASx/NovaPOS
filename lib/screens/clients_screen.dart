import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/db_helper.dart';
import '../services/session_service.dart';
import '../services/locale_service.dart';

String _t(String es) => LocaleService().esEspanol ? es : (_mapEn[es] ?? es);

const Map<String, String> _mapEn = {
  'Nuevo Cliente': 'New Client',
  'Nombre': 'Name',
  'Teléfono': 'Phone',
  'Dirección': 'Address',
  'Guardar': 'Save',
  'Editar Cupo de Crédito': 'Edit Credit Limit',
  'Cupo': 'Credit Limit',
  'Cancelar': 'Cancel',
  'Cupo inválido': 'Invalid credit limit',
  '✅ Cupo actualizado': '✅ Credit limit updated',
  '❌ No se pudo actualizar': '❌ Could not be updated',
  'GUARDAR': 'SAVE',
  'Deuda': 'Debt',
  'Monto a Abonar': 'Amount to Pay',
  'Monto inválido': 'Invalid amount',
  'Resultado': 'Result',
  'REGISTRAR ABONO': 'REGISTER PAYMENT',
  'Clientes': 'Clients',
  'El monto del abono debe ser mayor a cero': 'The payment amount must be greater than zero',
  'El abono excede la deuda actual del cliente': 'The payment exceeds the client\'s current debt',
  'Abono registrado': 'Payment recorded',
};

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});
  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final formater = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );
  List<Map<String, dynamic>> _clientes = [];

  @override
  void initState() {
    super.initState();
    _cargarClientes();
  }

  void _cargarClientes() async {
    final data = await DBHelper().obtenerClientes();
    setState(() {
      _clientes = data;
    });
  }

  void _crearCliente() {
    final n = TextEditingController();
    final t = TextEditingController();
    final d = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(_t("Nuevo Cliente")),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: n,
              decoration: InputDecoration(labelText: _t("Nombre")),
            ),
            TextField(
              controller: t,
              decoration: InputDecoration(labelText: _t("Teléfono")),
            ),
            TextField(
              controller: d,
              decoration: InputDecoration(labelText: _t("Dirección")),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              if (n.text.isNotEmpty) {
                await DBHelper().crearCliente({
                  'nombre': n.text,
                  'telefono': t.text,
                  'direccion': d.text,
                  'deuda_actual': 0,
                  'cupo_credito': 500000,
                });
                Navigator.pop(c);
                _cargarClientes();
              }
            },
            child: Text(_t("Guardar")),
          ),
        ],
      ),
    );
  }

  void _editarCupo(Map<String, dynamic> c) async {
    final ctrl = TextEditingController(
      text: (c['cupo_credito'] ?? 0).toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t("Editar Cupo de Crédito")),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _t("Cupo"),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t("Cancelar"), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              double? cupo = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (cupo == null || cupo < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_t("Cupo inválido")),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final ok = await DBHelper().actualizarClienteCupo(c['id'], cupo);
              if (ctx.mounted) Navigator.pop(ctx);
              _cargarClientes();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? _t("✅ Cupo actualizado") : _t("❌ No se pudo actualizar")),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ),
              );
            },
            child: Text(_t("GUARDAR")),
          ),
        ],
      ),
    );
  }

  void _mostrarFichaCliente(Map<String, dynamic> c) {
    final a = TextEditingController();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        height: 430,
        child: Column(
          children: [
            Text(
              c['nombre'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "${_t('Deuda')}: ${formater.format(c['deuda_actual'])}",
              style: const TextStyle(fontSize: 20, color: Colors.red),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${_t('Cupo')}: ${formater.format(c['cupo_credito'] ?? 0)}",
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _editarCupo(c),
                  child: const Icon(Icons.edit, size: 16, color: Colors.blueGrey),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: a,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _t("Monto a Abonar")),
            ),
            ElevatedButton(
              onPressed: () async {
                double? m = double.tryParse(a.text);
                if (m != null) {
                  double deudaActual =
                      (c['deuda_actual'] as num?)?.toDouble() ?? 0;
                  if (m <= 0 || m > deudaActual) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_t("Monto inválido")),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  final res = await DBHelper().registrarAbonoCliente(
                    c['id'],
                    c['nombre'],
                    m,
                    usuarioId: SessionService.userId() ?? 1,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _cargarClientes();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_t(res['mensaje']?.toString() ?? "Resultado")),
                      backgroundColor:
                          res['exito'] == true ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
              child: Text(_t("REGISTRAR ABONO")),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_t("Clientes")),
        backgroundColor: Colors.purple[800],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _crearCliente,
        child: const Icon(Icons.add),
      ),
      body: ListView.builder(
        itemCount: _clientes.length,
        itemBuilder: (c, i) {
          final cli = _clientes[i];
          return ListTile(
            title: Text(cli['nombre']),
            trailing: Text(formater.format(cli['deuda_actual'])),
            onTap: () => _mostrarFichaCliente(cli),
          );
        },
      ),
    );
  }
}
