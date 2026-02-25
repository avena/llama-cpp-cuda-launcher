# start-llama-server-rtx.ps1
# Servidor llama.cpp otimizado para NVIDIA RTX 4050 (Ada Lovelace, 6 GB VRAM)
# Para uso com Cline no VS Code
#
# OTIMIZACOES vs script base (start-llama-server.ps1):
# ┌──────────────────────┬──────────────────────────────────────────────────────┐
# │ Parametro adicionado │ Motivo                                               │
# ├──────────────────────┼──────────────────────────────────────────────────────┤
# │ --n-gpu-layers 99    │ CAUSA RAIZ do ~20% GPU: sem isso = 0 camadas na GPU  │
# │ --flash-attn         │ Flash Attention: -40% VRAM no KV, +velocidade        │
# │ --cache-type-k q8_0  │ KV cache quantizado: -50% VRAM vs FP16               │
# │ --cache-type-v q8_0  │ Compativel com flash-attn no Ada Lovelace (cc 8.9)   │
# │ --batch-size 2048    │ Batches maiores = melhor throughput GPU no prompt     │
# │ --cont-batching      │ Batching continuo para requisicoes do Cline           │
# │ --parallel 1         │ 1 slot (Cline single-user); contexto nao desperdicado │
# │ -t 4 / -tb AllCores  │ GPU faz o pesado; CPU minimo em geracao               │
# └──────────────────────┴──────────────────────────────────────────────────────┘
#
# VRAM estimada por modelo (RTX 4050 6 GB):
#   Qwen 0.5B  Q4_K_M  ctx=16384 KV q8: ~0.4 GB modelo + ~0.4 GB KV  =  ~0.8 GB ✓
#   DeepSeek 6.7B Q4_K_M ctx=8192 KV q8: ~3.8 GB modelo + ~2.0 GB KV  = ~5.8 GB ✓
#   (ctx 16384 no DeepSeek excederia 6 GB -> context reduzido para 8192)

# ============================================================================
# CATALOGO DE MODELOS — configuracoes especificas para RTX 4050 6 GB
# ============================================================================

$MODELS = @(
    @{
        Name          = 'Qwen2.5 Coder 0.5B (rapido, leve)'
        Path          = 'C:\models-ai\qwen2.5-coder-0.5b-instruct\qwen2.5-coder-0.5b-instruct-q4_k_m.gguf'
        ID            = 'qwen2.5-coder-0.5b-instruct-q4_k_m.gguf'
        Context       = 16384   # ~0.4 GB modelo + ~0.4 GB KV q8 = ~0.8 GB total
        Template      = 'qwen'
        DefaultTemp   = 0.4
        DefaultRepeat = 1.3
        GPULayers     = 99      # Offload total: modelo pequeno, VRAM de sobra
        KVType        = 'q8_0'  # Alta qualidade, VRAM muito suficiente
        VramEst       = '~0.8 GB'
    },
    @{
        Name          = 'DeepSeek Coder 6.7B (mais capaz, mais lento)'
        Path          = 'C:\models-ai\deepseek-coder-6.7b-instruct\deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        ID            = 'deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        Context       = 8192    # 16384 estouraria 6 GB; 8192 com KV q8 = ~5.8 GB (seguro)
        Template      = 'deepseek-coder-chat-template.jinja'
        DefaultTemp   = 0.1
        DefaultRepeat = 1.1
        GPULayers     = 99      # Offload total: maximiza velocidade de geracao
        KVType        = 'q8_0'  # ~50% menos VRAM vs FP16; precisao praticamente igual
        VramEst       = '~5.8 GB'
    }
)

# ============================================================================
# CONFIGURACOES GERAIS
# ============================================================================

$PORT           = 8080
$API_HOST       = '0.0.0.0'    # escuta em todas as interfaces (local + rede)
$LOG_FILE       = "$env:TEMP\llama-server-rtx.log"

# --- Parametros de paralelismo (otimizados para GPU) ---
$BATCH_SIZE     = 2048          # batch logico: maior = melhor throughput de prompt na GPU
$UBATCH_SIZE    = 512           # micro-batch fisico para geracao token a token
$GEN_THREADS    = 4             # threads CPU para geracao (GPU faz o trabalho pesado)
$BATCH_THREADS  = $([Environment]::ProcessorCount)   # maximo de threads no prompt processing
$PARALLEL_SLOTS = 1             # slots paralelos: 1 para Cline (single-user)

# ============================================================================
# FUNCOES AUXILIARES
# ============================================================================

function Show-ModelMenu {
    Write-Host ''
    Write-Host '+------------------------------------------------------+' -ForegroundColor Cyan
    Write-Host '|    Selecao de Modelo  [llama.cpp :: RTX 4050 6 GB]   |' -ForegroundColor Cyan
    Write-Host '+------------------------------------------------------+' -ForegroundColor Cyan
    Write-Host ''

    for ($i = 0; $i -lt $script:MODELS.Count; $i++) {
        $m      = $script:MODELS[$i]
        $exists = Test-Path $m.Path
        $status = if ($exists) { '[OK]            ' } else { '[NAO ENCONTRADO]' }
        $color  = if ($exists) { 'White' } else { 'Red' }

        Write-Host "  [$($i + 1)] $($m.Name)" -ForegroundColor $color
        Write-Host "       $status $($m.Path)" -ForegroundColor Gray
        Write-Host "       GPU Layers : $($m.GPULayers)  |  Context : $($m.Context) tokens  |  KV Cache : $($m.KVType)  |  VRAM est. : $($m.VramEst)" -ForegroundColor DarkCyan
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
    Write-Host "Range permitido : $MinValue a $MaxValue" -ForegroundColor Gray
    Write-Host "Valor padrao    : $DefaultValue (pressione Enter para usar)" -ForegroundColor Gray
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

function Test-CudaBinary {
    Write-Host ''
    Write-Host 'Verificando suporte CUDA no binario...' -ForegroundColor Gray
    $info = & llama-server.exe --version 2>&1 | Out-String
    if ($info -match 'CUDA|cublas|cuda') {
        Write-Host '  CUDA detectado no binario llama-server.exe' -ForegroundColor Green
    } else {
        Write-Host '  AVISO: CUDA nao detectado no binario.' -ForegroundColor Yellow
        Write-Host '  Sem CUDA, --n-gpu-layers sera ignorado e tudo roda na CPU.' -ForegroundColor Yellow
        Write-Host '  Baixe a versao CUDA em: https://github.com/ggml-org/llama.cpp/releases' -ForegroundColor Gray
        Write-Host ''
        $confirm = Read-Host 'Continuar mesmo assim? (s/N)'
        if ($confirm -notmatch '^[sS]$') { exit 0 }
    }
}

# ============================================================================
# SELECAO DO MODELO
# ============================================================================

$MODEL = Show-ModelMenu

Write-Host ''
Write-Host "Modelo selecionado : $($MODEL.Name)" -ForegroundColor Green
Write-Host "VRAM estimada      : $($MODEL.VramEst) / 6 GB" -ForegroundColor DarkCyan
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
    Write-Error 'llama-server.exe nao encontrado no PATH do sistema.'
    Write-Host 'Adicione o diretorio do llama.cpp ao PATH e tente novamente.'
    exit 1
}

Test-CudaBinary

# ============================================================================
# INICIO DO SERVIDOR
# ============================================================================

Write-Host ''
Write-Host '+------------------------------------------------------+' -ForegroundColor Green
Write-Host '|         Iniciando API llama.cpp  [RTX 4050]          |' -ForegroundColor Green
Write-Host '+------------------------------------------------------+' -ForegroundColor Green
Write-Host ''
Write-Host "Modelo       : $($MODEL.Path)"
Write-Host "ID p/ Cline  : $($MODEL.ID)"
Write-Host "Endpoint     : http://$API_HOST`:$PORT/v1"
Write-Host "Log          : $LOG_FILE"
Write-Host ''
Write-Host 'Otimizacoes RTX 4050 ativas:' -ForegroundColor Cyan
Write-Host "  --n-gpu-layers $($MODEL.GPULayers)  -> offload TOTAL do modelo para a GPU"
Write-Host "  --flash-attn             -> Flash Attention ativo (Ada Lovelace suportado)"
Write-Host "  --cache-type-k/v q8_0   -> KV cache quantizado em 8 bits (-50% VRAM vs FP16)"
Write-Host "  --batch-size $BATCH_SIZE         -> batch logico maior para melhor throughput de prompt"
Write-Host "  --cont-batching          -> batching continuo para requisicoes do Cline"
Write-Host "  --parallel $PARALLEL_SLOTS               -> 1 slot (Cline single-user)"
Write-Host "  -t $GEN_THREADS / -tb $BATCH_THREADS        -> CPU minimo em geracao / maximo no prompt"
Write-Host ''

$processArgs = @(
    # --- Modelo ---
    '-m',               $MODEL.Path,

    # --- Rede ---
    '--host',           $API_HOST,
    '--port',           $PORT,

    # --- Contexto ---
    '-c',               $MODEL.Context,

    # --- GPU: offload total das camadas ---
    '--n-gpu-layers',   $MODEL.GPULayers,

    # --- Flash Attention (requer CUDA compute capability >= 8.0; RTX 4050 = 8.9) ---
    '--flash-attn',

    # --- KV cache quantizado: economiza ~50% VRAM vs FP16, precisao proxima ao original ---
    '--cache-type-k',   $MODEL.KVType,
    '--cache-type-v',   $MODEL.KVType,

    # --- Batching: batch maior = melhor utilizacao dos Tensor Cores na GPU ---
    '--batch-size',     $BATCH_SIZE,
    '--ubatch-size',    $UBATCH_SIZE,

    # --- Paralelismo: batching continuo + 1 slot para Cline ---
    '--parallel',       $PARALLEL_SLOTS,
    '--cont-batching',

    # --- Threads: poucos para geracao (GPU domina), todos no prompt processing ---
    '-t',               $GEN_THREADS,
    '-tb',              $BATCH_THREADS,

    # --- Parametros de geracao ---
    '--temp',           $TEMPERATURE.ToString('F2', [System.Globalization.CultureInfo]::InvariantCulture),
    '--repeat-penalty', $REPEAT_PENALTY.ToString('F2', [System.Globalization.CultureInfo]::InvariantCulture),

    # --- Recursos extras ---
    '--embedding',
    '--metrics',
    '--log-disable'
)

# --- Template de chat ---
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
Write-Host 'Aguardando servidor ficar pronto (maximo 90 segundos)...'
Write-Host ''

# ============================================================================
# HEALTH CHECK — usa 127.0.0.1 localmente mesmo com host 0.0.0.0
# ============================================================================

$ready   = $false
$timeout = 90   # modelos maiores levam mais tempo para carregar layers na GPU

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
    Write-Host '+------------------------------------------------------+' -ForegroundColor Green
    Write-Host '|          SERVIDOR PRONTO  --  RTX 4050               |' -ForegroundColor Green
    Write-Host '+------------------------------------------------------+' -ForegroundColor Green
    Write-Host ''
    Write-Host "Modelo ativo  : $($MODEL.Name)" -ForegroundColor Yellow
    Write-Host "VRAM em uso   : $($MODEL.VramEst) (estimado)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Endpoints disponíveis:'
    Write-Host "  Local              : http://127.0.0.1:$PORT/v1"
    Write-Host "  Rede local         : http://192.168.50.1:$PORT/v1"
    Write-Host "  Saude do servidor  : http://127.0.0.1:$PORT/health"
    Write-Host "  Lista de modelos   : http://127.0.0.1:$PORT/v1/models"
    Write-Host "  Metricas (Prometheus): http://127.0.0.1:$PORT/metrics"
    Write-Host ''
    Write-Host 'Parametros de geracao aplicados:'
    Write-Host "  Temperature    : $TEMPERATURE"
    Write-Host "  Repeat Penalty : $REPEAT_PENALTY"
    Write-Host ''
    Write-Host 'Otimizacoes RTX 4050 confirmadas:' -ForegroundColor Cyan
    Write-Host "  GPU Layers     : $($MODEL.GPULayers) camadas na RTX 4050"
    Write-Host "  Flash Attention: ATIVO"
    Write-Host "  KV Cache       : $($MODEL.KVType) (quantizado)"
    Write-Host "  Batch size     : $BATCH_SIZE (prompt) / $UBATCH_SIZE (geracao)"
    Write-Host "  Cont. Batching : ATIVO"
    Write-Host "  CPU Threads    : gen=$GEN_THREADS / batch=$BATCH_THREADS"
    Write-Host ''
    Write-Host 'Configuracao para o Cline no VS Code:' -ForegroundColor Cyan
    Write-Host "  API Provider   : OpenAI Compatible"
    Write-Host "  Base URL       : http://127.0.0.1:$PORT/v1"
    Write-Host '  API Key        : sk-no-key-required'
    Write-Host "  Model          : $($MODEL.ID)"
    Write-Host '  Max Tokens     : 512'
    Write-Host "  Temperature    : $TEMPERATURE"
    Write-Host ''
    Write-Host 'Monitoramento GPU (RTX 4050):' -ForegroundColor Cyan
    Write-Host '  GPU em tempo real  : nvidia-smi -l 1'
    Write-Host '  Uso detalhado      : nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.free --format=csv -l 2'
    Write-Host "  Metricas llama.cpp : curl http://127.0.0.1:$PORT/metrics"
    Write-Host "  Logs ao vivo       : Get-Content $LOG_FILE -Tail 50 -Wait"
    Write-Host ''
    Write-Host 'Comandos uteis:'
    Write-Host '  Parar servidor : Get-Process llama-server | Stop-Process'
    Write-Host "  Testar local   : curl http://127.0.0.1:$PORT/health"
    Write-Host "  Testar rede    : curl http://192.168.50.1:$PORT/health"
} else {
    Write-Host ''
    Write-Host 'AVISO: Servidor nao respondeu no tempo esperado.' -ForegroundColor Yellow
    Write-Host "Verifique o log: Get-Content $LOG_FILE -Tail 50"
    Write-Host ''
    Write-Host 'Possiveis causas (RTX 4050):' -ForegroundColor Yellow
    Write-Host "  - Porta $PORT em uso         : netstat -ano | findstr :$PORT"
    Write-Host '  - VRAM insuficiente          : Reduza Context no catalogo ou mude KVType para q4_0'
    Write-Host '  - Binario sem CUDA           : Baixe versao CUDA do llama.cpp no GitHub Releases'
    Write-Host '  - DLLs CUDA ausentes no PATH : Verifique instalacao do CUDA Toolkit / cuBLAS'
    Write-Host '  - Flash-attn incompativel    : Remova --flash-attn do processArgs e tente novamente'
    Write-Host '  - KV cache incompativel      : Remova --cache-type-k/v e tente sem quantizacao KV'
}

Pause
