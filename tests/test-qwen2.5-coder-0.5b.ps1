#!/usr/bin/env pwsh
# test-qwen2.5-coder-0.5b.ps1 - Teste especifico para Qwen2.5-Coder-0.5B

param(
    [int]$MaxTokens = 512,
    [float]$Temperature = 0.3,
    [string]$OutputFile = "",
    [string]$Model = "",
    [switch]$IncludeMetrics
)

# Carrega variaveis de ambiente do .env
. "$PSScriptRoot\..\load-env.ps1"

# Importa funcoes de teste
. "$PSScriptRoot\_test-core.ps1"

# Configuracoes especificas do modelo
$prompt = "Write a Python function to filter even numbers"
$systemPrompt = "You are a precise coding assistant."
$fullPrompt = "[INST] $systemPrompt $prompt [/INST]"
$stopTokens = @("</s>", "[INST]")
$modelLabel = if ($Model) { $Model } else { "Qwen2.5-Coder-0.5B-Instruct" }

Invoke-TestCompletion -Prompt $fullPrompt -Model $modelLabel `
    -MaxTokens $MaxTokens -Temperature $Temperature `
    -StopTokens $stopTokens -OutputFile $OutputFile `
    -ModelLabel $modelLabel -IncludeMetrics:$IncludeMetrics
