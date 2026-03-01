# start-llama-server.ps1
# Responsabilidades:
#   - Ponto de entrada — orquestra seleção de modelo, parâmetros e inicialização
#   - Carrega configurações (config/models.ps1)
#   - Importa módulo de funções (lib/LlamaServer.psm1)
#   - Coordena fluxo: seleção → validação → início do servidor

# Carrega catálogo de modelos (dados)
. "$PSScriptRoot\config\models.ps1"

# Importa módulo de funções do servidor
Import-Module "$PSScriptRoot\lib\LlamaServer.psm1" -Force

# ============================================================================
# CONFIGURACOES GERAIS
# ============================================================================

$PORT = 8080
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
}
else {
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
