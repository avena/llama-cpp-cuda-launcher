<#
.SYNOPSIS
    Download de modelos GGUF para Windows com aria2c

.DESCRIPTION
    Script interativo para baixar modelos de linguagem (LLM) no formato GGUF:
    - Qwen2.5-Coder-0.5B-Instruct (~379 MB)
    - Qwen2.5-3B-Instruct (~1.93 GB)
    - deepseek-coder-6.7b-instruct (~4.08 GB)
    - Qwen2.5-Coder-7B-Instruct (~4.68 GB)
    
    Funcionalidades:
    • Menu de seleção de modelo
    • Escolha dinâmica de drive (C:, D:, E:, etc.)
    • Verificação case-insensitive de arquivos existentes
    • Download com resume automático via aria2c
    • Padronização de nomes para minúsculas
    • Estrutura organizada: [DRIVE]:\models-ai\[modelo]\[arquivo]

.PARAMETER None
    Este script não aceita parâmetros. Todas as opções são selecionadas interativamente.

.OUTPUTS
    Nenhum. O script baixa o modelo para o diretório escolhido e exibe mensagens no console.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\setup-models.ps1
    Descrição: Executa o script com permissões temporárias para download interativo.

.EXAMPLE
    # Verificar ajuda do script
    Get-Help .\setup-models.ps1 -Full

.LINK
    GitHub Gist: https://gist.github.com/avena/13eb7c9b7388caded8e145f6e3052e65
    llama.cpp: https://github.com/ggml-org/llama.cpp
    aria2c: https://aria2.github.io/
    Modelos GGUF: https://huggingface.co/models?search=gguf

.NOTES
    Autor: avena
    Data: 2026-02
    Versão: 1.0
    Requisitos:
      - Windows 10/11 com PowerShell 5.1+
      - aria2c instalado e no PATH (winget install aria2.aria2)
      - Conexão com internet para download dos modelos
    
    Estrutura de pastas criada:
      [DRIVE]:\models-ai\
        ├── qwen2.5-coder-0.5b-instruct\
        │   └── qwen2.5-coder-0.5b-instruct-q4_k_m.gguf
        ├── qwen2.5-3b-instruct\
        │   └── Qwen2.5-3B-Instruct-Q4_K_M.gguf
        ├── deepseek-coder-6.7b-instruct\
        │   └── deepseek-coder-6.7b-instruct-q4_k_m.gguf
        └── qwen2.5-coder-7b-instruct\
            └── qwen2.5-coder-7b-instruct-q4_k_m.gguf
    
    Tamanhos reais dos modelos (Q4_K_M):
      • Qwen2.5-Coder-0.5B: ~379 MB
      • Qwen2.5-3B-Instruct: ~1.93 GB
      • deepseek-coder-6.7B: ~4.08 GB
      • Qwen2.5-Coder-7B: ~4.68 GB
    
    Segurança:
      - Revise sempre o código antes de executar scripts da internet
      - Este script não coleta ou envia dados pessoais
      - Os modelos são baixados diretamente do Hugging Face

    Para baixar este script:
      Invoke-WebRequest -Uri "https://gist.githubusercontent.com/avena/13eb7c9b7388caded8e145f6e3052e65/raw/setup-models.ps1" -OutFile "setup-models.ps1"
#>

# === CONFIGURACOES GLOBAIS ===
$script:modelConfig = $null
$script:driveLetter = $null
$script:paths = $null

# === CONFIGURACOES DOS MODELOS ===
# Tamanhos baseados no tamanho REAL dos arquivos no Hugging Face
$models = @(
    @{
        Id = "1"
        Name = "qwen2.5-coder-0.5b-instruct"
        DisplayName = "Qwen2.5-Coder 0.5B"
        File = "qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
        Url = "https://huggingface.co/bartowski/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-0.5B-Instruct-Q4_K_M.gguf"
        ExpectedSizeMB = 379  # Tamanho REAL do arquivo Q4_K_M
        SizeDesc = "379 MB"
        Description = "Modelo pequeno (0.5B), rápido para testes e desenvolvimento"
    },
    @{
        Id = "2"
        Name = "qwen2.5-3b-instruct"
        DisplayName = "Qwen2.5-3B Instruct"
        File = "Qwen2.5-3B-Instruct-Q4_K_M.gguf"
        Url = "https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf"
        ExpectedSizeMB = 1976
        SizeDesc = "1.93 GB"
        Description = "Recomendado: Melhor balanço entre velocidade e inteligência (6GB VRAM)"
    },
    @{
        Id = "3"
        Name = "deepseek-coder-6.7b-instruct"
        DisplayName = "deepseek-coder 6.7B"
        File = "deepseek-coder-6.7b-instruct-q4_k_m.gguf"
        Url = "https://huggingface.co/TheBloke/deepseek-coder-6.7B-instruct-GGUF/resolve/main/deepseek-coder-6.7b-instruct.Q4_K_M.gguf"
        ExpectedSizeMB = 4175  # Tamanho REAL do arquivo Q4_K_M
        SizeDesc = "4.08 GB"
        Description = "Modelo grande (6.7B), alta qualidade para produção"
    },
    @{
        Id = "4"
        Name = "qwen2.5-coder-7b-instruct"
        DisplayName = "Qwen2.5-Coder 7B"
        File = "qwen2.5-coder-7b-instruct-q4_k_m.gguf"
        Url = "https://huggingface.co/Triangle104/Qwen2.5-Coder-7B-Instruct-Q4_K_M-GGUF/resolve/main/qwen2.5-coder-7b-instruct-q4_k_m.gguf"
        ExpectedSizeMB = 4800  # Tamanho REAL do arquivo Q4_K_M (aproximadamente 4.68 GB)
        SizeDesc = "4.68 GB"
        Description = "Modelo grande (7B), alta qualidade para desenvolvimento avançado"
    }
)

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

function Select-Model {
    Write-Header "SELECAO DE MODELO"
    
    Write-Host "Escolha um modelo para baixar:`n" -ForegroundColor White
    
    foreach ($model in $models) {
        Write-Host "[$($model.Id)] $($model.DisplayName) - $($model.SizeDesc)"
        Write-Host "    $($model.Description)"
        Write-Host ""
    }
    
    do {
        $choice = Read-Host "Digite o numero do modelo (1-$($models.Count))"
        
        $selectedModel = $models | Where-Object { $_.Id -eq $choice }
        if ($selectedModel) {
            Write-Host ""
            Write-Host "OK: Modelo selecionado: $($selectedModel.DisplayName)" -ForegroundColor Green
            return $selectedModel
        }
        else {
            Write-Host "ERROR: Opcao invalida. Digite 1 a $($models.Count)." -ForegroundColor Red
        }
    } while ($true)
}

function Select-Drive {
    Write-Header "SELECAO DE DRIVE"
    
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
        File  = Join-Path $modelPath $script:modelConfig.File
        Drive = $Root
    }
}

function Check-ExistingFile {
    param(
        [string]$ModelPath,
        [string]$ExpectedFileName
    )
    
    $expectedLower = $ExpectedFileName.ToLower()
    
    $foundFiles = Get-ChildItem -Path $ModelPath -File | Where-Object {
        $_.Name.ToLower() -eq $expectedLower
    }
    
    if ($foundFiles.Count -eq 0) {
        return @{
            Exists = $false
            SizeMB = 0
            Complete = $false
            Reason = "Arquivo não encontrado"
            FilePath = Join-Path $ModelPath $ExpectedFileName
        }
    }
    
    $file = $foundFiles[0]
    $filePath = $file.FullName
    $sizeMB = [math]::Round($file.Length / 1MB, 2)
    $expectedSizeMB = $script:modelConfig.ExpectedSizeMB
    
    # Tolerância de 98% para acomodar pequenas variações de arredondamento
    # Ex: 379.38 MB >= 98% de 379 MB (371.42 MB) = ✅ Completo
    $isComplete = $sizeMB -ge ($expectedSizeMB * 0.98)
    
    # Calcular porcentagem real para mensagem mais clara
    $percentComplete = [math]::Round(($sizeMB / $expectedSizeMB) * 100, 1)
    
    $reason = if ($isComplete) {
        "Tamanho correto ($sizeMB MB = $percentComplete% de $expectedSizeMB MB)"
    } else {
        "Tamanho incompleto ($sizeMB MB = $percentComplete% de $expectedSizeMB MB)"
    }
    
    return @{
        Exists = $true
        SizeMB = $sizeMB
        ExpectedSizeMB = $expectedSizeMB
        PercentComplete = $percentComplete
        Complete = $isComplete
        Reason = $reason
        FilePath = $filePath
        FileName = $file.Name
    }
}

function Download-With-Aria2 {
    param(
        [string]$Url,
        [string]$ModelPath,
        [string]$ExpectedFileName,
        [int]$Connections = 16
    )
    
    $expectedSizeDesc = "$($script:modelConfig.ExpectedSizeMB) MB"
    
    Write-SubHeader "DOWNLOAD DO MODELO"
    Write-Host "Modelo: $($script:modelConfig.DisplayName)" -ForegroundColor Gray
    Write-Host "URL: $Url" -ForegroundColor Gray
    Write-Host "Destino: $ModelPath" -ForegroundColor Gray
    Write-Host "Arquivo esperado: $ExpectedFileName" -ForegroundColor Gray
    Write-Host "Tamanho esperado: $expectedSizeDesc" -ForegroundColor Gray
    Write-Host "Conexoes simultaneas: $Connections" -ForegroundColor Gray
    Write-Host "DICA: Resume automatico habilitado. Pode pausar com Ctrl+C e retomar depois." -ForegroundColor Cyan
    Write-Host ""
    
    $checkResult = Check-ExistingFile -ModelPath $ModelPath -ExpectedFileName $ExpectedFileName
    
    if ($checkResult.Exists) {
        if ($checkResult.Complete) {
            Write-Host "INFO: Arquivo ja existe e esta completo ($($checkResult.SizeMB) MB)" -ForegroundColor Green
            Write-Host "      Encontrado como: $($checkResult.FileName)" -ForegroundColor Gray
            Write-Host "      $($checkResult.Reason)" -ForegroundColor Gray
            Write-Host "      Pulando download." -ForegroundColor Gray
            
            if ($checkResult.FileName -ne $ExpectedFileName) {
                Write-Host "      Padronizando nome do arquivo para: $ExpectedFileName" -ForegroundColor Yellow
                Rename-Item -Path $checkResult.FilePath -NewName $ExpectedFileName -Force
            }
            
            return @{
                Success = $true
                FilePath = Join-Path $ModelPath $ExpectedFileName
            }
        }
        else {
            Write-Host "INFO: Arquivo parcial encontrado: $($checkResult.SizeMB) MB de $($checkResult.ExpectedSizeMB) MB" -ForegroundColor Yellow
            Write-Host "      Encontrado como: $($checkResult.FileName)" -ForegroundColor Yellow
            Write-Host "      $($checkResult.Reason)" -ForegroundColor Yellow
            Write-Host "      aria2c continuara de onde parou automaticamente." -ForegroundColor Gray
            Write-Host ""
        }
    }
    
    $aria2Args = @(
        $Url,
        "-d", $ModelPath,
        "-o", $ExpectedFileName,
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
            $finalCheck = Check-ExistingFile -ModelPath $ModelPath -ExpectedFileName $ExpectedFileName
            
            Write-Host ""
            if ($finalCheck.Complete) {
                Write-Host "OK: Download concluido!" -ForegroundColor Green
                Write-Host "Tamanho final: $($finalCheck.SizeMB) MB" -ForegroundColor Green
                
                if ($finalCheck.FileName -ne $ExpectedFileName) {
                    Write-Host "Padronizando nome do arquivo para: $ExpectedFileName" -ForegroundColor Yellow
                    Rename-Item -Path $finalCheck.FilePath -NewName $ExpectedFileName -Force
                }
                
                return @{
                    Success = $true
                    FilePath = Join-Path $ModelPath $ExpectedFileName
                }
            } else {
                Write-Warning "AVISO: Download concluido, mas arquivo parece incompleto ($($finalCheck.SizeMB) MB de $($finalCheck.ExpectedSizeMB) MB)"
                return @{
                    Success = $false
                    FilePath = $finalCheck.FilePath
                }
            }
        }
        else {
            Write-Error "ERROR: aria2c falhou com codigo: $($process.ExitCode)"
            return @{
                Success = $false
                FilePath = Join-Path $ModelPath $ExpectedFileName
            }
        }
    }
    catch {
        Write-Error "ERROR: Erro ao executar aria2c: $_"
        return @{
            Success = $false
            FilePath = Join-Path $ModelPath $ExpectedFileName
        }
    }
}

# === EXECUCAO PRINCIPAL ===
function Main {
    Write-Header "DOWNLOAD DE MODELOS LLM"
    
    Write-SubHeader "VERIFICANDO DEPENDENCIAS"
    if (!(Test-Aria2)) {
        Show-Aria2InstallGuide
    }
    Write-Host "OK: aria2c encontrado" -ForegroundColor Green
    
    $script:modelConfig = Select-Model
    
    $script:driveLetter = Select-Drive
    
    $script:paths = Setup-Directory -Root $script:driveLetter -ModelName $script:modelConfig.Name
    Write-Host "Caminho do modelo: $($script:paths.File)" -ForegroundColor Gray
    Write-Host ""
    
    $checkResult = Check-ExistingFile -ModelPath $script:paths.Model -ExpectedFileName $script:modelConfig.File
    
    if ($checkResult.Exists -and $checkResult.Complete) {
        $sizeDesc = "$($checkResult.SizeMB) MB"
        
        Write-Host "OK: Modelo ja existe e esta completo ($sizeDesc)." -ForegroundColor Green
        $redownload = Read-Host "Deseja baixar novamente? [y/N]"
        if ($redownload -notin @("Y", "y", "Sim", "sim")) {
            Write-Header "CONCLUIDO!"
            Write-Host "Modelo: $($script:paths.File)" -ForegroundColor Green
            Write-Host "DICA: Use este caminho no seu script do llama.cpp" -ForegroundColor Cyan
            return
        }
        Write-Host "INICIANDO: Novo download..." -ForegroundColor Yellow
    }
    
    $downloadResult = Download-With-Aria2 `
        -Url $script:modelConfig.Url `
        -ModelPath $script:paths.Model `
        -ExpectedFileName $script:modelConfig.File
    
    if (!$downloadResult.Success) {
        Write-Warning "AVISO: Download nao concluido. Execute novamente para retomar."
        exit 1
    }
    
    $file = Get-Item $downloadResult.FilePath
    $finalSizeDesc = "$([math]::Round($file.Length / 1MB, 2)) MB"
    
    Write-Header "DOWNLOAD CONCLUIDO!"
    Write-Host "Modelo: $($script:modelConfig.DisplayName)" -ForegroundColor Green
    Write-Host "Caminho: $($downloadResult.FilePath)" -ForegroundColor Green
    Write-Host "Tamanho: $finalSizeDesc" -ForegroundColor Green
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