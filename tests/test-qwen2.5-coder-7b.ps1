#!/usr/bin/env pwsh
# test-qwen2.5-coder-7b.ps1 - Teste para Qwen2.5-Coder-7B-Instruct
# Executa todos os 5 testes de código automaticamente

param(
  [int]$MaxTokens = 2048,
  [float]$Temperature = 0.2,
  [string]$OutputFile = "",
  [string]$Model = "",
  [switch]$IncludeMetrics
)

# Carrega variáveis de ambiente do .env
. "$PSScriptRoot\..\load-env.ps1"

# Importa funções de teste
. "$PSScriptRoot\_test-core.ps1"

# Configurações específicas do modelo
$modelLabel = if ($Model) { $Model } else { "qwen2.5-coder-7b-instruct-q4_k_m.gguf" }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Teste: Qwen2.5 Coder 7B - Todos os 5 testes" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Executa todos os testes automaticamente
Invoke-AllTests -Model $modelLabel `
  -MaxTokens $MaxTokens -Temperature $Temperature `
  -StopTokens @("<|im_end|>", "<|im_start|>") -OutputFile $OutputFile `
  -ModelLabel $modelLabel -IncludeMetrics:$IncludeMetrics
