# Test-ServerHealth.ps1 - Verifica a saúde do servidor llama.cpp

function Test-ServerHealth {
  param(
    [string]$BaseUrl
  )

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
    }
    else {
      Write-Host "❌ Servidor retornou status $($response.StatusCode)" -ForegroundColor Red
      return $false
    }
  }
  catch {
    Write-Host "❌ Servidor não está respondendo: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}
