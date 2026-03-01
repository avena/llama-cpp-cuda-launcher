# Invoke-AllTests.ps1 - Executa todos os 5 testes de código automaticamente

function Invoke-AllTests {
  param(
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

  # Pega BaseUrl do .env
  $BaseUrl = $env:LLAMA_SERVER_URL
  if (-not $BaseUrl) {
    Write-Host "❌ ERRO: LLAMA_SERVER_URL não definida no .env" -ForegroundColor Red
    return $false
  }

  # Gera nome do arquivo de saída se não fornecido
  if (-not $OutputFile) {
    $OutputFile = "test-all-$($ModelLabel.ToLower() -replace '[^a-zA-Z0-9]', '-').txt"
  }

  Write-Host ""
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host "  EXECUTANDO TODOS OS TESTES ($($ModelLabel))" -ForegroundColor Cyan
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host ""

  $systemPrompt = "You are a precise coding assistant."
  $results = @{}
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

  # Limpa o arquivo de saída
  "" | Out-File -FilePath $OutputFile -Encoding UTF8

  # Cabeçalho inicial
  $header = @"
================================================================================
ALL TESTS REPORT — llama.cpp API
================================================================================
Timestamp    : $timestamp
Model        : $ModelLabel
Server URL   : $BaseUrl
Temperature  : $Temperature
Max Tokens   : $MaxTokens
================================================================================

"@
  $header | Out-File -FilePath $OutputFile -Encoding UTF8

  # Executa cada pergunta
  for ($i = 1; $i -le 5; $i++) {
    $prompt = $script:CodePrompts[$i]
    $testName = switch ($i) {
      1 { "Fibonacci" }
      2 { "Reverse String" }
      3 { "Filter Even Numbers" }
      4 { "Binary Search Tree" }
      5 { "Quicksort" }
    }

    Write-Host "[$i/5] Executando: $testName" -ForegroundColor Yellow
    Write-Host "        Prompt: $prompt" -ForegroundColor Gray

    $Messages = @(
      @{ role = "system"; content = $systemPrompt },
      @{ role = "user"; content = $prompt }
    )

    $body = @{
      model       = $Model
      temperature = $Temperature
      max_tokens  = $MaxTokens
      messages    = $Messages
    } | ConvertTo-Json -Depth 5

    $startTime = Get-Date

    try {
      $response = Invoke-RestMethod -Uri "$BaseUrl$Endpoint" `
        -Method POST `
        -ContentType "application/json" `
        -Body $body `
        -ErrorAction Stop
    }
    catch {
      Write-Host "  ❌ ERRO: $($_.Exception.Message)" -ForegroundColor Red
      $results[$testName] = @{
        Test    = $testName
        Prompt  = $prompt
        Success = $false
        Error   = $_.Exception.Message
        Tokens  = 0
        Time    = 0
        Speed   = 0
      }
      continue
    }

    $wallClock = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
        
    $usage = $response.usage
    $t = $response.timings
        
    if ($usage) {
      $promptTokens = $usage.prompt_tokens ?? 0
      $predictTokens = $usage.completion_tokens ?? 0
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
    $truncatedWarn = if ($stopReason -eq "limit" -or $stopReason -eq "length") {
      "  ⚠️  TRUNCADO"
    }
    else {
      "  ✔  OK"
    }

    $answer = $response.choices[0].message.content ?? $response.choices[0].text ?? ""

    Write-Host "  ✅ Concluído: $predictTokens tokens | ${wallClock}s | ${predictTps} t/s" -ForegroundColor Green

    $results[$testName] = @{
      Test         = $testName
      Prompt       = $prompt
      Success      = $true
      Tokens       = $predictTokens
      Time         = $wallClock
      Speed        = $predictTps
      PromptTokens = $promptTokens
      TotalMs      = $totalMs
      StopReason   = $stopReason
    }

    # Salva resultado individual no arquivo usando o mesmo template
    $report = @"
================================================================================
TEST: $testName
================================================================================
PROMPT
--------------------------------------------------------------------------------
$prompt
--------------------------------------------------------------------------------
RESPONSE
--------------------------------------------------------------------------------
$answer
--------------------------------------------------------------------------------
PERFORMANCE METRICS
--------------------------------------------------------------------------------
Prompt Tokens  : $promptTokens
Generation    : $predictTokens tokens
Time          : ${wallClock} s (${predictTps} t/s)
Total         : ${totalMs} ms
Stop Reason   : $stopReason $truncatedWarn
================================================================================

"@
    $report | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
  }

  # Resumo final
  $totalTime = 0
  $totalTokens = 0

  foreach ($key in $results.Keys) {
    $r = $results[$key]
    if ($r.Success) {
      $totalTime += $r.Time
      $totalTokens += $r.Tokens
    }
  }

  $avgSpeed = if ($totalTime -gt 0) { [math]::Round($totalTokens / $totalTime, 2) } else { 0 }

  $summary = @"
================================================================================
RESUMO DOS TESTES
================================================================================
"

    foreach ($key in $results.Keys) {
        $r = $results[$key]
        if ($r.Success) {
            $summary += "`n  ✅ $($r.Test): $($r.Tokens) tokens | $($r.Time)s | $($r.Speed) t/s"
        }
        else {
            $summary += "`n  ❌ $($r.Test): $($r.Error)"
        }
    }

    $summary += @"


  ───────────────────────────────────────────────────────────────────────────
  Total: $totalTokens tokens em ${totalTime}s (média: ${avgSpeed} t/s)
================================================================================

"@

  $summary | Out-File -FilePath $OutputFile -Encoding UTF8 -Append

  Write-Host ""
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
  Write-Host "  RESUMO DOS TESTES" -ForegroundColor Cyan
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

  foreach ($key in $results.Keys) {
    $r = $results[$key]
    if ($r.Success) {
      Write-Host "  ✅ $($r.Test): $($r.Tokens) tokens | $($r.Time)s | $($r.Speed) t/s" -ForegroundColor Green
    }
    else {
      Write-Host "  ❌ $($r.Test): $($r.Error)" -ForegroundColor Red
    }
  }

  Write-Host ""
  Write-Host "  Total: $($totalTokens) tokens em ${totalTime}s (média: ${avgSpeed} t/s)" -ForegroundColor Cyan
  Write-Host "  ✔ Salvo em: $OutputFile" -ForegroundColor Green
  Write-Host ""

  return $true
}
