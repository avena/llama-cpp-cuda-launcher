# Estrutura do Projeto — LLaMA.cpp CUDA Tools

Este documento descreve a organização das pastas e arquivos do projeto **llama-cpp-cuda-launcher**, detalhando a responsabilidade de cada componente.

---

## 📂 Visão Geral do Diretório Raiz

A raiz do projeto contém scripts de ponto de entrada (entry points) e arquivos de configuração global.

| Arquivo / Pasta | Descrição |
| :--- | :--- |
| `start-llama-server.ps1` | Script principal para iniciar o servidor `llama.cpp` via menu interativo (Modularizado). |
| `setup-models.ps1` | Script interativo para baixar e organizar modelos GGUF via `aria2c`. |
| `run-test.ps1` | Script para executar testes de inferência e benchmark nos modelos ativos. |
| `load-env.ps1` | Carrega variáveis de ambiente do arquivo `.env`. |
| `README.md` | Documentação principal do projeto em português. |
| `.env.example` | Modelo para o arquivo de variáveis de ambiente. |

> Scripts de instalação e versões alternativas estão em `docs/old-scripts/`.

---

## 📂 Subdiretórios

### `lib/` (Biblioteca de Scripts)
Contém a lógica modularizada em PowerShell usada pelos scripts principais.

*   `LlamaServer.psm1`: Módulo PowerShell que agrega as funções de servidor.
*   `server.ps1`: Lógica de construção de argumentos e gerenciamento do processo `llama-server`.
*   `menu.ps1`: Interface de usuário via terminal (menus de seleção de modelos e parâmetros).
*   `validation.ps1`: Funções de validação de entrada de dados e verificação de saúde do sistema.

### `config/` (Configurações)
Centraliza as definições de modelos e templates de chat.

*   `models.ps1`: Catálogo de modelos suportados, caminhos de arquivos e parâmetros padrão (Contexto, GPU Layers, etc).
*   `chat-templates/`: Contém arquivos `.jinja` para formatação de prompts específica de cada modelo (ChatML, DeepSeek, etc).

### `tests/` (Suíte de Testes)
Ambiente para validação de performance e fidelidade dos modelos.

*   `test-qwen.ps1` / `test-deepseek-coder-6.7b.ps1`: Scripts específicos para validar cada família de modelos.
*   `_test-core.ps1`: Funções base para execução dos testes (Single Source of Truth).
*   `README.md`: Guia detalhado de como executar e adicionar novos testes.

#### `tests/Test-Module/` (Framework Interno)
Módulo avançado para automação de testes.
*   `Test-Module.psm1`: Ponto de entrada do módulo de testes.
*   `Invoke-AllTests.ps1`: Executa uma bateria de 5 testes de codificação (Fibonacci, Quicksort, etc).
*   `Invoke-TestCompletion.ps1`: Função principal que faz a chamada à API e mede métricas (tokens/s).
*   `CodePrompts.ps1`: Armazena a biblioteca de perguntas/prompts usados nos testes.
*   `Test-ServerHealth.ps1` & `Test-ModelsList.ps1`: Utilitários de verificação da API.

### `docs/` (Documentação)
Pasta destinada a relatórios técnicos e manuais do projeto.

*   `ESTRUTURA_DO_PROJETO.md`: Este relatório.

### `docs/old-scripts/` (Scripts Legados)
Scripts de uso histórico, versões alternativas e instaladores one-shot.
Não são entry points ativos — mantidos para referência.
- `start-llama-server-rtx4050.ps1`: Versão para RTX 4050 (substituída pelo script principal).
- `start-llama-server_qwen2.5-3b.ps1`: Versão legacy para Qwen2.5-3B.
- `setup_llama_cpp_*.ps1`: Instaladores do llama.cpp para diferentes versões de CUDA.
- `Set-PowerShell7AsDefault.ps1`: Script de configuração inicial do ambiente.
- `feat-modularize-llama-server.md`: Registro do progresso da modularização.

### `logs/`
Armazena logs de execução do servidor e resultados de benchmarks (ex: `test-all-*.txt`).

### `.continue/`
Configurações específicas para a extensão **Continue.dev** do VS Code.

### `.vscode/`
Configurações do ambiente de desenvolvimento (launch, tasks, settings) para VS Code.

---

## 🛠 Fluxo de Trabalho Típico

1.  **Instalação**: Execute os scripts de setup em `docs/old-scripts/` para configurar o ambiente.
2.  **Modelos**: Use `setup-models.ps1` na raiz para baixar os modelos desejados.
3.  **Execução**: Inicie o servidor com `start-llama-server.ps1`.
4.  **Uso**: Configure **Cline** ou **Continue.dev** para apontar para `http://127.0.0.1:8080/v1`.
5.  **Validação**: Use `run-test.ps1` para garantir que o modelo está respondendo corretamente.
