-- DML DE LA BASE DE SEGURIDAD DE GANADERO (seguridadganadero) ---------------------------------------------------------------------------------------
-- EJECUTAR DESPUES DE "npm run migrate" EN ms-seguridad-ganadero (CREA LAS TABLAS usuario, rol, menu, menurol, login)
-- LOS IDS DEBEN COINCIDIR CON ConfiguracionSeguridad EN AMBOS MICROSERVICIOS
-- APROBADA EL 22/10/2026. SEGURIDAD DICE QUE PUEDE HACER CADA ROL; LA BASE DE LOGICA DICE SOBRE QUE FINCA (TAB_FINCAS_PERSONAS)


-- ROLES ----------------------------------------------------------------------------------------------------------------------------
INSERT INTO rol (id_rol, nombre, comentario) VALUES
(1, 'Administrador', 'Administra la plataforma: usuarios y catalogos (vacunas, razas, ciclos del ICA)'),
(2, 'Dueño', 'Maneja su finca: personas, hato y eventos; corrige y anula'),
(3, 'Vaquero', 'Registra animales y eventos; no corrige ni anula'),
(4, 'Veterinario', 'Registra sanidad y reproduccion y consulta indicadores (fase 5)');


-- MENUS ----------------------------------------------------------------------------------------------------------------------------
INSERT INTO menu (id_menu, nombre, comentario) VALUES
(1, 'Usuarios', 'Cuentas de la plataforma'),
(2, 'Mi finca', 'Datos de la finca y sus personas'),
(3, 'Hato', 'Animales, lotes y ficha con la linea de tiempo'),
(4, '¿Qué pasó hoy?', 'Registrar eventos: ordeño, pesaje, vacuna, servicio, parto, salida'),
(5, 'Hoy y alertas', 'Partos proximos, vacas vacias, vacunas y retiros de leche'),
(6, 'Indicadores y Excel', 'Natalidad, intervalo entre partos, litros, ganancia de peso'),
(7, 'Configuración', 'Vacunas, razas y ciclos del ICA'),
(8, 'Sincronización', 'Subir y bajar cambios del celular'),
(9, 'Mi perfil', 'Mis datos y cambiar la clave');


-- PERMISOS (MENUROL) ---------------------------------------------------------------------------------------------------------------
-- listar = true ES EL INDICADOR PARA MOSTRAR EL MENU EN EL FRONTEND. eliminar = ANULAR (EN GANADERO NO SE BORRA)
-- LEYENDA LGEXB: L listar · G guardar · E editar · X eliminar (anular) · B buscar_id
INSERT INTO menurol (listar, guardar, eliminar, editar, buscar_id, rolid, menuid) VALUES
-- ADMINISTRADOR
(true, true, true, true, true, 1, 1),      -- Usuarios            LGEXB
(true, true, true, true, true, 1, 2),      -- Mi finca            LGEXB
(true, true, true, true, true, 1, 3),      -- Hato                LGEXB
(true, true, true, true, true, 1, 4),      -- ¿Qué pasó hoy?      LGEXB
(true, false, false, false, true, 1, 5),   -- Hoy y alertas       L···B
(true, false, false, false, true, 1, 6),   -- Indicadores         L···B
(true, true, true, true, true, 1, 7),      -- Configuración       LGEXB
(true, true, false, false, true, 1, 8),    -- Sincronización      LG··B
(true, false, false, true, false, 1, 9),   -- Mi perfil           L··E·
-- DUEÑO
(true, true, false, true, true, 2, 2),     -- Mi finca            LGE·B
(true, true, true, true, true, 2, 3),      -- Hato                LGEXB
(true, true, true, true, true, 2, 4),      -- ¿Qué pasó hoy?      LGEXB
(true, false, false, false, true, 2, 5),   -- Hoy y alertas       L···B
(true, false, false, false, true, 2, 6),   -- Indicadores         L···B
(true, false, false, false, true, 2, 7),   -- Configuración       L···B
(true, true, false, false, true, 2, 8),    -- Sincronización      LG··B
(true, false, false, true, false, 2, 9),   -- Mi perfil           L··E·
-- VAQUERO
(true, true, false, false, true, 3, 3),    -- Hato                LG··B
(true, true, false, false, true, 3, 4),    -- ¿Qué pasó hoy?      LG··B
(true, false, false, false, true, 3, 5),   -- Hoy y alertas       L···B
(true, true, false, false, true, 3, 8),    -- Sincronización      LG··B
(true, false, false, true, false, 3, 9),   -- Mi perfil           L··E·
-- VETERINARIO
(true, false, false, false, true, 4, 3),   -- Hato                L···B
(true, true, false, false, true, 4, 4),    -- ¿Qué pasó hoy?      LG··B
(true, false, false, false, true, 4, 5),   -- Hoy y alertas       L···B
(true, false, false, false, true, 4, 6),   -- Indicadores         L···B
(true, true, false, false, true, 4, 8),    -- Sincronización      LG··B
(true, false, false, true, false, 4, 9);   -- Mi perfil           L··E·
