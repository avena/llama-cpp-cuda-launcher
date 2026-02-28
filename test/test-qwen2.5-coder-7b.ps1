#!/usr/bin/env pwsh
# test-qwen2.5-coder-7b.ps1 - Teste específico para Qwen2.5-Coder-7B-Instruct

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
$prompt = "Write a Python function to filter even numbers"
$systemPrompt = "You are a precise coding assistant."
$fullPrompt = "[INST] $systemPrompt $prompt [/INST]"
$stopTokens = @("</s>", "[INST]")
$modelLabel = if ($Model) { $Model } else { "Qwen2.5-Coder-7B-Instruct-Q4_K_M" }

Invoke-TestCompletion -Prompt $fullPrompt -Model $modelLabel `
  -MaxTokens $MaxTokens -Temperature $Temperature `
  -StopTokens $stopTokens -OutputFile $OutputFile `
  -ModelLabel $modelLabel -IncludeMetrics:$IncludeMetrics
