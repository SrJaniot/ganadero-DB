# ═══════════════════════════════════════════════════════════════════════════
# SCRIPT DE INSTALACION DE LAS BASES DE DATOS DE GANADERO
# Plataforma: Windows PowerShell 5.1+
# Uso: .\setup.ps1 -PgPassword "tu_clave"
# Crea las bases ganadero y seguridadganadero y carga SETUP_CLEAN_DB.SQL en ganadero
# ═══════════════════════════════════════════════════════════════════════════

param(
    [string]$PgUser = "postgres",
    [string]$PgPassword = "",
    [string]$PgHost = "localhost",
    [int]$PgPort = 5432,
    [string]$DbNegocio = "ganadero",
    [string]$DbSeguridad = "seguridadganadero"
)

function Write-Ok { Write-Host "[OK] $args" -ForegroundColor Green }
function Write-Falla { Write-Host "[X] $args" -ForegroundColor Red }
function Write-Info { Write-Host "[i] $args" -ForegroundColor Cyan }

# BUSCAR psql EN EL PATH O EN LA INSTALACION POR DEFECTO DE POSTGRESQL
$psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
if (-not $psql) {
    $psql = Get-ChildItem "C:\Program Files\PostgreSQL\*\bin\psql.exe" -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $psql) {
    Write-Falla "No se encontro psql. Instala PostgreSQL o agregalo al PATH"
    exit 1
}
Write-Ok "psql: $psql"

$env:PGHOST = $PgHost
$env:PGPORT = $PgPort
$env:PGUSER = $PgUser
$env:PGCLIENTENCODING = "UTF8"
if ($PgPassword) { $env:PGPASSWORD = $PgPassword }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# CREAR LAS BASES SI NO EXISTEN
foreach ($db in @($DbNegocio, $DbSeguridad)) {
    $existe = & $psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'"
    if ($LASTEXITCODE -ne 0) { Write-Falla "No fue posible conectarse a PostgreSQL"; exit 1 }
    if ($existe -eq "1") {
        Write-Info "La base $db ya existe"
    } else {
        & $psql -d postgres -c "CREATE DATABASE $db ENCODING 'UTF8'" | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Falla "No fue posible crear la base $db"; exit 1 }
        Write-Ok "Base $db creada"
    }
}

# CARGAR EL SCRIPT MAESTRO EN LA BASE DE NEGOCIO
& $psql -d $DbNegocio -v ON_ERROR_STOP=1 -q -f (Join-Path $scriptDir "SETUP_CLEAN_DB.SQL")
if ($LASTEXITCODE -ne 0) { Write-Falla "Error al cargar SETUP_CLEAN_DB.SQL"; exit 1 }
Write-Ok "SETUP_CLEAN_DB.SQL cargado en $DbNegocio"

Write-Host ""
Write-Info "Pasos siguientes para la base de seguridad:"
Write-Info "  1. cd ..\backend\ms-seguridad-ganadero ; npm run migrate"
Write-Info "  2. psql -d $DbSeguridad -f SEGURIDAD\DML_SEGURIDAD_GANADERO.SQL"
Write-Info "  3. El primer administrador se crea desde ms-seguridad-ganadero (cuando exista el backend)"
