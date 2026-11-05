// CREA UNA SOLA VEZ LAS TRES CUENTAS DE EJEMPLO DE LA DEMO (DUEÑO, VAQUERO Y VETERINARIA) EN LA BASE DE SEGURIDAD DE LA DEMO
// CON CLAVES ALEATORIAS QUE NADIE NECESITA (SE ENTRA CON LOS BOTONES, /entrar-demo). GUARDA LOS id_usuario EN UN JSON (PERMISO 600)
// QUE LEE resembrar_demo.sh. SI LA CUENTA YA EXISTE, SOLO LA BUSCA
// USO: SEGURIDAD_URL=http://127.0.0.1:3020 CLAVE_SERVICIOS=<la del .env> CUENTAS_DEMO=/home/ejaniot/demoganadera-cuentas.json node crear_cuentas_demo.mjs
import { writeFileSync, chmodSync } from 'node:fs';
import { randomBytes } from 'node:crypto';

const SEG = process.env.SEGURIDAD_URL ?? 'http://127.0.0.1:3020';
const CLAVE_SERVICIOS = process.env.CLAVE_SERVICIOS;
const SALIDA = process.env.CUENTAS_DEMO;
if (!CLAVE_SERVICIOS || !SALIDA) {
  console.error('Faltan CLAVE_SERVICIOS o CUENTAS_DEMO');
  process.exit(1);
}

//LOS MISMOS CELULARES DE DEMO_CELULARES EN EL .env DE ms-seguridad
const CUENTAS = [
  { rol: 'DUENIO', nombre: 'Álvaro Ramírez', celular: '3100000001', rolid: 2 },
  { rol: 'VAQUERO', nombre: 'Jairo Pinto', celular: '3100000002', rolid: 3 },
  { rol: 'VETERINARIO', nombre: 'Paola Rueda', celular: '3100000003', rolid: 4 },
];

async function post(ruta, cuerpo, servicio = false) {
  const r = await fetch(`${SEG}/${ruta}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(servicio ? { 'x-clave-servicio': CLAVE_SERVICIOS } : {}) },
    body: JSON.stringify(cuerpo),
  });
  return r.json();
}

const resultado = {};
for (const c of CUENTAS) {
  let r = await post('buscar-usuario-celular-servicio', { celular: c.celular }, true);
  if (r.CODIGO !== 200) {
    const clave = 'Demo-' + randomBytes(12).toString('base64url');
    r = c.rolid === 2
      ? await post('registrar-duenio', { nombre: c.nombre, celular: c.celular, clave })
      : await post('crear-usuario-servicio', { nombre: c.nombre, celular: c.celular, clave, rolid: c.rolid }, true);
    if (r.CODIGO !== 200) {
      console.error(`No se pudo crear la cuenta ${c.rol}: ${r.MENSAJE}`);
      process.exit(1);
    }
  }
  resultado[c.rol] = { id_usuario: r.DATOS.id_usuario, nombre: c.nombre, celular: c.celular };
  console.log(`${c.rol}: lista (${c.celular})`);
}
writeFileSync(SALIDA, JSON.stringify(resultado, null, 2));
chmodSync(SALIDA, 0o600);
console.log('Cuentas guardadas en ' + SALIDA);
