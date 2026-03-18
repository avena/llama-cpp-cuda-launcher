#!/usr/bin/env pwsh
# run-test.ps1 — Executa testes dos modelos usando a estrutura na pasta test/

param(
    [switch]$IncludeMetrics
)

# Carrega variáveis de ambiente do .env
. "$PSScriptRoot\load-env.ps1" -Silent

# Configuração
$testDir = Join-Path -Path $PSScriptRoot -ChildPath "tests"

# Gera timestamp para nome do arquivo
$timestamp = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
$modelBase = "test-all-qwen2-5-coder-0-5b-instruct-q4-k-m-gguf"
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "logs"
$logFile = Join-Path -Path $logPath -ChildPath "$modelBase-$timestamp.txt"

# Verifica se diretório de logs existe
if (-not (Test-Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath | Out-Null
}

# Redireciona toda a saída para arquivo de log (suprime mensagem inicial)
Start-Transcript -Path $logFile -Force | Out-Null

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

# Verifica se o servidor está respondendo
Write-Host "Verificando conexão com o servidor..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing -TimeoutSec 10
    if ($healthResponse.StatusCode -eq 200) {
        Write-Host "✅ Servidor respondendo em $baseUrl" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Servidor retornou status $($healthResponse.StatusCode)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "❌ Servidor não está respondendo: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Obtém o modelo ativo do servidor
Write-Host "Obtendo modelo ativo..." -ForegroundColor Yellow
$activeModel = $null
try {
    $propsResponse = Invoke-RestMethod -Uri "$baseUrl/props" -ErrorAction Stop
    if ($propsResponse.model_alias) {
        $activeModel = $propsResponse.model_alias
        Write-Host "Modelo encontrado (model_alias): $activeModel" -ForegroundColor Green
    }
    elseif ($propsResponse.model_path) {
        $activeModel = Split-Path -Path $propsResponse.model_path -Leaf
        Write-Host "Modelo encontrado (model_path): $activeModel" -ForegroundColor Green
    }
}
catch {
    Write-Host "❌ Erro ao obter modelo: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not $activeModel) {
    Write-Host "❌ Nenhum modelo encontrado" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Encontra o script de teste correspondente ao modelo
Write-Host "Procurando script de teste para o modelo: $activeModel" -ForegroundColor Yellow

$modelNameLower = $activeModel.ToLower()
$allTestScripts = Get-ChildItem -Path $testDir -Filter "test-*.ps1" -File
$testScript = $null

# Estágio 1 — Match exato
foreach ($script in $allTestScripts) {
    $scriptKey = $script.Name.ToLower() -replace '^test-', '' -replace '\.ps1$', ''
    if ($modelNameLower.Contains($scriptKey)) {
        $testScript = $script
        Write-Host "✅ Script encontrado (match exato): $($script.Name)" -ForegroundColor Green
        break
    }
}

# Estágio 2 — Match por família
if (-not $testScript) {
    $modelFamily = ($modelNameLower -split '[-_\d]')[0]
    foreach ($script in $allTestScripts) {
        $scriptKey = $script.Name.ToLower() -replace '^test-', '' -replace '\.ps1$', ''
        $scriptFamily = ($scriptKey -split '[-_\d]')[0]
        if ($scriptFamily -eq $modelFamily) {
            $testScript = $script
            Write-Host "✅ Script encontrado (match família '$modelFamily'): $($script.Name)" -ForegroundColor Green
            break
        }
    }
}

if (-not $testScript) {
    Write-Host "❌ Nenhum script de teste encontrado para: $activeModel" -ForegroundColor Red
    Write-Host "Scripts disponíveis:" -ForegroundColor Yellow
    foreach ($script in $allTestScripts) {
        Write-Host "  - $($script.Name)" -ForegroundColor Gray
    }
    exit 1
}
Write-Host ""

# Executa o script de teste
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Executando teste: $($testScript.Name)" -ForegroundColor Cyan
Write-Host "Modelo: $activeModel" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Executa o script de teste passando o modelo ativo
    # O proprio script de teste pega BaseUrl do .env
    & $testScript.FullName -Model $activeModel -IncludeMetrics:$IncludeMetrics

    if ($?) {
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
    Stop-Transcript | Out-Null
    Write-Host "❌ Erro ao executar teste: $($_.Exception.Message)" -ForegroundColor Red
    
    # Adiciona o erro fatal ao final do arquivo de log para debug
    $ErrorMessage = "`n`n============================================================`nFATAL ERROR`n============================================================`n$($_ | Out-String)"
    $ErrorMessage | Add-Content -Path $logFile
    
    exit 1
}
