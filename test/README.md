# Test Structure

This folder contains the test framework for validating LLaMA.cpp models.

## Structure

```
test/
├── _test-core.ps1              # Core test functions (single source of truth)
├── test-deepseek-coder-6.7b.ps1 # Test for DeepSeek Coder 6.7B
├── test-qwen2.5-3b.ps1          # Test for Qwen2.5 3B
├── test-qwen2.5-coder-0.5b.ps1 # Test for Qwen2.5 Coder 0.5B
├── test-qwen2.5-coder-7b.ps1   # Test for Qwen2.5 Coder 7B
└── README.md                   # This file
```

## How It Works

### Core Functions (`_test-core.ps1`)

Provides reusable functions for testing:

| Function                | Description                                              |
| ----------------------- | -------------------------------------------------------- |
| `Invoke-TestCompletion` | Main test function - sends prompt and validates response |
| `Test-ServerHealth`     | Checks if the LLaMA server is running                    |
| `Test-ModelsList`       | Lists available models on the server                     |

### Test Scripts

Each test script:

1. Loads environment variables from `.env` via `load-env.ps1`
2. Imports core functions from `_test-core.ps1`
3. Defines model-specific configuration
4. Calls `Invoke-TestCompletion` with the model

## Adding a New Model

### Step 1: Create Test Script

Create a new file `test/test-<model-name>.ps1`:

```powershell
#!/usr/bin/env pwsh
# test-<model-name>.ps1 - Teste específico para <Model Name>

param(
    [int]$MaxTokens = 2048,
    [float]$Temperature = 0.2,
    [string]$OutputFile = "",
    [string]$Model = "",
    [switch]$IncludeMetrics
)

# Carrega variáveis de ambiente do .env
. "$PSScriptRoot\..\load-env.ps1"

# Importa funções de teste
. "$PSScriptRoot\_test-core.ps1"

# Configurações específicas do modelo
$prompt = "Write a Python function to filter even numbers"
$systemPrompt = "You are a precise coding assistant."
$fullPrompt = "[INST] $systemPrompt $prompt [/INST]"
$stopTokens = @("</s>", "[INST]")
$modelLabel = if ($Model) { $Model } else { "<Default-Model-Name>" }

Invoke-TestCompletion -Prompt $fullPrompt -Model $modelLabel `
    -MaxTokens $MaxTokens -Temperature $Temperature `
    -StopTokens $stopTokens -OutputFile $OutputFile `
    -ModelLabel $modelLabel -IncludeMetrics:$IncludeMetrics
```

### Step 2: Customize Parameters

| Parameter       | Description                                     |
| --------------- | ----------------------------------------------- |
| `$systemPrompt` | System prompt to set model behavior             |
| `$prompt`       | Test prompt to send to the model                |
| `$fullPrompt`   | Full prompt with template (see templates below) |
| `$stopTokens`   | Array of stop tokens specific to model family   |
| `$modelLabel`   | Default model name (filename pattern)           |

### Prompt Templates by Model Family

#### Qwen2.5 Family

```powershell
$fullPrompt = "[INST] $systemPrompt $prompt [/INST]"
$stopTokens = @("</s>", "[INST]")
```

#### DeepSeek Family

```powershell
$fullPrompt = "$systemPrompt`n### Instruction:`n$prompt`n### Response:`n"
$stopTokens = @("</s>", "<|EOT|>", "### Instruction:")
```

## Running Tests

### Option 1: Run Specific Test

```powershell
.\test\test-qwen2.5-coder-7b.ps1
```

### Option 2: Auto-detect Model (via run-test.ps1)

```powershell
.\run-test.ps1
```

This will:

1. Check server health at `LLAMA_SERVER_URL`
2. Detect the currently loaded model
3. Find and execute the matching test script

### Option 3: With Custom Parameters

```powershell
.\test\test-qwen2.5-coder-7b.ps1 -MaxTokens 512 -Temperature 0.5 -IncludeMetrics
```

## Environment Variables

Tests require `LLAMA_SERVER_URL` in your `.env` file:

```bash
LLAMA_SERVER_URL=http://127.0.0.1:8080
```

## Output

Test results are saved to:

- Console (colored output)
- Text file (specified via `-OutputFile` or auto-generated)

Example output filename: `test-qwen2.5-coder-7b.txt`
