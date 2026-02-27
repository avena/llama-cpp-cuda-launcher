#!/usr/bin/env pwsh
# run-test.ps1 — Executa testes dos modelos usando a estrutura na pasta test/

param(
    [switch]$IncludeMetrics
)

# Carrega variáveis de ambiente do .env
. "$PSScriptRoot\load-env.ps1"

# Configuração
$testDir = Join-Path -Path $PSScriptRoot -ChildPath "test"
$coreTestScript = Join-Path -Path $testDir -ChildPath "_test-core.ps1"

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
    } else {
        Write-Host "❌ Servidor retornou status $($healthResponse.StatusCode)" -ForegroundColor Red
        exit 1
    }
} catch {
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
    } elseif ($propsResponse.model_path) {
        $activeModel = Split-Path -Path $propsResponse.model_path -Leaf
        Write-Host "Modelo encontrado (model_path): $activeModel" -ForegroundColor Green
    }
} catch {
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

# Extrai o nome base do modelo para encontrar o script
# Ex: Qwen2.5-3B-Instruct-Q4_K_M.gguf -> qwen2.5-3b
$modelNameLower = $activeModel.ToLower()
$testScript = $null

# Tenta encontrar um script que corresponda ao nome do modelo
$allTestScripts = Get-ChildItem -Path $testDir -Filter "test-*.ps1" -File
foreach ($script in $allTestScripts) {
    $scriptName = $script.Name.ToLower()
    # Remove extensão e prefixo para comparar
    $scriptModelName = $scriptName -replace '^test-', '' -replace '\.ps1$', ''
    
    # Verifica se o nome do modelo contém o nome do script ou vice-versa
    if ($modelNameLower.Contains($scriptModelName) -or $scriptModelName.Contains($modelNameLower.Split('.')[0])) {
        $testScript = $script
        Write-Host "✅ Script encontrado: $($script.Name)" -ForegroundColor Green
        break
    }
}

if (-not $testScript) {
    Write-Host "❌ Nenhum script de teste encontrado para o modelo: $activeModel" -ForegroundColor Red
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
        exit 0
    } else {
        Write-Host "❌ Teste falhou." -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Erro ao executar teste: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
