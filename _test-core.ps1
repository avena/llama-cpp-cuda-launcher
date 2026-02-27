# _test-core.ps1 — NAO executar diretamente, usado pelos scripts de teste
# Variaveis esperadas: $BaseUrl, $OutputFile, $MaxTokens, $Temperature,
#                      $fullPrompt, $prompt, $stopTokens, $modelLabel

Write-Host "Modelo: $modelLabel" -ForegroundColor Cyan
Write-Host "Temperature: $Temperature  |  MaxTokens: $MaxTokens" -ForegroundColor Gray

$body = @{
    prompt      = $fullPrompt
    n_predict   = $MaxTokens
    temperature = $Temperature
    stop        = $stopTokens
} | ConvertTo-Json

$startTime = Get-Date

try {
    $response = Invoke-RestMethod -Uri "$BaseUrl/completion" `
        -Method Post `
        -ContentType "application/json" `
        -Body $body `
        -ErrorAction Stop
} catch {
    Write-Error "Falha na chamada a API: $_"
    exit 1
}

$wallClock = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
$t         = $response.timings

$promptTokens  = $t.prompt_n
$promptMs      = [math]::Round($t.prompt_ms, 2)
$promptTps     = [math]::Round($t.prompt_per_second, 2)
$predictTokens = $t.predicted_n
$predictMs     = [math]::Round($t.predicted_ms, 2)
$predictTps    = [math]::Round($t.predicted_per_second, 2)
$totalMs       = [math]::Round($t.prompt_ms + $t.predicted_ms, 2)
$stopReason    = $response.stop_type ?? $response.finish_reason ?? "n/a"
$stoppingWord  = $response.stopping_word ?? ""
$truncatedWarn = if ($stopReason -eq "limit") { "  ⚠️  TRUNCADO — aumente MaxTokens" } else { "  ✔  Terminou naturalmente" }

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$report = @"
================================================================================
TEST REPORT — llama.cpp API
================================================================================
Timestamp    : $timestamp
Model        : $modelLabel
Server URL   : $BaseUrl
Temperature  : $Temperature
Max Tokens   : $MaxTokens
--------------------------------------------------------------------------------
PROMPT
--------------------------------------------------------------------------------
$prompt
--------------------------------------------------------------------------------
RESPONSE
--------------------------------------------------------------------------------
$($response.content)
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
Tokens cached    : $($response.tokens_cached ?? 0)
================================================================================

"@

$report | Out-File -FilePath $OutputFile -Encoding UTF8 -Append
Write-Host $report
Write-Host "✔ Salvo em: $OutputFile" -ForegroundColor Green
