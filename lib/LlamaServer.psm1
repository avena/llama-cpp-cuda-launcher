# LlamaServer.psm1 - Módulo de funções para o servidor llama.cpp
# Responsabilidades:
#   - Aggregar todas as funções de lib/ em um único módulo
#   - Exportar funções públicas para uso externo
#   - Fornecer API consistente para start-llama-server.ps1

# Importa os scripts internos
. "$PSScriptRoot\menu.ps1"
. "$PSScriptRoot\validation.ps1"
. "$PSScriptRoot\server.ps1"

# Exporta as funções disponíveis
Export-ModuleMember -Function @(
  'Show-ModelMenu',
  'Get-ValidNumber',
  'Build-ServerArgs',
  'Wait-ServerReady'
)
