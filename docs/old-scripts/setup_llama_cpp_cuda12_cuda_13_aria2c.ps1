# ============================
# Setup llama.cpp CUDA 12.4 / 13.1 com aria2c + deteccao + validacao ZIP
# ============================

function Get-DetectedCudaMajor {
    try {
        $smiOutput = & nvidia-smi 2>$null
        if (-not $smiOutput) { return $null }

        $cudaLine = $smiOutput | Select-String -Pattern "CUDA Version"
        if (-not $cudaLine) { return $null }

        if ($cudaLine -match "CUDA Version:\s*([0-9]+)\.([0-9]+)") {
            $major = [int]$Matches[1]
            $minor = [int]$Matches[2]
            Write-Host "CUDA suportado pelo driver (nvidia-smi): $major.$minor" -ForegroundColor Cyan
            return $major
        }
        return $null
    } catch {
        return $null
    }
}

function Test-Aria2cAvailable {
    try {
        $null = & aria2c --version 2>$null
        return $true
    } catch {
        return $false
    }
}

function Download-File {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    $useAria2c = Test-Aria2cAvailable

    if ($useAria2c) {
        Write-Host "" -ForegroundColor DarkCyan
        Write-Host "========================================" -ForegroundColor DarkCyan
        Write-Host "  Iniciando download com aria2c" -ForegroundColor Cyan
        Write-Host "  URL: $Url" -ForegroundColor Cyan
        Write-Host "  Destino: $OutFile" -ForegroundColor Cyan
        Write-Host "  A barra abaixo e do proprio aria2c (progresso, velocidade, ETA)" -ForegroundColor DarkGray
        Write-Host "========================================" -ForegroundColor DarkCyan

        $outDir = Split-Path -Parent $OutFile
        $fileName = Split-Path -Leaf $OutFile

        if (!(Test-Path $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }

        $cmdArgs = "aria2c --allow-overwrite=true --max-connection-per-server=16 --split=16 --min-split-size=1M --console-log-level=notice --summary-interval=1 --dir=""$outDir"" --out=""$fileName"" ""$Url"""

        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $cmdArgs" -NoNewWindow -Wait -PassThru
        $exitCode = $process.ExitCode

        if ($exitCode -eq 0 -and (Test-Path $OutFile) -and (Get-Item $OutFile).Length -gt 0) {
            Write-Host "" 
            Write-Host "Download concluido com sucesso via aria2c: $fileName" -ForegroundColor Green
        } else {
            Write-Warning "aria2c falhou (codigo $exitCode). Tentando Invoke-WebRequest..."
            Invoke-WebRequest -Uri $Url -OutFile $OutFile
            Write-Host "Download concluido via Invoke-WebRequest: $fileName" -ForegroundColor Yellow
        }
    } else {
        Write-Host "aria2c nao encontrado. Usando Invoke-WebRequest para baixar $Url" -ForegroundColor Yellow
        Invoke-WebRequest -Uri $Url -OutFile $OutFile
        Write-Host "Download concluido via Invoke-WebRequest: $(Split-Path -Leaf $OutFile)" -ForegroundColor Green
    }
}

# ----------------------------
# Deteccao da versao de CUDA
# ----------------------------
$detectedMajor = Get-DetectedCudaMajor
$defaultChoice = $null

if ($detectedMajor) {
    if ($detectedMajor -ge 13) {
        $defaultChoice = "2"
    } elseif ($detectedMajor -ge 12) {
        $defaultChoice = "1"
    }
}

Write-Host ""
Write-Host "Escolha a versao do pacote llama.cpp (Windows x64):" -ForegroundColor Cyan
Write-Host "1 - CUDA 12.4 (b8083)" -ForegroundColor Yellow
Write-Host "2 - CUDA 13.1 (b8149)" -ForegroundColor Yellow

if ($defaultChoice) {
    Write-Host "Sugestao com base no driver NVIDIA (nvidia-smi): opcao $defaultChoice" -ForegroundColor Green
    $choice = Read-Host "Digite 1, 2 ou pressione ENTER para usar a sugestao ($defaultChoice)"
    if ([string]::IsNullOrWhiteSpace($choice)) {
        $choice = $defaultChoice
    }
} else {
    Write-Host "Nao foi possivel detectar a versao de CUDA via nvidia-smi. Escolha manualmente." -ForegroundColor Yellow
    $choice = Read-Host "Digite 1 ou 2"
}

switch ($choice) {
    "1" {
        $LLAMA_URL   = "https://github.com/ggml-org/llama.cpp/releases/download/b8083/llama-b8083-bin-win-cuda-12.4-x64.zip"
        $CUDART_URL  = "https://github.com/ggml-org/llama.cpp/releases/download/b8083/cudart-llama-bin-win-cuda-12.4-x64.zip"
        $LLAMA_ZIP   = "llama-b8083-bin-win-cuda-12.4-x64.zip"
        $CUDART_ZIP  = "cudart-llama-bin-win-cuda-12.4-x64.zip"
        $defaultInstallFolder = "llama-cpp-cuda124"
    }
    "2" {
        $LLAMA_URL   = "https://github.com/ggml-org/llama.cpp/releases/download/b8149/llama-b8149-bin-win-cuda-13.1-x64.zip"
        $CUDART_URL  = "https://github.com/ggml-org/llama.cpp/releases/download/b8149/cudart-llama-bin-win-cuda-13.1-x64.zip"
        $LLAMA_ZIP   = "llama-b8149-bin-win-cuda-13.1-x64.zip"
        $CUDART_ZIP  = "cudart-llama-bin-win-cuda-13.1-x64.zip"
        $defaultInstallFolder = "llama-cpp-cuda131"
    }
    default {
        Write-Host "Opcao invalida. Saindo..." -ForegroundColor Red
        Pause
        exit
    }
}

# ----------------------------
# Caminhos
# ----------------------------
$downloadsKey = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}" -ErrorAction SilentlyContinue

if ($downloadsKey) {
    $DOWNLOADS_DIR = [System.Environment]::ExpandEnvironmentVariables($downloadsKey."{374DE290-123F-4565-9164-39C4925E467B}")
} else {
    Write-Warning "Nao foi possivel obter o caminho da pasta Downloads via registro. Usando metodo alternativo."
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $DOWNLOADS_DIR = Join-Path $userProfile "Downloads"
}

$LLAMA_DL_PATH  = Join-Path $DOWNLOADS_DIR $LLAMA_ZIP
$CUDART_DL_PATH = Join-Path $DOWNLOADS_DIR $CUDART_ZIP

$DISK_DRIVE  = Read-Host "Em qual disco deseja instalar? (Ex: C, D)"
$INSTALL_DIR = "${DISK_DRIVE}:\$defaultInstallFolder"

try {
    # --- Download LLAMA ---
    if (Test-Path $LLAMA_DL_PATH) {
        Write-Host "Arquivo $LLAMA_ZIP ja existe na pasta Downloads. Pulando o download." -ForegroundColor Green
    } else {
        Write-Host "Baixando $LLAMA_ZIP ..." -ForegroundColor Yellow
        try {
            Download-File -Url $LLAMA_URL -OutFile $LLAMA_DL_PATH
        } catch {
            Write-Error "Erro ao baixar $LLAMA_ZIP`: $_"
            throw $_
        }
    }

    # --- Download CUDART ---
    if (Test-Path $CUDART_DL_PATH) {
        Write-Host "Arquivo $CUDART_ZIP ja existe na pasta Downloads. Pulando o download." -ForegroundColor Green
    } else {
        Write-Host "Baixando $CUDART_ZIP ..." -ForegroundColor Yellow
        try {
            Download-File -Url $CUDART_URL -OutFile $CUDART_DL_PATH
        } catch {
            Write-Error "Erro ao baixar $CUDART_ZIP`: $_"
            throw $_
        }
    }

    # --- Criar diretorio de destino ---
    if (!(Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        Write-Host "Diretorio de instalacao $INSTALL_DIR criado." -ForegroundColor Green
    } else {
        Write-Host "Diretorio de instalacao $INSTALL_DIR ja existia." -ForegroundColor Green
    }

    # --- Descompactar LLAMA ---
    Write-Host "Descompactando arquivos..." -ForegroundColor Yellow

    try {
        if (-not (Test-Path $LLAMA_DL_PATH) -or (Get-Item $LLAMA_DL_PATH).Length -eq 0) {
            throw "Arquivo $LLAMA_DL_PATH esta ausente ou com tamanho zero. Provavel erro de download."
        }
        Expand-Archive -Path $LLAMA_DL_PATH -DestinationPath $INSTALL_DIR -Force
        Write-Host "Arquivo $LLAMA_ZIP descompactado com sucesso." -ForegroundColor Green
    } catch {
        Write-Error "Erro ao descompactar $LLAMA_ZIP`: $_"
        Write-Warning "Delete o ZIP em $DOWNLOADS_DIR e rode o script novamente para forcar novo download."
        throw $_
    }

    # --- Descompactar CUDART ---
    try {
        if (-not (Test-Path $CUDART_DL_PATH) -or (Get-Item $CUDART_DL_PATH).Length -eq 0) {
            throw "Arquivo $CUDART_DL_PATH esta ausente ou com tamanho zero. Provavel erro de download."
        }
        Expand-Archive -Path $CUDART_DL_PATH -DestinationPath $INSTALL_DIR -Force
        Write-Host "Arquivo $CUDART_ZIP descompactado com sucesso." -ForegroundColor Green
    } catch {
        Write-Error "Erro ao descompactar $CUDART_ZIP`: $_"
        Write-Warning "Delete o ZIP em $DOWNLOADS_DIR e rode o script novamente para forcar novo download."
        throw $_
    }

    Write-Host ""
    Write-Host "Instalacao concluida em: $INSTALL_DIR" -ForegroundColor Cyan

    # --- PATH ---
    $ADD_PATH = Read-Host "Deseja adicionar o diretorio $INSTALL_DIR ao PATH do sistema? (S/N)"
    if ($ADD_PATH -eq "S" -or $ADD_PATH -eq "s") {
        try {
            $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
            if ($currentPath -split ";" -notcontains $INSTALL_DIR) {
                $newPath = $currentPath + ";$INSTALL_DIR"
                [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
                Write-Host "Diretorio adicionado ao PATH do SISTEMA com sucesso. Reinicie o terminal para aplicar as alteracoes." -ForegroundColor Green
                Write-Warning "Se o script nao foi executado como administrador, a alteracao pode nao ter efeito ate uma reinicializacao."
            } else {
                Write-Host "Diretorio ja estava presente no PATH do sistema." -ForegroundColor Green
            }
        } catch {
            Write-Warning "Erro ao adicionar ao PATH do sistema. Tentando adicionar ao PATH do usuario..."
            try {
                $currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
                if ($currentUserPath -split ";" -notcontains $INSTALL_DIR) {
                    $newUserPath = $currentUserPath + ";$INSTALL_DIR"
                    [System.Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
                    Write-Host "Diretorio adicionado ao PATH do USUARIO com sucesso. Reinicie o terminal para aplicar as alteracoes." -ForegroundColor Green
                } else {
                    Write-Host "Diretorio ja estava presente no PATH do usuario." -ForegroundColor Green
                }
            } catch {
                Write-Warning "Erro ao adicionar ao PATH do usuario tambem. Voce pode adiciona-lo manualmente mais tarde."
            }
        }
    } else {
        Write-Host "Voce optou por nao adicionar ao PATH. O diretorio de instalacao e: $INSTALL_DIR"
    }

    Write-Host ""
    Write-Host "`t *** Todas as etapas foram concluidas com sucesso! ***" -ForegroundColor Magenta
    Write-Host "`t - Arquivos necessarios baixados ou verificados." -ForegroundColor White
    Write-Host "`t - Arquivos descompactados na pasta de destino." -ForegroundColor White
    Write-Host "`t - Configuracao do PATH concluida conforme sua escolha." -ForegroundColor White
    Write-Host "`t - O ambiente llama.cpp esta pronto para uso." -ForegroundColor White
    Write-Host "`t Lembre-se de reiniciar seu terminal se adicionou ao PATH." -ForegroundColor White
    Write-Host ""

} finally {
    Write-Verbose "Tentando voltar ao diretorio original..."
    Set-Location $PSScriptRoot
}

Pause
