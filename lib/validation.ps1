# lib/validation.ps1
# Responsabilidades:
#   - Validar entrada numérica do usuário
#   - Suportar valores padrão quando usuário pressiona Enter
#   - Aceitar ponto ou vírgula como separador decimal
#   - Garantir que valores fiquem dentro do range especificado

function Get-ValidNumber {
  param(
    [string]$Prompt,
    [string]$Description,
    [double]$MinValue,
    [double]$MaxValue,
    [double]$DefaultValue,
    [int]$DecimalPlaces = 2
  )

  Write-Host ''
  Write-Host $Description -ForegroundColor Cyan
  Write-Host "Range: $MinValue a $MaxValue  |  Padrao: $DefaultValue (Enter para usar)" -ForegroundColor Gray
  Write-Host 'Aceita ponto ou virgula como decimal' -ForegroundColor Gray
  Write-Host ''

  do {
    $raw = Read-Host $Prompt

    if ([string]::IsNullOrWhiteSpace($raw)) {
      Write-Host "Usando padrao: $DefaultValue" -ForegroundColor Green
      return $DefaultValue
    }

    $norm = $raw.Replace(',', '.')
    $value = 0.0
    $ok = [double]::TryParse(
      $norm,
      [System.Globalization.NumberStyles]::Any,
      [System.Globalization.CultureInfo]::InvariantCulture,
      [ref]$value
    )

    if ($ok -and $value -ge $MinValue -and $value -le $MaxValue) {
      $r = [math]::Round($value, $DecimalPlaces)
      Write-Host "Aceito: $r" -ForegroundColor Green
      return $r
    }

    Write-Host "ERROR: Valor invalido ou fora do range ($MinValue–$MaxValue)." -ForegroundColor Red
  } while ($true)
}
