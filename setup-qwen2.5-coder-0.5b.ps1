<#
.SYNOPSIS
    Download de modelo GGUF para Windows com aria2c
    - Modelo: qwen2.5-coder-0.5b-instruct (~398 MB)
    - Pergunta qual letra do drive usar (C, D, E, ou qualquer outra)
    - Verifica se arquivo ja existe antes de baixar
    - Usa aria2c com resume automatico
    - Estrutura: [DRIVE]:\models-ai\[modelo]\[arquivo]

.USO
    powershell -ExecutionPolicy Bypass -File .\qwen2.5-coder-0.5b.ps1
#>

# === CONFIGURACOES DO MODELO ===
$MODEL_NAME = "qwen2.5-coder-0.5b-instruct"
$MODEL_FILE = "qwen2.5-coder-0.5b-instruct.Q4_K_M.gguf"
$MODEL_URL = "https://huggingface.co/bartowski/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-0.5B-Instruct-Q4_K_M.gguf"
$EXPECTED_SIZE_GB = 0.39
$MIN_SPACE_GB = 1.0

# === VARIAVEIS GLOBAIS ===
$script:driveLetter = $null
$script:paths = $null

# === FUNCOES AUXILIARES ===

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host ("=" * 70) -ForegroundColor Cyan
    Write-Host ""
}

function Write-SubHeader {
    param([string]$Text)
    Write-Host ""
    Write-Host "--- $Text ---" -ForegroundColor Gray
}

function Test-Aria2 {
    try {
        $null = Get-Command aria2c -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Show-Aria2InstallGuide {
    Write-Host "ERROR: aria2c nao encontrado no PATH." -ForegroundColor Red
    Write-Host ""
    Write-Host "Instale aria2 com uma das opcoes:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "[1] Winget (recomendado):" -ForegroundColor Green
    Write-Host "    winget install -e --id aria2.aria2"
    Write-Host ""
    Write-Host "[2] Chocolatey:" -ForegroundColor Green
    Write-Host "    choco install aria2 -y"
    Write-Host ""
    Write-Host "[3] Scoop:" -ForegroundColor Green
    Write-Host "    iwr -useb get.scoop.sh | iex"
    Write-Host "    scoop install aria2"
    Write-Host ""
    Write-Host "AVISO: Apos instalar, REINICIE este terminal e execute novamente." -ForegroundColor Red
    exit 1
}

function Select-Drive {
    Write-Header "Selecao de Drive"
    
    do {
        $letter = Read-Host "Qual drive deseja usar? (digite a letra, ex: C, D, E)"
        
        if ($letter -match '^[A-Za-z]$') {
            $drivePath = "$($letter.ToUpper()):"
            
            if (Test-Path "$drivePath\") {
                Write-Host "OK: Drive selecionado: $drivePath" -ForegroundColor Green
                return $drivePath
            }
            else {
                Write-Host "ERROR: Drive $drivePath nao encontrado. Tente outra letra." -ForegroundColor Red
            }
        }
        else {
            Write-Host "ERROR: Digite apenas uma letra (ex: C, D, E)" -ForegroundColor Red
        }
    } while ($true)
}

function Setup-Directory {
    param(
        [string]$Root,
        [string]$ModelName
    )
    
    $basePath = Join-Path $Root "models-ai"
    $modelPath = Join-Path $basePath $ModelName
    
    if (!(Test-Path $modelPath)) {
        New-Item -ItemType Directory -Path $modelPath -Force | Out-Null
        Write-Host "OK: Criado: $modelPath" -ForegroundColor Green
    }
    else {
        Write-Host "INFO: Ja existe: $modelPath" -ForegroundColor Gray
    }
    
    return @{
        Base  = $basePath
        Model = $modelPath
        File  = Join-Path $modelPath $MODEL_FILE
        Drive = $Root
    }
}

function Check-ExistingFile {
    param([string]$FilePath)
    
    if (!(Test-Path $FilePath)) {
        return @{
            Exists = $false
            SizeMB = 0
            Complete = $false
        }
    }
    
    $file = Get-Item $FilePath
    $sizeMB = [math]::Round($file.Length / 1MB, 2)
    $isComplete = $sizeMB -ge (($EXPECTED_SIZE_GB * 1024) - 50)
    
    return @{
        Exists = $true
        SizeMB = $sizeMB
        Complete = $isComplete
        File = $file
    }
}

function Download-With-Aria2 {
    param(
        [string]$Url,
        [string]$OutputPath,
        [int]$Connections = 4
    )
    
    Write-SubHeader "Download do Modelo"
    Write-Host "URL: $Url" -ForegroundColor Gray
    Write-Host "Destino: $OutputPath" -ForegroundColor Gray
    Write-Host "Conexoes simultaneas: $Connections" -ForegroundColor Gray
    Write-Host "DICA: Resume automatico habilitado. Pode pausar com Ctrl+C e retomar depois." -ForegroundColor Cyan
    Write-Host ""
    
    $checkResult = Check-ExistingFile -FilePath $OutputPath
    if ($checkResult.Exists) {
        if ($checkResult.Complete) {
            Write-Host "INFO: Arquivo ja existe e esta completo ($($checkResult.SizeMB) MB)" -ForegroundColor Green
            Write-Host "      Pulando download." -ForegroundColor Gray
            return $true
        }
        else {
            Write-Host "INFO: Arquivo parcial encontrado: $($checkResult.SizeMB) MB de ~$([math]::Round($EXPECTED_SIZE_GB * 1024, 0)) MB" -ForegroundColor Yellow
            Write-Host "      aria2c continuara de onde parou automaticamente." -ForegroundColor Gray
            Write-Host ""
        }
    }
    
    $aria2Args = @(
        $Url,
        "-d", (Split-Path $OutputPath),
        "-o", (Split-Path $OutputPath -Leaf),
        "-x$Connections",
        "-s$Connections",
        "-c",
        "--auto-file-renaming=false",
        "--console-log-level=warn",
        "--summary-interval=10",
        "--max-connection-per-server=$Connections"
    )
    
    try {
        $process = Start-Process -FilePath "aria2c" `
            -ArgumentList $aria2Args `
            -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Host ""
            Write-Host "OK: Download concluido!" -ForegroundColor Green
            
            $file = Get-Item $OutputPath
            $sizeMB = [math]::Round($file.Length / 1MB, 2)
            Write-Host "Tamanho final: $sizeMB MB" -ForegroundColor Green
            
            if ($sizeMB -lt (($EXPECTED_SIZE_GB * 1024) - 100)) {
                Write-Warning "AVISO: Arquivo parece incompleto. Tente executar novamente."
                return $false
            }
            return $true
        }
        else {
            Write-Error "ERROR: aria2c falhou com codigo: $($process.ExitCode)"
            return $false
        }
    }
    catch {
        Write-Error "ERROR: Erro ao executar aria2c: $_"
        return $false
    }
}

# === EXECUCAO PRINCIPAL ===
function Main {
    Write-Header "Download: $MODEL_NAME (~$([math]::Round($EXPECTED_SIZE_GB * 1024, 0)) MB)"
    
    # 1. Verificar aria2c
    Write-SubHeader "Verificando Dependencias"
    if (!(Test-Aria2)) {
        Show-Aria2InstallGuide
    }
    Write-Host "OK: aria2c encontrado" -ForegroundColor Green
    
    # 2. Perguntar qual drive usar
    $script:driveLetter = Select-Drive
    
    # 3. Configurar diretorios
    $script:paths = Setup-Directory -Root $script:driveLetter -ModelName $MODEL_NAME
    Write-Host "Caminho do modelo: $($script:paths.File)" -ForegroundColor Gray
    Write-Host ""
    
    # 4. Verificar se arquivo ja existe e esta completo
    $checkResult = Check-ExistingFile -FilePath $script:paths.File
    
    if ($checkResult.Exists -and $checkResult.Complete) {
        Write-Host "OK: Modelo ja existe e esta completo ($($checkResult.SizeMB) MB)." -ForegroundColor Green
        $redownload = Read-Host "Deseja baixar novamente? [y/N]"
        if ($redownload -notin @("Y", "y", "Sim", "sim")) {
            Write-Header "Concluido!"
            Write-Host "Modelo: $($script:paths.File)" -ForegroundColor Green
            Write-Host "DICA: Use este caminho no seu script do llama.cpp" -ForegroundColor Cyan
            return
        }
        Write-Host "INICIANDO: Novo download..." -ForegroundColor Yellow
    }
    
    # 5. Baixar modelo
    $success = Download-With-Aria2 -Url $MODEL_URL -OutputPath $script:paths.File
    
    if (!$success) {
        Write-Warning "AVISO: Download nao concluido. Execute novamente para retomar."
        exit 1
    }
    
    # 6. Resumo final
    $finalSizeMB = (Get-Item $script:paths.File).Length / 1MB
    
    Write-Header "Download Concluido!"
    Write-Host "Modelo: $($script:paths.File)" -ForegroundColor Green
    Write-Host "Tamanho: $([math]::Round($finalSizeMB, 2)) MB" -ForegroundColor Green
    Write-Host "Drive: $script:driveLetter" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximos passos:" -ForegroundColor Cyan
    Write-Host "   1. Use seu script de instalacao do llama.cpp" -ForegroundColor Gray
    Write-Host "   2. Execute o modelo apontando para o caminho acima" -ForegroundColor Gray
    Write-Host ""
    Write-Host "DICA: Para retomar download interrompido, execute o script novamente." -ForegroundColor Gray
    Write-Host "      O aria2c continuara automaticamente de onde parou." -ForegroundColor Gray
}

# Executar
Main
