-- DEJA LA BASE DE SEGURIDAD DE LA DEMO COMO NUEVA (LA CORRE resembrar_demo.sh CADA NOCHE). SOLO PARA seguridaddemoganadera
-- LAS TRES CUENTAS DE EJEMPLO QUEDAN ACTIVAS Y SIN BLOQUEOS (UN VISITANTE PUDO DESACTIVAR AL VAQUERO DESDE "MI FINCA" O EQUIVOCARSE DE CLAVE)
-- LAS CUENTAS QUE CREARON LOS VISITANTES (DUEÑOS NUEVOS, SUS VAQUEROS) SE BORRAN; EL ADMINISTRADOR (ROL 1) NO SE TOCA
-- USO: psql -X -1 -v ON_ERROR_STOP=1 -v celulares="'3100000001','3100000002','3100000003'" -d seguridaddemoganadera -f LIMPIAR_SEGURIDAD_DEMO.SQL
UPDATE usuario SET aceptado = true, intentoslogin = 0, bloqueadohasta = NULL WHERE celular IN (:celulares);
DELETE FROM login WHERE usuarioid IN (SELECT id_usuario FROM usuario WHERE celular NOT IN (:celulares) AND rolid <> 1);
DELETE FROM usuario WHERE celular NOT IN (:celulares) AND rolid <> 1;
SELECT 'Cuentas en la demo: ' || COUNT(*) FROM usuario;
