-- MIGRACION 001 (FASE 3, 04/11/2026): LOS DIAS DE LAS ALERTAS DE LA PANTALLA "HOY". SE PUEDE CORRER VARIAS VECES (NO PISA LO QUE EL ADMIN CAMBIO)
-- DESPUES DE CORRERLA, CARGAR LA FUNCION NUEVA: psql -d ganadero -f FUNCIONES/FUN_ALERTAS/FUN_TAB_ALERTAS.SQL
INSERT INTO TAB_CONFIGURACION (ID_CONFIGURACION, NOM_CONFIGURACION, VALOR_CONFIGURACION, VALOR_ORIGINAL_CONFIGURACION, DESCRIPCION_CONFIGURACION, USUARIO_CREACION) VALUES
(7, 'DIAS_AVISO_PARTO', '30', '30', 'Días antes del parto probable en que empieza a salir en "Partos próximos"', 'SISTEMA'),
(8, 'DIAS_PALPAR_DESPUES_SERVICIO', '45', '45', 'Días después del servicio en que se pide palpar si aún no se ha palpado', 'SISTEMA'),
(9, 'DIAS_VACIA_ALERTA', '120', '120', 'Días después del parto en que una vaca sin servir ni preñada sale como "vacía"', 'SISTEMA'),
(10, 'DIAS_AVISO_VACUNA', '15', '15', 'Días antes de la próxima dosis en que la vacuna sale como "por aplicar"', 'SISTEMA')
ON CONFLICT (NOM_CONFIGURACION) DO NOTHING;
