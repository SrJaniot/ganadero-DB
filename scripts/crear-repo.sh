#!/usr/bin/env sh
# CREA EL REPO PUBLICO SrJaniot/ganadero-DB SI NO EXISTE Y SUBE main
# USA LA API DE GITHUB CON LA CREDENCIAL DE GIT DEL PC, SIN MOSTRAR EL TOKEN
# USO (DESDE LA CARPETA db): sh scripts/crear-repo.sh
set -e
USUARIO=SrJaniot
REPO=ganadero-DB
API=https://api.github.com
cd "$(dirname "$0")/.."

TOKEN=$(printf "protocol=https\nhost=github.com\n\n" | git credential fill | sed -n 's/^password=//p')
if [ -z "$TOKEN" ]; then echo "No encontre la credencial de GitHub en git"; exit 1; fi

#PASO 1: EL REPO
CODIGO=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $TOKEN" "$API/repos/$USUARIO/$REPO")
if [ "$CODIGO" = "404" ]; then
  curl -s -o /dev/null -w "Repo creado: %{http_code}\n" -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
    "$API/user/repos" -d "{\"name\":\"$REPO\",\"description\":\"Base de datos PostgreSQL de Ganadero: SQL primero, sin internet con sincronizacion, triggers de auditoria\",\"private\":false,\"has_wiki\":false}"
else
  echo "El repo ya existe ($CODIGO)"
fi
unset TOKEN

#PASO 2: EL CODIGO
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/$USUARIO/$REPO.git"
git push -u origin main
