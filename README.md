# LLaMA.cpp CUDA Tools – Execute Modelos de Linguagem Localmente com GPU NVIDIA

Conjunto completo de scripts PowerShell para Windows que automatiza a instalação do **llama.cpp** com aceleração CUDA, download de modelos GGUF do Hugging Face e inicialização de um servidor compatível com a API OpenAI para integração com extensões como **Cline** e **Continue.dev** no VS Code.

## Visão Geral

Este projeto é construído sobre **quatro pilares fundamentais**:

1. **llama.cpp + CUDA 12.4** - Inferência de modelos locais com aceleração de GPU NVIDIA
2. **Modelos GGUF** - Modelos otimizados e quantizados (DeepSeek Coder, Qwen2.5-Coder)
3. **API OpenAI compatível** - Servidor que expõe a mesma interface que a OpenAI
4. **Integração com IDEs** - Uso direto via Cline ou Continue.dev no VS Code

### Opções de Integração

- **Cline** - Extensão popular focada em assistência de código
- **Continue.dev** - Alternativa moderna com suporte nativo para llama.cpp local (recomendado para máquinas com VRAM limitada)
- **Interface Web** - Chat direto em http://127.0.0.1:8080/

### Fluxo Rápido (Workflow)

```
1. setup_llama_cpp_cuda124.ps1 ─→ Instala binários + DLLs CUDA
          ↓
2. setup-models.ps1 ─→ Baixa modelo (Qwen2.5 ou DeepSeek)
          ↓
3. start-llama-server.ps1 ─→ Inicia servidor (porta 8080)
          ↓
4. Cline (VS Code) ─→ Conecta com Base URL: http://127.0.0.1:8080/v1
          ↓
5. test-deepseek.ps1 ─→ (Opcional) Valida funcionamento
```



## Pré-requisitos

- **Windows 10/11** com PowerShell 5.1+
- **GPU NVIDIA** com suporte a CUDA 12.4 (RTX 3090, RTX 4090, etc.)
- **NVIDIA CUDA Toolkit 12.4** instalado
- **Git** (opcional, para clonar o repositório)
- **aria2c** (recomendado para downloads mais rápidos): `winget install aria2.aria2`
- Mínimo **8GB de VRAM** (recomendado 16GB+ para modelos maiores)
- Espaço em disco: ~5GB para llama.cpp + modelos

---

## Scripts Incluídos

### 1. **setup_llama_cpp_cuda124.ps1**
**Configuração do llama.cpp com CUDA 12.4 (Download Padrão)**

Instala o compilado binário do **llama.cpp** com suporte a CUDA 12.4 e as DLLs do NVIDIA CUDA Runtime necessárias para executar modelos com aceleração de GPU.

**O que faz:**
- Download do `llama-b8083-bin-win-cuda-12.4-x64.zip` (binários pré-compilados)
- Download do `cudart-llama-bin-win-cuda-12.4-x64.zip` (DLLs do CUDA Runtime)
- Detecta automaticamente a pasta **Downloads** do usuário
- Permite escolher o disco de instalação (C:, D:, E:, etc.)
- Extrai os arquivos para `[DISCO]:\llama-cpp-cuda124`
- Verifica e valida a instalação

**Uso:**
```powershell
powershell -ExecutionPolicy Bypass -File .\setup_llama_cpp_cuda124.ps1
```

**Saída esperada:**
```
Em qual disco deseja instalar? (Ex: C, D): C
OK - llama-b8083-bin-win-cuda-12.4-x64.zip baixado
OK - cudart-llama-bin-win-cuda-12.4-x64.zip baixado
OK - Instalação completa em C:\llama-cpp-cuda124
```

---

### 2. **setup_llama_cpp_cuda124_aria2c.ps1**
**Configuração do llama.cpp com CUDA 12.4 (Download via aria2c)**

Mesme funcionalidade do script anterior, mas utiliza **aria2c** para downloads paralelos e resumíveis (mais rápido para conexões instáveis ou downloads grandes).

**O que faz:**
- Verifica se aria2c está instalado
- Download paralelo dos binários usando aria2c
- Download paralelo das DLLs do CUDA Runtime
- Suporte a resumo automático se o download for interrompido
- Mesma instalação e validação que o script padrão

**Diferenças principais:**
- **Mais rápido**: Downloads paralelos com até 4 conexões simultâneas
- **Mais robusto**: Resume downloads interrompidos automaticamente
- **Requer aria2c**: Execute `winget install aria2.aria2` antes

**Uso:**
```powershell
winget install aria2.aria2  # Se não tiver instalado
powershell -ExecutionPolicy Bypass -File .\setup_llama_cpp_cuda124_aria2c.ps1
```

---

### 3. **setup-models.ps1**
**Download Inteligente de Modelos GGUF**

Script interativo que permite escolher e baixar modelos de linguagem otimizados no formato GGUF da comunidade Hugging Face.

**Modelos disponíveis:**

| Modelo | Tamanho | Velocidade | Capacidade | Ideal para |
|--------|---------|-----------|-----------|-----------|
| **Qwen2.5-Coder-0.5B** | ~379 MB | Muito rápido | Básica | Testes, prototipagem rápida |
| **DeepSeek-Coder-6.7B** | ~4.08 GB | Moderado | Avançada | Produção, tarefas complexas |

**O que faz:**
- Menu interativo para seleção de modelo
- Escolha dinâmica de disco de instalação
- Verifica se o modelo já existe (case-insensitive)
- Download com resumo automático via aria2c
- Padroniza nomes para minúsculas
- Organiza em estrutura: `[DISCO]:\models-ai\[modelo]\[arquivo.gguf]`

**Uso:**
```powershell
powershell -ExecutionPolicy Bypass -File .\setup-models.ps1

# Selecione:
# [1] Qwen2.5-Coder-0.5B-Instruct (~379 MB)
# [2] DeepSeek-Coder-6.7B-Instruct (~4.08 GB)
# [3] Ambos
```

**Estrutura criada:**
```
C:\models-ai\
├── qwen2.5-coder-0.5b-instruct\
│   └── qwen2.5-coder-0.5b-instruct-q4_k_m.gguf
└── deepseek-coder-6.7b-instruct\
    └── deepseek-coder-6.7b-instruct-q4_k_m.gguf
```

---

### 4. **setup-deepseek-coder-6.7b-instruct.ps1**
**Download do DeepSeek Coder 6.7B**

Script simplificado que baixa diretamente o modelo **DeepSeek Coder 6.7B Instruct** (~4.08 GB) sem menu de seleção.

**O que faz:**
- Download direto do `deepseek-coder-6.7b-instruct-q4_k_m.gguf`
- Salva automaticamente em `C:\models-ai\deepseek-coder-6.7b-instruct\`
- Usa aria2c para download paralelo e resumível
- Verifica integridade do arquivo após download

**Uso:**
```powershell
powershell -ExecutionPolicy Bypass -File .\setup-deepseek-coder-6.7b-instruct.ps1
```

**Quando usar:**
- Quando você sabe que quer especificamente o DeepSeek
- Para automação ou CI/CD
- Para evitar prompts interativos

---

### 5. **setup-qwen2.5-coder-0.5b.ps1**
**Download do Qwen2.5 Coder 0.5B**

Script simplificado que baixa diretamente o modelo **Qwen2.5 Coder 0.5B Instruct** (~379 MB) sem menu de seleção.

**O que faz:**
- Download direto do `qwen2.5-coder-0.5b-instruct-q4_k_m.gguf`
- Salva automaticamente em `C:\models-ai\qwen2.5-coder-0.5b-instruct\`
- Usa aria2c para download paralelo e resumível
- Muito mais rápido que DeepSeek (ideal para testes)

**Uso:**
```powershell
powershell -ExecutionPolicy Bypass -File .\setup-qwen2.5-coder-0.5b.ps1
```

**Quando usar:**
- Testes rápidos e prototipagem
- Máquinas com VRAM limitada (< 8GB)
- Automação sem interação do usuário

---

### 6. **start-llama-server.ps1**
**Inicia o Servidor llama.cpp com API OpenAI compatível**

Script que inicializa um servidor HTTP rodando **llama-server** (parte do llama.cpp) expondo uma API idêntica à OpenAI.

**Onde fica o Context no script:**
```powershell
$MODELS = @(
    @{
        Name          = 'Qwen2.5 Coder 0.5B (rapido, leve)'
        Path          = 'C:\models-ai\qwen2.5-coder-0.5b-instruct\qwen2.5-coder-0.5b-instruct-q4_k_m.gguf'
        ID            = 'qwen2.5-coder-0.5b-instruct-q4_k_m.gguf'
        Context       = 16384  # ALTERE AQUI PARA OTIMIZAR (8192, 4096, etc)
        Template      = 'qwen'
        DefaultTemp   = 0.4
        DefaultRepeat = 1.3
    },
    @{
        Name          = 'DeepSeek Coder 6.7B (mais capaz, mais lento)'
        Path          = 'C:\models-ai\deepseek-coder-6.7b-instruct\deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        ID            = 'deepseek-coder-6.7b-instruct-q4_k_m.gguf'
        Context       = 16384  # ALTERE AQUI PARA OTIMIZAR (8192, 4096, etc)
        Template      = 'deepseek-coder-chat-template.jinja'
        DefaultTemp   = 0.1
        DefaultRepeat = 1.1
    }
)
```

**O que faz:**
- Menu interativo para seleção do modelo (Qwen2.5 ou DeepSeek)
- Valida se o modelo existe antes de iniciar
- Inicia `llama-server` na porta `8080`
- Suporta templates específicos por modelo:
  - **Qwen**: Template nativo do Qwen
  - **DeepSeek**: Template customizado (`deepseek-coder-chat-template.jinja`)
- Parametrizações dinâmicas:
  - Temperatura (controla criatividade)
  - Context window (tamanho do histórico)
  - Repeat penalty (evita repetição)
- Log do servidor em `%TEMP%\llama-server.log`

**Configurações por modelo:**

| Parametro | Qwen2.5 | DeepSeek |
|-----------|---------|----------|
| **Context Window** | 16384 tokens | 16384 tokens |
| Temperature Padrão | 0.4 | 0.1 |
| Repeat Penalty | 1.3 | 1.1 |
| Template | qwen | deepseek-coder-chat-template.jinja |

#### 📌 Entendendo o `Context Window` (16384 tokens)

**O que é:**
- Context Window é o tamanho máximo da "memória" do modelo
- 16384 tokens ≈ ~12.000 caracteres ou ~2.000 linhas de código
- Inclui: histórico da conversa + prompt + sua mensagem atual

**Por que é importante:**
- Maior context = Modelo lembra de mais contexto anterior
- Ideal para conversas longas ou análise de projetos grandes
- Menor context = Respostas mais rápidas, menos VRAM usado
- Se ultrapassar o limite, as mensagens antigas são descartadas

**Relação com Cline (VS Code):**
```
Context Window (16384) = Max Tokens TOTAL (histórico + resposta)
Max Tokens (Cline) = Tokens para APENAS a resposta
```

**Recomendações:**
- Deixe **Max Tokens no Cline em ~2048 a 4096**
- Assim sobra espaço para histórico: `16384 - 4096 = 12288 tokens para contexto anterior`

**Uso:**
```powershell
powershell -ExecutionPolicy Bypass -File .\start-llama-server.ps1

# Selecione:
# [1] Qwen2.5 Coder 0.5B (rápido, leve)
# [2] DeepSeek Coder 6.7B (mais capaz, mais lento)

# Output esperado:
# OK - Servidor iniciado em http://127.0.0.1:8080
# OK - Modelo: deepseek-coder-6.7b-instruct-q4_k_m.gguf
```

**Endpoints disponíveis:**
- `POST /completion` - Endpoint raw com template manual
- `POST /v1/chat/completions` - Endpoint OpenAI (usado pelo Cline)
- `GET /health` - Verificar status do servidor

**Interface Web de Chat:**

O servidor llama.cpp fornece uma **interface de chat web** interativa disponível em:

```
http://127.0.0.1:8080/
```

Você pode acessar pelo navegador enquanto o servidor está rodando. Esta interface permite:
- Chat interativo direto com o modelo
- Ajuste de parâmetros (temperatura, max tokens, etc.)
- Visualização de respostas em tempo real
- Teste completo do modelo sem precisar de Cline ou API

**Como acessar:**
1. Execute: `.\start-llama-server.ps1`
2. Abra no navegador: `http://127.0.0.1:8080/`
3. Comece a conversar com o modelo

---

### 7. **test-deepseek.ps1**
**Teste de Funcionalidade do Modelo DeepSeek**

Script de teste que valida se o servidor está funcionando corretamente, testando os dois endpoints principais com prompts reais.

**O que faz:**
- Testa **2 tarefas de programação** diferentes
- Usa **2 endpoints distintos**:
  1. `/completion` (endpoint raw com template manual)
  2. `/v1/chat/completions` (endpoint OpenAI - usado pelo Cline)
- Salva resultados em `test-deepseek-result.txt`
- Exibe progresso no console e no arquivo

**Prompts de teste:**
1. "Write a Python function to check if a number is prime."
2. "Write a Python function that receives a list of integers and returns only the even numbers."

**Configurações:**
- Temperatura: 0.1 (determinístico)
- Max tokens: 300 (limite de resposta)
- Modelo: deepseek-coder-6.7b-instruct

**Uso (com servidor rodando):**
```powershell
# Em outro terminal PowerShell:
powershell -ExecutionPolicy Bypass -File .\test-deepseek.ps1

# Saída em test-deepseek-result.txt:
# OK - /completion - Resposta 1: ...
# OK - /v1/chat/completions - Resposta 1: ...
# OK - /completion - Resposta 2: ...
# OK - /v1/chat/completions - Resposta 2: ...
```

---

### 8. **deepseek-coder-chat-template.jinja**
**Template Jinja2 para Format do DeepSeek Coder**

Template de formatação que adapta as mensagens do chat para o formato esperado pelo modelo DeepSeek Coder.

**O que faz:**
- Define o sistema de prompt padrão do DeepSeek
- Formata mensagens de usuário como `### Instruction:`
- Formata respostas como `### Response:`
- Garante alternância correta de papéis (user/assistant)
- Suporta system message customizada

**Conteúdo:**
```jinja
{{- bos_token }}
{%- if messages[0]['role'] == 'system' %}
    {%- set system_message = messages[0]['content'] %}
{%- else %}
    {%- set system_message = 'You are an AI programming assistant...' %}
{%- endif %}

{%- for message in loop_messages %}
    {%- if message['role'] == 'user' %}
        {{- '### Instruction:\n' + message['content'] + '\n' }}
    {%- elif message['role'] == 'assistant' %}
        {{- '### Response:\n' + message['content'] + '\n<|EOT|>\n' }}
    {%- endif %}
{%- endfor %}
```

**Usado por:**
- `start-llama-server.ps1` quando DeepSeek é selecionado
- Garante formatação correta das conversas no endpoint `/v1/chat/completions`

### 9. **.continue/continue.config.yaml**
**Configuração Pré-Configurada para Continue.dev**

Arquivo de configuração YAML que define automaticamente o servidor llama.cpp local para uso com a extensão Continue.dev no VS Code.

**O que faz:**
- Define o modelo DeepSeek Coder 6.7B como padrão
- Configura a URL do servidor local (`http://127.0.0.1:8080/v1`)
- Define a chave de API fictícia (não verificada)
- Pronta para uso sem edições adicionais

**Conteúdo:**
```yaml
name: DeepSeek Coder 6.7B
version: 1.0.0

models:
  - name: DeepSeek Coder Local
    provider: openai
    model: deepseek-coder-6.7b-instruct-q4_k_m.gguf
    apiBase: http://127.0.0.1:8080/v1
    apiKey: sk-no-key-required
```

**Como usar:**
1. Instale a extensão [Continue.dev](https://marketplace.visualstudio.com/items?itemName=Continue.continue)
2. Continue detecta automaticamente este arquivo ao abrir o workspace
3. Pronto para usar!

---

## Fluxo de Trabalho Recomendado

### Primeira Configuração (One-time setup):

1. **Instalar aria2c** (recomendado)
   ```powershell
   winget install aria2.aria2
   ```

2. **Instalar llama.cpp com CUDA** (escolha um):
   ```powershell
   # Opção 1: Download padrão
   .\setup_llama_cpp_cuda124.ps1
   
   # Opção 2: Download rápido com aria2c
   .\setup_llama_cpp_cuda124_aria2c.ps1
   ```

3. **Fazer download dos modelos**:
   ```powershell
   .\setup-models.ps1  # Menu interativo
   # Ou escolha específico:
   .\setup-qwen2.5-coder-0.5b.ps1      # Para testes rápidos
   .\setup-deepseek-coder-6.7b-instruct.ps1  # Para produção
   ```

### Uso Diário:

4. **Iniciar o servidor** (em um terminal):
   ```powershell
   .\start-llama-server.ps1
   # Selecione o modelo desejado
   # Servidor estará em http://127.0.0.1:8080
   ```

5. **Usar no Cline** (VS Code):
   - Abra as configurações do Cline
   - Clique em **"Connect to a model"** → **"OpenAI Compatible"**
   - Preencha os campos conforme tabela abaixo

**Tabela de Configuração do Cline:**

| Campo | Valor | Descrição | Necessário? |
|-------|-------|-----------|-------------|
| **Provider** | `OpenAI Compatible` | API compatível com OpenAI | Sim |
| **Base URL** | `http://127.0.0.1:8080/v1` | URL do servidor llama.cpp + `/v1` | Sim |
| **API Key** | `sk-no-key-required` | Chave fictícia (não verificada) | Sim |
| **Model** | `deepseek-coder-6.7b-instruct-q4_k_m.gguf` | Mesmo nome do modelo (ou qwen2.5...) | Sim |
| **Max Tokens** | `4096` | Máximo de tokens por resposta | IMPORTANTE |

**CRÍTICO - Max Tokens vs Context Window:**

```
Context Window do modelo (servidor):  16384 tokens TOTAL
├── Histórico da conversa:            ~8288 tokens
├── Sua pergunta atual:               ~2000 tokens
└── Max Tokens no Cline (resposta):   4096 tokens (MÁXIMO)
                                     ───────────────────
                                    TOTAL: 14384 OK
```

**Recomendações de Max Tokens:**
- DeepSeek 6.7B: `4096` tokens (balanceado entre qualidade e velocidade)
- Qwen2.5 0.5B: `2048` tokens (modelo menor, menos tokens necessários)
- Máximo seguro: Nunca exceda `12000` (deixa pouco espaço para histórico)

**Teste a configuração:**
```powershell
# Em PowerShell, verifique se servidor responde:
Invoke-WebRequest http://127.0.0.1:8080/v1/models -UseBasicParsing | ConvertFrom-Json
# Deve mostrar os modelos disponíveis
```

#### Alternativa: Continue.dev (Moderna e Local-First)

**Continue.dev** é uma alternativa moderna ao Cline com suporte nativo para llama.cpp local.

**Instalação:**
- Abra o VS Code Marketplace: Search "Continue"
- Instale a extensão [Continue - continue.dev](https://marketplace.visualstudio.com/items?itemName=Continue.continue)
- Reload VS Code

**Configuração:**
- Este repositório já inclui arquivo de configuração pronto em `.continue/continue.config.yaml`
- Continue detecta automaticamente este arquivo ao abrir o workspace
- Nenhuma configuração adicional necessária!

**Tabela de Configuração do Continue.dev:**

| Campo | Valor |
|-------|-------|
| Provider | openai |
| Model | deepseek-coder-6.7b-instruct-q4_k_m.gguf |
| API Base | http://127.0.0.1:8080/v1 |
| API Key | sk-no-key-required |

**Arquivo de Configuração:**
O arquivo `.continue/continue.config.yaml` já está pré-configurado:
```yaml
name: DeepSeek Coder 6.7B
version: 1.0.0

models:
  - name: DeepSeek Coder Local
    provider: openai
    model: deepseek-coder-6.7b-instruct-q4_k_m.gguf
    apiBase: http://127.0.0.1:8080/v1
    apiKey: sk-no-key-required
```

---

**Se Max Tokens for muito alto:**
- Resposta fica muito longa (e lenta)
- Pouco espaço para histórico anterior
- Alto consumo de VRAM

**Se Max Tokens for muito baixo:**
- Respostas incompletas ou truncadas
- Mais rápido
- Menos VRAM usado

> **Dica Pro:** Comece com `Max Tokens = 4096` no Cline. Se as respostas forem muito curtas, aumente para `6144`. Se ficar lento, reduza para `2048`.

6. **Testar (opcional)**:
   ```powershell
   # Em outro terminal
   .\test-deepseek.ps1
   ```

---

## Parâmetros e Personalização

> **Aviso Importante:** Os 3 parâmetros mais críticos são `Context`, `DefaultTemp` e `DefaultRepeat`. Não modifique sem entender o impacto!

### Os 3 Parâmetros Críticos

| Parâmetro | O que faz | Impacto em VRAM | Impacto em Velocidade | Padrão |
|-----------|-----------|----------------|-----------------------|--------|
| **Context** | Tamanho da memória do modelo | ALTO | ALTO | 16384 |
| **DefaultTemp** | Criatividade (0.0 = determinístico, 2.0 = criativo) | Nenhum | Nenhum | 0.1-0.4 |
| **DefaultRepeat** | Penalidade para evitar repetição (1.0 = sem penalidade) | Nenhum | Nenhum | 1.1-1.3 |



O `Context` é o fator mais importante para performance. Edite `start-llama-server.ps1`:

```powershell
# MUITO GRANDE (lento, alto uso de VRAM)
Context = 32768

# RECOMENDADO (balanceado)
Context = 16384  # Padrão

# PARA MÁQUINAS COM POUCA VRAM
Context = 8192   # 50% mais rápido, menos memória

# PARA TESTES RÁPIDOS
Context = 4096   # Muito rápido, pouco histórico
```

**Impacto do Context Window:**

| Context | VRAM (DeepSeek) | Velocidade | Histórico | Melhor para |
|---------|-----------------|-----------|-----------|-----------|
| 4096 | ~6GB | Muito rápido | Curto | Testes, protótipos |
| 8192 | ~8GB | Rápido | Médio | Balanceado |
| 16384 | ~12GB | Moderado | Longo | Produção, conversas longas |
| 32768 | ~20GB | Lento | Muito longo | Análise de projetos grandes |

**Cálculo de VRAM usado:**
```
VRAM (GB) ≈ (Tamanho do modelo em GB) + (Context / 1000)
```

**Exemplo DeepSeek 6.7B:**
- Modelo base: ~6.7GB
- Context 16384: ~6.7 + 16.4 ≈ **23.1 GB VRAM**
- Context 8192: ~6.7 + 8.2 ≈ **14.9 GB VRAM**
- Context 4096: ~6.7 + 4.1 ≈ **10.8 GB VRAM**

### Ajustar Temperatura (Criatividade)

```powershell
# Mais determinístico (0.0-0.5)
DefaultTemp = 0.1  # Respostas previsíveis

# Equilibrado (0.5-1.0)
DefaultTemp = 0.7  # Bom para geral

# Mais criativo (1.0-2.0)
DefaultTemp = 1.3  # Respostas diversas
```

### Ajustar Context Window

```powershell
Context = 16384  # Janela de contexto em tokens
# Quanto maior, mais histórico de conversa, mas mais lenta a inferência
```

### Usar Template Customizado

Copie `deepseek-coder-chat-template.jinja` para outra localização e modifique:

```powershell
Template = 'C:\custom\meu-template.jinja'
```

### Outros Modelos GGUF

Para adicionar novo modelo no `start-llama-server.ps1`:

```powershell
$MODELS = @(
    # ... modelos existentes ...
    @{
        Name          = 'Novo Modelo Local'
        Path          = 'C:\models-ai\novo-modelo\modelo.gguf'
        ID            = 'novo-modelo-q4_k_m.gguf'
        Context       = 8192
        Template      = 'default'
        DefaultTemp   = 0.7
        DefaultRepeat = 1.1
    }
)
```

---

## Solução de Problemas

### Erro: "aria2c não encontrado"
```powershell
winget install aria2.aria2
# Reinicie o PowerShell após instalar
```

### Erro: "Pasta Downloads não encontrada"
O script tenta detectar automaticamente. Se falhar, edite e defina:
```powershell
$DOWNLOADS_DIR = "C:\Users\SeuUsuário\Downloads"
```

### GPU não está sendo usada
Verifique instalação do CUDA 12.4:
```powershell
nvidia-smi  # Deve mostrar sua GPU e driver
nvcc --version  # Deve mostrar CUDA 12.4.x
```

### Download muito lento
- Use `setup_llama_cpp_cuda124_aria2c.ps1` para downloads paralelos
- Verifique sua conexão de internet
- Considere fazer download manual e mover para a pasta apropriada

### Servidor não inicia
- Verifique se porta 8080 está livre: `netstat -an | findstr 8080`
- Verifique se o modelo existe: `Test-Path C:\models-ai\...`
- Consulte o log: `cat $env:TEMP\llama-server.log`

### Resposta muito lenta ou trava

**Primeira ação: Reduzir o Context Window!**

```powershell
# Em start-llama-server.ps1, reduza:
Context = 16384  # Altere para:
Context = 8192   # Ou até 4096 se muito lento
```

- Reduz o `Context` de 16384 para 8192 ou 4096
- Use Qwen2.5 em vez de DeepSeek (muito mais rápido)
- Feche outros aplicativos que usam VRAM
- Monitore com `nvidia-smi -l 1` em outro terminal

**Checklist de otimização:**
- Context reduzido para 8192 ou 4096?
- Temperatura baixa (0.1-0.4 é ideal)?
- Outras aplicações fechadas?
- VRAM disponível >= 8GB?
- Usando Qwen2.5 para testes?

### Cline não se conecta ao servidor
```powershell
# Teste manualmente:
Invoke-WebRequest http://127.0.0.1:8080/health -UseBasicParsing
# Deve retornar {"status":"ok"}
```

---

## Comparação de Modelos

| Aspecto | Qwen2.5-Coder-0.5B | DeepSeek-Coder-6.7B |
|---------|-------------------|-------------------|
| **Tamanho** | 379 MB | 4.08 GB |
| **VRAM requerida** | ~2GB | ~8GB |
| **Velocidade** | Muito rápido | Moderado |
| **Qualidade** | Básica | Avançada |
| **Tempo/token** | ~0.1s | ~0.5s |
| **Ideal para** | Testes, prototipagem | Produção, análise |

---

## Referências e Links

- [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)
- [Modelos GGUF no Hugging Face](https://huggingface.co/models?search=gguf)
- [aria2c Documentation](https://aria2.github.io/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Cline VS Code Extension](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev)

---

## Context Window vs Cline Max Tokens (Guia Rápido)

```
┌─────────────────────────────────────────────────────┐
│         CONTEXT WINDOW DO SERVIDOR (16384)          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  Histó­rico anterior:          ~8288 tokens        │
│  ─────────────────────────────────                 │
│  • Mensagens da conversa antiga                    │
│  • Contexto de arquivos anteriores                 │
│  • Respostas prévias do modelo                    │
│                                                     │
│  Sua mensagem atual:           ~2000 tokens       │
│  ───────────────────────────────                  │
│  • Pergunta que você está fazendo                │
│  • Código que enviou                             │
│                                                     │
│  Resposta do modelo (Cline):   4096 tokens (MAX)  │
│  ───────────────────────────────────────          │
│  • O que o Cline exibe como resposta             │
│  • Configurável em Max Tokens                    │
│                                                     │
│  TOTAL: 8288 + 2000 + 4096 = 14384 tokens OK      │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Recomendação Final:**
- Context no servidor: `16384` (não mude sem necessidade)
- Max Tokens no Cline: `4096` (começa com este valor)
- Se ficar lento: Reduz Max Tokens para `2048` ou Context para `8192`

---

- Todos os scripts requerem PowerShell com `ExecutionPolicy Bypass`
- CUDA 12.4 é obrigatório; versões anteriores não funcionarão
- A primeira execução de cada script será mais lenta (downloads)
- Modelos são cacheados localmente após primeiro download
- O servidor llama.cpp roda indefinidamente até ser interrompido (Ctrl+C)

### Lembrete de Parâmetros (Context vs Max Tokens)

**No servidor (start-llama-server.ps1):**
- `Context = 16384` = Tamanho total da memória do modelo
- Impacto direto em VRAM e velocidade
- Reduza para `8192` ou `4096` se ficar lento

**No Cline (VS Code):**
- Max Tokens = 4096 = Tamanho máximo da RESPOSTA
- Deve ser menor que o Context do servidor
- Recomendado: 4096 para DeepSeek, 2048 para Qwen2.5

**Validação rápida:**
```powershell
# Teste se servidor está respondendo:
Invoke-WebRequest http://127.0.0.1:8080/v1/models -UseBasicParsing
# Deve retornar lista de modelos disponíveis
```

---

**Versão:** 1.0  
**Última atualização:** Fevereiro 2026  
**Autor:** Fernando Padilha Avena