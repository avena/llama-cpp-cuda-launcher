# test-deepseek.ps1
# Salva resultado em test-deepseek-result.txt na pasta do script
# Testa o DeepSeek em ambos os endpoints com dois prompts diferentes
# /completion        -> endpoint raw com template manual
# /v1/chat/completions -> endpoint OpenAI (usado pelo Cline)

$MODEL       = 'deepseek-coder-6.7b-instruct-q4_k_m.gguf'
$BASE_URL    = 'http://127.0.0.1:8080'
$TEMPERATURE = 0.1
$MAX_TOKENS  = 300
$RESULT_FILE = Join-Path $PSScriptRoot 'test-deepseek-result.txt'

# Limpa arquivo anterior
'' | Set-Content $RESULT_FILE

$PROMPTS = @(
    'Write a Python function to check if a number is prime.',
    'Write a Python function that receives a list of integers and returns only the even numbers.'
)

# ============================================================================

function Write-Output-Both {
    param([string]$Text, [string]$Color = 'White')
    Write-Host $Text -ForegroundColor $Color
    Add-Content -Path $script:RESULT_FILE -Value $Text
}

function Invoke-RawCompletion {
    param([string]$Prompt)

    $body = @{
        prompt      = "### Instruction:`n$Prompt`n### Response:`n"
        temperature = $TEMPERATURE
        n_predict   = $MAX_TOKENS
        stop        = @('### Instruction:', '### Response:')
    } | ConvertTo-Json -Depth 5

    $resp = Invoke-WebRequest -Uri "$BASE_URL/completion" `
        -Method POST `
        -Headers @{ 'Content-Type' = 'application/json' } `
        -Body $body `
        -UseBasicParsing

    return ($resp.Content | ConvertFrom-Json).content
}

function Invoke-ChatCompletion {
    param([string]$Prompt)

    $body = @{
        model       = $MODEL
        temperature = $TEMPERATURE
        max_tokens  = $MAX_TOKENS
        messages    = @(
            @{ role = 'user'; content = $Prompt }
        )
    } | ConvertTo-Json -Depth 5

    $resp = Invoke-WebRequest -Uri "$BASE_URL/v1/chat/completions" `
        -Method POST `
        -Headers @{ 'Content-Type' = 'application/json' } `
        -Body $body `
        -UseBasicParsing

    return ($resp.Content | ConvertFrom-Json).choices[0].message.content
}

# ============================================================================

$separator = '=' * 60

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
Write-Output-Both "Teste DeepSeek - $timestamp"
Write-Output-Both "Modelo: $MODEL  |  Temperature: $TEMPERATURE  |  Max Tokens: $MAX_TOKENS"

for ($i = 0; $i -lt $PROMPTS.Count; $i++) {
    $prompt = $PROMPTS[$i]
    $num    = $i + 1

    Write-Output-Both ''
    Write-Output-Both $separator 'DarkGray'
    Write-Output-Both "PROMPT $($num): $prompt" 'Yellow'
    Write-Output-Both $separator 'DarkGray'

    # --- /completion ---
    Write-Output-Both ''
    Write-Output-Both '[/completion - template manual]' 'Cyan'
    Write-Output-Both ''
    try {
        $out = Invoke-RawCompletion -Prompt $prompt
        Write-Output-Both $out
    } catch {
        Write-Output-Both "ERRO: $($_.Exception.Message)" 'Red'
    }

    # --- /v1/chat/completions ---
    Write-Output-Both ''
    Write-Output-Both '[/v1/chat/completions - template automatico]' 'Cyan'
    Write-Output-Both ''
    try {
        $out = Invoke-ChatCompletion -Prompt $prompt
        Write-Output-Both $out
    } catch {
        Write-Output-Both "ERRO: $($_.Exception.Message)" 'Red'
    }

    Write-Output-Both ''
}

Write-Output-Both $separator 'DarkGray'
Write-Output-Both 'Teste concluido.' 'Green'
Write-Output-Both ''
Write-Output-Both 'O que avaliar nas saidas:' 'Yellow'
Write-Output-Both '  - Ambos devem gerar codigo Python coerente e funcional'
Write-Output-Both '  - As saidas devem ser similares entre os dois endpoints'
Write-Output-Both '  - Se /completion ok mas /chat alucina: chat template errado'
Write-Output-Both '  - Se ambos alucinam: problema no modelo ou parametros'

Write-Host ''
Write-Host "Resultado salvo em: $RESULT_FILE" -ForegroundColor Green