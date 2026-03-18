# config/models.ps1
# Catálogo de modelos restaurado para a configuração de referência (que funcionava)

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
    Template      = 'config/chat-templates/deepseek-coder-6.7b-instruct-q4_k_m.jinja'
    DefaultTemp   = 0.1
    DefaultRepeat = 1.1
    GpuLayers     = 28
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
    GpuLayers     = 33
  }
)