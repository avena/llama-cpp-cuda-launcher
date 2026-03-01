#!/usr/bin/env pwsh
# _test-core.ps1 — Ponto de entrada para funções de teste llama.cpp
# Importa o módulo Test-Module

# Carrega o módulo de testes
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath "Test-Module\Test-Module.psm1"

if (Test-Path $modulePath) {
    Import-Module $modulePath -Force
}
else {
    Write-Warning "Módulo Test-Module não encontrado em: $modulePath"
}

# Disponibiliza as variáveis do módulo no escopo global
# O CodePrompts é carregado automaticamente pelo módulo
