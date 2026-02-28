#!/usr/bin/env pwsh
# _test-core.ps1 — Função central de teste para modelos LLaMA.cpp

function Invoke-TestCompletion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,

        [Parameter(Mandatory=$true)]
        [string]$Model,

        [Parameter(Mandatory=$true)]
        [int]$MaxTokens,

        [Parameter(Mandatory=$true)]
        [float]$Temperature,

        [Parameter(Mandatory=$true)]
        [array]$StopTokens,

        [string]$OutputFile,

        [Parameter(Mandatory=$true)]
        [string]$ModelLabel,

        [string]$Endpoint = "/v1/chat/completions",

        [switch]$IncludeMetrics
    )

    # Pega BaseUrl do .env (obrigatório)
    $BaseUrl = $env:LLAMA_SERVER_URL
    if (-not $BaseUrl) {
        Write-Host "❌ ERRO: LLAMA_SERVER_URL não definida no .env" -ForegroundColor Red
        return $false
    }

    # Gera nome do arquivo de saída se não fornecido
    if (-not $OutputFile) {
        $OutputFile = "test-$($modelLabel.ToLower() -replace '[^a-zA-Z0-9]', '-').txt"
    }

    Write-Host "Modelo: $ModelLabel" -ForegroundColor Cyan
    Write-Host "Temperature: $Temperature  |  MaxTokens: $MaxTokens" -ForegroundColor Gray
    Write-Host "Endpoint: $BaseUrl$Endpoint" -ForegroundColor Gray
    Write-Host ""

    # Prepara o corpo da requisição
    $body = @{
        model       = $Model
        temperature = $Temperature
        max_tokens  = $MaxTokens
        messages    = @(
            @{ role = 'user'; content = $Prompt }
        )
    } | ConvertTo-Json -Depth 5

    $startTime = Get-Date

    try {
        # Faz a requisição HTTP
        $response = Invoke-RestMethod -Uri "$BaseUrl$Endpoint" `
            -Method POST `
            -ContentType "application/json" `
            -Body $body `
            -ErrorAction Stop
    } catch {
        Write-Error "Falha na chamada a API: $_"
        
        # Escreve erro no arquivo de saída
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $errorContent = @"
============================================================
ERRO - Teste: $ModelLabel
Data: $timestamp
Prompt: $Prompt
Modelo: $Model
Erro: $($_.Exception.Message)
============================================================

"@
        Add-Content -Path $OutputFile -Value $errorContent
        return $false
    }

    $wallClock = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

    # Extrai métricas da resposta (se disponíveis)
    # Priorizar usage (OpenAI compatível) sobre timings
    $usage = $response.usage
    $t = $response.timings

    if ($usage) {
        # API OpenAI compatível (/v1/chat/completions)
        $promptTokens = $usage.prompt_tokens ?? 0
        $predictTokens = $usage.completion_tokens ?? 0
        $totalTokens = $usage.total_tokens ?? 0
        $promptMs = 0
        $promptTps = 0
        $predictMs = [math]::Round($wallClock * 1000, 2)
        $predictTps = if ($predictMs -gt 0) { [math]::Round(($predictTokens / $predictMs) * 1000, 2) } else { 0 }
        $totalMs = $predictMs
    } elseif ($t) {
        # llama.cpp nativo (/completion)
        $promptTokens = $t.prompt_n ?? 0
        $promptMs = [math]::Round($t.prompt_ms ?? 0, 2)
        $promptTps = [math]::Round($t.prompt_per_second ?? 0, 2)
        $predictTokens = $t.predicted_n ?? 0
        $predictMs = [math]::Round($t.predicted_ms ?? 0, 2)
        $predictTps = [math]::Round($t.predicted_per_second ?? 0, 2)
        $totalMs = [math]::Round(($t.prompt_ms ?? 0) + ($t.predicted_ms ?? 0), 2)
    } else {
        # Métricas estimadas
        $promptTokens = 0
        $predictTokens = 0
        $promptMs = 0
        $promptTps = 0
        $predictMs = [math]::Round($wallClock * 1000, 2)
        $predictTps = 0
        $totalMs = $predictMs
    }

    # API OpenAI compatível armazena stop reason em choices[0]
    $choice = $response.choices[0]
    $stopReason = $choice.finish_reason ?? $response.stop_type ?? $response.finish_reason ?? "n/a"
    $stoppingWord = $choice.stopping_word ?? $response.stopping_word ?? ""
    $truncatedWarn = if ($stopReason -eq "limit" -or $stopReason -eq "length") {
        "  ⚠️  TRUNCADO — aumente MaxTokens"
    } else {
        "  ✔  Terminou naturalmente"
    }

    # Extrai a resposta
    if ($response.choices) {
        $answer = $response.choices[0].message.content ?? $response.choices[0].text ?? ""
    } else {
        $answer = $response.content ?? ""
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $report = @"
================================================================================
TEST REPORT — llama.cpp API
================================================================================
Timestamp    : $timestamp
Model        : $ModelLabel
Server URL   : $BaseUrl
Temperature  : $Temperature
Max Tokens   : $MaxTokens
--------------------------------------------------------------------------------
PROMPT
--------------------------------------------------------------------------------
$Prompt
--------------------------------------------------------------------------------
RESPONSE
--------------------------------------------------------------------------------
$answer
--------------------------------------------------------------------------------
PERFORMANCE METRICS
--------------------------------------------------------------------------------
Reading (Prompt)
  Tokens   : $promptTokens
  Time     : ${promptMs} ms
  Speed    : ${promptTps} t/s

Generation
  Tokens   : $predictTokens
  Time     : ${predictMs} ms
  Speed    : ${predictTps} t/s

Total inference  : ${totalMs} ms
Wall clock       : ${wallClock} s
Stop reason      : $stopReason
$truncatedWarn
Stopping word    : $stoppingWord
================================================================================

"@

    # Salva no arquivo
    $report | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
    
    # Mostra no console
    Write-Host $report
    Write-Host "✔ Salvo em: $OutputFile" -ForegroundColor Green
    
    return $true
}

function Test-ServerHealth {
    param(
        [string]$BaseUrl
    )

    # Pega do .env se não fornecido
    if (-not $BaseUrl) { $BaseUrl = $env:LLAMA_SERVER_URL }
    if (-not $BaseUrl) {
        Write-Host "❌ ERRO: LLAMA_SERVER_URL não definida no .env" -ForegroundColor Red
        return $false
    }

    Write-Host "Verificando saúde do servidor..." -ForegroundColor Cyan

    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/health" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Servidor respondendo corretamente" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ Servidor retornou status $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Servidor não está respondendo: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-ModelsList {
    param(
        [string]$BaseUrl
    )

    # Pega do .env se não fornecido
    if (-not $BaseUrl) { $BaseUrl = $env:LLAMA_SERVER_URL }
    if (-not $BaseUrl) {
        Write-Host "❌ ERRO: LLAMA_SERVER_URL não definida no .env" -ForegroundColor Red
        return $false
    }

    Write-Host "Verificando lista de modelos disponíveis..." -ForegroundColor Cyan

    try {
        $response = Invoke-WebRequest -Uri "$BaseUrl/v1/models" -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            $models = $response.Content | ConvertFrom-Json
            Write-Host "✅ Modelos disponíveis:" -ForegroundColor Green
            foreach ($model in $models.data) {
                Write-Host "  - $($model.id)" -ForegroundColor White
            }
            return $true
        } else {
            Write-Host "❌ Erro ao obter lista de modelos: $($response.StatusCode)" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "❌ Erro ao obter lista de modelos: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
