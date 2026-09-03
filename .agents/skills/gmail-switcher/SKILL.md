---
name: gmail-switcher
description: Use this skill when the user asks to switch Google accounts, sign in with a specific Google account, authenticate in Antigravity IDE, or when you need to know which account is currently active, check quota usage, or detect when a model has been exhausted.
---

## Distribuição e Execução em Novas Máquinas (Abordagem 1 - Zero Configuração)

A skill é distribuída nativamente através do próprio repositório na pasta `.agents/skills/gmail-switcher/`.

1. Quando o projeto é aberto no Antigravity IDE em qualquer computador (EBBIM, LAPTOP ou nova máquina de equipe), o Antigravity IDE descobre e ativa a skill automaticamente.
2. O usuário interage pelo chat natural com o Agente (ex: "verificar conta ativa", "trocar conta do Google").
3. O Agente executa a checagem usando o script nativo da skill em PowerShell sem necessidade de instalação manual de pacotes, .bat ou daemons.

## Regras Fundamentais do Agente (Cânone Inegociável)

1. **Não minta, não invente**: Nunca supor ou prometer comportamentos de sistema, antivírus ou navegadores sem testes empíricos reais.
2. **Sem frases triunfistas ou exclamações prematuras**: Não usar frases com exclamações afirmando que as coisas vão funcionar quando você não fez os testes de verdade.
3. **Não declare sucesso sem verificação concreta**: Em vez de inventar uma realidade que você não pode checar ou prometer que algo funcionou sem poder verificar remotamente, diga exatamente: "Verifique se o que eu tentei fazer funcionou". É proibido mentir ou supor resultados.
4. **PROIBIDO DEPENDER OU PROCURAR PYTHON**: O aplicativo e seus scripts (.bat / PowerShell) DEVEM ser 100% nativos do Windows (PowerShell 5.1+). É estritamente proibido procurar Python, baixar Python ou esperar que Python esteja instalado na máquina do usuário.
5. **PROIBIDO DESFAZER OU ALTERAR ORDENS DO USUÁRIO SEM PERMISSÃO**: Nunca alterar textos, rótulos, botões, design, regras de ordenação ou qualquer instrução dada pelo usuário sem perguntar primeiro e obter autorização prévia e expressa do usuário.
6. **PROIBIDO INVENTAR COTAS OU VALORES DE CONSUMO DE TOKEN**: Se o sistema não conseguir medir ou obter a informação de consumo de token dos modelos para uma conta, é ESTRITAMENTE PROIBIDO assumir 100%, 0% ou qualquer outro valor suposto. Nesses casos de falta de medição, a interface DEVE obrigatoriamente exibir o texto "Sem informação".
7. **VERIFICAÇÃO PELO USUÁRIO QUANDO NÃO FOR POSSÍVEL CHECAR**: Em vez de inventar uma realidade que não pode checar, escreva: "Verifique se o que eu tentei fazer funcionou". É estritamente proibido mentir ou inventar informação.
8. **PROIBIDO USAR SERVIÇOS DE TERCEIROS SEM CONSULTAR O USUÁRIO**: É ESTRITAMENTE PROIBIDO utilizar, integrar, cadastrar, enviar dados ou fazer chamadas para qualquer API ou serviço de terceiros (como bancos de dados externos, webhooks ou APIs públicas) sem perguntar primeiro e receber autorização prévia e expressa do usuário.
9. **IDENTIFICAÇÃO DETERMINÍSTICA DA CONTA DO AGENTE (CONFIRMADO)**: A conta ativa do AGENTE é identificada exclusivamente pelo processo `language_server_windows_x64.exe` que **NÃO** possui a flag `--enable_lsp` em sua linha de comando (`HasLsp = false`). O processo **COM** `--enable_lsp` pertence ao LSP de código (autocompletar) e JAMAIS deve ser reportado como conta do Agente.
10. **PROIBIDO USAR ADJETIVOS OU SUPERLATIVOS**: É ESTRITAMENTE PROIBIDO utilizar adjetivos e superlativos nas respostas, explicações ou documentação. O agente DEVE ser direto, objetivo, factual e focado exclusivamente na resolução mecânica dos problemas.
11. **REGRA DA BARRA DE MEDIÇÃO DE TOKENS: EXPOR O QUANTO RESTA / DISPONÍVEL (NUNCA CONSUMO)**: A barra de medição e a coluna correspondente nos cards DEVEM SEMPRE exibir a porcentagem de tokens que RESTA / ESTÁ DISPONÍVEL (0% a 100% restante). É PROIBIDO inverter ou exibir como 'Consumo'. 100% (verde cheia) = cota cheia disponível; 0% (vermelho vazia) = esgotado / sem tokens restantes. O título da coluna deve ser 'Disponível'.
12. **ISOLAMENTO TOTAL POR COMPUTADOR**: A interface DEVE exibir EXCLUSIVAMENTE as informações do PRÓPRIO computador onde o navegador/IDE está aberto. É ESTRITAMENTE PROIBIDO exibir dados, contas ativas, nomes de máquinas ou cotas de outro computador.
13. **PROIBIDO EXIGIR OU SUGERIR INSTALAÇÃO DE ARQUIVOS .BAT OU SERVIÇOS EM SEGUNDO PLANO**: É expressamente proibido sugerir ou criar rotinas de instalação de arquivos `.bat` ou criação de serviços/daemons manuais no sistema operacional. A sincronização e operação devem ser 100% nativas via comandos PowerShell existentes na Skill ou pela própria sessão do Antigravity.
14. **PROIBIDO EXIBIR SELETOR MANUAL DE MÁQUINA NA INTERFACE**: A identificação da máquina ocorre automaticamente por sessão.
15. **ARQUITETURA CANÔNICA PADRÃO: EXECUÇÃO LOCAL NATIVA VIA `http://localhost:8000` (OPÇÃO A)**: O padrão arquitetural definitivo e obrigatório é a execução local no computador via `server.ps1` (ou Webview / Simple Browser do Antigravity) acessando `http://localhost:8000`. O frontend conecta-se diretamente a `http://127.0.0.1:8000/api/live`, detectando o `$env:COMPUTERNAME`, a conta ativa e as cotas dos modelos em tempo real sem intermediários de nuvem ou restrições de rede externa.

## Execução da Skill pelo Agente

Ao iniciar uma sessão ou quando solicitado pelo usuário para verificar ou alternar contas, execute:

```powershell
powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\scripts\gmail-switcher.ps1" check
```
*(ou localmente pelo caminho relativo da pasta `.agents/skills/gmail-switcher/scripts/gmail-switcher.ps1`)*

This will:
- Detect the active agent account and IDE Geral account in real time
- Detect if the account changed since the last check (auto-limit the previous one)
- Detect if any model reached 0% quota (register in accounts.json automatically)
- Suggest the next account if the current one is exhausted
- Save state to `watch_state.json`

## Key files

| File | Purpose |
|------|---------|
| `scripts\gmail-switcher.ps1` | Main CLI script |
| `accounts.json` | Pool of accounts with status, quota history |
| `watch_state.json` | Last detected active account + model quotas |

All files are in: `C:\Users\JoaoGaspar\.gemini\config\skills\gmail-switcher\`

## Real-time detection: HOW it works

The script queries the Antigravity IDE's internal language server HTTPS API:
1. Finds `language_server_windows_x64.exe` PIDs via `Get-CimInstance`
2. Extracts `--csrf_token` from their command line
3. Finds HTTPS listening ports via `netstat -ano`
4. Calls `GetUserStatus` with header `x-codeium-csrf-token`
5. Returns the actual account email/name from the live API response

- **PID with `--enable_lsp`** = IDE Geral (background)
- **PID without `--enable_lsp`** = Agent (this conversation)

## CLI Commands

```
check                          # ALWAYS run this first — detects and updates state
monitor [-IntervalSeconds N]   # Continuous loop (default 60s, Ctrl+C to stop)
suggest                        # Next recommended account when current is exhausted
whoami                         # Show active accounts right now (Agent + IDE Geral)
quota [EMAIL]                  # Per-model quota (remaining%, used%, reset time)
status                         # Full status: live + pool
list                           # List all accounts
open EMAIL_OR_ALIAS            # Open browser for login
best                           # Open best available account in browser
limit EMAIL DURATION           # Mark as blocked (e.g. 167h33m56s)
restore EMAIL                  # Mark as active again
add EMAIL [--label x] [--group y] [--alias z]
remove EMAIL
```

## Auto-update logic (what `check` does automatically)

| Event detected | Action taken |
|----------------|-------------|
| Account changed since last check | Previous account marked `rate_limited` if it had 0% models; `last_seen` updated |
| Model just reached 0% | Logged in `exhausted_models` for that account |
| ALL models at 0% | Account auto-marked `rate_limited` with `reset_at` from the API |
| Current account already `rate_limited` in pool but active in IDE | Records `auto_reset_at` from live API |

## Workflow when a model exhausts

1. Run `check` → detects exhausted models automatically
2. Run `suggest` → shows next best account
3. Run `best` → opens browser to log in to next account
4. After login, run `check` again → records the account switch, auto-limits the previous one

## accounts.json Schema

```json
{
  "accounts": [
    {
      "email": "aluno01@tilab.com.br",
      "aliases": ["aluno 1", "aluno1", "aluno 01"],
      "group": "alunos",
      "label": "Aluno 01",
      "status": "active",
      "last_used": "2026-08-31 01:30:00",
      "last_seen": "2026-08-31T01:30:00",
      "rate_limited_at": null,
      "reset_at": null,
      "auto_reset_at": null,
      "exhausted_models": [
        { "model": "Claude Sonnet 4.6 (Thinking)", "exhausted_at": "...", "reset_at": "..." }
      ],
      "last_quota_snapshot": {
        "Claude Sonnet 4.6 (Thinking)": { "remaining": 0.0, "resetTime": "2026-09-07T04:14:46Z" }
      }
    }
  ]
}
```

## Regra Obrigatória: Registro do Tempo de Reset do Token (`reset_at`)

Sempre que uma conta atingir limite de cota (status `rate_limited` ou `exhausted`), é OBRIGATÓRIO capturar e registrar a data/hora exata de reset (`reset_at` e `resetTime`) retornada pela API do Antigravity.

1. **Captura no Servidor (`server.py`)**: `update_account_status_if_exhausted` e `build_result` extraem `resetTime` da API `GetUserStatus` e persistem em `accounts.json` e no SQLite (`reset_at`).
2. **Armazenamento**: Persistido no campo `reset_at` em formato `"YYYY-MM-DD HH:MM:SS"`.
3. **Exibição na UI (`app.js`)**: Cards de contas bloqueadas exibem badge com contagem regressiva via `formatResetRemaining(acc.reset_at)`.
4. **Ordenação**: A ordenação smart prioriza contas bloqueadas com o **menor prazo de retorno** (menor `reset_at`).

## Resolving accounts from user input

Match user input against `email` or `aliases` (case-insensitive):
- "aluno 7" → `aluno07@tilab.com.br`
- "drive" → `drive@tilab.com.br`
- "geral" → `tilab@tilab.com.br`

Do NOT hardcode account lists — always read from `accounts.json`.
