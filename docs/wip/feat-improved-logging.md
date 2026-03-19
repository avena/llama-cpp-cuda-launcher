# Feature: Estratégia de Log e Debug para llama-server

## 🎯 Objetivo

Melhorar a observabilidade do `start-llama-server.ps1` implementando uma estratégia de logging robusta, similar à utilizada no `run-test.ps1`. O objetivo é garantir que cada execução do servidor gere um arquivo de log único, identificável pelo modelo e horário, facilitando o diagnóstico de erros (como falhas de inicialização ou saídas corrompidas).

## Current State (Estado Atual)

Melhorar a observabilidade do `start-llama-server.ps1` implementando uma estratégia de logging robusta, similar à utilizada no `run-test.ps1`. O objetivo é garantir que cada execução do servidor gere um arquivo de log único, identificável pelo modelo e horário, facilitando o diagnóstico de erros (como falhas de inicialização ou saídas corrompidas).

## Current State (Estado Atual)

- O script `start-llama-server.ps1` define o arquivo de log **antes** de saber qual modelo será selecionado.
- Nome atual: `logs/llama-server_YYYY-MM-DD_HHmmss.log`.
- Problema: O nome é genérico. Se o usuário rodar vários testes, não dá para saber qual log pertence a qual modelo sem abrir o arquivo.
- Captura de erro: Usa `-RedirectStandardError`, mas não captura o `stdout` completo do processo do servidor.

## Inspiration from `run-test.ps1` (Inspiração do `run-test.ps1`)

O script `run-test.ps1` já implementa uma estratégia de logging mais avançada:

- **Nome Dinâmico:** Determina o modelo ativo (`$activeModel`) _antes_ de definir o arquivo de log.
- **Nome Semântico:** Cria o log com o nome do modelo e timestamp: `logs/test-all-[MODELO]-[TIMESTAMP].txt`.
- **Captura Completa:** Utiliza `Start-Transcript` para registrar todo o output do console (stdout e stderr).
- **Gerenciamento de Erros:** Inclui blocos `try/catch` e `Stop-Transcript` para garantir o fechamento correto do log.

## 🚀 Proposta de Solução (Target State)

Adaptar a estratégia de logging do `run-test.ps1` para o `start-llama-server.ps1`.

1.  **Nome Dinâmico para Logs:** O arquivo de log deve ser nomeado com base no modelo selecionado e no timestamp.
2.  **Captura Abrangente:** Utilizar `Start-Transcript` para registrar toda a saída do console durante a execução do servidor.
3.  **Tratamento de Erros Aprimorado:** Garantir que erros de inicialização sejam capturados e exibidos de forma clara.

## 📋 Etapas de Implementação

### Fase 1: Análise e Preparação

- [x] Mapear onde a variável `$LOG_FILE` é usada atualmente em `start-llama-server.ps1`. (Feito internamente)
- [x] Analisar o mecanismo de `Start-Process` vs `Start-Transcript` e como `run-test.ps1` os utiliza. (Feito internamente)

### Fase 2: Refatoração do Script (`start-llama-server.ps1`)

- [ ] **Passo 2.1: Mover Definição de Log:** Mover a criação de `$LOG_FILE` para _depois_ que o modelo é selecionado (após `Show-ModelMenu`).
- [ ] **Passo 2.2: Nome Dinâmico:** Construir o nome do log usando `$MODEL.ID` (limpo) e o timestamp, seguindo o padrão `logs/server-[MODELO]-[TIMESTAMP].log`.
  ```powershell
  $modelClean = $MODEL.ID -replace '\.gguf$', ''
  $timestamp = Get-Date -Format "dd-MM-yyyy_HH-mm-ss"
  $LOG_FILE = Join-Path $LOG_DIR "server-$modelClean-$timestamp.log"
  ```
- [ ] **Passo 2.3: Captura Abrangente:** Substituir `-RedirectStandardError $LOG_FILE` por `Start-Transcript -Path $LOG_FILE -Force`.
- [ ] **Passo 2.4: Gerenciar Transcript:** Garantir que `Stop-Transcript` seja chamado no final do script, nos blocos `try/catch` e em todas as saídas de erro.

### Fase 3: Melhoria de Debug (Feedback Imediato)

- [ ] Adicionar um bloco `try/catch` ao redor do `Start-Process` e `Wait-ServerReady`.
- [ ] Em caso de falha imediata, ler as últimas linhas do log recém-criado e exibi-las no console para um diagnóstico rápido.

### Fase 4: Validação

- [ ] Executar `start-llama-server.ps1` com um modelo.
- [ ] Verificar se o arquivo de log foi criado em `logs/` com o nome correto (modelo + timestamp).
- [ ] Inspecionar o conteúdo do log para confirmar se stdout e stderr foram capturados.
- [ ] Simular um erro (ex: modelo inexistente) e verificar se o feedback no console e o log são informativos.

## 📦 Benefícios Esperados

- **Rastreabilidade Aprimorada:** Logs claramente identificados pelo modelo e hora de execução.
- **Diagnóstico Rápido:** Facilidade para encontrar e analisar problemas.
- **Consistência:** Padrão de log alinhado com `run-test.ps1`.
- **Debug Facilitado:** Captura completa de saída e feedback imediato em caso de falha.
