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
        Template      = 'chatml'
        DefaultTemp   = 0.4
        DefaultRepeat = 1.3
        GpuLayers     = 0       # CPU only — modelo leve, nao precisa de GPU
    },
    @{
        Name          = 'DeepSeek Coder 6.7B (mais capaz, mais lento)'
        Path          = 'C:\models-ai\deepseek-coder-6.7b-instruct\deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        ID            = 'deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        Context       = 16384
        Template      = 'deepseek-coder-chat-template.jinja'
        DefaultTemp   = 0.1
        DefaultRepeat = 1.1
        GpuLayers     = 28      # opcional: ~4.2 GB VRAM se quiser offload
    },
    @{
        Name          = 'Qwen2.5 3B Instruct (equilibrio velocidade/qualidade)'
        Path          = 'C:\models-ai\qwen2.5-3b-instruct\Qwen2.5-3B-Instruct-Q4_K_M.gguf'
        ID            = 'qwen2.5-3b-instruct-q4_k_m.gguf'
        Context       = 32768
        Template      = 'chatml'
        DefaultTemp   = 0.35
        DefaultRepeat = 1.2
        GpuLayers     = 0       # CPU only — ~2 GB VRAM se quiser offload (use 36)
    },
    @{
        Name          = 'Qwen2.5 Coder 7B (capaz, equilibrado)'
        Path          = 'C:\models-ai\qwen2.5-coder-7b-instruct\qwen2.5-coder-7b-instruct-q4_k_m.gguf'
        ID            = 'qwen2.5-coder-7b-instruct-q4_k_m.gguf'
        Context       = 32768
        Template      = 'chatml'
        DefaultTemp   = 0.3
        DefaultRepeat = 1.2
        GpuLayers     = 33        # faz offload total para GPU (~4.7 GB VRAM)

    }
)

# ============================================================================
# TABELA DE REFERENCIA: MODELOS DISPONIVEIS
# ============================================================================
#
# Modelo                              Params  VRAM(Q4)  Contexto  Velocidade  Uso Recomendado
# qwen2.5-coder-0.5b Q4_K_M          0.5B    ~1 GB     16384     Muito rap.  Tarefas rapidas, baixo consumo
# qwen2.5-3b-instruct Q4_K_M         3B      ~2 GB     32768     Rapida      Equilibrio qualidade/velocidade
# deepseek-coder-6.7b Q4_K_M         6.7B    ~4.2 GB   16384     Moderada    Tarefas complexas, alta capacidade
# qwen2.5-coder-7b-instruct Q4_K_M   7B      ~4.7 GB   32768     Moderada    Maxima capacidade, codificacao avancada
#
# ============================================================================
# TABELA DE REFERENCIA: PARAMETROS DE GERACAO
# ============================================================================
#
# TEMPERATURA
# -----------
# Valor     Comportamento                       Quando Usar
# 0.0-0.3   Respostas deterministicas, focadas  Codigo, fatos, instrucoes precisas
# 0.4-0.6   Equilibrio foco/criatividade        Uso geral, assistente de programacao
# 0.7-1.0   Mais criativo, pode divagar         Brainstorming, texto criativo
# > 1.0     Muito aleatorio, imprevisivel       Experimental, nao recomendado
#
# REPEAT PENALTY
# --------------
# Valor     Comportamento                       Quando Usar
# 1.0       Sem penalidade, pode repetir muito  Nao recomendado
# 1.1-1.3   Penalidade leve, evita loops        Uso geral, recomendado padrao
# 1.4-1.6   Penalidade moderada, mais variado   Quando houver repeticao excessiva
# > 1.7     Penalidade forte, pode prejudicar   Casos especificos graves
#
# COMBINACOES RECOMENDADAS POR MODELO
# -----------------------------------
# Qwen2.5 Coder 0.5B:    Temperature 0.3-0.5  |  Repeat Penalty 1.2-1.3
# Qwen2.5 3B Instruct:   Temperature 0.3-0.4  |  Repeat Penalty 1.1-1.2
# DeepSeek Coder 6.7B:   Temperature 0.1-0.3  |  Repeat Penalty 1.1-1.2
# Qwen2.5 Coder 7B:      Temperature 0.2-0.4  |  Repeat Penalty 1.1-1.3
#
# ============================================================================
# DICAS DE USO
# ============================================================================
#
# 1. TROCAR DE MODELO SEM REINICIAR O CLINE:
#    - Pare o servidor:  Get-Process llama-server | Stop-Process
#    - Execute o script novamente e escolha outro modelo
#    - No Cline, atualize o campo Model com o novo ID
#
# 2. VERIFICAR QUAL MODELO ESTA ATIVO:
#    - Acesse: http://127.0.0.1:8080/v1/models
#    - O campo id mostra o nome exato do modelo carregado
#
# 3. SE O DEEPSEEK OU QWEN 7B NAO CARREGAR (OOM de VRAM):
#    - Reduza Context para 8192 ou 4096 no catalogo $MODELS
#    - Ou use o Qwen 3B ou 0.5B como alternativa
#
# 4. ADICIONAR NOVOS MODELOS AO MENU:
#    - Adicione um bloco @{ } ao array $MODELS no topo do script
#    - Campos obrigatorios: Name, Path, ID, Context, Template,
#                           DefaultTemp, DefaultRepeat
#    - Templates validos: qwen, chatml, deepseek, llama3, phi3, gemma
#
# ============================================================================
# COMANDOS UTEIS PARA MANUTENCAO
# ============================================================================
#
# Verificar modelo ativo e status:
#   curl http://127.0.0.1:8080/health
#   curl http://127.0.0.1:8080/v1/models
#
# Ver logs em tempo real:
#   Get-Content $env:TEMP\llama-server.log -Tail 20 -Wait
#
# Parar o servidor:
#   Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process
#
# Verificar processos na porta 8080:
#   netstat -ano | findstr :8080
#
# Liberar porta ocupada:
#   taskkill /PID <PID> /F
#
# ============================================================================
# SOLUCAO DE PROBLEMAS
# ============================================================================
#
# PROBLEMA: Model not found no Cline
# SOLUCAO:  Use exatamente o ID retornado por /v1/models, incluindo .gguf
#
# PROBLEMA: DeepSeek ou Qwen 7B demora muito para carregar
# SOLUCAO:  Normal para modelos maiores. Aguarde ou reduza Context no $MODELS
#
# PROBLEMA: Respostas truncadas ou incompletas
# SOLUCAO:  Aumente MaxTokens no catalogo $MODELS (tente 4096)
#
# PROBLEMA: Servidor nao inicia, porta em uso
# SOLUCAO:  netstat -ano | findstr :8080 para achar o PID, depois taskkill /PID X /F
#
# PROBLEMA: Erros de CUDA/DLL nao encontrada
# SOLUCAO:  Verifique se o diretorio do llama.cpp esta no PATH do sistema
#
# PROBLEMA: OOM / Out of Memory na GPU
# SOLUCAO:  Reduza Context no modelo (ex: 32768 -> 16384 -> 8192)
#           Ou use modelos menores (0.5B ou 3B)
#
# ============================================================================

# ============================================================================
# CONFIGURACOES GERAIS
# ============================================================================

$PORT = 8080
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
        $m = $script:MODELS[$i]
        $exists = Test-Path $m.Path
        $status = if ($exists) { '[OK]' } else { '[NAO ENCONTRADO]' }
        $color = if ($exists) { 'White' } else { 'Red' }
        $gpu = if ($m.GpuLayers -and $m.GpuLayers -gt 0) { " | GPU: $($m.GpuLayers) layers" } else { " | CPU only" }
        Write-Host "  [$($i + 1)] $($m.Name)" -ForegroundColor $color
        Write-Host "       $status  $($m.Path)$gpu" -ForegroundColor Gray
        Write-Host ''
    }

    $selected = $null
    do {
        $choice = Read-Host "Digite o numero do modelo (1-$($script:MODELS.Count))"
        $idx = 0
        $parsed = [int]::TryParse($choice, [ref]$idx)

        if ($parsed -and $idx -ge 1 -and $idx -le $script:MODELS.Count) {
            $candidate = $script:MODELS[$idx - 1]
            if (Test-Path $candidate.Path) {
                $selected = $candidate
            }
            else {
                Write-Host 'ERROR: Arquivo do modelo nao encontrado. Escolha outro.' -ForegroundColor Red
            }
        }
        else {
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

        $norm = $raw.Replace(',', '.')
        $value = 0.0
        $ok = [double]::TryParse(
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
            }
            else {
                Write-Host "ERROR: Valor fora do range. Digite entre $MinValue e $MaxValue." -ForegroundColor Red
            }
        }
        else {
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

# GPU offload — adicionar logo após o bloco $processArgs = @( ... )
if ($MODEL.GpuLayers -and $MODEL.GpuLayers -gt 0) {
    $processArgs += '--n-gpu-layers'
    $processArgs += $MODEL.GpuLayers
    Write-Host "GPU offload: $($MODEL.GpuLayers) camadas" -ForegroundColor Cyan
}


if ($MODEL.Template -ne 'auto') {
    if ($MODEL.Template -like '*.jinja') {
        $templatePath = Join-Path $PSScriptRoot $MODEL.Template
        if (!(Test-Path $templatePath)) {
            Write-Error "Arquivo de template nao encontrado: $templatePath"
            exit 1
        }
        $processArgs += '--chat-template-file'
        $processArgs += $templatePath
    }
    else {
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

$ready = $false
$timeout = 60

for ($i = 1; $i -le $timeout; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$PORT/health" `
            -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
        if ($resp.StatusCode -eq 200) {
            $ready = $true
            break
        }
    }
    catch {
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
    if ($MODEL.GpuLayers -and $MODEL.GpuLayers -gt 0) {
        Write-Host "  GPU Layers:       $($MODEL.GpuLayers) (offload ativo)" -ForegroundColor Cyan
    }
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
}
else {
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
