-- SIEMBRA DE LA FINCA DE DEMOSTRACION (FASE 6): "Finca La Esperanza", SAN GIL, CON DOS AÑOS DE HISTORIA Y ALERTAS ACTIVAS HOY
-- SOLO PARA LA BASE DE LA DEMO (demoganadera): BORRA TODO LO DE TODAS LAS FINCAS Y VUELVE A SEMBRAR. NUNCA CORRERLA EN LA BASE REAL
-- USA LAS MISMAS FUNCIONES DE LA BASE (CADA UNA DEBE RESPONDER 200: SI NO, SE DETIENE Y NO QUEDA NADA A MEDIAS)
-- LAS FECHAS SON RELATIVAS A HOY: CORRIDA CADA NOCHE, SIEMPRE HAY PARTOS PROXIMOS, VACAS POR PALPAR, RETIROS DE LECHE Y UN CICLO DEL ICA
-- USO (UNA SOLA TRANSACCION):
--   psql -X -1 -v ON_ERROR_STOP=1 -v duenio=<id_usuario> -v vaquero=<id_usuario> -v veterinario=<id_usuario> -d <base_demo> -f SEMBRAR_FINCA_DEMO.SQL
-- LOS id_usuario SON LOS DE LAS TRES CUENTAS DE EJEMPLO EN LA BASE DE SEGURIDAD DE LA DEMO (crear_cuentas_demo.mjs)
-- LOS DATOS SALEN DE random() CON SEMILLA FIJA: CADA NOCHE LA FINCA ES LA MISMA, SOLO SE CORREN LAS FECHAS
SELECT set_config('demo.duenio', :'duenio', false), set_config('demo.vaquero', :'vaquero', false), set_config('demo.veterinario', :'veterinario', false);

--1. LIMPIAR (LA BASE DE LA DEMO SOLO TIENE LA DEMO). LA CONFIGURACION Y LOS CATALOGOS NO SE TOCAN
SET LOCAL ganadero.permitir_borrar = 'SI';
DELETE FROM TAB_MENSAJES_WHATSAPP;
DELETE FROM TAB_MOVIMIENTOS;
DELETE FROM TAB_OCUPACIONES;
DELETE FROM TAB_POTREROS;
DELETE FROM TAB_PESAJES;
DELETE FROM TAB_ORDENOS;
DELETE FROM TAB_VACUNACIONES;
DELETE FROM TAB_PALPACIONES;
DELETE FROM TAB_SALIDAS;
DELETE FROM TAB_PARTOS;
DELETE FROM TAB_SERVICIOS;
UPDATE TAB_ANIMALES SET ID_MADRE = NULL, ID_PADRE = NULL;
DELETE FROM TAB_ANIMALES;
DELETE FROM TAB_LOTES;
DELETE FROM TAB_SINCRONIZACIONES;
DELETE FROM TAB_FINCAS_PERSONAS;
DELETE FROM TAB_FINCAS;
DELETE FROM TAB_CICLOS_ICA WHERE NOM_CICLO LIKE 'Ciclo % demo';
DELETE FROM TAB_AUDITORIAS;

--2. AYUDANTES (SOLO EN ESTA SESION)
--UNA FUNCION DE LA BASE QUE NO RESPONDE 200 DETIENE LA SIEMBRA CON SU MENSAJE
CREATE FUNCTION pg_temp.OK(jRESPUESTA JSON, jQUE TEXT) RETURNS JSON AS $$
BEGIN
    IF (jRESPUESTA ->> 'CODIGO')::INTEGER != 200 THEN
        RAISE EXCEPTION 'La siembra se detuvo en "%": %', jQUE, jRESPUESTA ->> 'MENSAJE';
    END IF;
    RETURN jRESPUESTA;
END;
$$ LANGUAGE plpgsql;
CREATE FUNCTION pg_temp.HACE(jDIAS INTEGER, jHORA TIME DEFAULT '07:00') RETURNS TIMESTAMP AS $$ SELECT (CURRENT_DATE - jDIAS) + jHORA $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.D() RETURNS VARCHAR AS $$ SELECT current_setting('demo.duenio') $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.V() RETURNS VARCHAR AS $$ SELECT current_setting('demo.vaquero') $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.VET() RETURNS VARCHAR AS $$ SELECT current_setting('demo.veterinario') $$ LANGUAGE sql;
SELECT setseed(0.4242);

--3. LA FINCA, SUS PERSONAS, LOS LOTES Y LOS POTREROS
DO $$
DECLARE
    jFINCA INTEGER;
BEGIN
    jFINCA := (pg_temp.OK(FUN_CREAR_FINCA_JSON('Finca La Esperanza', 'San Gil', 'Vereda Guarigua', '68679-0042', 'LE', pg_temp.D(), 'Álvaro Ramírez'), 'finca') -> 'DATOS' ->> 'ID_FINCA')::INTEGER;
    PERFORM set_config('demo.finca', jFINCA::TEXT, false);
    PERFORM pg_temp.OK(FUN_AGREGAR_PERSONA_FINCA_JSON(jFINCA, pg_temp.V(), 'Jairo Pinto', 'VAQUERO', pg_temp.D()), 'vaquero');
    PERFORM pg_temp.OK(FUN_AGREGAR_PERSONA_FINCA_JSON(jFINCA, pg_temp.VET(), 'Paola Rueda', 'VETERINARIO', pg_temp.D()), 'veterinaria');
    PERFORM pg_temp.OK(FUN_CREAR_LOTE_JSON(gen_random_uuid(), jFINCA, n, pg_temp.D()), 'lote ' || n) FROM unnest(ARRAY['Ordeño', 'Horras y novillas', 'Levante']) n;
    PERFORM pg_temp.OK(FUN_CREAR_POTRERO_JSON(gen_random_uuid(), jFINCA, 'La Loma', 4.5, 20, '[[6.6012,-73.1211],[6.6031,-73.1209],[6.6033,-73.1188],[6.6014,-73.1186]]'::JSON, pg_temp.D()), 'potrero');
    PERFORM pg_temp.OK(FUN_CREAR_POTRERO_JSON(gen_random_uuid(), jFINCA, 'El Bajo', 3.2, 25, '[[6.5995,-73.1213],[6.6012,-73.1211],[6.6014,-73.1186],[6.5996,-73.1190]]'::JSON, pg_temp.D()), 'potrero');
    PERFORM pg_temp.OK(FUN_CREAR_POTRERO_JSON(gen_random_uuid(), jFINCA, 'El Mango', 2.8, 28, '[[6.6031,-73.1209],[6.6047,-73.1206],[6.6049,-73.1190],[6.6033,-73.1188]]'::JSON, pg_temp.D()), 'potrero');
    PERFORM pg_temp.OK(FUN_CREAR_POTRERO_JSON(gen_random_uuid(), jFINCA, 'La Quebrada', 5.0, 35, NULL, pg_temp.D()), 'potrero');
    PERFORM pg_temp.OK(FUN_CREAR_POTRERO_JSON(gen_random_uuid(), jFINCA, 'Potrero Nuevo', 6.0, 30, NULL, pg_temp.D()), 'potrero');
END $$;
CREATE FUNCTION pg_temp.F() RETURNS INTEGER AS $$ SELECT current_setting('demo.finca')::INTEGER $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.LOTE(jNOM VARCHAR) RETURNS UUID AS $$ SELECT UUID_LOTE FROM TAB_LOTES WHERE ID_FINCA = pg_temp.F() AND NOM_LOTE = jNOM $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.POTRERO(jNOM VARCHAR) RETURNS UUID AS $$ SELECT UUID_POTRERO FROM TAB_POTREROS WHERE ID_FINCA = pg_temp.F() AND NOM_POTRERO = jNOM $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.SALIO(jUUID UUID) RETURNS INTEGER AS $$ SELECT COALESCE((SELECT CURRENT_DATE - S.FECHA_EVENTO::DATE FROM TAB_SALIDAS S JOIN TAB_ANIMALES A ON A.ID_ANIMAL = S.ID_ANIMAL WHERE A.UUID_ANIMAL = jUUID AND S.ESTADO_SALIDA = 'ACTIVO'), 0) $$ LANGUAGE sql;
CREATE FUNCTION pg_temp.ANIMAL(jCHAPETA VARCHAR) RETURNS UUID AS $$ SELECT UUID_ANIMAL FROM TAB_ANIMALES WHERE ID_FINCA = pg_temp.F() AND CHAPETA_ANIMAL = jCHAPETA $$ LANGUAGE sql;

--4. LOS ANIMALES COMPRADOS HACE 2 AÑOS: 18 VACAS (101 A 118), EL TORO T01 Y 4 NOVILLAS (201 A 204)
DO $$
DECLARE
    jK INTEGER;
    jNOMBRES TEXT[] := ARRAY['Lucero', 'Canela', 'Mariposa', 'Paloma', 'Estrella', 'Morena', 'Linda', 'Princesa', 'Bonita', 'Perla',
                              'Golondrina', 'Azucena', 'Margarita', 'Pinta', 'Gitana', 'Violeta', 'Reina', 'Manchas'];
    jRAZAS INTEGER[] := ARRAY[9, 2, 7, 13, 9, 1, 13, 9, 2, 7, 13, 9, 2, 13, 7, 9, 13, 2];
BEGIN
    FOR jK IN 1..18 LOOP
        PERFORM pg_temp.OK(FUN_CREAR_ANIMAL_JSON(gen_random_uuid(), pg_temp.F(), NULL, jRAZAS[jK], (100 + jK)::TEXT, jNOMBRES[jK], 'H',
            (CURRENT_DATE - (1500 + jK * 97 % 900)), 'SI', NULL, NULL, NULL, 'COMPRADO', CURRENT_DATE - 760, pg_temp.D()), 'vaca ' || (100 + jK));
    END LOOP;
    PERFORM pg_temp.OK(FUN_CREAR_ANIMAL_JSON(gen_random_uuid(), pg_temp.F(), NULL, 2, 'T01', 'Sultán', 'M', CURRENT_DATE - 2300, 'SI', NULL, NULL, NULL,
        'COMPRADO', CURRENT_DATE - 760, pg_temp.D()), 'toro');
    FOR jK IN 1..4 LOOP
        PERFORM pg_temp.OK(FUN_CREAR_ANIMAL_JSON(gen_random_uuid(), pg_temp.F(), NULL, 9, (200 + jK)::TEXT, NULL, 'H', CURRENT_DATE - (690 + jK * 11), 'NO',
            NULL, NULL, NULL, 'COMPRADO', CURRENT_DATE - 700, pg_temp.D()), 'novilla ' || (200 + jK));
    END LOOP;
    --LA COMPRA DE LAS NOVILLAS (PLATA)
    PERFORM pg_temp.OK(FUN_CREAR_MOVIMIENTO_JSON(gen_random_uuid(), pg_temp.F(), 'GASTO', 'COMPRA_ANIMAL', 7200000, NULL, '4 novillas Girolando', pg_temp.HACE(700, '10:00'), pg_temp.D()), 'compra');
END $$;

--5. LA REPRODUCCION DE CADA VACA: PARTO, SERVICIO A LOS ~85 DIAS, PALPACION A LOS ~50, PARTO A LOS 283... HASTA HOY
--   VARIAS QUEDAN A PROPOSITO PARA LAS ALERTAS: SIN PALPAR (101, 107), VACIAS SIN SERVIR (104, 112) Y PARTOS QUE VIENEN
--   LA CRIA NACE VIVA (MENOS UNA DE CADA 9) Y QUEDA CON CHAPETA 3xx Y SU PESO AL NACER
DO $$
DECLARE
    jK INTEGER;
    jVACA UUID;
    jPARTO INTEGER;
    jSERVICIO INTEGER;
    jCRIA INTEGER := 300;
    jVIVA BOOLEAN;
    jSEXO VARCHAR;
BEGIN
    FOR jK IN 1..18 LOOP
        jVACA := pg_temp.ANIMAL((100 + jK)::TEXT);
        jPARTO := 380 + (jK * 37) % 330;                      --EL PRIMER PARTO REGISTRADO: ENTRE 380 Y 710 DIAS ATRAS
        LOOP
            jCRIA := jCRIA + 1;
            jVIVA := jCRIA % 9 <> 0;
            jSEXO := CASE WHEN jCRIA % 2 = 0 THEN 'H' ELSE 'M' END;
            PERFORM pg_temp.OK(FUN_CREAR_PARTO_JSON(gen_random_uuid(), pg_temp.F(), jVACA, CASE WHEN jVIVA THEN 'NORMAL' ELSE 'ABORTO' END,
                CASE WHEN jVIVA THEN 'SI' ELSE 'NO' END, CASE WHEN jVIVA THEN gen_random_uuid() END, CASE WHEN jVIVA THEN jSEXO END,
                CASE WHEN jVIVA THEN jCRIA::TEXT END, NULL, CASE WHEN jVIVA THEN 28 + (jCRIA % 9) END, pg_temp.HACE(jPARTO, '05:30'),
                NULL, pg_temp.V()), 'parto de ' || (100 + jK));
            --LAS VACIAS: 104 Y 112 NO SE SIRVEN DESPUES DE SU ULTIMO PARTO SI YA PASARON 130 DIAS
            jSERVICIO := jPARTO - 80 - (jK * 7) % 25;
            EXIT WHEN jSERVICIO < 1;
            EXIT WHEN jK IN (4, 12) AND jSERVICIO - 283 < 1;
            PERFORM pg_temp.OK(FUN_CREAR_SERVICIO_JSON(gen_random_uuid(), pg_temp.F(), jVACA, CASE WHEN jK % 3 = 0 THEN 'INSEMINACION' ELSE 'MONTA' END,
                CASE WHEN jK % 3 = 0 THEN NULL ELSE pg_temp.ANIMAL('T01') END, CASE WHEN jK % 3 = 0 THEN 'Pajilla Gyr lechero' END,
                pg_temp.HACE(jSERVICIO, '08:00'), NULL, pg_temp.V()), 'servicio de ' || (100 + jK));
            --PALPACION A LOS 50 DIAS (101 Y 107 SE QUEDAN SIN PALPAR SI EL SERVICIO ES RECIENTE)
            IF jSERVICIO - 50 >= 1 AND NOT (jK IN (1, 7) AND jSERVICIO < 120) THEN
                PERFORM pg_temp.OK(FUN_CREAR_PALPACION_JSON(gen_random_uuid(), pg_temp.F(), jVACA, 'PRENIADA', 2, pg_temp.HACE(jSERVICIO - 50, '09:00'),
                    NULL, pg_temp.VET()), 'palpación de ' || (100 + jK));
            END IF;
            jPARTO := jSERVICIO - 283;
            EXIT WHEN jPARTO < 1;
        END LOOP;
    END LOOP;
    --LAS 4 NOVILLAS: SERVIDAS HACE 276, 262, 150 Y 60 DIAS (LAS DOS PRIMERAS PAREN EN 1 Y 3 SEMANAS); PALPADAS LAS QUE PASARON 50 DIAS
    FOR jK IN 1..4 LOOP
        jSERVICIO := (ARRAY[276, 262, 150, 60])[jK];
        PERFORM pg_temp.OK(FUN_CREAR_SERVICIO_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.ANIMAL((200 + jK)::TEXT), 'MONTA', pg_temp.ANIMAL('T01'), NULL,
            pg_temp.HACE(jSERVICIO, '08:00'), NULL, pg_temp.V()), 'servicio de novilla');
        IF jSERVICIO > 60 THEN
            PERFORM pg_temp.OK(FUN_CREAR_PALPACION_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.ANIMAL((200 + jK)::TEXT), 'PRENIADA', 2,
                pg_temp.HACE(jSERVICIO - 50, '09:00'), NULL, pg_temp.VET()), 'palpación de novilla');
        END IF;
    END LOOP;
END $$;

--5B. SALIDAS (ANTES DE PESAR Y VACUNAR: DESPUES DE LA SALIDA NO SE PUEDE REGISTRAR NADA): SE VENDIERON 4 MACHOS DE LEVANTE (LOS MAS VIEJOS) Y SE MURIO UNA TERNERA
DO $$
DECLARE
    jR RECORD;
    jN INTEGER := 0;
BEGIN
    FOR jR IN SELECT UUID_ANIMAL, CHAPETA_ANIMAL, CURRENT_DATE - FECHA_NACIMIENTO AS EDAD FROM TAB_ANIMALES
              WHERE ID_FINCA = pg_temp.F() AND ORIGEN_ANIMAL = 'NACIDO' AND SEXO_ANIMAL = 'M' AND CURRENT_DATE - FECHA_NACIMIENTO > 330
              ORDER BY FECHA_NACIMIENTO LIMIT 4 LOOP
        jN := jN + 1;
        PERFORM pg_temp.OK(FUN_CREAR_SALIDA_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 'VENTA', 1650000 + jN * 120000, round((32 + (jR.EDAD - (jN * 20)) * 0.7)::NUMERIC, 1),
            NULL, pg_temp.HACE(jN * 20 - 1, '11:00'), 'Al comprador de Barbosa', pg_temp.D()), 'venta de ' || jR.CHAPETA_ANIMAL);
    END LOOP;
    FOR jR IN SELECT UUID_ANIMAL FROM TAB_ANIMALES WHERE ID_FINCA = pg_temp.F() AND ORIGEN_ANIMAL = 'NACIDO' AND SEXO_ANIMAL = 'H'
              AND CURRENT_DATE - FECHA_NACIMIENTO BETWEEN 60 AND 200 ORDER BY FECHA_NACIMIENTO LIMIT 1 LOOP
        PERFORM pg_temp.OK(FUN_CREAR_SALIDA_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 'MUERTE', NULL, NULL, 'Diarrea', pg_temp.HACE(40, '06:00'), NULL, pg_temp.D()), 'muerte');
    END LOOP;
END $$;

--6. ORDEÑOS: CADA DIA, MAÑANA Y TARDE, LAS VACAS QUE PARIERON HACE ENTRE 4 Y 300 DIAS (LOS ULTIMOS 365 DIAS, HASTA AYER)
--   CURVA DE LACTANCIA: SUBE HASTA LOS 50 DIAS Y BAJA; LA TARDE DA MENOS QUE LA MAÑANA
DO $$
DECLARE
    jR RECORD;
    jDIA INTEGER;
    jLITROS NUMERIC;
BEGIN
    FOR jR IN
        SELECT A.UUID_ANIMAL, A.CHAPETA_ANIMAL, CURRENT_DATE - P.FECHA_EVENTO::DATE AS HACE_PARTO,
               COALESCE((SELECT MIN(CURRENT_DATE - P2.FECHA_EVENTO::DATE) FROM TAB_PARTOS P2
                         WHERE P2.ID_ANIMAL = P.ID_ANIMAL AND P2.FECHA_EVENTO > P.FECHA_EVENTO AND P2.ESTADO_PARTO = 'ACTIVO'), 0) AS HACE_SIGUIENTE
        FROM TAB_PARTOS P JOIN TAB_ANIMALES A ON A.ID_ANIMAL = P.ID_ANIMAL
        WHERE P.ID_FINCA = pg_temp.F() AND P.TIPO_PARTO <> 'ABORTO' AND CURRENT_DATE - P.FECHA_EVENTO::DATE <= 365 + 300
    LOOP
        FOR jDIA IN GREATEST(1, jR.HACE_PARTO - 300, jR.HACE_SIGUIENTE + 1)..LEAST(365, jR.HACE_PARTO - 4) LOOP
            jLITROS := round((CASE WHEN jR.HACE_PARTO - jDIA < 50 THEN 4 + (jR.HACE_PARTO - jDIA) * 0.08 ELSE 8 - (jR.HACE_PARTO - jDIA - 50) * 0.018 END
                              + random() * 1.2 - 0.6)::NUMERIC, 1);
            PERFORM pg_temp.OK(FUN_CREAR_ORDENO_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 'MANANA', GREATEST(jLITROS, 1.5), pg_temp.HACE(jDIA, '05:00'),
                NULL, pg_temp.V()), 'ordeño de ' || jR.CHAPETA_ANIMAL);
            PERFORM pg_temp.OK(FUN_CREAR_ORDENO_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 'TARDE', GREATEST(round(jLITROS * 0.7, 1), 1), pg_temp.HACE(jDIA, '15:00'),
                NULL, pg_temp.V()), 'ordeño de ' || jR.CHAPETA_ANIMAL);
        END LOOP;
    END LOOP;
END $$;

--7. PESAJES: LAS CRIAS CADA MES DESDE QUE NACIERON (UNOS 700 G AL DIA), LAS NOVILLAS CADA 3 MESES Y EL TORO DOS VECES
DO $$
DECLARE
    jR RECORD;
    jDIA INTEGER;
BEGIN
    FOR jR IN SELECT UUID_ANIMAL, CHAPETA_ANIMAL, CURRENT_DATE - FECHA_NACIMIENTO AS EDAD FROM TAB_ANIMALES
              WHERE ID_FINCA = pg_temp.F() AND ORIGEN_ANIMAL = 'NACIDO' LOOP
        jDIA := jR.EDAD - 30;
        WHILE jDIA >= GREATEST(3, pg_temp.SALIO(jR.UUID_ANIMAL) + 1) LOOP
            PERFORM pg_temp.OK(FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, round((32 + (jR.EDAD - jDIA) * 0.7 + random() * 6 - 3)::NUMERIC, 1),
                'NO', NULL, pg_temp.HACE(jDIA, '07:30'), NULL, pg_temp.V()), 'pesaje de ' || jR.CHAPETA_ANIMAL);
            jDIA := jDIA - 30;
        END LOOP;
    END LOOP;
    FOR jR IN SELECT UUID_ANIMAL, CHAPETA_ANIMAL FROM TAB_ANIMALES WHERE ID_FINCA = pg_temp.F() AND CHAPETA_ANIMAL LIKE '20_' LOOP
        FOR jDIA IN SELECT generate_series(690, 10, -90) LOOP
            PERFORM pg_temp.OK(FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, round((300 + (690 - jDIA) * 0.35 + random() * 10)::NUMERIC, 1),
                'NO', NULL, pg_temp.HACE(jDIA, '07:30'), NULL, pg_temp.V()), 'pesaje de novilla');
        END LOOP;
    END LOOP;
    PERFORM pg_temp.OK(FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.ANIMAL('T01'), 720, 'NO', NULL, pg_temp.HACE(400), NULL, pg_temp.V()), 'pesaje del toro');
    PERFORM pg_temp.OK(FUN_CREAR_PESAJE_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.ANIMAL('T01'), NULL, 'SI', 215, pg_temp.HACE(30), 'Con cinta', pg_temp.V()), 'pesaje del toro');
END $$;

--8. SANIDAD: LOS CICLOS DE AFTOSA DEL ICA (NOVIEMBRE PASADO, MAYO Y EL DE AHORA, VIGENTE Y A MEDIAS), BRUCELOSIS A LAS TERNERAS,
--   DESPARASITANTE CADA 3 MESES Y DOS TRATAMIENTOS RECIENTES (LECHE QUE NO SE PUEDE VENDER HOY)
DO $$
DECLARE
    jR RECORD;
    jN INTEGER := 0;
BEGIN
    PERFORM pg_temp.OK(FUN_CREAR_CICLO_ICA_JSON(1, 'Ciclo anterior demo', CURRENT_DATE - 365, CURRENT_DATE - 320, 'SISTEMA'), 'ciclo');
    PERFORM pg_temp.OK(FUN_CREAR_CICLO_ICA_JSON(1, 'Ciclo de mitad de año demo', CURRENT_DATE - 185, CURRENT_DATE - 140, 'SISTEMA'), 'ciclo');
    PERFORM pg_temp.OK(FUN_CREAR_CICLO_ICA_JSON(1, 'Ciclo de ahora demo', CURRENT_DATE - 6, CURRENT_DATE + 30, 'SISTEMA'), 'ciclo');
    FOR jR IN SELECT A.UUID_ANIMAL, A.CHAPETA_ANIMAL, A.FECHA_NACIMIENTO, A.SEXO_ANIMAL, pg_temp.SALIO(A.UUID_ANIMAL) AS SALIO
              FROM TAB_ANIMALES A WHERE A.ID_FINCA = pg_temp.F() ORDER BY A.ID_ANIMAL LOOP
        jN := jN + 1;
        --AFTOSA EN LOS DOS CICLOS PASADOS (LOS QUE YA HABIAN NACIDO) Y EN EL DE AHORA A DOS DE CADA TRES
        IF jR.FECHA_NACIMIENTO <= CURRENT_DATE - 360 AND 355 - jN % 10 > jR.SALIO THEN
            PERFORM pg_temp.OK(FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 1, '2 ml', pg_temp.HACE(355 - jN % 10, '08:30'), NULL, pg_temp.VET()), 'aftosa');
        END IF;
        IF jR.FECHA_NACIMIENTO <= CURRENT_DATE - 180 AND 175 - jN % 10 > jR.SALIO THEN
            PERFORM pg_temp.OK(FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 1, '2 ml', pg_temp.HACE(175 - jN % 10, '08:30'), NULL, pg_temp.VET()), 'aftosa');
        END IF;
        IF jN % 3 <> 0 AND jR.SALIO = 0 THEN
            PERFORM pg_temp.OK(FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 1, '2 ml', pg_temp.HACE(3, '08:30'), NULL, pg_temp.VET()), 'aftosa');
        END IF;
        --BRUCELOSIS A LAS TERNERAS ENTRE 3 Y 8 MESES
        IF jR.SEXO_ANIMAL = 'H' AND jR.FECHA_NACIMIENTO BETWEEN CURRENT_DATE - 700 AND CURRENT_DATE - 160
           AND (jR.SALIO = 0 OR CURRENT_DATE - (jR.FECHA_NACIMIENTO + 150) > jR.SALIO) THEN
            PERFORM pg_temp.OK(FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 2, NULL,
                (jR.FECHA_NACIMIENTO + 150) + TIME '08:30', NULL, pg_temp.VET()), 'brucelosis');
        END IF;
        --DESPARASITANTE (EL ULTIMO HACE 60 DIAS: EL REFUERZO TOCA EN UN MES)
        IF jR.FECHA_NACIMIENTO <= CURRENT_DATE - 90 AND 60 > jR.SALIO THEN
            PERFORM pg_temp.OK(FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.F(), jR.UUID_ANIMAL, 6, '10 ml', pg_temp.HACE(60, '09:00'), NULL, pg_temp.VET()), 'albendazol');
        END IF;
    END LOOP;
    PERFORM pg_temp.OK(FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.ANIMAL('105'), 8, '20 ml', pg_temp.HACE(2, '10:00'), 'Cojera en la pata trasera', pg_temp.VET()), 'oxitetraciclina');
    PERFORM pg_temp.OK(FUN_CREAR_VACUNACION_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.ANIMAL('109'), 9, '1 jeringa', pg_temp.HACE(1, '10:00'), 'Mastitis en un cuarto', pg_temp.VET()), 'mastitis');
END $$;

--10. LOTES DE HOY: EN ORDEÑO LAS QUE PARIERON HACE MENOS DE 300 DIAS, EL LEVANTE LAS CRIAS DE MENOS DE 2 AÑOS, LAS DEMAS HEMBRAS EN HORRAS
--    (EN LA APP EL LOTE SE CAMBIA EDITANDO EL ANIMAL; AQUI SE PONE DIRECTO PORQUE ES LA FOTO DE HOY)
UPDATE TAB_ANIMALES A SET ID_LOTE = (SELECT ID_LOTE FROM TAB_LOTES WHERE ID_FINCA = pg_temp.F() AND NOM_LOTE =
    CASE WHEN EXISTS (SELECT 1 FROM TAB_PARTOS P WHERE P.ID_ANIMAL = A.ID_ANIMAL AND P.TIPO_PARTO <> 'ABORTO' AND P.FECHA_EVENTO >= CURRENT_DATE - 300) THEN 'Ordeño'
         WHEN A.ORIGEN_ANIMAL = 'NACIDO' THEN 'Levante'
         ELSE 'Horras y novillas' END), USUARIO_MODIFICACION = pg_temp.D()
WHERE A.ID_FINCA = pg_temp.F() AND A.ESTADO_ANIMAL = 'ACTIVO' AND A.CHAPETA_ANIMAL <> 'T01';

--11. ROTACION DE LOS ULTIMOS 4 MESES: ORDEÑO CADA 10 DIAS ENTRE LA LOMA, EL BAJO Y EL MANGO; HORRAS CADA 20 ENTRE LA QUEBRADA Y POTRERO NUEVO;
--    EL LEVANTE ENTRO A POTRERO NUEVO HACE 18 DIAS. HOY: EL MANGO Y LA QUEBRADA OCUPADOS, EL BAJO DESCANSANDO Y LA LOMA LISTA
DO $$
DECLARE
    jDIA INTEGER;
    jN INTEGER := 0;
BEGIN
    FOR jDIA IN SELECT generate_series(120, 8, -10) LOOP
        jN := jN + 1;
        PERFORM pg_temp.OK(FUN_ENTRAR_LOTE_POTRERO_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.LOTE('Ordeño'),
            pg_temp.POTRERO((ARRAY['La Loma', 'El Bajo', 'El Mango'])[(jN - 1) % 3 + 1]), pg_temp.HACE(jDIA, '16:00'), NULL, pg_temp.V()), 'rotación del ordeño');
    END LOOP;
    jN := 0;
    FOR jDIA IN SELECT generate_series(120, 20, -20) LOOP
        jN := jN + 1;
        PERFORM pg_temp.OK(FUN_ENTRAR_LOTE_POTRERO_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.LOTE('Horras y novillas'),
            pg_temp.POTRERO((ARRAY['La Quebrada', 'Potrero Nuevo'])[(jN - 1) % 2 + 1]), pg_temp.HACE(jDIA, '16:30'), NULL, pg_temp.V()), 'rotación de las horras');
    END LOOP;
    PERFORM pg_temp.OK(FUN_ENTRAR_LOTE_POTRERO_JSON(gen_random_uuid(), pg_temp.F(), pg_temp.LOTE('Levante'), pg_temp.POTRERO('Potrero Nuevo'),
        pg_temp.HACE(18, '16:45'), NULL, pg_temp.V()), 'levante');
END $$;

--12. LA PLATA DE LOS ULTIMOS 12 MESES: LECHE CADA 15 DIAS (CON LITROS), SAL Y JORNALES CADA MES, DROGAS DE VEZ EN CUANDO
DO $$
DECLARE
    jDIA INTEGER;
    jLITROS NUMERIC;
BEGIN
    FOR jDIA IN SELECT generate_series(362, 1, -15) LOOP
        SELECT COALESCE(SUM(LITROS_ORDENO), 0) INTO jLITROS FROM TAB_ORDENOS
        WHERE ID_FINCA = pg_temp.F() AND FECHA_EVENTO::DATE BETWEEN CURRENT_DATE - jDIA - 14 AND CURRENT_DATE - jDIA;
        IF jLITROS > 0 THEN
            --SE VENDE CASI TODA (EL RESTO SE QUEDA EN LA CASA Y PARA LOS TERNEROS) A UNOS $1.650 EL LITRO
            PERFORM pg_temp.OK(FUN_CREAR_MOVIMIENTO_JSON(gen_random_uuid(), pg_temp.F(), 'INGRESO', 'VENTA_LECHE', round(jLITROS * 0.9 * 1650), round(jLITROS * 0.9, 1),
                'Quincena a la cooperativa', pg_temp.HACE(jDIA, '17:00'), pg_temp.D()), 'venta de leche');
        END IF;
    END LOOP;
    FOR jDIA IN SELECT generate_series(333, 1, -30) LOOP
        PERFORM pg_temp.OK(FUN_CREAR_MOVIMIENTO_JSON(gen_random_uuid(), pg_temp.F(), 'GASTO', 'SAL_CONCENTRADO', 380000 + (jDIA % 7) * 10000, NULL, 'Sal mineralizada y concentrado',
            pg_temp.HACE(jDIA, '12:00'), pg_temp.D()), 'sal');
        PERFORM pg_temp.OK(FUN_CREAR_MOVIMIENTO_JSON(gen_random_uuid(), pg_temp.F(), 'GASTO', 'JORNALES', 1300000, NULL, 'Mes del vaquero',
            pg_temp.HACE(jDIA, '12:30'), pg_temp.D()), 'jornales');
        IF jDIA % 60 < 30 THEN
            PERFORM pg_temp.OK(FUN_CREAR_MOVIMIENTO_JSON(gen_random_uuid(), pg_temp.F(), 'GASTO', 'DROGAS', 150000 + (jDIA % 5) * 25000, NULL, NULL,
                pg_temp.HACE(jDIA, '13:00'), pg_temp.D()), 'drogas');
        END IF;
    END LOOP;
    PERFORM pg_temp.OK(FUN_CREAR_MOVIMIENTO_JSON(gen_random_uuid(), pg_temp.F(), 'GASTO', 'OTRO_GASTO', 450000, NULL, 'Arreglo de la cerca de La Loma',
        pg_temp.HACE(45, '14:00'), pg_temp.D()), 'cerca');
END $$;

--13. EL RESUMEN DE LO SEMBRADO (LO LEE EL SCRIPT DE LA RESIEMBRA)
SELECT 'Finca demo sembrada: ' || (SELECT COUNT(*) FROM TAB_ANIMALES WHERE ID_FINCA = pg_temp.F() AND ESTADO_ANIMAL = 'ACTIVO') || ' animales activos, '
    || (SELECT COUNT(*) FROM TAB_PARTOS WHERE ID_FINCA = pg_temp.F()) || ' partos, '
    || (SELECT COUNT(*) FROM TAB_ORDENOS WHERE ID_FINCA = pg_temp.F()) || ' ordeños, '
    || (SELECT COUNT(*) FROM TAB_PESAJES WHERE ID_FINCA = pg_temp.F()) || ' pesajes, '
    || (SELECT COUNT(*) FROM TAB_VACUNACIONES WHERE ID_FINCA = pg_temp.F()) || ' vacunaciones, '
    || (SELECT COUNT(*) FROM TAB_MOVIMIENTOS WHERE ID_FINCA = pg_temp.F()) || ' movimientos de plata' AS RESULTADO;
