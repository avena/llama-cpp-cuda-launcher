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
$API_HOST = '127.0.0.1'
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
# HEALTH CHECK
# ============================================================================

$ready   = $false
$timeout = 60

for ($i = 1; $i -le $timeout; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri "http://$API_HOST`:$PORT/health" `
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
    Write-Host "  API OpenAI compativel: http://$API_HOST`:$PORT/v1"
    Write-Host "  Saude do servidor:     http://$API_HOST`:$PORT/health"
    Write-Host "  Lista de modelos:      http://$API_HOST`:$PORT/v1/models"
    Write-Host ''
    Write-Host 'Parametros de geracao aplicados:'
    Write-Host "  Temperature:      $TEMPERATURE"
    Write-Host "  Repeat Penalty:   $REPEAT_PENALTY"
    Write-Host ''
    Write-Host 'Configuracao para o Cline no VS Code:'
    Write-Host "  API Provider:     OpenAI Compatible"
    Write-Host "  Base URL:         http://$API_HOST`:$PORT/v1"
    Write-Host '  API Key:          sk-no-key-required'
    Write-Host "  Model:            $($MODEL.ID)"
    Write-Host '  Max Tokens:       512'
    Write-Host "  Temperature:      $TEMPERATURE"
    Write-Host ''
    Write-Host 'Comandos uteis:'
    Write-Host '  Parar servidor:   Get-Process llama-server | Stop-Process'
    Write-Host "  Ver logs:         Get-Content $LOG_FILE -Tail 50 -Wait"
    Write-Host "  Testar API:       curl http://$API_HOST`:$PORT/health"
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

# ============================================================================
# TABELA DE REFERENCIA: MODELOS DISPONIVEIS
# ============================================================================
#
# Modelo                         Params   VRAM min   Velocidade    Qualidade
# qwen2.5-coder-0.5b Q4_K_M     0.5B     ~1 GB      Muito rapida  Basica
# deepseek-coder-6.7b Q4_K_M    6.7B     ~5 GB      Moderada      Boa
#
# Use o Qwen 0.5B para:
#   - Completions simples, autocomplete, snippets rapidos
#   - Maquinas com pouca VRAM (iGPU, GPUs antigas)
#   - Testes rapidos de fluxo no Cline
#
# Use o DeepSeek 6.7B para:
#   - Tarefas mais complexas: refatoracao, arquitetura, debugging
#   - GPUs com 6GB+ VRAM (RTX 3060, 4060, etc.)
#   - Respostas mais coerentes em contextos longos
#
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
# Defaults deste script por modelo:
#   qwen2.5-coder-0.5b  -> 0.4  (modelos pequenos alucinam com valores altos)
#   deepseek-coder-6.7b -> 0.3  (mais conservador, respostas mais precisas)
#
# REPEAT PENALTY
# --------------
# Valor     Comportamento                       Quando Usar
# 1.0       Sem penalidade, pode repetir muito  Nao recomendado
# 1.1-1.3   Penalidade leve, evita loops        Uso geral, recomendado padrao
# 1.4-1.6   Penalidade moderada, mais variado   Quando houver repeticao excessiva
# > 1.7     Penalidade forte, pode prejudicar   Casos especificos graves
#
# Sintomas de repeat-penalty muito BAIXO:
#   - Texto repetitivo: wenwenwen, the the the
#   - Loops em geracao de codigo
#
# Sintomas de repeat-penalty muito ALTO:
#   - Texto desconexo, respostas curtas ou evasivas
#
# COMBINACOES RECOMENDADAS
# ------------------------
# Para programacao:    Temperature 0.2-0.4  |  Repeat Penalty 1.2-1.3
# Para conversas:      Temperature 0.4-0.6  |  Repeat Penalty 1.1-1.2
#
# Se o modelo travar em loops:
#   1. Aumente Repeat Penalty: 1.3 -> 1.4 -> 1.5
#   2. Reduza Temperature:     0.4 -> 0.3 -> 0.2
#   3. Verifique o chat-template: qwen para Qwen, deepseek para DeepSeek
#
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
# 3. SE O DEEPSEEK NAO CARREGAR (pouca VRAM):
#    - Reduza o contexto editando Context = 2048 no catalogo $MODELS
#    - Ou use o Qwen 0.5B como alternativa
#
# 4. ADICIONAR NOVOS MODELOS AO MENU:
#    - Adicione um bloco @{ } ao array $MODELS no topo do script
#    - Campos obrigatorios: Name, Path, ID, Context, Template, DefaultTemp
#    - Templates validos: qwen, deepseek, llama3, chatml, phi3, gemma
#
# 5. CONFIGURACAO DO CLINE POR MODELO:
#    - Base URL:    http://127.0.0.1:8080/v1  (igual para todos)
#    - API Key:     sk-no-key-required         (igual para todos)
#    - Model:       use o ID exato de /v1/models (muda por modelo)
#    - Max Tokens:  512 para 0.5B, pode usar 1024-2048 para 6.7B
#
#
# ============================================================================
# COMANDOS UTEIS PARA MANUTENCAO
# ============================================================================
#
# Verificar modelo ativo e status:
#   curl http://127.0.0.1:8080/health
#   curl http://127.0.0.1:8080/v1/models
#
# Testar geracao:
#   curl -X POST http://127.0.0.1:8080/v1/chat/completions
#   -H Content-Type: application/json
#   -d {model: deepseek-coder-6.7b-instruct-q4_k_m.gguf, messages:[{role:user,content:Ola!}]}
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
#
# ============================================================================
# SOLUCAO DE PROBLEMAS
# ============================================================================
#
# PROBLEMA: Model not found no Cline
# SOLUCAO:  Use exatamente o ID retornado por /v1/models, incluindo .gguf
#
# PROBLEMA: Menu mostra NAO ENCONTRADO para um modelo
# SOLUCAO:  Verifique o Path no array $MODELS e o nome exato do arquivo .gguf
#
# PROBLEMA: DeepSeek demora muito para carregar
# SOLUCAO:  Normal para 6.7B. Aguarde ou reduza Context para 2048 no $MODELS
#
# PROBLEMA: Respostas truncadas ou incompletas
# SOLUCAO:  Aumente Max Tokens no Cline (tente 1024 ou 2048)
#
# PROBLEMA: Servidor nao inicia, porta em uso
# SOLUCAO:  netstat -ano | findstr :8080 para achar o PID, depois taskkill /PID X /F
#
# PROBLEMA: Erros de CUDA/DLL nao encontrada
# SOLUCAO:  Verifique se o diretorio do llama.cpp esta no PATH do sistema
#
# PROBLEMA: Texto repetitivo ou loops no Qwen 0.5B
# SOLUCAO:  Aumente repeat-penalty para 1.4-1.5 e reduza temperature para 0.2-0.3
#
# PROBLEMA: DeepSeek com respostas incoerentes
# SOLUCAO:  Reduza temperature para 0.2, verifique --chat-template deepseek
#
# ============================================================================