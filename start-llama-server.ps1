# start-llama-server.ps1
# Inicia o servidor llama.cpp como API compativel com OpenAI para uso com Cline no VS Code

# ============================================================================
# CATALOGO DE MODELOS
# ============================================================================

$MODELS = @(
    @{
        Name          = 'Qwen2.5 Coder 0.5B (rapido, leve)'
        Path          = 'C:\models-ai\qwen2.5-coder-0.5b-instruct\qwen2.5-coder-0.5b-instruct-q4_k_m.gguf'
        ID            = 'qwen2.5-coder-0.5b-instruct-q4_k_m.gguf'
        Context       = 16384
        Template      = 'qwen'
        DefaultTemp   = 0.4
        DefaultRepeat = 1.3
    },
    @{
        Name          = 'DeepSeek Coder 6.7B (mais capaz, mais lento)'
        Path          = 'C:\models-ai\deepseek-coder-6.7b-instruct\deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        ID            = 'deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        Context       = 16384
        Template      = 'deepseek-coder-chat-template.jinja'
        DefaultTemp   = 0.1
        DefaultRepeat = 1.1
    }
)

# ============================================================================
# CONFIGURACOES GERAIS
# ============================================================================

$PORT     = 8080
$API_HOST = '0.0.0.0'   # escuta em todas as interfaces (local + rede)
$LOG_FILE = "$env:TEMP\llama-server.log"

# ============================================================================
# FUNCOES AUXILIARES
# ============================================================================

function Show-ModelMenu {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║       Selecao de Modelo llama.cpp        ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''

    for ($i = 0; $i -lt $script:MODELS.Count; $i++) {
        $m      = $script:MODELS[$i]
        $exists = Test-Path $m.Path
        $status = if ($exists) { '[OK]' } else { '[NAO ENCONTRADO]' }
        $color  = if ($exists) { 'White' } else { 'Red' }
        Write-Host "  [$($i + 1)] $($m.Name)" -ForegroundColor $color
        Write-Host "       $status  $($m.Path)" -ForegroundColor Gray
        Write-Host ''
    }

    $selected = $null
    do {
        $choice = Read-Host "Digite o numero do modelo (1-$($script:MODELS.Count))"
        $idx    = 0
        $parsed = [int]::TryParse($choice, [ref]$idx)

        if ($parsed -and $idx -ge 1 -and $idx -le $script:MODELS.Count) {
            $candidate = $script:MODELS[$idx - 1]
            if (Test-Path $candidate.Path) {
                $selected = $candidate
            } else {
                Write-Host 'ERROR: Arquivo do modelo nao encontrado. Escolha outro.' -ForegroundColor Red
            }
        } else {
            Write-Host "ERROR: Digite um numero entre 1 e $($script:MODELS.Count)." -ForegroundColor Red
        }
    } while ($null -eq $selected)

    return $selected
}

function Get-ValidNumber {
    param(
        [string]$Prompt,
        [string]$Description,
        [double]$MinValue,
        [double]$MaxValue,
        [double]$DefaultValue,
        [int]$DecimalPlaces = 2
    )

    Write-Host ''
    Write-Host $Description -ForegroundColor Cyan
    Write-Host "Range permitido: $MinValue a $MaxValue" -ForegroundColor Gray
    Write-Host "Valor padrao: $DefaultValue (pressione Enter para usar)" -ForegroundColor Gray
    Write-Host 'Aceita ponto ou virgula como decimal' -ForegroundColor Gray
    Write-Host ''

    do {
        $raw = Read-Host $Prompt

        if ([string]::IsNullOrWhiteSpace($raw)) {
            Write-Host "Usando valor padrao: $DefaultValue" -ForegroundColor Green
            return $DefaultValue
        }

        $norm  = $raw.Replace(',', '.')
        $value = 0.0
        $ok    = [double]::TryParse(
            $norm,
            [System.Globalization.NumberStyles]::Any,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$value
        )

        if ($ok) {
            if ($value -ge $MinValue -and $value -le $MaxValue) {
                $r = [math]::Round($value, $DecimalPlaces)
                Write-Host "Valor aceito: $r" -ForegroundColor Green
                return $r
            } else {
                Write-Host "ERROR: Valor fora do range. Digite entre $MinValue e $MaxValue." -ForegroundColor Red
            }
        } else {
            Write-Host 'ERROR: Digite um numero valido.' -ForegroundColor Red
        }
    } while ($true)
}

# ============================================================================
# SELECAO DO MODELO
# ============================================================================

$MODEL = Show-ModelMenu

Write-Host ''
Write-Host "Modelo selecionado: $($MODEL.Name)" -ForegroundColor Green
Write-Host ''

# ============================================================================
# PARAMETROS DE GERACAO
# ============================================================================

Write-Host 'Configuracao de Parametros de Geracao' -ForegroundColor Cyan
Write-Host '======================================' -ForegroundColor Cyan

$TEMPERATURE = Get-ValidNumber `
    -Prompt 'Digite a temperatura' `
    -Description 'TEMPERATURA: Controla a criatividade/aleatoriedade das respostas.' `
    -MinValue 0.0 `
    -MaxValue 2.0 `
    -DefaultValue $MODEL.DefaultTemp `
    -DecimalPlaces 2

$REPEAT_PENALTY = Get-ValidNumber `
    -Prompt 'Digite a penalidade de repeticao' `
    -Description 'REPEAT PENALTY: Evita repeticoes e loops de texto.' `
    -MinValue 1.0 `
    -MaxValue 2.0 `
    -DefaultValue $MODEL.DefaultRepeat `
    -DecimalPlaces 2

# ============================================================================
# VERIFICACOES PREVIAS
# ============================================================================

if (!(Get-Command 'llama-server.exe' -ErrorAction SilentlyContinue)) {
    Write-Error 'llama-server.exe nao encontrado no PATH do sistema'
    Write-Host 'Adicione o diretorio do llama.cpp ao PATH e tente novamente.'
    exit 1
}

# ============================================================================
# INICIO DO SERVIDOR
# ============================================================================

Write-Host ''
Write-Host 'Iniciando API llama.cpp para Cline...'
Write-Host "Modelo: $($MODEL.Path)"
Write-Host "ID do modelo para Cline: $($MODEL.ID)"
Write-Host "Endpoint da API: http://$API_HOST`:$PORT/v1"
Write-Host "Endpoint de saude: http://$API_HOST`:$PORT/health"
Write-Host "Acesso pela rede local: http://192.168.50.1:$PORT/v1"
Write-Host "Arquivo de log: $LOG_FILE"
Write-Host ''

$processArgs = @(
    '-m', $MODEL.Path,
    '--host', $API_HOST,
    '--port', $PORT,
    '-c', $MODEL.Context,
    '-t', $([Environment]::ProcessorCount),
    '--log-disable',
    '--embedding',
    '--metrics',
    '--batch-size', '512',
    '--ubatch-size', '512',
    '--temp', $TEMPERATURE.ToString('F2', [System.Globalization.CultureInfo]::InvariantCulture),
    '--repeat-penalty', $REPEAT_PENALTY.ToString('F2', [System.Globalization.CultureInfo]::InvariantCulture)
)

if ($MODEL.Template -ne 'auto') {
    if ($MODEL.Template -like '*.jinja') {
        $templatePath = Join-Path $PSScriptRoot $MODEL.Template
        if (!(Test-Path $templatePath)) {
            Write-Error "Arquivo de template nao encontrado: $templatePath"
            exit 1
        }
        $processArgs += '--chat-template-file'
        $processArgs += $templatePath
    } else {
        $processArgs += '--chat-template'
        $processArgs += $MODEL.Template
    }
}

$process = Start-Process -FilePath 'llama-server.exe' `
    -ArgumentList $processArgs `
    -NoNewWindow `
    -PassThru `
    -RedirectStandardError $LOG_FILE

Write-Host "Processo iniciado (PID: $($process.Id))"
Write-Host 'Aguardando servidor ficar pronto (maximo 60 segundos)...'
Write-Host ''

# ============================================================================
# HEALTH CHECK — usa 127.0.0.1 localmente mesmo com host 0.0.0.0
# ============================================================================

$ready   = $false
$timeout = 60

for ($i = 1; $i -le $timeout; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$PORT/health" `
            -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        Write-Host "  Aguardando... ($i/$timeout)" -ForegroundColor Gray
        Start-Sleep -Seconds 1
    }
}

# ============================================================================
# SAIDA FINAL
# ============================================================================

if ($ready) {
    Write-Host ''
    Write-Host '=== SERVIDOR PRONTO PARA USO ===' -ForegroundColor Green
    Write-Host ''
    Write-Host "Modelo ativo: $($MODEL.Name)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Endpoints disponiveis:'
    Write-Host "  Local:              http://127.0.0.1:$PORT/v1"
    Write-Host "  Rede local:         http://192.168.50.1:$PORT/v1"
    Write-Host "  Saude do servidor:  http://127.0.0.1:$PORT/health"
    Write-Host "  Lista de modelos:   http://127.0.0.1:$PORT/v1/models"
    Write-Host ''
    Write-Host 'Parametros de geracao aplicados:'
    Write-Host "  Temperature:      $TEMPERATURE"
    Write-Host "  Repeat Penalty:   $REPEAT_PENALTY"
    Write-Host ''
    Write-Host 'Configuracao para o Cline no VS Code:'
    Write-Host "  API Provider:     OpenAI Compatible"
    Write-Host "  Base URL:         http://127.0.0.1:$PORT/v1"
    Write-Host '  API Key:          sk-no-key-required'
    Write-Host "  Model:            $($MODEL.ID)"
    Write-Host '  Max Tokens:       512'
    Write-Host "  Temperature:      $TEMPERATURE"
    Write-Host ''
    Write-Host 'Comandos uteis:'
    Write-Host '  Parar servidor:   Get-Process llama-server | Stop-Process'
    Write-Host "  Ver logs:         Get-Content $LOG_FILE -Tail 50 -Wait"
    Write-Host "  Testar local:     curl http://127.0.0.1:$PORT/health"
    Write-Host "  Testar rede:      curl http://192.168.50.1:$PORT/health"
} else {
    Write-Host ''
    Write-Host 'AVISO: Servidor nao respondeu no tempo esperado.' -ForegroundColor Yellow
    Write-Host "Verifique o log: Get-Content $LOG_FILE"
    Write-Host ''
    Write-Host 'Possiveis causas:'
    Write-Host "  - Porta $PORT ja em uso (netstat -ano | findstr :$PORT)"
    Write-Host '  - Pouca VRAM para o modelo escolhido (tente o modelo menor)'
    Write-Host '  - DLLs do CUDA nao encontradas no PATH'
}

Pause
