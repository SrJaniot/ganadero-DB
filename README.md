# ganadero-DB

Bases de datos PostgreSQL de **Ganadero** (nombre técnico; el comercial está por definir). Es un proyecto universitario: una aplicación para el pequeño ganadero de doble propósito que funciona **sin internet** y sincroniza después.

Propuesta del proyecto: https://srjaniot.github.io/propuesta-ganadero/

Se trabaja **SQL primero**: toda la lógica de negocio y las validaciones están en funciones PostgreSQL. LoopBack 4 (ms-logica) solo pasa los datos y devuelve el JSON que arma la base.

| Base | Contenido | Cómo se crea |
|---|---|---|
| `ganadero` | Negocio: tablas `TAB_*`, funciones `FUN_*_JSON` y triggers `TRG_*` | `SETUP_CLEAN_DB.SQL` |
| `seguridadganadero` | `usuario`, `rol`, `menu`, `menurol` y `login` | `npm run migrate` en ms-seguridad-ganadero, después `SEGURIDAD/DML_SEGURIDAD_GANADERO.SQL` |

## Estructura

```
DDL_GANADERO.SQL             tablas, índices y funcion_Retorna_ultmoid (con candado)
SETUP_CLEAN_DB.SQL           script maestro GENERADO (no se edita a mano)
generar_setup.sh             regenera SETUP_CLEAN_DB.SQL
setup.ps1                    crea las dos bases y carga el script maestro
SEGURIDAD/                   roles, menús y permisos (LGEXB)
FUNCIONES/FUN_<ENTIDAD>/
   FUN_TAB_<ENTIDAD>.SQL     funciones
   DML_TAB_<ENTIDAD>.SQL     datos semilla
   PRU_FUN_TAB_<ENTIDAD>.SQL pruebas (dentro de BEGIN ... ROLLBACK: no dejan datos)
```

| Carpeta | Qué tiene |
|---|---|
| `FUN_GENERALES` | Acceso a la finca, configuración, categoría y etiqueta del animal, UUID → ID, validación común de los eventos |
| `FUN_FINCAS` | Fincas y personas de cada finca (dueño, vaquero, veterinario) |
| `FUN_CATALOGOS` | Razas, vacunas y ciclos del ICA (globales), con su semilla y la configuración |
| `FUN_LOTES`, `FUN_ANIMALES` | Hato: lotes, animales, ficha y **línea de tiempo** |
| `FUN_PESAJES` … `FUN_SALIDAS` | Los siete eventos: pesaje (con cinta), vacunación, servicio, palpación, parto (crea la cría), ordeño por jornada y salida |
| `FUN_EVENTOS` | Anular cualquier evento (el parto anula también su cría) |
| `FUN_SINCRONIZACION` | Subir la bandeja del celular y bajar los cambios desde una marca |
| `FUN_AUDITORIA` | Los triggers y las consultas de la auditoría |

## Funcionamiento sin internet

- Toda tabla que se llena desde el celular lleva `UUID_X UNIQUE`, que genera el celular. Las funciones de crear son **idempotentes**: si el UUID ya existe, responden 200 con `YA_EXISTIA: true` y no duplican.
- Todo evento lleva `FECHA_EVENTO` (cuándo pasó en el potrero) y `FECHA_CREACION` (cuándo llegó al servidor).
- No se borra: **se anula** (`ESTADO_X = 'ANULADO'`). Así la anulación también llega a los demás celulares.
- `FUN_SINCRONIZAR_REGISTROS_JSON` recibe hasta 50 registros y los procesa en orden. Cada uno va en su propio `BEGIN … EXCEPTION`, de modo que uno malo no frena a los demás. Cada registro responde `OK`, `YA_EXISTIA` o `RECHAZADO`, este último con su mensaje.
- `FUN_OBTENER_CAMBIOS_JSON` devuelve lo que cambió desde la marca del celular y la marca nueva, que es la hora del servidor.

## Triggers

La lógica de negocio sigue en las funciones. Los triggers solo hacen lo que debe cumplirse siempre, venga el cambio de una función, de la sincronización o de un `UPDATE` a mano:

| Trigger | Cuándo | Qué hace |
|---|---|---|
| `TRG_PROTEGER_<TABLA>` | `BEFORE INSERT / UPDATE` | Pone `FECHA_MODIFICACION = NOW()`, que es la marca con la que el celular baja los cambios. Impide cambiar el UUID, la finca, `FECHA_CREACION` y `USUARIO_CREACION` |
| `TRG_NO_BORRAR_<TABLA>` | `BEFORE DELETE` | Impide el `DELETE`: aquí se anula. Para limpiar datos de prueba: `SET LOCAL ganadero.permitir_borrar = 'SI'` |
| `TRG_AUDITORIA_<TABLA>` | `AFTER INSERT / UPDATE / DELETE` | Guarda en `TAB_AUDITORIAS` quién cambió qué y cuándo (solo las columnas que cambiaron). Distingue `CREAR`, `EDITAR`, `ANULAR` y `BORRAR` |
| `TRG_PESO_ACTUAL` | Al guardar o anular un pesaje | Deja en el animal el peso de su último pesaje activo |
| `TRG_SALIDA_ANIMAL` | Al guardar o anular una salida | Venta, muerte o traslado cambian el estado del animal. Al anular la salida, el animal vuelve a `ACTIVO` |

## Instalación

```powershell
.\setup.ps1 -PgPassword "tu_clave"
```

## Reglas

- Funciones `FUN_<VERBO>_<ENTIDAD>_JSON` con parámetros `jCOLUMNA TAB.COL%TYPE` y respuesta `{CODIGO, MENSAJE, DATOS}`.
- Códigos: 200 éxito, 400 validación, 404 no encontrado o lista vacía, 500 error.
- Operaciones con más de un DML: bloque `BEGIN … EXCEPTION` con `RAISE EXCEPTION` (rollback real).
- `funcion_Retorna_ultmoid` siempre con `pg_advisory_xact_lock`.
- Al agregar o cambiar una función: `sh generar_setup.sh` y correr **todas** las `PRU_*.SQL`.
- Una base que ya tiene datos se actualiza con migraciones (`MIGRACIONES/`), nunca recargando el SETUP.
