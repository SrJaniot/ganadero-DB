-- DATOS SEMILLA DE LOS CATALOGOS Y DE LA CONFIGURACION (SE PUEDE CORRER VARIAS VECES: NO PISA LO QUE EL ADMINISTRADOR YA CAMBIO)


-- CONFIGURACION GENERAL ------------------------------------------------------------------------------------------------------------------------------
INSERT INTO TAB_CONFIGURACION (ID_CONFIGURACION, NOM_CONFIGURACION, VALOR_CONFIGURACION, VALOR_ORIGINAL_CONFIGURACION, DESCRIPCION_CONFIGURACION, USUARIO_CREACION) VALUES
(1, 'DIAS_GESTACION', '283', '283', 'Días promedio de gestación de una vaca: con esto se calcula el parto probable desde el servicio', 'SISTEMA'),
(2, 'DIAS_MINIMOS_ENTRE_PARTOS', '240', '240', 'Una vaca no puede tener dos partos con menos de estos días de diferencia', 'SISTEMA'),
(3, 'COEFICIENTE_CINTA', '80', '80', 'Peso con cinta (fórmula de Quetelet): kilos = (perímetro torácico en metros)³ × este número. Es una estimación', 'SISTEMA'),
(4, 'MARGEN_SINCRONIZACION_SEGUNDOS', '5', '5', 'Segundos que se restan a la marca al bajar cambios, para no perder lo que se guardaba en ese momento', 'SISTEMA'),
(5, 'LOTE_MAXIMO_SINCRONIZACION', '50', '50', 'Máximo de registros que el celular sube en cada envío', 'SISTEMA'),
(6, 'MESES_MINIMOS_SERVICIO', '12', '12', 'Edad mínima en meses para registrar un servicio (monta o inseminación) a una hembra', 'SISTEMA')
ON CONFLICT (NOM_CONFIGURACION) DO NOTHING;


-- RAZAS COMUNES EN LA GANADERIA DE DOBLE PROPOSITO DE COLOMBIA --------------------------------------------------------------------------------------
INSERT INTO TAB_RAZAS (ID_RAZA, NOM_RAZA, USUARIO_CREACION) VALUES
(1, 'Cebú Brahman', 'SISTEMA'),
(2, 'Gyr', 'SISTEMA'),
(3, 'Guzerat', 'SISTEMA'),
(4, 'Holstein', 'SISTEMA'),
(5, 'Pardo Suizo', 'SISTEMA'),
(6, 'Jersey', 'SISTEMA'),
(7, 'Normando', 'SISTEMA'),
(8, 'Simmental', 'SISTEMA'),
(9, 'Girolando', 'SISTEMA'),
(10, 'Romosinuano', 'SISTEMA'),
(11, 'Blanco Orejinegro (BON)', 'SISTEMA'),
(12, 'Costeño con Cuernos', 'SISTEMA'),
(13, 'Cruce o mestizo', 'SISTEMA'),
(14, 'Otra', 'SISTEMA')
ON CONFLICT (NOM_RAZA) DO NOTHING;


-- VACUNAS Y TRATAMIENTOS DE EJEMPLO ------------------------------------------------------------------------------------------------------------------
-- LOS DIAS DE REFUERZO Y DE RETIRO DE LECHE SON VALORES DE REFERENCIA PARA EMPEZAR: CADA PRODUCTO COMERCIAL TIENE LOS SUYOS EN LA ETIQUETA
-- Y EL ADMINISTRADOR LOS AJUSTA EN CONFIGURACION. NO REEMPLAZAN LA INDICACION DEL VETERINARIO
INSERT INTO TAB_VACUNAS (ID_VACUNA, NOM_VACUNA, TIPO_VACUNA, DIAS_REFUERZO, DIAS_RETIRO_LECHE, OBLIGATORIA_ICA, USUARIO_CREACION) VALUES
(1, 'Fiebre aftosa', 'VACUNA', 180, 0, 'SI', 'SISTEMA'),
(2, 'Brucelosis (RB51)', 'VACUNA', NULL, 0, 'SI', 'SISTEMA'),
(3, 'Carbón sintomático y edema maligno', 'VACUNA', 365, 0, 'NO', 'SISTEMA'),
(4, 'Rabia de origen silvestre', 'VACUNA', 365, 0, 'NO', 'SISTEMA'),
(5, 'IBR y DVB', 'VACUNA', 365, 0, 'NO', 'SISTEMA'),
(6, 'Desparasitante interno (albendazol)', 'DESPARASITANTE', 90, 3, 'NO', 'SISTEMA'),
(7, 'Desparasitante de garrapata (baño)', 'DESPARASITANTE', 21, 0, 'NO', 'SISTEMA'),
(8, 'Antibiótico (oxitetraciclina)', 'TRATAMIENTO', NULL, 5, 'NO', 'SISTEMA'),
(9, 'Tratamiento de mastitis (intramamario)', 'TRATAMIENTO', NULL, 4, 'NO', 'SISTEMA'),
(10, 'Vitaminas A, D y E', 'VITAMINA', NULL, 0, 'NO', 'SISTEMA')
ON CONFLICT (NOM_VACUNA) DO NOTHING;
