# Test-Module.psm1 - Manifesto do módulo de testes llama.cpp

# Importa os scripts internos
. "$PSScriptRoot\CodePrompts.ps1"
. "$PSScriptRoot\Test-ServerHealth.ps1"
. "$PSScriptRoot\Test-ModelsList.ps1"
. "$PSScriptRoot\Invoke-TestCompletion.ps1"
. "$PSScriptRoot\Invoke-AllTests.ps1"

# Exporta as funções disponíveis
Export-ModuleMember -Function @(
  'Test-ServerHealth',
  'Test-ModelsList',
  'Invoke-TestCompletion',
  'Invoke-AllTests'
)
