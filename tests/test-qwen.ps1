#!/usr/bin/env pwsh
# test-qwen.ps1 — Teste unificado para todos os modelos Qwen2.5
# Responsabilidades:
#   - Detectar automaticamente o perfil de parâmetros pelo tamanho do modelo
#   - Chamar Invoke-AllTests com parâmetros adequados para cada modelo
#   - Suportar parâmetros manuais que substituem os automáticos

param(
  [string]$Model = "",
  [int]$MaxTokens = 0,        # 0 = auto pelo tamanho do modelo
  [float]$Temperature = -1,   # -1 = auto pelo tamanho do modelo
  [string]$OutputFile = "",
  [switch]$IncludeMetrics
)

# Carrega variáveis de ambiente e funções core
. "$PSScriptRoot\..\load-env.ps1" -Silent
. "$PSScriptRoot\_test-core.ps1"

function Get-QwenProfile {
  param([string]$ModelName)
  $ModelNameLower = $ModelName.ToLower()
    
  # Extrai tamanho em bilhões via regex
  if ($ModelNameLower -match '(\d+\.?\d*)b') {
    $sizeInB = [double]$Matches[1]
        
    # Define perfil com base no tamanho
    switch ($sizeInB) {
      { $_ -le 0.5 } {
        return @{ MaxTokens = 768; Temperature = 0.3; Label = "0.5B (leve)" }
      }
      { $_ -le 1.5 } {
        return @{ MaxTokens = 768; Temperature = 0.3; Label = "1.5B" }
      }
      { $_ -le 3 } {
        return @{ MaxTokens = 1024; Temperature = 0.2; Label = "3B (equilíbrio)" }
      }
      { $_ -le 7 } {
        return @{ MaxTokens = 2048; Temperature = 0.2; Label = "7B (capaz)" }
      }
      default {
        return @{ MaxTokens = 2048; Temperature = 0.2; Label = "grande" }
      }
    }
  }
    
  # Fallback caso não seja possível detectar o tamanho
  return @{ MaxTokens = 2048; Temperature = 0.2; Label = "desconhecido" }
}

function Main {
  if ([string]::IsNullOrWhiteSpace($Model)) {
    Write-Error "Erro: Parâmetro -Model é obrigatório"
    exit 1
  }
    
  # Obtém perfil do modelo
  $profile = Get-QwenProfile -ModelName $Model
    
  # Resolve parâmetros com prioridade para valores manuais
  $resolvedMaxTokens = if ($MaxTokens -gt 0) { $MaxTokens } else { $profile.MaxTokens }
  $resolvedTemperature = if ($Temperature -ge 0) { $Temperature } else { $profile.Temperature }
    
  # Exibe cabeçalho do teste
  Write-Host "============================================================" -ForegroundColor Cyan
  Write-Host "  Teste Qwen2.5 Unificado — $($profile.Label)" -ForegroundColor Cyan
  Write-Host "============================================================" -ForegroundColor Cyan
  Write-Host "  Modelo     : $Model" -ForegroundColor Gray
  Write-Host "  MaxTokens  : $resolvedMaxTokens$(if ($MaxTokens -le 0) { "  (auto)" })" -ForegroundColor Gray
  Write-Host "  Temperature: $resolvedTemperature$(if ($Temperature -lt 0) { "  (auto)" })" -ForegroundColor Gray
  Write-Host "============================================================" -ForegroundColor Cyan
  Write-Host ""
    
  # Parâmetros para Invoke-AllTests
  $testParams = @{
    Model          = $Model
    MaxTokens      = $resolvedMaxTokens
    Temperature    = $resolvedTemperature
    StopTokens     = @("<|im_end|>", "<|im_start|>")
    ModelLabel     = $Model
    IncludeMetrics = $IncludeMetrics.IsPresent
  }
  if (-not [string]::IsNullOrWhiteSpace($OutputFile)) {
    $testParams.OutputFile = $OutputFile
  }
    
  # Executa os testes
  Invoke-AllTests @testParams
}

# Executa o script
Main
