# lib/server.ps1
# Responsabilidades:
#   - Build-ServerArgs: construir argumentos de linha de comando para llama-server.exe
#   - Wait-ServerReady: verificar se o servidor está pronto via endpoint /health
#   - Suportar configuração de GPU offload via GpuLayers
#   - Suportar templates de chat (built-in ou arquivo .jinja)

function Build-ServerArgs {
  param(
    [hashtable]$Model,
    [double]$Temperature,
    [double]$RepeatPenalty,
    [string]$ApiHost,
    [int]$Port,
    [string]$ScriptRoot
  )

  $args = @(
    '-m', $Model.Path,
    '--host', $ApiHost,
    '--port', $Port,
    '-c', $Model.Context,
    '-t', $([Environment]::ProcessorCount),
    '--log-disable',
    '--embedding',
    '--metrics',
    '--batch-size', '512',
    '--ubatch-size', '512',
    '--temp', $Temperature.ToString('F2', [cultureinfo]::InvariantCulture),
    '--repeat-penalty', $RepeatPenalty.ToString('F2', [cultureinfo]::InvariantCulture)
  )

  # GPU offload
  if ($Model.GpuLayers -and $Model.GpuLayers -gt 0) {
    $args += '--n-gpu-layers', $Model.GpuLayers
    Write-Host "GPU offload ativo: $($Model.GpuLayers) camadas" -ForegroundColor Cyan
  }

  # Chat template
  if ($Model.Template -ne 'auto') {
    if ($Model.Template -like '*.jinja') {
      $tplPath = Join-Path $ScriptRoot $Model.Template
      if (!(Test-Path $tplPath)) {
        throw "Template Jinja nao encontrado: $tplPath"
      }
      $args += '--chat-template-file', $tplPath
    }
    else {
      $args += '--chat-template', $Model.Template
    }
  }

  return $args
}

function Wait-ServerReady {
  param(
    [int]$Port,
    [int]$TimeoutSec = 60
  )

  for ($i = 1; $i -le $TimeoutSec; $i++) {
    try {
      $r = Invoke-WebRequest "http://127.0.0.1:$Port/health" `
        -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
      if ($r.StatusCode -eq 200) { return $true }
    }
    catch {
      Write-Host "  Aguardando... ($i/$TimeoutSec)" -ForegroundColor Gray
      Start-Sleep -Seconds 1
    }
  }
  return $false
}
