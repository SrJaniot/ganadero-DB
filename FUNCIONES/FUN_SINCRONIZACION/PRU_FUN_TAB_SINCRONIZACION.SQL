-- PRUEBAS del motor de sincronización: FUN_SINCRONIZAR_REGISTROS_JSON (subir) y FUN_OBTENER_CAMBIOS_JSON (bajar)
-- SE EJECUTAN DENTRO DE UNA TRANSACCION Y AL FINAL SE HACE ROLLBACK PARA NO DEJAR DATOS DE PRUEBA
-- OJO: DENTRO DE UNA TRANSACCION NOW() NO AVANZA, ASI QUE LA MARCA SE SIMULA MOVIENDO FECHA_MODIFICACION HACIA ATRAS
BEGIN;

SELECT FUN_CREAR_FINCA_JSON('Finca Prueba', 'San Gil', NULL, NULL, NULL, 'PRU-DUENO', 'Dueño Prueba') ->> 'CODIGO' AS FINCA_200;
CREATE FUNCTION pg_temp.FINCA() RETURNS INTEGER AS $$ SELECT ID_FINCA FROM TAB_FINCAS WHERE NOM_FINCA = 'Finca Prueba' $$ LANGUAGE sql;
SELECT FUN_AGREGAR_PERSONA_FINCA_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', 'Vaquero Prueba', 'VAQUERO', 'PRU-DUENO') ->> 'CODIGO' AS VAQUERO_200;


SELECT 'PRUEBA 1.1: El vaquero sube sin señal un lote, una vaca y sus eventos EN ORDEN (la vaca antes que sus eventos). DEBE SALIR 200 con "6 subidos, 0 ya existían, 1 rechazado"' as PRUEBA;
CREATE TEMP TABLE PRU_RESPUESTA AS
SELECT FUN_SINCRONIZAR_REGISTROS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', '[
  {"orden": 1, "uuid": "00000000-0000-0000-0000-000000000001", "tipo": "LOTE", "operacion": "CREAR", "datos": {"nom_lote": "Ordeño"}},
  {"orden": 2, "uuid": "00000000-0000-0000-0000-00000000000a", "tipo": "ANIMAL", "operacion": "CREAR",
     "datos": {"uuid_lote": "00000000-0000-0000-0000-000000000001", "id_raza": 2, "chapeta_animal": "23", "nom_animal": "Lucero", "sexo_animal": "H",
               "fecha_nacimiento": "2021-03-10", "fecha_nacimiento_estimada": "SI", "origen_animal": "COMPRADO", "fecha_ingreso_animal": "2024-05-01"}},
  {"orden": 3, "uuid": "00000000-0000-0000-0000-000000000e01", "tipo": "PESAJE", "operacion": "CREAR",
     "datos": {"uuid_animal": "00000000-0000-0000-0000-00000000000a", "peso_kg": 412, "estimado_cinta": "NO", "fecha_evento": "2026-10-20T07:40"}},
  {"orden": 4, "uuid": "00000000-0000-0000-0000-000000000e02", "tipo": "ORDENO", "operacion": "CREAR",
     "datos": {"uuid_animal": "00000000-0000-0000-0000-00000000000a", "jornada_ordeno": "MANANA", "litros_ordeno": 7.5, "fecha_evento": "2026-10-20T05:30"}},
  {"orden": 5, "uuid": "00000000-0000-0000-0000-000000000e03", "tipo": "VACUNACION", "operacion": "CREAR",
     "datos": {"uuid_animal": "00000000-0000-0000-0000-00000000000a", "id_vacuna": 1, "fecha_evento": "2026-10-20T09:00"}},
  {"orden": 6, "uuid": "00000000-0000-0000-0000-000000000e04", "tipo": "PESAJE", "operacion": "CREAR",
     "datos": {"uuid_animal": "00000000-0000-0000-0000-00000000000a", "peso_kg": 0, "fecha_evento": "2026-10-21T07:40"}},
  {"orden": 7, "uuid": "00000000-0000-0000-0000-000000000e05", "tipo": "PESAJE", "operacion": "CREAR",
     "datos": {"uuid_animal": "00000000-0000-0000-0000-00000000000a", "peso_kg": 415, "estimado_cinta": "SI", "perimetro_cm": 175, "fecha_evento": "2026-10-22T07:40"}}
]'::JSON) AS R;
SELECT R ->> 'CODIGO' AS CODIGO, R ->> 'MENSAJE' AS MENSAJE FROM PRU_RESPUESTA;
SELECT E ->> 'ORDEN' AS ORDEN, E ->> 'ESTADO' AS ESTADO, E ->> 'MENSAJE' AS MENSAJE FROM PRU_RESPUESTA, json_array_elements(R -> 'DATOS') E;

SELECT 'PRUEBA 1.2: Reintento del mismo lote (se cortó la señal antes de la respuesta): nada se duplica. DEBE SALIR "0 subidos, 6 ya existían, 1 rechazado" y 2 pesajes guardados' as PRUEBA;
SELECT FUN_SINCRONIZAR_REGISTROS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', (SELECT json_agg(X) FROM (
    SELECT json_build_object('orden', 1, 'uuid', '00000000-0000-0000-0000-000000000001', 'tipo', 'LOTE', 'operacion', 'CREAR', 'datos', json_build_object('nom_lote', 'Ordeño')) X
    UNION ALL SELECT json_build_object('orden', 2, 'uuid', '00000000-0000-0000-0000-00000000000a', 'tipo', 'ANIMAL', 'operacion', 'CREAR', 'datos', json_build_object())
    UNION ALL SELECT json_build_object('orden', 3, 'uuid', '00000000-0000-0000-0000-000000000e01', 'tipo', 'PESAJE', 'operacion', 'CREAR', 'datos', json_build_object())
    UNION ALL SELECT json_build_object('orden', 4, 'uuid', '00000000-0000-0000-0000-000000000e02', 'tipo', 'ORDENO', 'operacion', 'CREAR', 'datos', json_build_object())
    UNION ALL SELECT json_build_object('orden', 5, 'uuid', '00000000-0000-0000-0000-000000000e03', 'tipo', 'VACUNACION', 'operacion', 'CREAR', 'datos', json_build_object())
    UNION ALL SELECT json_build_object('orden', 6, 'uuid', '00000000-0000-0000-0000-000000000e04', 'tipo', 'PESAJE', 'operacion', 'CREAR', 'datos', json_build_object('peso_kg', 0))
    UNION ALL SELECT json_build_object('orden', 7, 'uuid', '00000000-0000-0000-0000-000000000e05', 'tipo', 'PESAJE', 'operacion', 'CREAR', 'datos', json_build_object())
) T)) ->> 'MENSAJE' AS REINTENTO;
SELECT COUNT(*) AS DOS_PESAJES FROM TAB_PESAJES WHERE ID_FINCA = pg_temp.FINCA();

SELECT 'PRUEBA 1.3: Registros malos no frenan a los demás: UUID mal formado, fecha inválida, tipo desconocido y el vaquero intentando anular. "1 subido, 0 ya existían, 4 rechazados"' as PRUEBA;
SELECT E ->> 'ESTADO' AS ESTADO, E ->> 'MENSAJE' AS MENSAJE
FROM json_array_elements(FUN_SINCRONIZAR_REGISTROS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', '[
  {"orden": 8, "uuid": "no-es-un-uuid", "tipo": "PESAJE", "operacion": "CREAR", "datos": {}},
  {"orden": 9, "uuid": "00000000-0000-0000-0000-000000000e06", "tipo": "PESAJE", "operacion": "CREAR",
     "datos": {"uuid_animal": "00000000-0000-0000-0000-00000000000a", "peso_kg": 420, "fecha_evento": "ayer"}},
  {"orden": 10, "uuid": "00000000-0000-0000-0000-000000000e07", "tipo": "GALLINA", "operacion": "CREAR", "datos": {}},
  {"orden": 11, "uuid": "00000000-0000-0000-0000-000000000e01", "tipo": "PESAJE", "operacion": "ANULAR"},
  {"orden": 12, "uuid": "00000000-0000-0000-0000-000000000e08", "tipo": "PESAJE", "operacion": "CREAR",
     "datos": {"uuid_animal": "00000000-0000-0000-0000-00000000000a", "peso_kg": 418, "fecha_evento": "2026-10-23T07:40"}}
]'::JSON) -> 'DATOS') E;

SELECT 'PRUEBA 1.4: Límites. Lista vacía 400; no es lista 400; 51 registros 400; extraño 400. Y quedaron 3 sincronizaciones registradas con sus rechazados' as PRUEBA;
SELECT FUN_SINCRONIZAR_REGISTROS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', '[]'::JSON) ->> 'CODIGO' AS VACIA_400,
       FUN_SINCRONIZAR_REGISTROS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', '{"tipo": "PESAJE"}'::JSON) ->> 'CODIGO' AS NO_ES_LISTA_400,
       FUN_SINCRONIZAR_REGISTROS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', (SELECT json_agg(json_build_object('uuid', gen_random_uuid())) FROM generate_series(1, 51))) ->> 'CODIGO' AS MAS_DE_50_400,
       FUN_SINCRONIZAR_REGISTROS_JSON(pg_temp.FINCA(), 'PRU-EXTRANO', '[{"uuid": "00000000-0000-0000-0000-000000000e09"}]'::JSON) ->> 'CODIGO' AS EXTRANO_400;
SELECT json_array_length(FUN_OBTENER_SINCRONIZACIONES_JSON(pg_temp.FINCA(), 'PRU-DUENO') -> 'DATOS') AS TRES,
       FUN_OBTENER_SINCRONIZACIONES_JSON(pg_temp.FINCA(), 'PRU-DUENO') -> 'DATOS' -> 0 ->> 'RECHAZADOS_SINCRONIZACION' AS CUATRO_RECHAZADOS;


SELECT 'PRUEBA 2.1: Bajar la primera vez (marca nula): finca completa. DEBE SALIR COMPLETO true, 1 lote, 1 animal con su UUID de lote, 3 pesajes, 14 razas, 10 vacunas, 2 personas' as PRUEBA;
CREATE TEMP TABLE PRU_CAMBIOS AS SELECT FUN_OBTENER_CAMBIOS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', NULL) -> 'DATOS' AS D;
SELECT D ->> 'COMPLETO' AS COMPLETO, json_array_length(D -> 'LOTES') AS LOTES, json_array_length(D -> 'ANIMALES') AS ANIMALES,
       D -> 'ANIMALES' -> 0 ->> 'UUID_LOTE' AS UUID_LOTE, json_array_length(D -> 'PESAJES') AS PESAJES,
       json_array_length(D -> 'RAZAS') AS RAZAS, json_array_length(D -> 'VACUNAS') AS VACUNAS, json_array_length(D -> 'PERSONAS') AS PERSONAS,
       D ->> 'ROL_FINCA' AS VAQUERO
FROM PRU_CAMBIOS;

SELECT 'PRUEBA 2.2: Bajar desde una marca. Todo lo anterior se mueve 1 hora atrás; el dueño anula un pesaje y pesa otro. DEBE SALIR COMPLETO false, 2 pesajes (uno ANULADO), el animal con su peso nuevo y 0 razas' as PRUEBA;
ALTER TABLE TAB_ANIMALES DISABLE TRIGGER TRG_PROTEGER_ANIMALES;
ALTER TABLE TAB_PESAJES DISABLE TRIGGER TRG_PROTEGER_PESAJES;
ALTER TABLE TAB_RAZAS DISABLE TRIGGER TRG_PROTEGER_RAZAS;
ALTER TABLE TAB_VACUNAS DISABLE TRIGGER TRG_PROTEGER_VACUNAS;
ALTER TABLE TAB_LOTES DISABLE TRIGGER TRG_PROTEGER_LOTES;
ALTER TABLE TAB_FINCAS DISABLE TRIGGER TRG_PROTEGER_FINCAS;
ALTER TABLE TAB_FINCAS_PERSONAS DISABLE TRIGGER TRG_PROTEGER_FINCAS_PERSONAS;
ALTER TABLE TAB_ORDENOS DISABLE TRIGGER TRG_PROTEGER_ORDENOS;
ALTER TABLE TAB_VACUNACIONES DISABLE TRIGGER TRG_PROTEGER_VACUNACIONES;
UPDATE TAB_ANIMALES SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
UPDATE TAB_PESAJES SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
UPDATE TAB_RAZAS SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
UPDATE TAB_VACUNAS SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
UPDATE TAB_LOTES SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
UPDATE TAB_FINCAS SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
UPDATE TAB_FINCAS_PERSONAS SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
UPDATE TAB_ORDENOS SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
UPDATE TAB_VACUNACIONES SET FECHA_MODIFICACION = FECHA_MODIFICACION - INTERVAL '1 hour';
ALTER TABLE TAB_ANIMALES ENABLE TRIGGER TRG_PROTEGER_ANIMALES;
ALTER TABLE TAB_PESAJES ENABLE TRIGGER TRG_PROTEGER_PESAJES;
ALTER TABLE TAB_RAZAS ENABLE TRIGGER TRG_PROTEGER_RAZAS;
ALTER TABLE TAB_VACUNAS ENABLE TRIGGER TRG_PROTEGER_VACUNAS;
ALTER TABLE TAB_LOTES ENABLE TRIGGER TRG_PROTEGER_LOTES;
ALTER TABLE TAB_FINCAS ENABLE TRIGGER TRG_PROTEGER_FINCAS;
ALTER TABLE TAB_FINCAS_PERSONAS ENABLE TRIGGER TRG_PROTEGER_FINCAS_PERSONAS;
ALTER TABLE TAB_ORDENOS ENABLE TRIGGER TRG_PROTEGER_ORDENOS;
ALTER TABLE TAB_VACUNACIONES ENABLE TRIGGER TRG_PROTEGER_VACUNACIONES;
SELECT FUN_SINCRONIZAR_REGISTROS_JSON(pg_temp.FINCA(), 'PRU-DUENO', '[
  {"orden": 1, "uuid": "00000000-0000-0000-0000-000000000e08", "tipo": "PESAJE", "operacion": "ANULAR"},
  {"orden": 2, "uuid": "00000000-0000-0000-0000-000000000e10", "tipo": "PESAJE", "operacion": "CREAR",
     "datos": {"uuid_animal": "00000000-0000-0000-0000-00000000000a", "peso_kg": 430, "fecha_evento": "2026-10-25T07:40"}}
]'::JSON) ->> 'MENSAJE' AS DOS_SUBIDOS;
SELECT D ->> 'COMPLETO' AS COMPLETO, json_array_length(D -> 'PESAJES') AS DOS_PESAJES,
       (SELECT string_agg(P ->> 'ESTADO_PESAJE', ',' ORDER BY P ->> 'ESTADO_PESAJE') FROM json_array_elements(D -> 'PESAJES') P) AS ACTIVO_ANULADO,
       D -> 'ANIMALES' -> 0 ->> 'PESO_ACTUAL_KG' AS PESO_430,
       json_array_length(D -> 'RAZAS') AS CERO_RAZAS, json_array_length(D -> 'LOTES') AS CERO_LOTES
FROM (SELECT FUN_OBTENER_CAMBIOS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', (LOCALTIMESTAMP - INTERVAL '30 minutes')::TIMESTAMP) -> 'DATOS' AS D) T;

SELECT 'PRUEBA 2.3: Marca del futuro 400; extraño 400' as PRUEBA;
SELECT FUN_OBTENER_CAMBIOS_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', (LOCALTIMESTAMP + INTERVAL '1 day')::TIMESTAMP) ->> 'CODIGO' AS FUTURO_400,
       FUN_OBTENER_CAMBIOS_JSON(pg_temp.FINCA(), 'PRU-EXTRANO', NULL) ->> 'CODIGO' AS EXTRANO_400;

ROLLBACK;
