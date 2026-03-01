# Test-ModelsList.ps1 - Lista os modelos disponíveis no servidor

function Test-ModelsList {
  param(
    [string]$BaseUrl
  )

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
    }
    else {
      Write-Host "❌ Erro ao obter lista de modelos: $($response.StatusCode)" -ForegroundColor Red
      return $false
    }
  }
  catch {
    Write-Host "❌ Erro ao obter lista de modelos: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}
