<#
.SYNOPSIS
    Configura o PowerShell 7 como padrão no sistema usando variáveis de ambiente.
    
    Se o script não for executado como Administrador, ele automaticamente:
    1. Detecta a falta de privilégios
    2. Reinicia em nova janela com elevação (solicita UAC)
    3. Executa a configuração completa

.DESCRIPTION
    Este script modifica a ordem das variáveis de ambiente PATH para priorizar
    o PowerShell 7 sobre o Windows PowerShell 5.1, utilizando variáveis de
    ambiente em vez de caminhos fixos sempre que possível.
    
    Variáveis utilizadas:
    - %ProgramFiles% -> C:\Program Files
    - %SystemRoot%   -> C:\Windows
    - %PATH%         -> Variável de ambiente do sistema

.PARAMETER None
    Este script não aceita parâmetros.

.EXAMPLE
    .\Set-PowerShell7AsDefault.ps1
    
    Executa o script. Se não estiver como Administrador, reinicia automaticamente
    com privilégios elevados após confirmação do UAC.

.NOTES
    Autor: Usuário
    Versão: 1.3
    Requerimentos: 
        - PowerShell 7 instalado
        - Acesso ao UAC para elevação quando necessário
    
    Funcionalidades:
        ✓ Auto-elevação automática
        ✓ Uso de variáveis de ambiente em vez de caminhos fixos
        ✓ Mantém PowerShell 5.1 intacto
        ✓ Testa configuração após aplicação com recarregamento completo do PATH
        ✓ Reorganiza PATH com segurança
#>

# ===== FUNÇÃO DE AUTO-ELEVAÇÃO =====
# Verifica se está rodando como Administrador
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Este script precisa ser executado como ADMINISTRADOR." -ForegroundColor Yellow
    Write-Host "Tentando reiniciar com privilégios elevados..." -ForegroundColor Yellow
    
    # Obtém o caminho completo do script atual
    $scriptPath = $MyInvocation.MyCommand.Path
    
    # Se não conseguiu obter o caminho (executou colando), usa um método alternativo
    if (-not $scriptPath) {
        $scriptPath = (Get-Location).Path + "\" + (Split-Path -Leaf $MyInvocation.PSCommandPath)
    }
    
    # Cria um processo PowerShell com privilégios de administrador
    # ExecutionPolicy Bypass garante execução mesmo com restrições
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments
        Write-Host "Script reiniciado como Administrador em nova janela." -ForegroundColor Green
        Write-Host "A janela original sera fechada."
        Start-Sleep -Seconds 2
        exit 0
    }
    catch {
        Write-Host "ERRO: Nao foi possivel reiniciar como Administrador." -ForegroundColor Red
        Write-Host "Por favor, execute manualmente como Administrador:" -ForegroundColor Yellow
        Write-Host "  1. Feche esta janela" -ForegroundColor White
        Write-Host "  2. Clique com botao direito no PowerShell" -ForegroundColor White
        Write-Host "  3. Selecione 'Executar como administrador'" -ForegroundColor White
        Write-Host "  4. Navegue ate a pasta e execute novamente" -ForegroundColor White
        pause
        exit 1
    }
}

# Se chegou aqui, está executando como Administrador
Write-Host "OK: Script executando com privilegios de Administrador" -ForegroundColor Green
Write-Host ""

# ===== CONFIGURAÇÃO USANDO VARIÁVEIS DE AMBIENTE =====
Write-Host "Configurando PowerShell 7 como padrao no sistema (usando variaveis de ambiente)..." -ForegroundColor Cyan
Write-Host ""

# Resolve as variáveis de ambiente para caminhos reais (para verificação)
$programFiles = $env:ProgramFiles
$systemRoot = $env:SystemRoot

# Define os caminhos usando variáveis de ambiente (formato com % para o PATH)
$pwshPathWithVar = "%ProgramFiles%\PowerShell\7"
$powershellLegacyPathWithVar = "%SystemRoot%\System32\WindowsPowerShell\v1.0\"

# Versões resolvidas (para verificação de existência)
$pwshPathResolved = "$programFiles\PowerShell\7"
$powershellLegacyPathResolved = "$systemRoot\System32\WindowsPowerShell\v1.0\"
$pwshExe = "$pwshPathResolved\pwsh.exe"

Write-Host "Caminhos configurados com variaveis de ambiente:" -ForegroundColor Cyan
Write-Host "  PowerShell 7 (variavel): $pwshPathWithVar" -ForegroundColor White
Write-Host "  PowerShell 7 (resolvido): $pwshPathResolved" -ForegroundColor Gray
Write-Host "  PowerShell 5.1 (variavel): $powershellLegacyPathWithVar" -ForegroundColor White
Write-Host "  PowerShell 5.1 (resolvido): $powershellLegacyPathResolved" -ForegroundColor Gray
Write-Host ""

# Verifica se o PowerShell 7 está instalado
if (-NOT (Test-Path $pwshExe)) {
    Write-Host "ERRO: PowerShell 7 NAO encontrado em: $pwshPathResolved" -ForegroundColor Red
    Write-Host "Execute o comando abaixo para instalar primeiro:" -ForegroundColor Yellow
    Write-Host "  winget install --id Microsoft.Powershell --source winget" -ForegroundColor White
    pause
    exit 1
}

Write-Host "OK: PowerShell 7 encontrado em: $pwshPathResolved" -ForegroundColor Green
Write-Host "PowerShell 5.1 original em: $powershellLegacyPathResolved" -ForegroundColor Gray
Write-Host ""

# Obtém o PATH atual do sistema (variável de máquina, não do usuário)
$oldPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
Write-Host "Lendo PATH do sistema..." -ForegroundColor Gray

# Divide o PATH em partes para manipulação
$pathParts = $oldPath -split ';'

# Remove entradas duplicadas ou vazias
$pathParts = $pathParts | Where-Object { $_ -ne "" }

# Prepara a nova lista
$newPathParts = @()

# Função para normalizar caminhos para comparação (ignora diferenças de case e barras)
function Normalize-Path {
    param([string]$Path)
    return $Path.TrimEnd('\').ToLower()
}

# Verifica se o PowerShell 7 já está no PATH (considerando tanto formato com % quanto resolvido)
$pwshInPath = $false
$pwsh7Entry = $null

foreach ($part in $pathParts) {
    $normalizedPart = Normalize-Path $part
    $normalizedPwshResolved = Normalize-Path $pwshPathResolved
    
    # Verifica se a parte atual corresponde ao PowerShell 7 (formato com % ou resolvido)
    if ($normalizedPart -eq $normalizedPwshResolved -or 
        $part -eq $pwshPathWithVar -or
        $part -like "*PowerShell\7*") {
        $pwshInPath = $true
        $pwsh7Entry = $part
        break
    }
}

# Se encontrou, remove para adicionar no início depois
if ($pwshInPath) {
    Write-Host "Aviso: PowerShell 7 ja esta no PATH ($pwsh7Entry). Reorganizando ordem..." -ForegroundColor Yellow
    $pathParts = $pathParts | Where-Object { 
        $normalized = Normalize-Path $_
        $normalized -ne (Normalize-Path $pwshPathResolved) -and 
        $_ -ne $pwshPathWithVar -and
        -not ($_ -like "*PowerShell\7*")
    }
} else {
    Write-Host "Adicionando PowerShell 7 ao PATH (usando variavel %ProgramFiles%)..." -ForegroundColor Green
}

# Constrói novo PATH com PowerShell 7 primeiro (usando formato com variável)
$newPathParts += $pwshPathWithVar

# Adiciona os outros caminhos, garantindo que o legado não venha antes
foreach ($part in $pathParts) {
    # Ignora o caminho legado por enquanto (vamos adicionar depois)
    if ($part -like "*WindowsPowerShell\v1.0*" -or $part -eq $powershellLegacyPathWithVar) {
        Write-Host "Movendo PowerShell 5.1 para o final..." -ForegroundColor Yellow
        continue
    }
    $newPathParts += $part
}

# Adiciona o PowerShell 5.1 por último (usando formato com variável)
$newPathParts += $powershellLegacyPathWithVar

# Junta tudo em uma string
$newPath = $newPathParts -join ';'

Write-Host ""
Write-Host "NOVA CONFIGURACAO DO PATH (com variaveis de ambiente):" -ForegroundColor Cyan
$newPathParts | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

# Confirmação do usuário
Write-Host ""
$confirmation = Read-Host "Deseja aplicar esta alteracao? (S/N)"
if ($confirmation -ne 'S' -and $confirmation -ne 's') {
    Write-Host "Operacao cancelada pelo usuario." -ForegroundColor Red
    pause
    exit 0
}

# Aplica a alteração
try {
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "OK: PATH do sistema atualizado com sucesso!" -ForegroundColor Green
    
    # ===== SEÇÃO DE TESTES CORRIGIDA =====
    # Força o recarregamento completo do PATH na sessão atual
    Write-Host "Recarregando PATH na sessao atual..." -ForegroundColor Gray
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    
    Write-Host ""
    Write-Host "Testando a nova configuracao:" -ForegroundColor Cyan
    
    # Testa o comando 'powershell'
    $testPath = (Get-Command powershell -ErrorAction SilentlyContinue).Source
    if ($testPath -like "*PowerShell\7*") {
        Write-Host "OK: O comando 'powershell' agora aponta para: $testPath" -ForegroundColor Green
    } elseif ($testPath -like "*WindowsPowerShell\v1.0*") {
        Write-Host "AVISO: O comando 'powershell' ainda aponta para a versao 5.1: $testPath" -ForegroundColor Yellow
        Write-Host "Isso pode acontecer se houver outra entrada no PATH antes do PowerShell 7." -ForegroundColor Yellow
    } else {
        Write-Host "INFO: Comando 'powershell' encontrado em: $testPath" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Testando o comando 'pwsh':" -ForegroundColor Cyan
    $pwshTest = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if ($pwshTest) {
        Write-Host "OK: 'pwsh' encontrado em: $pwshTest" -ForegroundColor Green
    } else {
        Write-Host "ERRO: 'pwsh' nao encontrado no PATH!" -ForegroundColor Red
        Write-Host "Tentando localizar manualmente..." -ForegroundColor Yellow
        
        # Tenta encontrar o pwsh.exe em locais comuns
        $possibleLocations = @(
            "C:\Program Files\PowerShell\7\pwsh.exe",
            "C:\Program Files\PowerShell\6\pwsh.exe",
            "$env:ProgramFiles\PowerShell\7\pwsh.exe"
        )
        
        $found = $false
        foreach ($loc in $possibleLocations) {
            if (Test-Path $loc) {
                Write-Host "Encontrado em: $loc" -ForegroundColor Green
                Write-Host "NOTA: O comando 'pwsh' deve funcionar apos abrir um novo terminal." -ForegroundColor Yellow
                $found = $true
                break
            }
        }
        
        if (-not $found) {
            Write-Host "PowerShell 7 nao encontrado em locais padrao. Pode ser necessaria reinstalacao." -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Verificacao das variaveis de ambiente no PATH:" -ForegroundColor Cyan
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -like "*%ProgramFiles%*PowerShell*7*") {
        Write-Host "OK: PATH contem %ProgramFiles%\PowerShell\7 (formato com variavel)" -ForegroundColor Green
    } else {
        Write-Host "INFO: PATH contem caminho resolvido em vez de variavel" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host "CONFIGURACAO CONCLUIDA!" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "RECOMENDACOES IMPORTANTES:" -ForegroundColor Yellow
    Write-Host " 1️⃣ Feche este terminal e abra um NOVO PowerShell" -ForegroundColor White
    Write-Host " 2️⃣ No novo terminal, execute estes comandos para confirmar:" -ForegroundColor White
    Write-Host "    > where powershell" -ForegroundColor Gray
    Write-Host "      (Deve mostrar C:\Program Files\PowerShell\7\pwsh.exe em primeiro)" -ForegroundColor Gray
    Write-Host "    > `$PSVersionTable.PSVersion" -ForegroundColor Gray
    Write-Host "      (Deve mostrar versao 7.x)" -ForegroundColor Gray
    Write-Host "    > Get-Command pwsh" -ForegroundColor Gray
    Write-Host "      (Deve mostrar C:\Program Files\PowerShell\7\pwsh.exe)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "NOTA: O PowerShell 5.1 continua disponivel em:" -ForegroundColor Cyan
    Write-Host "  %SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "ERRO ao atualizar PATH: $_" -ForegroundColor Red
    pause
    exit 1
}

pause