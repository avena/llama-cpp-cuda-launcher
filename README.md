# LLaMA.cpp CUDA Tools – Modelos de Linguagem Local com GPU NVIDIA

Scripts PowerShell para Windows que automatizam instalação do **llama.cpp** com CUDA, download de modelos GGUF e inicialização de servidor compatível com a API OpenAI para uso com **Cline** e **Continue.dev** no VS Code.

---

## Tabela de Conteúdos

- [Configuração do Ambiente](#configuração-do-ambiente)
- [Quick Start](#quick-start)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Modelos](#modelos)
- [Execução do Servidor](#execução-do-servidor)
- [Integração com VS Code](#integração-com-vs-code)
- [Conceitos](#conceitos)
- [Ferramentas Avançadas](#ferramentas-avançadas)
- [TODO – Modelos a Explorar](#todo--modelos-a-explorar)
- [Solução de Problemas](#solução-de-problemas)
- [Changelog](#changelog)

---

## Configuração do Ambiente

Configure seu ambiente Windows antes de começar. Esta seção instala o PowerShell 7, Scoop e aria2c.

### Passo 1 — PowerShell 7

```powershell
# Instalar PS7
winget install Microsoft.PowerShell

# Definir como padrão
powershell -ExecutionPolicy Bypass -File .\Set-PowerShell7AsDefault.ps1
```

### Passo 2 — Scoop (opcional mas recomendado)

Scoop é um gerenciador de pacotes para Windows que facilita a instalação e atualização de ferramentas como aria2c.

```powershell
# Instalar Scoop (execute em PowerShell 7)
irm get.scoop.sh | iex

# Adicionar bucket principal
scoop bucket add main
```

### Passo 3 — aria2c

Escolha uma das opções abaixo para instalar o aria2c (usado para downloads rápidos):

| Método     | Comando                      | Observação                             |
| ---------- | ---------------------------- | -------------------------------------- |
| **winget** | `winget install aria2.aria2` | Método oficial Microsoft               |
| **scoop**  | `scoop install aria2`        | Recomendado se Scoop estiver instalado |

> **Por que usar aria2c?** Downloads paralelos e resumíveis, essencial para baixar modelos GGUF de vários GB rapidamente.

---

## Quick Start

Para quem já tem o ambiente configurado — os 4 comandos do dia a dia:

```powershell
# 1. Baixar modelo (primeira vez)
.\setup-models.ps1

# 2. Iniciar servidor
.\start-llama-server.ps1

# 3. Testar (opcional, em outro terminal)
cp .env.example .env
.\run-test.ps1

# 4. Usar no VS Code
# Cline → OpenAI Compatible → http://127.0.0.1:8080/v1
```

---

## Pré-requisitos

- Windows 10/11 com PowerShell 5.1+ (recomendado PowerShell 7)
- GPU NVIDIA com suporte a CUDA 12.4 ou 13.1
- Mínimo **6 GB de VRAM**
- ~5 GB de espaço em disco

> **Nota:** A configuração do PowerShell 7, Scoop e aria2c está descrita na seção [Configuração do Ambiente](#configuração-do-ambiente).

---

## Instalação

### Passo 1 — Instalar o llama.cpp

O script abaixo detecta automaticamente a versão de CUDA suportada pelo seu driver e usa aria2c para download paralelo:

```powershell
powershell -ExecutionPolicy Bypass -File .\setup_llama_cpp_cuda12_cuda_13_aria2c.ps1
```

O script irá:

- Detectar CUDA via `nvidia-smi` (suporta 12.4 e 13.1)
- Baixar binários pré-compilados + DLLs do CUDA Runtime
- Extrair para `[DISCO]:\llama-cpp-cuda124` ou `cuda131`

<details>
<summary>Alternativas de instalação (scripts legados)</summary>

| Script                               | Quando usar                     |
| ------------------------------------ | ------------------------------- |
| `setup_llama_cpp_cuda12_cuda_13.ps1` | Sem aria2c, detecção automática |
| `setup_llama_cpp_cuda124.ps1`        | CUDA 12.4 fixo, sem aria2c      |
| `setup_llama_cpp_cuda124_aria2c.ps1` | CUDA 12.4 fixo, com aria2c      |

</details>

### Passo 2 — PowerShell 7, Scoop e aria2c

Consulte a seção [Configuração do Ambiente](#configuração-do-ambiente) para instalar PowerShell 7, Scoop e aria2c.

---

## Modelos

### Como baixar

```powershell
.\setup-models.ps1
# Menu interativo — escolha o modelo desejado
```

Scripts diretos para automação:

```powershell
.\setup-qwen2.5-coder-0.5b.ps1            # ~379 MB
.\setup-deepseek-coder-6.7b-instruct.ps1  # ~4.08 GB
```

> O **Qwen2.5-3B-Instruct** não tem script dedicado ainda. Baixe manualmente em
> `bartowski/Qwen2.5-3B-Instruct-GGUF` no Hugging Face e salve em
> `[DISCO]:\models-ai\qwen2.5-3b-instruct\`.

<details>
<summary>Estrutura de pastas esperada</summary>

```
C:\models-ai\
├── qwen2.5-coder-0.5b-instruct\
│   └── qwen2.5-coder-0.5b-instruct-q4_k_m.gguf
├── qwen2.5-3b-instruct\
│   └── qwen2.5-3b-instruct-q4_k_m.gguf
└── deepseek-coder-6.7b-instruct\
    └── deepseek-coder-6.7b-instruct-q4_k_m.gguf
```

</details>

### Qual modelo escolher

| Modelo                            | Tamanho | VRAM    | Tokens/s (RTX 4050) | Ideal para                       |
| --------------------------------- | ------- | ------- | ------------------- | -------------------------------- |
| Qwen2.5-Coder-0.5B Q4_K_M         | 379 MB  | ~0.8 GB | >80 t/s             | Testes rápidos, protótipos       |
| ✅ **Qwen2.5-3B-Instruct Q4_K_M** | ~1.9 GB | ~2 GB   | **~58 t/s**         | **Uso geral — recomendado**      |
| Qwen2.5-Coder-7B Q4_K_M           | ~4.7 GB | ~5.3 GB | 15–25 t/s           | Código, melhor qualidade         |
| DeepSeek-Coder-6.7B Q4_K_M        | ~4.0 GB | ~5.8 GB | ~6 t/s              | Produção (hardware mais potente) |

> **Por que o Qwen2.5-3B é o sweet spot na RTX 4050?**
> Com ~2 GB de VRAM, deixa ~4 GB livres para cache KV — roda 100% na GPU com contexto longo sem spill para RAM.
> O DeepSeek-6.7B ocupa ~5.8 GB dos 6 GB disponíveis, resultando em ~9,5x menos tokens/s no benchmark real.

### Benchmark Real — RTX 4050 Notebook (6 GB VRAM)

> Teste: `"Write a Python function that receives a list of integers and returns only the even numbers"`

| Modelo                         | Tokens | Tempo | Tokens/s       |
| ------------------------------ | ------ | ----- | -------------- |
| deepseek-coder-6.7b Q4_K_M     | 86     | 14s   | 6,11 t/s       |
| **Qwen2.5-3B-Instruct Q4_K_M** | 263    | 4,5s  | **~58 t/s** ✅ |

> RTX 4050 notebook tem **192 GB/s** de bandwidth de memória. Inferência em LLMs é muito sensível a isso.

### Quantização — IQ vs K vs UD

**K-quants (Q4_K_M, Q5_K_M)** — padrão confiável, ampla compatibilidade. `_M` aplica bits extras seletivamente nas camadas mais sensíveis. Escolha segura para começar.

**IQ-quants (IQ4_XS, IQ3_M)** — tabelas de lookup não-lineares, arquivo ~10% menor que Q4_K_M com qualidade igual ou superior. Para modelos ≤7B a diferença é mais perceptível.

**UD — Unsloth Dynamic** — precisão mista por camada (críticas em 8-bit, demais em 2–3 bits). Qualidade próxima do Q8, tamanho menor que Q4. Disponível em menos modelos.

| Quantização | Qualidade  | Tamanho | Recomendação            |
| ----------- | ---------- | ------- | ----------------------- |
| Q5_K_M      | ⭐⭐⭐⭐⭐ | Maior   | Se sobrar VRAM          |
| Q4_K_M      | ⭐⭐⭐⭐   | Médio   | ✅ Padrão seguro        |
| IQ4_XS      | ⭐⭐⭐⭐+  | Menor   | Melhor para modelos ≤7B |
| UD-Q4       | ⭐⭐⭐⭐⭐ | Menor   | Melhor custo/benefício  |
| Q3_K_M      | ⭐⭐⭐     | Pequeno | Se VRAM for crítica     |

---

## Execução do Servidor

### Opção A — Uso Geral ⭐ Recomendado

```powershell
powershell -ExecutionPolicy Bypass -File .\start-llama-server.ps1
```

Menu interativo com 4 modelos, parâmetros configuráveis e suporte a LAN simultâneo.

| Parâmetro       | Qwen2.5-0.5B | Qwen2.5-3B | Qwen2.5-7B | DeepSeek-6.7B |
| --------------- | ------------ | ---------- | ---------- | ------------- |
| Context         | 16384        | 32768      | 32768      | 16384         |
| VRAM Est.       | ~0.8 GB      | ~2 GB      | ~5.3 GB    | ~5.8 GB       |
| GPU Layers      | 999          | 999        | 999        | 35            |
| Max Tokens      | 512          | 2048       | 2048       | 2048          |
| Flash Attention | ✅           | ✅         | ✅         | ✅            |

Output ao iniciar:

```
Endpoints - este PC:   http://127.0.0.1:8080
Endpoints - LAN:       http://192.168.1.100:8080
Config Cline/Continue: Base URL: http://127.0.0.1:8080/v1
                       API Key:  sk-no-key-required
```

### Opção B — RTX 4050 Otimizado

```powershell
powershell -ExecutionPolicy Bypass -File .\start-llama-server-rtx4050.ps1
```

Específico para Ada Lovelace (RTX 40xx) com 6 GB. Ativa:

- `--flash-attn` — reduz VRAM do cache KV em ~40%
- `--cache-type-k/v q8_0` — KV cache em 8-bit (~50% menos VRAM vs FP16)
- `--n-gpu-layers 99` — offload total para GPU
- `--batch-size 2048` — otimizado para Tensor Cores

> Context do DeepSeek reduzido para 8192 para caber nos 6 GB.

<details>
<summary>Opção C — Script com todos os 4 modelos</summary>

Script completo com todos os modelos disponíveis (Qwen2.5-0.5B, Qwen2.5-3B, Qwen2.5-Coder-7B, DeepSeek-6.7B). Recomendado para quem quer acesso a todos os modelos.

```powershell
powershell -ExecutionPolicy Bypass -File .\start-llama-server.ps1
```

</details>

---

## Integração com VS Code

### Cline

1. Abra as configurações do Cline → **Connect to a model** → **OpenAI Compatible**
2. Preencha os campos:

| Campo      | Valor                             |
| ---------- | --------------------------------- |
| Base URL   | `http://127.0.0.1:8080/v1`        |
| API Key    | `sk-no-key-required`              |
| Model      | `qwen2.5-3b-instruct-q4_k_m.gguf` |
| Max Tokens | `2048`                            |

### Continue.dev

O repositório já inclui `.continue/continue.config.yaml` pré-configurado — nenhuma edição necessária. Instale a extensão e abra o workspace.

```yaml
models:
  - name: DeepSeek Coder Local
    provider: openai
    model: deepseek-coder-6.7b-instruct-q4_k_m.gguf
    apiBase: http://127.0.0.1:8080/v1
    apiKey: sk-no-key-required
```

### Acesso via LAN

O script Opção A escuta em `0.0.0.0`, permitindo acesso de outros dispositivos na mesma rede:

```powershell
# Descobrir seu IP local
ipconfig | findstr "IPv4"
# Acessar de outro PC: http://[SEU-IP]:8080/v1
```

---

## Conceitos

### Context Window vs Max Tokens

```
Context do servidor (ex: 16384 tokens)
├── Histórico da conversa:   ~8288 tokens
├── Sua mensagem atual:      ~2000 tokens
└── Max Tokens (resposta):   4096 tokens  ← configure no Cline
                             ──────────────
                             TOTAL: 14384 ✔
```

- **Context alto** → mais memória de conversa, mais VRAM, mais lento
- **Reduza para `8192`** se a resposta estiver lenta ou se houver swap para RAM
- **Max Tokens no Cline**: recomendado `2048` (Qwen2.5) ou `4096` (DeepSeek)

---

## Ferramentas Avançadas

### Framework de Testes

```powershell
# Terminal 1 — inicia o servidor
.\start-llama-server_qwen2.5-3b.ps1

# Terminal 2 — executa o teste
cp .env.example .env
.\run-test.ps1
# Detecta o modelo ativo automaticamente e executa o script correspondente
```

**Métricas geradas:**

| Métrica         | Descrição                                       |
| --------------- | ----------------------------------------------- |
| Prompt Speed    | Velocidade de leitura do prompt (tokens/s)      |
| Predict Speed   | Velocidade de geração (tokens/s)                |
| Total Inference | Tempo total (ms)                                |
| Stop Reason     | `eos` = terminou natural ✔ / `limit` = truncado |

**Scripts de teste disponíveis:**

| Script                               | Modelo                    |
| ------------------------------------ | ------------------------- |
| `tests/test-qwen2.5-3b.ps1`          | Qwen2.5-3B-Instruct       |
| `tests/test-qwen2.5-coder-0.5b.ps1`  | Qwen2.5-Coder-0.5B        |
| `tests/test-qwen2.5-coder-7b.ps1`    | Qwen2.5-Coder-7B-Instruct |
| `tests/test-deepseek-coder-6.7b.ps1` | DeepSeek-Coder-6.7B       |

### Variáveis de Ambiente (.env)

```powershell
cp .env.example .env
```

| Variável              | Padrão                  | Descrição                 |
| --------------------- | ----------------------- | ------------------------- |
| `LLAMA_SERVER_URL`    | `http://localhost:8080` | URL do servidor           |
| `DEFAULT_MAX_TOKENS`  | `2048`                  | Tokens máximos na geração |
| `DEFAULT_TEMPERATURE` | `0.2`                   | Temperatura padrão        |

---

## TODO – Modelos a Explorar

> Modelos que podem rodar na RTX 4050 (6 GB VRAM) com quantizações adequadas ou que requerem hardware futuro.

### ✅ Em uso / Testados

- [x] **`deepseek-coder-6.7b` Q4_K_M** – ~6 t/s na RTX 4050 (funcional, lento)
- [x] **`Qwen2.5-3B-Instruct` Q4_K_M** – ~58 t/s ✅ recomendado atualmente

### 🔜 Próximos a testar (cabem na RTX 4050 – 6 GB)

#### DeepSeek – Modelos Distilled

- [ ] **`DeepSeek-R1-Distill-Qwen-1.5B` Q4_K_M** (~1.1 GB, ~1.3 GB VRAM)
  - Destilado do R1 671B com raciocínio chain-of-thought
  - Estimado: 25–43 t/s | HF: `bartowski/DeepSeek-R1-Distill-Qwen-1.5B-GGUF`

- [ ] **`DeepSeek-R1-Distill-Qwen-7B` Q4_K_M** (~4.7 GB, ~5.5 GB VRAM)
  - Estimado: 10–20 t/s | ⚠️ Testar com context 4096–8192
  - HF: `bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF`

- [ ] **`DeepSeek-R1-Distill-Llama-8B` Q4_K_M** (~5.0 GB, ~5.8 GB VRAM)
  - Estimado: 8–18 t/s | ⚠️ Mesma limitação de VRAM do Qwen-7B
  - HF: `bartowski/DeepSeek-R1-Distill-Llama-8B-GGUF`

- [ ] **`DeepSeek-R1-0528-Qwen3-1.5B` Q4_K_M** (~1.1 GB)
  - AIME 2025: 70% → 87,5% vs versão anterior
  - HF: `unsloth/DeepSeek-R1-0528-Qwen3-1.5B-GGUF`

#### Qwen2.5 – Pendentes

- [ ] **`qwen2.5-coder-3b` Q4_K_M** (~1.9 GB) — comparar vs Qwen2.5-3B-Instruct no benchmark de código
- [ ] **`qwen2.5-coder-7b` Q4_K_M** (~4.7 GB) — ⚠️ pouco espaço para cache KV nos 6 GB
- [ ] **`Qwen2.5-3B-Instruct` IQ4_XS** (~1.7 GB) — ~10% menor, levemente mais rápido
  - HF: `bartowski/Qwen2.5-3B-Instruct-GGUF` → arquivo `*IQ4_XS*`

### 🔭 Futuros / Requer hardware além dos 6 GB

#### DeepSeek

- [ ] **`DeepSeek-R1-Distill-Qwen-14B` Q4_K_M** (~9 GB VRAM) — requer RTX 4060 Ti 16GB+
- [ ] **`DeepSeek-V3.1` Q2/IQ2** (MoE 671B total, ~37B ativos)
  - Thinking + non-thinking em um modelo, tool calling melhorado para agentes
  - HF: `unsloth/DeepSeek-V3.1-GGUF`
- [ ] **`DeepSeek-R1-0528`** (versão completa 671B) — hardware enterprise

#### Qwen3

- [ ] **`Qwen3-Coder-Next` UD-IQ3_XXS** (MoE – 80B total, **3B ativos**) ⭐
  - Velocidade de modelo pequeno, qualidade de modelo grande | Context: 256K tokens
  - Estimado: 20–40 t/s com 24+ GB VRAM | ⚠️ Não roda na RTX 4050
  - HF: `unsloth/Qwen3-Coder-Next-GGUF`

- [ ] **`Qwen3-Coder-480B-A35B` UD-Q2** (MoE – 480B total, 35B ativos)
  - 7.5T tokens de treino (70% código) | Context: 256K–1M tokens | hardware enterprise
  - HF: `unsloth/Qwen3-Coder-480B-A35B-Instruct-GGUF`

### 🛠️ Tarefas de Scripts

- [ ] `setup-models.ps1` com opção para R1-distilled (1.5B e 7B)
- [ ] `tests/test-deepseek-r1-distill-1.5b.ps1` com prompts de raciocínio
- [ ] `tests/test-deepseek-r1-distill-7b.ps1`
- [x] `tests/test-qwen2.5-coder-7b.ps1` ✅
- [ ] `tests/test-qwen2.5-coder-3b.ps1`
- [ ] `start-llama-server_qwen2.5-3b.ps1` — opção `[4]` qwen2.5-coder-7b e `[5]` deepseek-r1-distill-1.5b
- [ ] `run-benchmark-all.ps1` — testa todos os modelos instalados e gera tabela comparativa de t/s

---

## Solução de Problemas

| Problema                | Solução                                                                          |
| ----------------------- | -------------------------------------------------------------------------------- |
| `aria2c não encontrado` | `winget install aria2.aria2` e reiniciar terminal                                |
| GPU não reconhecida     | Verificar `nvidia-smi` e `nvcc --version`                                        |
| Porta 8080 ocupada      | `netstat -an \| findstr 8080`                                                    |
| DeepSeek muito lento    | RTX 4050 tem bandwidth limitado; trocar para Qwen2.5-3B                          |
| Resposta truncada       | Stop reason `limit` — aumentar `DEFAULT_MAX_TOKENS` no `.env`                    |
| Cline não conecta       | `Invoke-WebRequest http://127.0.0.1:8080/health` deve retornar `{"status":"ok"}` |

```powershell
# Logs em tempo real
Get-Content $env:TEMP\llama-server.log -Tail 50 -Wait

# Monitorar VRAM
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.free --format=csv -l 2
```

---

## Referências

- [llama.cpp GitHub](https://github.com/ggml-org/llama.cpp)
- [bartowski – GGUF no Hugging Face](https://huggingface.co/bartowski)
- [unsloth – GGUF no Hugging Face](https://huggingface.co/unsloth)
- [Qwen2.5-3B-Instruct-GGUF](https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF)
- [aria2c](https://aria2.github.io/)
- [Cline – VS Code](https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev)
- [Continue.dev – VS Code](https://marketplace.visualstudio.com/items?itemName=Continue.continue)
