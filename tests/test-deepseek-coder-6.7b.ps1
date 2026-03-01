#!/usr/bin/env pwsh
# test-deepseek-coder-6.7b.ps1 - Teste para DeepSeek Coder 6.7B
# Executa todos os 5 testes de código automaticamente

param(
    [int]$MaxTokens = 2048,
    [float]$Temperature = 0.1,
    [string]$OutputFile = "",
    [string]$Model = "",
    [switch]$IncludeMetrics
)

# Carrega variáveis de ambiente do .env
. "$PSScriptRoot\..\load-env.ps1"

# Importa funções de teste
. "$PSScriptRoot\_test-core.ps1"

# Configurações específicas do modelo
$modelLabel = if ($Model) { $Model } else { "deepseek-coder-6.7b-instruct-q4_k_m.gguf" }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Teste: DeepSeek Coder 6.7B - Todos os 5 testes" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Executa todos os testes automaticamente
Invoke-AllTests -Model $modelLabel `
    -MaxTokens $MaxTokens -Temperature $Temperature `
    -StopTokens @("</s>", "<|EOT|>", "### Instruction:") -OutputFile $OutputFile `
    -ModelLabel $modelLabel -IncludeMetrics:$IncludeMetrics
