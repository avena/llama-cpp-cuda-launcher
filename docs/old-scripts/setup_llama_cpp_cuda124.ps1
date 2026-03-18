# Definir variáveis de download
$LLAMA_URL = "https://github.com/ggml-org/llama.cpp/releases/download/b8083/llama-b8083-bin-win-cuda-12.4-x64.zip"
$CUDART_URL = "https://github.com/ggml-org/llama.cpp/releases/download/b8083/cudart-llama-bin-win-cuda-12.4-x64.zip"
$LLAMA_ZIP = "llama-b8083-bin-win-cuda-12.4-x64.zip"
$CUDART_ZIP = "cudart-llama-bin-win-cuda-12.4-x64.zip"

# Obter caminho da pasta Downloads do usuário de forma correta
# Usando o provedor Registry para obter o caminho personalizado da pasta Downloads
$downloadsKey = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "{374DE290-123F-4565-9164-39C4925E467B}" -ErrorAction SilentlyContinue

if ($downloadsKey) {
    # O valor retornado pode conter variáveis de ambiente como %USERPROFILE%
    $DOWNLOADS_DIR = [System.Environment]::ExpandEnvironmentVariables($downloadsKey."{374DE290-123F-4565-9164-39C4925E467B}")
} else {
    # Fallback: tenta obter via SpecialFolder Personal e adiciona \Downloads
    Write-Warning "Nao foi possivel obter o caminho personalizado da pasta Downloads via registro. Usando metodo alternativo."
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    $DOWNLOADS_DIR = Join-Path $userProfile "Downloads"
}

# Caminhos completos dos arquivos zip na pasta Downloads
$LLAMA_DL_PATH = Join-Path $DOWNLOADS_DIR $LLAMA_ZIP
$CUDART_DL_PATH = Join-Path $DOWNLOADS_DIR $CUDART_ZIP

# Solicitar ao usuário o disco de instalação
$DISK_DRIVE = Read-Host "Em qual disco deseja instalar? (Ex: C, D)"
$INSTALL_DIR = "${DISK_DRIVE}:\llama-cpp-cuda124"
$TEMP_DIR = Join-Path $env:TEMP "llama_cpp_temp"

try {
    # Verificar se os arquivos já existem na pasta Downloads
    if (Test-Path $LLAMA_DL_PATH) {
        Write-Host "Arquivo $LLAMA_ZIP ja existe na pasta Downloads. Pulando o download." -ForegroundColor Green
    } else {
        Write-Host "Baixando $LLAMA_ZIP ..." -ForegroundColor Yellow
        try {
            Invoke-WebRequest -Uri $LLAMA_URL -OutFile $LLAMA_DL_PATH
            Write-Host "Download de $LLAMA_ZIP concluido com sucesso." -ForegroundColor Green
        } catch {
            Write-Error "Erro ao baixar $LLAMA_ZIP`: $_"
            throw $_ # Re-lança o erro para sair do bloco try
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
            throw $_ # Re-lança o erro para sair do bloco try
        }
    }

    # Criar diretório de destino
    if (!(Test-Path $INSTALL_DIR)) {
        New-Item -ItemType Directory -Path $INSTALL_DIR -Force
        Write-Host "Diretorio de instalacao $INSTALL_DIR criado." -ForegroundColor Green
    } else {
        Write-Host "Diretorio de instalacao $INSTALL_DIR ja existia." -ForegroundColor Green
    }

    # Copiar arquivos da pasta Downloads para o diretório temporário para descompactação
    if (!(Test-Path $TEMP_DIR)) {
        New-Item -ItemType Directory -Path $TEMP_DIR -Force
    }
    Copy-Item $LLAMA_DL_PATH -Destination $TEMP_DIR
    Copy-Item $CUDART_DL_PATH -Destination $TEMP_DIR

    Set-Location $TEMP_DIR

    Write-Host "Descompactando arquivos..." -ForegroundColor Yellow
    try {
        Expand-Archive -Path $LLAMA_ZIP -DestinationPath $INSTALL_DIR -Force
        Write-Host "Arquivo $LLAMA_ZIP descompactado com sucesso." -ForegroundColor Green
    } catch {
        Write-Error "Erro ao descompactar $LLAMA_ZIP`: $_"
        throw $_ # Re-lança o erro para sair do bloco try
    }

    try {
        Expand-Archive -Path $CUDART_ZIP -DestinationPath $INSTALL_DIR -Force
        Write-Host "Arquivo $CUDART_ZIP descompactado com sucesso." -ForegroundColor Green
    } catch {
        Write-Error "Erro ao descompactar $CUDART_ZIP`: $_"
        throw $_ # Re-lança o erro para sair do bloco try
    }

    Write-Host "`nInstalacao concluida em: $INSTALL_DIR" -ForegroundColor Cyan

    $ADD_PATH = Read-Host "`nDeseja adicionar o diretorio $INSTALL_DIR ao PATH do sistema? (S/N)"
    if ($ADD_PATH -eq 'S' -or $ADD_PATH -eq 's') {
        try {
            # Obter o PATH atual do sistema
            $currentPath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
            # Verificar se o diretório já está no PATH
            if ($currentPath -split ';' -notcontains $INSTALL_DIR) {
                # Adiciona o novo diretório ao PATH
                $newPath = $currentPath + ";$INSTALL_DIR"
                # Tenta definir a variável de ambiente do sistema
                # Esta operação pode falhar se o script não for executado como administrador
                [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "Machine")
                Write-Host "Diretorio adicionado ao PATH do SISTEMA com sucesso. Reinicie o terminal para aplicar as alteracoes." -ForegroundColor Green
                Write-Warning "Se o script nao foi executado como administrador, a alteracao pode nao ter efeito ate uma reinicializacao ou logoff/login."
            } else {
                Write-Host "Diretorio ja estava presente no PATH do sistema." -ForegroundColor Green
            }
        } catch {
            # Se falhar, tenta adicionar ao PATH do usuário
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
    # Bloco Finally garante que a limpeza seja feita, mesmo se houver erros
    Write-Verbose "Tentando voltar ao diretorio original..."
    Set-Location $PSScriptRoot # Retorna ao diretório onde o script foi iniciado

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

# Pausa final para manter a janela do PowerShell aberta
Pause
