-- PRUEBAS de los siete eventos (pesaje, vacunación, servicio, palpación, parto, ordeño, salida), de la anulación
-- y de los triggers TRG_PESO_ACTUAL y TRG_SALIDA_ANIMAL
-- SE EJECUTAN DENTRO DE UNA TRANSACCION Y AL FINAL SE HACE ROLLBACK PARA NO DEJAR DATOS DE PRUEBA
-- UUID DE PRUEBA: ...a VACA, ...b TORO, ...c NOVILLA, ...d CRIA; LOS EVENTOS USAN ...e01, ...e02, ...
BEGIN;

--FINCA, PERSONAS Y ANIMALES DE PRUEBA
SELECT FUN_CREAR_FINCA_JSON('Finca Prueba', 'San Gil', NULL, NULL, NULL, 'PRU-DUENO', 'Dueño Prueba') ->> 'CODIGO' AS FINCA_200;
CREATE FUNCTION pg_temp.FINCA() RETURNS INTEGER AS $$ SELECT ID_FINCA FROM TAB_FINCAS WHERE NOM_FINCA = 'Finca Prueba' $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.U(jSUFIJO VARCHAR) RETURNS UUID AS $$ SELECT ('00000000-0000-0000-0000-' || lpad(jSUFIJO, 12, '0'))::UUID $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.ANIMAL(jSUFIJO VARCHAR) RETURNS TAB_ANIMALES AS $$ SELECT * FROM TAB_ANIMALES WHERE UUID_ANIMAL = pg_temp.U(jSUFIJO) $$ LANGUAGE sql;
SELECT FUN_AGREGAR_PERSONA_FINCA_JSON(pg_temp.FINCA(), 'PRU-VAQUERO', 'Vaquero Prueba', 'VAQUERO', 'PRU-DUENO') ->> 'CODIGO' AS VAQUERO_200;
SELECT FUN_CREAR_ANIMAL_JSON(pg_temp.U('a'), pg_temp.FINCA(), NULL, 2, '23', 'Lucero', 'H', (CURRENT_DATE - INTERVAL '5 years')::DATE, 'SI', NULL, NULL, NULL, 'COMPRADO', (CURRENT_DATE - INTERVAL '2 years')::DATE, 'PRU-DUENO') ->> 'CODIGO' AS VACA_200,
       FUN_CREAR_ANIMAL_JSON(pg_temp.U('b'), pg_temp.FINCA(), NULL, 1, 'T1', 'Tormenta', 'M', (CURRENT_DATE - INTERVAL '4 years')::DATE, 'NO', NULL, NULL, NULL, 'COMPRADO', (CURRENT_DATE - INTERVAL '1 year')::DATE, 'PRU-DUENO') ->> 'CODIGO' AS TORO_200,
       FUN_CREAR_ANIMAL_JSON(pg_temp.U('c'), pg_temp.FINCA(), NULL, NULL, '41', NULL, 'H', (CURRENT_DATE - INTERVAL '8 months')::DATE, 'NO', NULL, NULL, NULL, 'NACIDO', NULL, 'PRU-DUENO') ->> 'CODIGO' AS TERNERA_200;


SELECT 'PRUEBA 1.1: Pesaje con báscula 200; con cinta sin peso (perímetro 180 cm = 466,6 kg) 200; reintento YA_EXISTIA; el vaquero puede pesar' as PRUEBA;
SELECT FUN_CREAR_PESAJE_JSON(pg_temp.U('e01'), pg_temp.FINCA(), pg_temp.U('a'), 450, 'NO', NULL, LOCALTIMESTAMP - INTERVAL '30 days', NULL, 'PRU-VAQUERO') ->> 'CODIGO' AS BASCULA_200,
       FUN_CREAR_PESAJE_JSON(pg_temp.U('e02'), pg_temp.FINCA(), pg_temp.U('a'), NULL, 'SI', 180, LOCALTIMESTAMP - INTERVAL '2 days', 'con cinta', 'PRU-VAQUERO') -> 'DATOS' ->> 'PESO_KG' AS CINTA_466_6,
       FUN_CREAR_PESAJE_JSON(pg_temp.U('e02'), pg_temp.FINCA(), pg_temp.U('a'), NULL, 'SI', 180, LOCALTIMESTAMP - INTERVAL '2 days', 'con cinta', 'PRU-VAQUERO') -> 'DATOS' ->> 'YA_EXISTIA' AS REINTENTO_TRUE;

SELECT 'PRUEBA 1.2: TRIGGER TRG_PESO_ACTUAL. El animal queda con 466.6 (el más reciente); llega tarde uno más viejo (400, hace 60 días) y sigue 466.6; se anula el de 466.6 y vuelve a 450.0' as PRUEBA;
SELECT (pg_temp.ANIMAL('a')).PESO_ACTUAL_KG AS PESO_466_6;
SELECT FUN_CREAR_PESAJE_JSON(pg_temp.U('e03'), pg_temp.FINCA(), pg_temp.U('a'), 400, 'NO', NULL, LOCALTIMESTAMP - INTERVAL '60 days', NULL, 'PRU-DUENO') ->> 'CODIGO' AS VIEJO_200;
SELECT (pg_temp.ANIMAL('a')).PESO_ACTUAL_KG AS SIGUE_466_6;
SELECT FUN_ANULAR_EVENTO_JSON('PESAJE', pg_temp.U('e02'), pg_temp.FINCA(), 'PRU-VAQUERO') ->> 'CODIGO' AS VAQUERO_NO_ANULA_400,
       FUN_ANULAR_EVENTO_JSON('PESAJE', pg_temp.U('e02'), pg_temp.FINCA(), 'PRU-DUENO') ->> 'CODIGO' AS DUENIO_ANULA_200;
SELECT (pg_temp.ANIMAL('a')).PESO_ACTUAL_KG AS VUELVE_450_0, (pg_temp.ANIMAL('a')).USUARIO_MODIFICACION AS PRU_DUENO;

SELECT 'PRUEBA 1.3: Validaciones del pesaje y de todo evento. TODAS 400 salvo ANIMAL DE OTRA FINCA (404)' as PRUEBA;
SELECT T.CASO, R ->> 'CODIGO' AS CODIGO, R ->> 'MENSAJE' AS MENSAJE
FROM (VALUES
    ('PESO CERO', FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 0, 'NO', NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('CINTA SIN PERIMETRO', FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), NULL, 'SI', NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('FECHA FUTURA', FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 400, 'NO', NULL, LOCALTIMESTAMP + INTERVAL '3 days', NULL, 'PRU-DUENO')),
    ('ANTES DE NACER', FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('c'), 100, 'NO', NULL, LOCALTIMESTAMP - INTERVAL '1 year', NULL, 'PRU-DUENO')),
    ('SIN FECHA', FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 400, 'NO', NULL, NULL, NULL, 'PRU-DUENO')),
    ('ANIMAL DE OTRA FINCA', FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), gen_random_uuid(), 400, 'NO', NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('EXTRAÑO', FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 400, 'NO', NULL, LOCALTIMESTAMP, NULL, 'PRU-EXTRANO'))
) AS T(CASO, R);


SELECT 'PRUEBA 2.1: Vacunación con retiro de leche (oxitetraciclina: 5 días) 200 y FECHA_FIN_RETIRO = fecha + 5; aftosa con refuerzo a 180 días; repetida el mismo día 400; producto inexistente 400' as PRUEBA;
SELECT FUN_CREAR_VACUNACION_JSON(pg_temp.U('e10'), pg_temp.FINCA(), pg_temp.U('a'), 8, '10 ml', LOCALTIMESTAMP - INTERVAL '1 day', NULL, 'PRU-VAQUERO') ->> 'MENSAJE' AS NO_VENDER_LECHE,
       FUN_CREAR_VACUNACION_JSON(pg_temp.U('e11'), pg_temp.FINCA(), pg_temp.U('a'), 1, NULL, LOCALTIMESTAMP - INTERVAL '1 day', NULL, 'PRU-VAQUERO') -> 'DATOS' ->> 'FECHA_PROXIMA_DOSIS' = to_char(CURRENT_DATE - 1 + 180, 'YYYY-MM-DD') AS REFUERZO_180_TRUE;
SELECT FECHA_FIN_RETIRO = CURRENT_DATE - 1 + 5 AS RETIRO_5_DIAS_TRUE FROM TAB_VACUNACIONES WHERE UUID_VACUNACION = pg_temp.U('e10');
SELECT FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 8, NULL, LOCALTIMESTAMP - INTERVAL '1 day', NULL, 'PRU-VAQUERO') ->> 'CODIGO' AS REPETIDA_400,
       FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), -1, NULL, LOCALTIMESTAMP, NULL, 'PRU-VAQUERO') ->> 'CODIGO' AS PRODUCTO_400;


SELECT 'PRUEBA 3.1: Servicio. Monta con el toro de la finca hace 300 días 200 (parto probable en el mensaje); a la ternera 400 (menos de 12 meses); al toro 400; inseminación sin pajilla 400; toro y pajilla a la vez 400' as PRUEBA;
SELECT FUN_CREAR_SERVICIO_JSON(pg_temp.U('e20'), pg_temp.FINCA(), pg_temp.U('a'), 'MONTA', pg_temp.U('b'), NULL, LOCALTIMESTAMP - INTERVAL '300 days', NULL, 'PRU-VAQUERO') ->> 'MENSAJE' AS PARTO_PROBABLE;
SELECT T.CASO, R ->> 'CODIGO' AS CODIGO, R ->> 'MENSAJE' AS MENSAJE
FROM (VALUES
    ('TERNERA', FUN_CREAR_SERVICIO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('c'), 'MONTA', pg_temp.U('b'), NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('AL TORO', FUN_CREAR_SERVICIO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('b'), 'MONTA', NULL, NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('INSEMINACION SIN PAJILLA', FUN_CREAR_SERVICIO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'INSEMINACION', NULL, ' ', LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('TORO Y PAJILLA', FUN_CREAR_SERVICIO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'MONTA', pg_temp.U('b'), 'Pajilla X', LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('TORO HEMBRA', FUN_CREAR_SERVICIO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'MONTA', pg_temp.U('c'), NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO'))
) AS T(CASO, R);


SELECT 'PRUEBA 4.1: Palpación preñada de 3 meses hace 210 días 200 y queda enlazada al servicio; preñada sin meses 400; a la ternera 400' as PRUEBA;
SELECT FUN_CREAR_PALPACION_JSON(pg_temp.U('e30'), pg_temp.FINCA(), pg_temp.U('a'), 'PRENIADA', 3, LOCALTIMESTAMP - INTERVAL '210 days', NULL, 'PRU-VAQUERO') ->> 'CODIGO' AS PALPACION_200;
SELECT ID_SERVICIO = (SELECT ID_SERVICIO FROM TAB_SERVICIOS WHERE UUID_SERVICIO = pg_temp.U('e20')) AS ENLAZADA_TRUE FROM TAB_PALPACIONES WHERE UUID_PALPACION = pg_temp.U('e30');
SELECT FUN_CREAR_PALPACION_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'PRENIADA', NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO') ->> 'CODIGO' AS SIN_MESES_400,
       FUN_CREAR_PALPACION_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('c'), 'VACIA', NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO') ->> 'CODIGO' AS TERNERA_400;


SELECT 'PRUEBA 5.1: Parto con ternera viva y peso al nacer 200. La cría entra al hato con la madre, el toro del servicio como padre, 32 kg y categoría TERNERA; la madre pasa a VACA' as PRUEBA;
SELECT FUN_CREAR_PARTO_JSON(pg_temp.U('e40'), pg_temp.FINCA(), pg_temp.U('a'), 'NORMAL', 'SI', pg_temp.U('d'), 'H', '57', 'Estrella', 32, LOCALTIMESTAMP - INTERVAL '10 days', NULL, 'PRU-VAQUERO') ->> 'MENSAJE' AS PARTO_GUARDADO;
SELECT (pg_temp.ANIMAL('d')).ID_MADRE = (pg_temp.ANIMAL('a')).ID_ANIMAL AS MADRE_TRUE,
       (pg_temp.ANIMAL('d')).ID_PADRE = (pg_temp.ANIMAL('b')).ID_ANIMAL AS PADRE_DEL_SERVICIO_TRUE,
       (pg_temp.ANIMAL('d')).PESO_ACTUAL_KG AS PESO_32_0,
       FUN_CATEGORIA_ANIMAL((pg_temp.ANIMAL('d')).ID_ANIMAL) AS TERNERA,
       FUN_CATEGORIA_ANIMAL((pg_temp.ANIMAL('a')).ID_ANIMAL) AS VACA;

SELECT 'PRUEBA 5.2: Validaciones del parto. TODAS 400: otro parto a los 10 días, aborto con cría viva, cría sin sexo, chapeta repetida, la ternera no pare, peso al nacer de 120' as PRUEBA;
SELECT T.CASO, R ->> 'CODIGO' AS CODIGO, R ->> 'MENSAJE' AS MENSAJE
FROM (VALUES
    ('OTRO PARTO', FUN_CREAR_PARTO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'NORMAL', 'NO', NULL, NULL, NULL, NULL, NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('ABORTO VIVA', FUN_CREAR_PARTO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'ABORTO', 'SI', gen_random_uuid(), 'H', NULL, NULL, NULL, LOCALTIMESTAMP - INTERVAL '400 days', NULL, 'PRU-DUENO')),
    ('CRIA SIN SEXO', FUN_CREAR_PARTO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'NORMAL', 'SI', gen_random_uuid(), NULL, NULL, NULL, NULL, LOCALTIMESTAMP - INTERVAL '400 days', NULL, 'PRU-DUENO')),
    ('CHAPETA REPETIDA', FUN_CREAR_PARTO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'NORMAL', 'SI', gen_random_uuid(), 'M', '23', NULL, NULL, LOCALTIMESTAMP - INTERVAL '400 days', NULL, 'PRU-DUENO')),
    ('TERNERA PARE', FUN_CREAR_PARTO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('c'), 'NORMAL', 'NO', NULL, NULL, NULL, NULL, NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO')),
    ('PESO 120', FUN_CREAR_PARTO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'NORMAL', 'SI', gen_random_uuid(), 'M', NULL, NULL, 120, LOCALTIMESTAMP - INTERVAL '400 days', NULL, 'PRU-DUENO'))
) AS T(CASO, R);

SELECT 'PRUEBA 5.3: Rollback real. Si falla el peso al nacer (trigger de prueba que lo rompe), no quedan ni el parto ni la cría: 500 y 0 animales con ese UUID' as PRUEBA;
CREATE FUNCTION pg_temp.FALLAR() RETURNS TRIGGER AS $T$ BEGIN RAISE EXCEPTION 'fallo forzado en el pesaje'; END; $T$ LANGUAGE plpgsql;
CREATE TRIGGER PRU_TRG_FALLAR BEFORE INSERT ON TAB_PESAJES FOR EACH ROW EXECUTE FUNCTION pg_temp.FALLAR();
SELECT FUN_CREAR_PARTO_JSON(pg_temp.U('e41'), pg_temp.FINCA(), pg_temp.U('a'), 'NORMAL', 'SI', pg_temp.U('dd'), 'M', '58', NULL, 30, LOCALTIMESTAMP - INTERVAL '400 days', NULL, 'PRU-DUENO') ->> 'CODIGO' AS FALLA_500;
DROP TRIGGER PRU_TRG_FALLAR ON TAB_PESAJES;
SELECT (SELECT COUNT(*) FROM TAB_ANIMALES WHERE UUID_ANIMAL = pg_temp.U('dd')) AS CRIAS_0, (SELECT COUNT(*) FROM TAB_PARTOS WHERE UUID_PARTO = pg_temp.U('e41')) AS PARTOS_0;


SELECT 'PRUEBA 6.1: Ordeño. Mañana 200; tarde 200; otra vez la mañana del mismo día con otro UUID 400 (dos celulares); a la ternera 400; 70 litros 400' as PRUEBA;
SELECT FUN_CREAR_ORDENO_JSON(pg_temp.U('e50'), pg_temp.FINCA(), pg_temp.U('a'), 'MANANA', 8.5, date_trunc('day', LOCALTIMESTAMP) - INTERVAL '1 day' + INTERVAL '5 hours', NULL, 'PRU-VAQUERO') ->> 'CODIGO' AS MANANA_200,
       FUN_CREAR_ORDENO_JSON(pg_temp.U('e51'), pg_temp.FINCA(), pg_temp.U('a'), 'TARDE', 6, date_trunc('day', LOCALTIMESTAMP) - INTERVAL '1 day' + INTERVAL '15 hours', NULL, 'PRU-VAQUERO') ->> 'CODIGO' AS TARDE_200;
SELECT FUN_CREAR_ORDENO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'MANANA', 9, date_trunc('day', LOCALTIMESTAMP) - INTERVAL '1 day' + INTERVAL '6 hours', NULL, 'PRU-DUENO') ->> 'MENSAJE' AS YA_SE_REGISTRO,
       FUN_CREAR_ORDENO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('c'), 'MANANA', 1, LOCALTIMESTAMP, NULL, 'PRU-DUENO') ->> 'CODIGO' AS TERNERA_400,
       FUN_CREAR_ORDENO_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'MANANA', 70, LOCALTIMESTAMP - INTERVAL '3 days', NULL, 'PRU-DUENO') ->> 'CODIGO' AS SETENTA_400;


SELECT 'PRUEBA 7.1: Salida. Venta sin valor 400; antes del último registro 400; venta hoy 200 y el TRIGGER TRG_SALIDA_ANIMAL la deja VENDIDO; después de la venta no se puede pesar (400 con la fecha)' as PRUEBA;
SELECT FUN_CREAR_SALIDA_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'VENTA', NULL, NULL, NULL, LOCALTIMESTAMP, NULL, 'PRU-DUENO') ->> 'CODIGO' AS SIN_VALOR_400,
       FUN_CREAR_SALIDA_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'VENTA', 3500000, NULL, NULL, LOCALTIMESTAMP - INTERVAL '20 days', NULL, 'PRU-DUENO') ->> 'CODIGO' AS ANTES_DE_REGISTROS_400;
SELECT FUN_CREAR_SALIDA_JSON(pg_temp.U('e60'), pg_temp.FINCA(), pg_temp.U('a'), 'VENTA', 3500000, 455, NULL, LOCALTIMESTAMP, NULL, 'PRU-VAQUERO') ->> 'CODIGO' AS VENTA_200;
SELECT (pg_temp.ANIMAL('a')).ESTADO_ANIMAL AS VENDIDO, (pg_temp.ANIMAL('a')).FECHA_SALIDA_ANIMAL IS NOT NULL AS FECHA_SALIDA_TRUE;
SELECT FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 460, 'NO', NULL, LOCALTIMESTAMP + INTERVAL '1 hour', NULL, 'PRU-DUENO') ->> 'MENSAJE' AS SE_VENDIO_EL;
SELECT FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 455, 'NO', NULL, LOCALTIMESTAMP - INTERVAL '1 hour', 'llega tarde, de antes de la venta', 'PRU-DUENO') ->> 'CODIGO' AS EVENTO_ANTERIOR_A_LA_VENTA_200;

SELECT 'PRUEBA 7.2: Anular la salida devuelve el animal a ACTIVO (trigger); otra salida (muerte sin causa) 400' as PRUEBA;
SELECT FUN_ANULAR_EVENTO_JSON('SALIDA', pg_temp.U('e60'), pg_temp.FINCA(), 'PRU-DUENO') ->> 'CODIGO' AS ANULAR_200;
SELECT (pg_temp.ANIMAL('a')).ESTADO_ANIMAL AS ACTIVO, (pg_temp.ANIMAL('a')).FECHA_SALIDA_ANIMAL IS NULL AS SIN_FECHA_SALIDA_TRUE,
       FUN_CREAR_SALIDA_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('a'), 'MUERTE', NULL, NULL, ' ', LOCALTIMESTAMP, NULL, 'PRU-DUENO') ->> 'CODIGO' AS MUERTE_SIN_CAUSA_400;


SELECT 'PRUEBA 8.1: Anular el parto anula también la cría y su peso (200); la cría con registros propios no deja anular el parto (400); tipo malo 400; ya anulado 200 YA_EXISTIA' as PRUEBA;
SELECT FUN_CREAR_PARTO_JSON(pg_temp.U('e42'), pg_temp.FINCA(), pg_temp.U('a'), 'ASISTIDO', 'SI', pg_temp.U('d2'), 'M', NULL, NULL, NULL, LOCALTIMESTAMP - INTERVAL '400 days', NULL, 'PRU-DUENO') ->> 'CODIGO' AS PARTO_VIEJO_200;
SELECT FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.FINCA(), pg_temp.U('d2'), 10, NULL, LOCALTIMESTAMP - INTERVAL '300 days', NULL, 'PRU-DUENO') ->> 'CODIGO' AS VACUNA_A_LA_CRIA_200;
SELECT FUN_ANULAR_EVENTO_JSON('PARTO', pg_temp.U('e42'), pg_temp.FINCA(), 'PRU-DUENO') ->> 'CODIGO' AS CRIA_CON_REGISTROS_400,
       FUN_ANULAR_EVENTO_JSON('ANIMAL', pg_temp.U('d'), pg_temp.FINCA(), 'PRU-DUENO') ->> 'CODIGO' AS TIPO_MALO_400;
SELECT FUN_ANULAR_EVENTO_JSON('PARTO', pg_temp.U('e40'), pg_temp.FINCA(), 'PRU-DUENO') ->> 'MENSAJE' AS PARTO_ANULADO_CON_CRIA;
SELECT (pg_temp.ANIMAL('d')).ESTADO_ANIMAL AS CRIA_ANULADO,
       (SELECT ESTADO_PESAJE FROM TAB_PESAJES WHERE ID_ANIMAL = (pg_temp.ANIMAL('d')).ID_ANIMAL) AS PESO_ANULADO,
       FUN_ANULAR_EVENTO_JSON('PARTO', pg_temp.U('e40'), pg_temp.FINCA(), 'PRU-DUENO') -> 'DATOS' ->> 'YA_EXISTIA' AS YA_EXISTIA_TRUE;


SELECT 'PRUEBA 9.1: Línea de tiempo de la vaca: sin lo anulado, lo más nuevo primero, y termina con "Llegó a la finca"' as PRUEBA;
SELECT E ->> 'TIPO_EVENTO' AS TIPO, E ->> 'DESCRIPCION_EVENTO' AS DESCRIPCION
FROM json_array_elements(FUN_OBTENER_LINEA_TIEMPO_JSON(pg_temp.FINCA(), pg_temp.U('a'), 'PRU-VAQUERO') -> 'DATOS') E;

ROLLBACK;
