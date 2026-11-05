#!/bin/sh
# VUELVE A SEMBRAR LA DEMO DE GANADERO (demoganadera.ejaniot.com). LO CORRE CADA MADRUGADA EL TIMER demoganadera-resembrar.timer
# 1. LA BASE DE SEGURIDAD: LAS 3 CUENTAS DE EJEMPLO ACTIVAS Y LAS DE LOS VISITANTES BORRADAS (LIMPIAR_SEGURIDAD_DEMO.SQL)
# 2. LA BASE DE NEGOCIO: BORRA TODO Y SIEMBRA LA "Finca La Esperanza" CON LAS FECHAS DE HOY (SEMBRAR_FINCA_DEMO.SQL, UNA SOLA TRANSACCION)
# LOS id_usuario SALEN DEL JSON QUE ESCRIBIO crear_cuentas_demo.mjs; LA CLAVE DE POSTGRES, DEL .env DE ms-logica (NO SE IMPRIME)
# NO SE BAJAN LAS APPS: LOS CELULARES QUE TENIAN LA DEMO BAJAN LA FINCA COMPLETA EN LA SIGUIENTE SINCRONIZACION (LA FINCA ES MAS NUEVA QUE SU MARCA)
set -eu
DEMO=${DEMO:-/home/ejaniot/proyectos/demoganadera}
CUENTAS=${CUENTAS_DEMO:-/home/ejaniot/demoganadera-cuentas.json}
ENV="$DEMO/ms-logica-ganadero/.env"
leer() { grep "^$1=" "$ENV" | cut -d= -f2- | tr -d '\r"'; }
export PGHOST=127.0.0.1 PGPORT=5432
export PGUSER="$(leer CONNECTION_USER_POSTGRES)"
export PGPASSWORD="$(leer CONNECTION_PASSWORD_POSTGRES)"
BASE="$(leer CONNECTION_DATABASE_POSTGRES)"
id() { node -e "process.stdout.write(require('$CUENTAS')['$1'].id_usuario)"; }
CEL="'3100000001','3100000002','3100000003'"

cd "$DEMO/db/DEMO"
psql -X -1 -q -v ON_ERROR_STOP=1 -v celulares="$CEL" -d "seguridad$BASE" -f LIMPIAR_SEGURIDAD_DEMO.SQL -t
psql -X -1 -q -v ON_ERROR_STOP=1 -v duenio="$(id DUENIO)" -v vaquero="$(id VAQUERO)" -v veterinario="$(id VETERINARIO)" \
  -d "$BASE" -f SEMBRAR_FINCA_DEMO.SQL -t 2>&1 | grep -v '^\s*$' | grep -v 'set_config\|setseed\|DEMO\|^ *|' | tail -3
echo "Demo resembrada el $(date '+%d/%m/%Y %H:%M')"
