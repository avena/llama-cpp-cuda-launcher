#!/usr/bin/env pwsh
# run-test.ps1 — Executa testes dos modelos usando a estrutura na pasta test/

param(
    [switch]$IncludeMetrics
)

# Carrega variáveis de ambiente do .env
. "$PSScriptRoot\load-env.ps1" -Silent

# Configuração
$testDir = Join-Path -Path $PSScriptRoot -ChildPath "tests"
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "logs"

# Verifica se diretório de logs existe
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

# Usa LLAMA_SERVER_URL do .env
$baseUrl = $env:LLAMA_SERVER_URL
if (-not $baseUrl) {
    Write-Warning "LLAMA_SERVER_URL não definida no .env"
    exit 1
}

Write-Host "=== Run Test ===" -ForegroundColor Cyan
Write-Host "Base URL: $baseUrl" -ForegroundColor Gray
Write-Host "Test Directory: $testDir" -ForegroundColor Gray
Write-Host ""

# 1. Verifica conexão e obtém o modelo ativo ANTES de iniciar o log
Write-Host "Verificando conexão com o servidor..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing -TimeoutSec 10
    if ($healthResponse.StatusCode -ne 200) {
        Write-Host "❌ Servidor retornou status $($healthResponse.StatusCode)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "❌ Servidor não está respondendo em $baseUrl" -ForegroundColor Red
    exit 1
}

$activeModel = $null
try {
    $propsResponse = Invoke-RestMethod -Uri "$baseUrl/props" -ErrorAction Stop
    $activeModel = if ($propsResponse.model_alias) { $propsResponse.model_alias } else { Split-Path -Path $propsResponse.model_path -Leaf }
}
catch {
    Write-Host "❌ Erro ao obter modelo ativo." -ForegroundColor Red
    exit 1
}

if (-not $activeModel) {
    Write-Host "❌ Nenhum modelo encontrado no servidor." -ForegroundColor Red
    exit 1
}

# 2. Agora que temos o modelo, criamos o log com o nome dele
$modelClean = $activeModel -replace '\.gguf$', ''
$timestamp = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
$logFile = Join-Path -Path $logPath -ChildPath "test-all-$modelClean-$timestamp.txt"

# Inicia o log (transcript)
Start-Transcript -Path $logFile -Force | Out-Null

Write-Host "✅ Servidor pronto. Modelo ativo: $activeModel" -ForegroundColor Green
Write-Host "📝 Log: $logFile" -ForegroundColor Gray
Write-Host ""

# 3. Encontra o script de teste correspondente ao modelo
Write-Host "Procurando script de teste..." -ForegroundColor Yellow

$modelNameLower = $activeModel.ToLower()
$allTestScripts = Get-ChildItem -Path $testDir -Filter "test-*.ps1" -File
$testScript = $null

foreach ($script in $allTestScripts) {
    $scriptKey = $script.Name.ToLower() -replace '^test-', '' -replace '\.ps1$', ''
    if ($modelNameLower.Contains($scriptKey)) {
        $testScript = $script
        Write-Host "✅ Script encontrado: $($script.Name)" -ForegroundColor Green
        break
    }
}

if (-not $testScript) {
    # Match por família
    $modelFamily = ($modelNameLower -split '[-_\d]')[0]
    foreach ($script in $allTestScripts) {
        $scriptKey = $script.Name.ToLower() -replace '^test-', '' -replace '\.ps1$', ''
        $scriptFamily = ($scriptKey -split '[-_\d]')[0]
        if ($scriptFamily -eq $modelFamily) {
            $testScript = $script
            Write-Host "✅ Script encontrado (família $modelFamily): $($script.Name)" -ForegroundColor Green
            break
        }
    }
}

if (-not $testScript) {
    Write-Host "❌ Nenhum script de teste encontrado para: $activeModel" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# 4. Executa o script de teste
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Executando teste: $($testScript.Name)" -ForegroundColor Cyan
Write-Host "Modelo: $activeModel" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

try {
    & $testScript.FullName -Model $activeModel -IncludeMetrics:$IncludeMetrics

    if ($?) {
        Write-Host ""
        Write-Host "✅ Teste concluído com sucesso!" -ForegroundColor Green
        Stop-Transcript | Out-Null
        exit 0
    }
    else {
        Write-Host "❌ Teste falhou." -ForegroundColor Red
        Stop-Transcript | Out-Null
        exit 1
    }
}
catch {
    Write-Host "❌ Erro ao executar teste: $($_.Exception.Message)" -ForegroundColor Red
    $ErrorMessage = "`n`n============================================================`nFATAL ERROR`n============================================================`n$($_ | Out-String)"
    $ErrorMessage | Add-Content -Path $logFile
    Stop-Transcript | Out-Null
    exit 1
}
