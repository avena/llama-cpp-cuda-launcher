# load-env.ps1 — Função para carregar variáveis de ambiente a partir de arquivo .env

function Load-Env {
    param(
        [string]$EnvPath = ".env"
    )
    
    # Verifica se o arquivo .env existe
    if (Test-Path $EnvPath) {
        Write-Host "Carregando configurações de: $EnvPath" -ForegroundColor Cyan
        
        # Lê o arquivo .env linha por linha
        Get-Content $EnvPath | ForEach-Object {
            # Ignora linhas vazias e comentários
            if ($_.Trim() -ne "" -and $_.Trim() -notmatch "^#") {
                # Divide a linha em chave e valor
                $parts = $_ -split "=", 2
                if ($parts.Count -eq 2) {
                    $key = $parts[0].Trim()
                    $value = $parts[1].Trim()
                    
                    # Remove aspas se existirem
                    if ($value.StartsWith('"') -and $value.EndsWith('"')) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }
                    if ($value.StartsWith("'") -and $value.EndsWith("'")) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }
                    
                    # Define a variável de ambiente
                    [Environment]::SetEnvironmentVariable($key, $value, "Process")
                    Write-Host "  $key = $value" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Warning "Arquivo .env não encontrado em: $EnvPath"
        Write-Warning "Usando valores padrão do sistema"
    }
}

# Carrega o .env na raiz do projeto
Load-Env -EnvPath ".env"