# ============================
# Setup llama.cpp CUDA 12.4 / 13.1 com deteccao
# ============================

function Get-DetectedCudaMajor {
    try {
        # Tenta rodar nvidia-smi e pegar a linha com "CUDA Version"
        $smiOutput = & nvidia-smi 2>$null
        if (-not $smiOutput) {
            return $null
        }

        $cudaLine = $smiOutput | Select-String -Pattern "CUDA Version"
        if (-not $cudaLine) {
            return $null
        }

        # Extrai o numero depois de "CUDA Version:"
        # Ex: "CUDA Version: 13.1" -> 13
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

$detectedMajor = Get-DetectedCudaMajor
$defaultChoice = $null

if ($detectedMajor) {
    if ($detectedMajor -ge 13) {
        $defaultChoice = '2'   # Sugerir CUDA 13.1
    } elseif ($detectedMajor -ge 12) {
        $defaultChoice = '1'   # Sugerir CUDA 12.4
    }
}

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
    '1' {
        # CUDA 12.4 (seu script original, b8083)
        $LLAMA_URL = "https://github.com/ggml-org/llama.cpp/releases/download/b8083/llama-b8083-bin-win-cuda-12.4-x64.zip"
        $CUDART_URL = "https://github.com/ggml-org/llama.cpp/releases/download/b8083/cudart-llama-bin-win-cuda-12.4-x64.zip"
        $LLAMA_ZIP = "llama-b8083-bin-win-cuda-12.4-x64.zip"
        $CUDART_ZIP = "cudart-llama-bin-win-cuda-12.4-x64.zip"
        $defaultInstallFolder = "llama-cpp-cuda124"
    }
    '2' {
        # CUDA 13.1 (b8149)
        $LLAMA_URL = "https://github.com/ggml-org/llama.cpp/releases/download/b8149/llama-b8149-bin-win-cuda-13.1-x64.zip"
        $CUDART_URL = "https://github.com/ggml-org/llama.cpp/releases/download/b8149/cudart-llama-bin-win-cuda-13.1-x64.zip"
        $LLAMA_ZIP = "llama-b8149-bin-win-cuda-13.1-x64.zip"
        $CUDART_ZIP = "cudart-llama-bin-win-cuda-13.1-x64.zip"
        $defaultInstallFolder = "llama-cpp-cuda131"
    }
    default {
        Write-Host "Opcao invalida. Saindo..." -ForegroundColor Red
        Pause
        exit
    }
}

# ==== resto do script igual ao anterior ====

# Obter caminho da pasta Downloads do usuário de forma correta
$downloadsKey = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}" -ErrorAction SilentlyContinue

if ($downloadsKey) {
    $DOWNLOADS_DIR = [System.Environment]::ExpandEnvironmentVariables($downloadsKey."{374DE290-123F-4565-9164-39C4925E467B}")
} else {
    Write-Warning "Nao foi possivel obter o caminho personalizado da pasta Downloads via registro. Usando metodo alternativo."
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $DOWNLOADS_DIR = Join-Path $userProfile "Downloads"
}

$LLAMA_DL_PATH = Join-Path $DOWNLOADS_DIR $LLAMA_ZIP
$CUDART_DL_PATH = Join-Path $DOWNLOADS_DIR $CUDART_ZIP

$DISK_DRIVE = Read-Host "Em qual disco deseja instalar? (Ex: C, D)"
$INSTALL_DIR = "${DISK_DRIVE}:\$defaultInstallFolder"
$TEMP_DIR = Join-Path $env:TEMP "llama_cpp_temp"

try {
    if (Test-Path $LLAMA_DL_PATH) {
        Write-Host "Arquivo $LLAMA_ZIP ja existe na pasta Downloads. Pulando o download." -ForegroundColor Green
    } else {
        Write-Host "Baixando $LLAMA_ZIP ..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $LLAMA_URL -OutFile $LLAMA_DL_PATH
            Write-Host "Download de $LLAMA_ZIP concluido com sucesso." -ForegroundColor Green
        } catch {
            Write-Error "Erro ao baixar $LLAMA_ZIP`: $_"
            throw $_
        }
    }

    if (Test-Path $CUDART_DL_PATH) {
        Write-Host "Arquivo $CUDART_ZIP ja existe na pasta Downloads. Pulando o download." -ForegroundColor Green
    } else {
        Write-Host "Baixando $CUDART_ZIP ..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $CUDART_URL -OutFile $CUDART_DL_PATH
            Write-Host "Download de $CUDART_ZIP concluido com sucesso." -ForegroundColor Green
        } catch {
            Write-Error "Erro ao baixar $CUDART_ZIP`: $_"
            throw $_
        }
    }

    if (!(Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
        Write-Host "Diretorio de instalacao $INSTALL_DIR criado." -ForegroundColor Green
    } else {
        Write-Host "Diretorio de instalacao $INSTALL_DIR ja existia." -ForegroundColor Green
    }

    if (!(Test-Path $TEMP_DIR)) {
        New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
    }
    Copy-Item $LLAMA_DL_PATH -Destination $TEMP_DIR -Force
    Copy-Item $CUDART_DL_PATH -Destination $TEMP_DIR -Force

    Set-Location $TEMP_DIR

    Write-Host "Descompactando arquivos..." -ForegroundColor Yellow
    try {
        Expand-Archive -Path $LLAMA_ZIP -DestinationPath $INSTALL_DIR -Force
        Write-Host "Arquivo $LLAMA_ZIP descompactado com sucesso." -ForegroundColor Green
    } catch {
        Write-Error "Erro ao descompactar $LLAMA_ZIP`: $_"
        throw $_
    }

    try {
        Expand-Archive -Path $CUDART_ZIP -DestinationPath $INSTALL_DIR -Force
        Write-Host "Arquivo $CUDART_ZIP descompactado com sucesso." -ForegroundColor Green
    } catch {
        Write-Error "Erro ao descompactar $CUDART_ZIP`: $_"
        throw $_
    }

    Write-Host "`nInstalacao concluida em: $INSTALL_DIR" -ForegroundColor Cyan

    $ADD_PATH = Read-Host "`nDeseja adicionar o diretorio $INSTALL_DIR ao PATH do sistema? (S/N)"
    if ($ADD_PATH -eq 'S' -or $ADD_PATH -eq 's') {
        try {
            $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
            if ($currentPath -split ';' -notcontains $INSTALL_DIR) {
                $newPath = $currentPath + ";$INSTALL_DIR"
                [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
                Write-Host "Diretorio adicionado ao PATH do SISTEMA com sucesso. Reinicie o terminal para aplicar as alteracoes." -ForegroundColor Green
                Write-Warning "Se o script nao foi executado como administrador, a alteracao pode nao ter efeito ate uma reinicializacao ou logoff/login."
            } else {
                Write-Host "Diretorio ja estava presente no PATH do sistema." -ForegroundColor Green
            }
        } catch {
            Write-Warning "Erro ao adicionar ao PATH do sistema. Tentando adicionar ao PATH do usuario..."
            try {
                $currentUserPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
                if ($currentUserPath -split ';' -notcontains $INSTALL_DIR) {
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

    Write-Host "`n`t *** Todas as etapas foram concluidas com sucesso! ***" -ForegroundColor Magenta
    Write-Host "`t - Arquivos necessarios baixados ou verificados." -ForegroundColor White
    Write-Host "`t - Arquivos descompactados na pasta de destino." -ForegroundColor White
    Write-Host "`t - Configuracao do PATH concluida conforme sua escolha." -ForegroundColor White
    Write-Host "`t - O ambiente llama.cpp esta pronto para uso." -ForegroundColor White
    Write-Host "`t Lembre-se de reiniciar seu terminal se adicionou ao PATH.`n" -ForegroundColor White

} finally {
    Write-Verbose "Tentando voltar ao diretorio original..."
    Set-Location $PSScriptRoot

    Write-Verbose "Tentando remover diretorio temporario: $TEMP_DIR"
    if (Test-Path $TEMP_DIR) {
        try {
            Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction Stop
            Write-Host "Arquivos temporarios removidos." -ForegroundColor Green
        } catch {
            Write-Warning "Nao foi possivel remover o diretorio temporario '$TEMP_DIR'. Ele pode estar em uso ou voce precisa de permissoes elevadas. Voce pode remove-lo manualmente mais tarde."
        }
    }
}

Pause
