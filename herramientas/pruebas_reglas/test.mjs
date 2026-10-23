import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, Bytes, serverTimestamp,
} from 'firebase/firestore';

const RULES = new URL('../../firestore.rules', import.meta.url).pathname;
const env = await initializeTestEnvironment({
  projectId: 'demo-novapos',
  firestore: { rules: readFileSync(RULES, 'utf8'), host: '127.0.0.1', port: 8080 },
});

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'usuarios/admin1'), { negocio_id: 'n1', rol: 'ADMIN' });
  await setDoc(doc(db, 'usuarios/cajero1'), { negocio_id: 'n1', rol: 'CAJERO' });
  await setDoc(doc(db, 'usuarios/ajeno'), { negocio_id: 'n2', rol: 'ADMIN' });
  await setDoc(doc(db, 'negocios/n1'), { estado: 'activo', licencia_fin: '2027-01-01', financiado: false, modo_sync: 'una_caja', nombre: 'Fruver 1' });
  await setDoc(doc(db, 'negocios/n2'), { estado: 'activo', nombre: 'Fruver 2' });
  await setDoc(doc(db, 'negocios/n1/ventas/v0'), { total: 1000 });
});

const admin = env.authenticatedContext('admin1').firestore();
const cajero = env.authenticatedContext('cajero1').firestore();
const ajeno = env.authenticatedContext('ajeno').firestore();
const anon = env.unauthenticatedContext().firestore();
const parte = (db, id, copia, n) =>
  setDoc(doc(db, `negocios/n1/respaldos/indice/partes/${id}`), {
    copia_id: copia, parte: n, total: 2, datos: Bytes.fromUint8Array(new Uint8Array([1, 2, 3])),
  });
const indice = (db, copia, partes) =>
  setDoc(doc(db, 'negocios/n1/respaldos/indice'), {
    copia_id: copia, partes, sha256: 'x', foto_epoch: Date.now(), creado_ts: serverTimestamp(), multicaja: false,
  });

let ok = 0, mal = 0;
async function caso(nombre, promesa) {
  try { await promesa; ok++; console.log('  ✔', nombre); }
  catch (e) { mal++; console.log('  ✘', nombre, '→', e.message); }
}

console.log('Sincronización de siempre (no debe cambiar):');
await caso('ADMIN lee y escribe ventas de su negocio', assertSucceeds(setDoc(doc(admin, 'negocios/n1/ventas/v1'), { total: 2000 })));
await caso('CAJERO escribe stock_ops de su negocio', assertSucceeds(setDoc(doc(cajero, 'negocios/n1/stock_ops/o1'), { cantidad: -1 })));
await caso('CAJERO lee productos de su negocio', assertSucceeds(getDoc(doc(cajero, 'negocios/n1/productos/p1'))));
await caso('Otro negocio NO lee ventas ajenas', assertFails(getDoc(doc(ajeno, 'negocios/n1/ventas/v0'))));
await caso('Otro negocio NO escribe ventas ajenas', assertFails(setDoc(doc(ajeno, 'negocios/n1/ventas/v9'), { total: 1 })));
await caso('Sin sesión NO lee nada', assertFails(getDoc(doc(anon, 'negocios/n1/ventas/v0'))));
await caso('ADMIN lee su negocio', assertSucceeds(getDoc(doc(admin, 'negocios/n1'))));

console.log('Campos que solo cambia el proveedor:');
await caso('ADMIN NO cambia modo_sync', assertFails(updateDoc(doc(admin, 'negocios/n1'), { modo_sync: 'multicaja' })));
await caso('ADMIN NO cambia licencia_fin', assertFails(updateDoc(doc(admin, 'negocios/n1'), { licencia_fin: '2099-01-01' })));
await caso('ADMIN NO cambia estado', assertFails(updateDoc(doc(admin, 'negocios/n1'), { estado: 'activo2' })));
await caso('ADMIN sí cambia otro campo (nombre)', assertSucceeds(updateDoc(doc(admin, 'negocios/n1'), { nombre: 'Fruver Uno' })));

console.log('Copia en la nube:');
await caso('CAJERO sube los pedazos de la copia c1', assertSucceeds(Promise.all([parte(cajero, 'c1_0', 'c1', 0), parte(cajero, 'c1_1', 'c1', 1)])));
await caso('CAJERO marca c1 como vigente', assertSucceeds(indice(cajero, 'c1', 2)));
await caso('ADMIN lee el índice y los pedazos', assertSucceeds(Promise.all([getDoc(doc(admin, 'negocios/n1/respaldos/indice')), getDoc(doc(admin, 'negocios/n1/respaldos/indice/partes/c1_0'))])));
await caso('Otro negocio NO lee la copia', assertFails(getDoc(doc(ajeno, 'negocios/n1/respaldos/indice/partes/c1_0'))));
await caso('Otro negocio NO lee el índice', assertFails(getDoc(doc(ajeno, 'negocios/n1/respaldos/indice'))));
await caso('Otro negocio NO sube pedazos', assertFails(parte(ajeno, 'z_0', 'z', 0)));
await caso('Otro negocio NO cambia el índice', assertFails(indice(ajeno, 'c1', 2)));
await caso('Sin sesión NO lee la copia', assertFails(getDoc(doc(anon, 'negocios/n1/respaldos/indice'))));
await caso('NO se borra un pedazo de la copia vigente', assertFails(deleteDoc(doc(admin, 'negocios/n1/respaldos/indice/partes/c1_0'))));
await caso('NO se modifica un pedazo ya subido', assertFails(updateDoc(doc(admin, 'negocios/n1/respaldos/indice/partes/c1_0'), { parte: 5 })));
await caso('NO se borra el índice', assertFails(deleteDoc(doc(admin, 'negocios/n1/respaldos/indice'))));
await caso('NO se apunta a una copia sin su último pedazo', assertFails(parte(cajero, 'c2_0', 'c2', 0).then(() => indice(cajero, 'c2', 3))));
await caso('NO se acepta un pedazo con nombre que no corresponde', assertFails(parte(cajero, 'c4_5', 'c4', 0)));
await caso('NO se escriben otros documentos en respaldos', assertFails(setDoc(doc(admin, 'negocios/n1/respaldos/otro'), { a: 1 })));
await caso('El índice sigue en c1 tras los intentos fallidos', (async () => {
  const d = await getDoc(doc(admin, 'negocios/n1/respaldos/indice'));
  if (d.data().copia_id !== 'c1') throw new Error('índice cambió a ' + d.data().copia_id);
})());
await caso('Nueva copia c3: sube y queda vigente', assertSucceeds(Promise.all([parte(cajero, 'c3_0', 'c3', 0), parte(cajero, 'c3_1', 'c3', 1)]).then(() => indice(cajero, 'c3', 2))));
await caso('Ahora SÍ se borran los pedazos de la copia anterior c1', assertSucceeds(Promise.all([deleteDoc(doc(cajero, 'negocios/n1/respaldos/indice/partes/c1_0')), deleteDoc(doc(cajero, 'negocios/n1/respaldos/indice/partes/c1_1'))])));
await caso('Pedazos sueltos de un intento cortado (c2) también se borran', assertSucceeds(deleteDoc(doc(cajero, 'negocios/n1/respaldos/indice/partes/c2_0'))));
await caso('Otro negocio NO borra pedazos viejos ajenos', assertFails(parte(cajero, 'c5_0', 'c5', 0).then(() => deleteDoc(doc(ajeno, 'negocios/n1/respaldos/indice/partes/c5_0')))));
await caso('Los pedazos de c3 (vigente) siguen protegidos', assertFails(deleteDoc(doc(admin, 'negocios/n1/respaldos/indice/partes/c3_1'))));

await env.cleanup();
console.log(`\n${ok} correctas, ${mal} fallidas`);
process.exit(mal ? 1 : 0);
