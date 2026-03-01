# lib/menu.ps1
# Responsabilidades:
#   - Exibir menu interativo de seleção de modelos
#   - Validar existência dos arquivos de modelo
#   - Retornar o modelo selecionado pelo usuário

function Show-ModelMenu {
  param([array]$Models)

  Write-Host ''
  Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
  Write-Host '║       Selecao de Modelo llama.cpp        ║' -ForegroundColor Cyan
  Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan
  Write-Host ''

  for ($i = 0; $i -lt $Models.Count; $i++) {
    $m = $Models[$i]
    $exists = Test-Path $m.Path
    $status = if ($exists) { '[OK]' } else { '[NAO ENCONTRADO]' }
    $color = if ($exists) { 'White' } else { 'Red' }
    $gpu = if ($m.GpuLayers -gt 0) { " | GPU: $($m.GpuLayers) layers" } else { ' | CPU only' }
    Write-Host "  [$($i + 1)] $($m.Name)" -ForegroundColor $color
    Write-Host "       $status$gpu" -ForegroundColor Gray
    Write-Host "       $($m.Path)" -ForegroundColor DarkGray
    Write-Host ''
  }

  $selected = $null
  do {
    $choice = Read-Host "Digite o numero do modelo (1-$($Models.Count))"
    $idx = 0
    $parsed = [int]::TryParse($choice, [ref]$idx)

    if ($parsed -and $idx -ge 1 -and $idx -le $Models.Count) {
      $candidate = $Models[$idx - 1]
      if (Test-Path $candidate.Path) {
        $selected = $candidate
      }
      else {
        Write-Host 'ERROR: Arquivo do modelo nao encontrado. Escolha outro.' -ForegroundColor Red
      }
    }
    else {
      Write-Host "ERROR: Digite um numero entre 1 e $($Models.Count)." -ForegroundColor Red
    }
  } while ($null -eq $selected)

  return $selected
}
