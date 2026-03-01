# Invoke-TestCompletion.ps1 - Executa um teste de completamento único

function Invoke-TestCompletion {
  param(
    # Para formato de mensagens (recomendado - template aplicado automaticamente)
    [array]$Messages,

    # Para formato de prompt raw (usar apenas com /v1/completions)
    [string]$Prompt,

    [Parameter(Mandatory = $true)]
    [string]$Model,

    [Parameter(Mandatory = $true)]
    [int]$MaxTokens,

    [Parameter(Mandatory = $true)]
    [float]$Temperature,

    [Parameter(Mandatory = $true)]
    [array]$StopTokens,

    [string]$OutputFile,

    [Parameter(Mandatory = $true)]
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
  if ($Messages) {
    $body = @{
      model       = $Model
      temperature = $Temperature
      max_tokens  = $MaxTokens
      messages    = $Messages
    } | ConvertTo-Json -Depth 5
        
    $promptDisplay = ($Messages | ForEach-Object { "$($_.role): $($_.content)" }) -join "`n"
  }
  else {
    $body = @{
      model       = $Model
      temperature = $Temperature
      max_tokens  = $MaxTokens
      messages    = @(
        @{ role = 'user'; content = $Prompt }
      )
    } | ConvertTo-Json -Depth 5
        
    $promptDisplay = $Prompt
  }

  $startTime = Get-Date

  try {
    $response = Invoke-RestMethod -Uri "$BaseUrl$Endpoint" `
      -Method POST `
      -ContentType "application/json" `
      -Body $body `
      -ErrorAction Stop
  }
  catch {
    Write-Error "Falha na chamada a API: $_"
        
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $errorContent = @"
================================================================================
ERRO - Teste: $ModelLabel
Data: $timestamp
Prompt: $Prompt
Modelo: $Model
Erro: $($_.Exception.Message)
================================================================================

"@
    Add-Content -Path $OutputFile -Value $errorContent
    return $false
  }

  $wallClock = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

  # Extrai métricas da resposta
  $usage = $response.usage
  $t = $response.timings

  if ($usage) {
    $promptTokens = $usage.prompt_tokens ?? 0
    $predictTokens = $usage.completion_tokens ?? 0
    $totalTokens = $usage.total_tokens ?? 0
    $promptMs = 0
    $promptTps = 0
    $predictMs = [math]::Round($wallClock * 1000, 2)
    $predictTps = if ($predictMs -gt 0) { [math]::Round(($predictTokens / $predictMs) * 1000, 2) } else { 0 }
    $totalMs = $predictMs
  }
  elseif ($t) {
    $promptTokens = $t.prompt_n ?? 0
    $promptMs = [math]::Round($t.prompt_ms ?? 0, 2)
    $promptTps = [math]::Round($t.prompt_per_second ?? 0, 2)
    $predictTokens = $t.predicted_n ?? 0
    $predictMs = [math]::Round($t.predicted_ms ?? 0, 2)
    $predictTps = [math]::Round($t.predicted_per_second ?? 0, 2)
    $totalMs = [math]::Round(($t.prompt_ms ?? 0) + ($t.predicted_ms ?? 0), 2)
  }
  else {
    $promptTokens = 0
    $predictTokens = 0
    $promptMs = 0
    $promptTps = 0
    $predictMs = [math]::Round($wallClock * 1000, 2)
    $predictTps = 0
    $totalMs = $predictMs
  }

  $choice = $response.choices[0]
  $stopReason = $choice.finish_reason ?? $response.stop_type ?? $response.finish_reason ?? "n/a"
  $stoppingWord = $choice.stopping_word ?? $response.stopping_word ?? ""
  $truncatedWarn = if ($stopReason -eq "limit" -or $stopReason -eq "length") {
    "  ⚠️  TRUNCADO — aumente MaxTokens"
  }
  else {
    "  ✔  Terminou naturalmente"
  }

  if ($response.choices) {
    $answer = $response.choices[0].message.content ?? $response.choices[0].text ?? ""
  }
  else {
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
PROMPT (format: $(if ($Messages) { 'messages' } else { 'raw prompt' }))
--------------------------------------------------------------------------------
$promptDisplay
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

  $report | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
    
  Write-Host $report
  Write-Host "✔ Salvo em: $OutputFile" -ForegroundColor Green
    
  return $true
}
