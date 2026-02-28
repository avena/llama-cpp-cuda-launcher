#!/usr/bin/env pwsh
# test-deepseek-coder-6.7b.ps1 - Teste especifico para DeepSeek Coder 6.7B

param(
    [int]$MaxTokens = 2048,
    [float]$Temperature = 0.1,
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
$systemPrompt = "You are an AI programming assistant utilizing DeepSeek Coder model."
$fullPrompt = "$systemPrompt`n### Instruction:`n$prompt`n### Response:`n"
$stopTokens = @("</s>", "<|EOT|>", "### Instruction:")
$modelLabel = if ($Model) { $Model } else { "DeepSeek-Coder-6.7B-Instruct" }

Invoke-TestCompletion -Prompt $fullPrompt -Model $modelLabel `
    -MaxTokens $MaxTokens -Temperature $Temperature `
    -StopTokens $stopTokens -OutputFile $OutputFile `
    -ModelLabel $modelLabel -IncludeMetrics:$IncludeMetrics
