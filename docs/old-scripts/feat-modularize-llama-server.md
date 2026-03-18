# feat: modularizar start-llama-server.ps1

## PASSO 1 — Criar branch

```bash
git checkout -b feat/modularize-llama-server
```

---

## Estrutura Final

```
llama-server/
│
├── start-llama-server.ps1       ← ponto de entrada (orquestra tudo)
│
├── config/
│   └── models.ps1               ← catálogo de modelos ($MODELS)
│
└── lib/
    ├── menu.ps1                 ← Show-ModelMenu
    ├── validation.ps1           ← Get-ValidNumber
    └── server.ps1               ← Build-ServerArgs, Wait-ServerReady
```

---

## PASSO 2 — Criar estrutura de diretórios

```bash
mkdir config
mkdir lib
```

---

## PASSO 3 — Criar: `config/models.ps1`

```powershell
# config/models.ps1
# Catalogo de modelos disponíveis para o llama-server
# Para adicionar um modelo: copie um bloco @{ } e ajuste os campos
# GpuLayers = 0  → CPU only
# GpuLayers > 0  → offload parcial/total para GPU

$MODELS = @(
    @{
        Name          = 'Qwen2.5 Coder 0.5B (rapido, leve)'
        Path          = 'C:\models-ai\qwen2.5-coder-0.5b-instruct\qwen2.5-coder-0.5b-instruct-q4_k_m.gguf'
        ID            = 'qwen2.5-coder-0.5b-instruct-q4_k_m.gguf'
        Context       = 16384
        Template      = 'chatml'
        DefaultTemp   = 0.4
        DefaultRepeat = 1.3
        GpuLayers     = 0
    },
    @{
        Name          = 'DeepSeek Coder 6.7B (mais capaz, mais lento)'
        Path          = 'C:\models-ai\deepseek-coder-6.7b-instruct\deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        ID            = 'deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        Context       = 16384
        Template      = 'deepseek-coder-chat-template.jinja'
        DefaultTemp   = 0.1
        DefaultRepeat = 1.1
        GpuLayers     = 0
    },
    @{
        Name          = 'Qwen2.5 3B Instruct (equilibrio velocidade/qualidade)'
        Path          = 'C:\models-ai\qwen2.5-3b-instruct\Qwen2.5-3B-Instruct-Q4_K_M.gguf'
        ID            = 'qwen2.5-3b-instruct-q4_k_m.gguf'
        Context       = 32768
        Template      = 'chatml'
        DefaultTemp   = 0.35
        DefaultRepeat = 1.2
        GpuLayers     = 0
    },
    @{
        Name          = 'Qwen2.5 Coder 7B (capaz, equilibrado)'
        Path          = 'C:\models-ai\qwen2.5-coder-7b-instruct\qwen2.5-coder-7b-instruct-q4_k_m.gguf'
        ID            = 'qwen2.5-coder-7b-instruct-q4_k_m.gguf'
        Context       = 32768
        Template      = 'chatml'
        DefaultTemp   = 0.3
        DefaultRepeat = 1.2
        GpuLayers     = 33      # offload total ~4.7 GB VRAM — reduza para 20 se OOM
    }
)
```

---

## PASSO 4 — Criar: `lib/menu.ps1`

```powershell
# lib/menu.ps1

function Show-ModelMenu {
    param([array]$Models)

    Write-Host ''
    Write-Host '╔══════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║       Selecao de Modelo llama.cpp        ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''

    for ($i = 0; $i -lt $Models.Count; $i++) {
        $m      = $Models[$i]
        $exists = Test-Path $m.Path
        $status = if ($exists) { '[OK]' } else { '[NAO ENCONTRADO]' }
        $color  = if ($exists) { 'White' } else { 'Red' }
        $gpu    = if ($m.GpuLayers -gt 0) { " | GPU: $($m.GpuLayers) layers" } else { ' | CPU only' }
        Write-Host "  [$($i + 1)] $($m.Name)" -ForegroundColor $color
        Write-Host "       $status$gpu" -ForegroundColor Gray
        Write-Host "       $($m.Path)" -ForegroundColor DarkGray
        Write-Host ''
    }

    $selected = $null
    do {
        $choice = Read-Host "Digite o numero do modelo (1-$($Models.Count))"
        $idx    = 0
        $parsed = [int]::TryParse($choice, [ref]$idx)

        if ($parsed -and $idx -ge 1 -and $idx -le $Models.Count) {
            $candidate = $Models[$idx - 1]
            if (Test-Path $candidate.Path) {
                $selected = $candidate
            } else {
                Write-Host 'ERROR: Arquivo do modelo nao encontrado. Escolha outro.' -ForegroundColor Red
            }
        } else {
            Write-Host "ERROR: Digite um numero entre 1 e $($Models.Count)." -ForegroundColor Red
        }
    } while ($null -eq $selected)

    return $selected
}
```

---

## PASSO 5 — Criar: `lib/validation.ps1`

```powershell
# lib/validation.ps1

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
    Write-Host "Range: $MinValue a $MaxValue  |  Padrao: $DefaultValue (Enter para usar)" -ForegroundColor Gray
    Write-Host 'Aceita ponto ou virgula como decimal' -ForegroundColor Gray
    Write-Host ''

    do {
        $raw = Read-Host $Prompt

        if ([string]::IsNullOrWhiteSpace($raw)) {
            Write-Host "Usando padrao: $DefaultValue" -ForegroundColor Green
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

        if ($ok -and $value -ge $MinValue -and $value -le $MaxValue) {
            $r = [math]::Round($value, $DecimalPlaces)
            Write-Host "Aceito: $r" -ForegroundColor Green
            return $r
        }

        Write-Host "ERROR: Valor invalido ou fora do range ($MinValue–$MaxValue)." -ForegroundColor Red
    } while ($true)
}
```

---

## PASSO 6 — Criar: `lib/server.ps1`

```powershell
# lib/server.ps1

function Build-ServerArgs {
    param(
        [hashtable]$Model,
        [double]$Temperature,
        [double]$RepeatPenalty,
        [string]$ApiHost,
        [int]$Port,
        [string]$ScriptRoot
    )

    $args = @(
        '-m',               $Model.Path,
        '--host',           $ApiHost,
        '--port',           $Port,
        '-c',               $Model.Context,
        '-t',               $([Environment]::ProcessorCount),
        '--log-disable',
        '--embedding',
        '--metrics',
        '--batch-size',     '512',
        '--ubatch-size',    '512',
        '--temp',           $Temperature.ToString('F2', [cultureinfo]::InvariantCulture),
        '--repeat-penalty', $RepeatPenalty.ToString('F2', [cultureinfo]::InvariantCulture)
    )

    # GPU offload
    if ($Model.GpuLayers -and $Model.GpuLayers -gt 0) {
        $args += '--n-gpu-layers', $Model.GpuLayers
        Write-Host "GPU offload ativo: $($Model.GpuLayers) camadas" -ForegroundColor Cyan
    }

    # Chat template
    if ($Model.Template -ne 'auto') {
        if ($Model.Template -like '*.jinja') {
            $tplPath = Join-Path $ScriptRoot $Model.Template
            if (!(Test-Path $tplPath)) {
                throw "Template Jinja nao encontrado: $tplPath"
            }
            $args += '--chat-template-file', $tplPath
        } else {
            $args += '--chat-template', $Model.Template
        }
    }

    return $args
}

function Wait-ServerReady {
    param(
        [int]$Port,
        [int]$TimeoutSec = 60
    )

    for ($i = 1; $i -le $TimeoutSec; $i++) {
        try {
            $r = Invoke-WebRequest "http://127.0.0.1:$Port/health" `
                -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
            if ($r.StatusCode -eq 200) { return $true }
        } catch {
            Write-Host "  Aguardando... ($i/$TimeoutSec)" -ForegroundColor Gray
            Start-Sleep -Seconds 1
        }
    }
    return $false
}
```

---

## PASSO 7 — Substituir: `start-llama-server.ps1`

```powershell
# start-llama-server.ps1
# Ponto de entrada — orquestra selecao de modelo, parametros e inicializacao

. "$PSScriptRoot\config\models.ps1"
. "$PSScriptRoot\lib\menu.ps1"
. "$PSScriptRoot\lib\validation.ps1"
. "$PSScriptRoot\lib\server.ps1"

# ============================================================================
# CONFIGURACOES GERAIS
# ============================================================================

$PORT     = 8080
$API_HOST = '0.0.0.0'
$LOG_FILE = "$env:TEMP\llama-server.log"

# ============================================================================
# SELECAO DO MODELO
# ============================================================================

$MODEL = Show-ModelMenu -Models $MODELS
Write-Host ''
Write-Host "Modelo selecionado: $($MODEL.Name)" -ForegroundColor Green

# ============================================================================
# PARAMETROS DE GERACAO
# ============================================================================

$TEMPERATURE = Get-ValidNumber `
    -Prompt       'Digite a temperatura' `
    -Description  'TEMPERATURA: Controla a criatividade/aleatoriedade das respostas.' `
    -MinValue     0.0 -MaxValue 2.0 `
    -DefaultValue $MODEL.DefaultTemp

$REPEAT_PENALTY = Get-ValidNumber `
    -Prompt       'Digite a penalidade de repeticao' `
    -Description  'REPEAT PENALTY: Evita repeticoes e loops de texto.' `
    -MinValue     1.0 -MaxValue 2.0 `
    -DefaultValue $MODEL.DefaultRepeat

# ============================================================================
# VERIFICACOES PREVIAS
# ============================================================================

if (!(Get-Command 'llama-server.exe' -ErrorAction SilentlyContinue)) {
    Write-Error 'llama-server.exe nao encontrado no PATH do sistema'
    Write-Host  'Adicione o diretorio do llama.cpp ao PATH e tente novamente.'
    exit 1
}

# ============================================================================
# INICIO DO SERVIDOR
# ============================================================================

Write-Host ''
Write-Host 'Iniciando API llama.cpp...'
Write-Host "Modelo:    $($MODEL.Path)"
Write-Host "API:       http://$API_HOST`:$PORT/v1"
Write-Host "Log:       $LOG_FILE"
Write-Host ''

$serverArgs = Build-ServerArgs `
    -Model         $MODEL `
    -Temperature   $TEMPERATURE `
    -RepeatPenalty $REPEAT_PENALTY `
    -ApiHost       $API_HOST `
    -Port          $PORT `
    -ScriptRoot    $PSScriptRoot

$process = Start-Process 'llama-server.exe' `
    -ArgumentList $serverArgs `
    -NoNewWindow -PassThru `
    -RedirectStandardError $LOG_FILE

Write-Host "Processo iniciado (PID: $($process.Id))"
Write-Host 'Aguardando servidor ficar pronto (maximo 60 segundos)...'
Write-Host ''

# ============================================================================
# RESULTADO FINAL
# ============================================================================

if (Wait-ServerReady -Port $PORT) {
    Write-Host ''
    Write-Host '=== SERVIDOR PRONTO PARA USO ===' -ForegroundColor Green
    Write-Host ''
    Write-Host "Modelo ativo:     $($MODEL.Name)" -ForegroundColor Yellow
    Write-Host ''
    Write-Host 'Endpoints:'
    Write-Host "  Local:          http://127.0.0.1:$PORT/v1"
    Write-Host "  Rede local:     http://192.168.50.1:$PORT/v1"
    Write-Host "  Health:         http://127.0.0.1:$PORT/health"
    Write-Host "  Models:         http://127.0.0.1:$PORT/v1/models"
    Write-Host ''
    Write-Host 'Parametros:'
    Write-Host "  Temperature:    $TEMPERATURE"
    Write-Host "  Repeat Penalty: $REPEAT_PENALTY"
    if ($MODEL.GpuLayers -gt 0) {
        Write-Host "  GPU Layers:     $($MODEL.GpuLayers)" -ForegroundColor Cyan
    }
    Write-Host ''
    Write-Host 'Configuracao Cline (VS Code):'
    Write-Host "  API Provider:   OpenAI Compatible"
    Write-Host "  Base URL:       http://127.0.0.1:$PORT/v1"
    Write-Host '  API Key:        sk-no-key-required'
    Write-Host "  Model:          $($MODEL.ID)"
    Write-Host ''
    Write-Host 'Comandos uteis:'
    Write-Host '  Parar:    Get-Process llama-server | Stop-Process'
    Write-Host "  Logs:     Get-Content $LOG_FILE -Tail 50 -Wait"
    Write-Host "  Health:   curl http://127.0.0.1:$PORT/health"
} else {
    Write-Host ''
    Write-Host 'AVISO: Servidor nao respondeu no tempo esperado.' -ForegroundColor Yellow
    Write-Host "Log: Get-Content $LOG_FILE"
    Write-Host ''
    Write-Host 'Possiveis causas:'
    Write-Host "  - Porta $PORT em uso:   netstat -ano | findstr :$PORT"
    Write-Host '  - VRAM insuficiente:    reduza GpuLayers em config/models.ps1'
    Write-Host '  - DLL CUDA ausente:     verifique PATH do llama.cpp'
}

Pause
```

---

## PASSO 8 — Commit

```bash
git add config/models.ps1
git add lib/menu.ps1
git add lib/validation.ps1
git add lib/server.ps1
git add start-llama-server.ps1

git commit -m "feat: modularize start-llama-server into config and lib modules

- Extract \$MODELS catalog to config/models.ps1
- Extract Show-ModelMenu to lib/menu.ps1
- Extract Get-ValidNumber to lib/validation.ps1
- Extract Build-ServerArgs and Wait-ServerReady to lib/server.ps1
- Add GpuLayers field to all models (GPU offload support)
- Reduce start-llama-server.ps1 to orchestration only (~50 lines)"
```

---

## Referência de GPU Layers por Modelo

| Modelo | GpuLayers total | VRAM necessária |
|---|---|---|
| Qwen2.5 0.5B Q4_K_M | 24 | ~1 GB |
| Qwen2.5 3B Q4_K_M | 36 | ~2 GB |
| DeepSeek 6.7B Q4_K_M | 32 | ~4.2 GB |
| Qwen2.5 7B Q4_K_M | 33 | ~4.7 GB |

> Se ocorrer **OOM**, reduza `GpuLayers` em `config/models.ps1` e reinicie.
> Confirme o offload nos logs com:
> ```powershell
> Get-Content $env:TEMP\llama-server.log | Select-String "offloaded"
> # Esperado: offloaded 33/33 layers to GPU
> ```
