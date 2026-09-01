# Diretrizes do Projeto AGS (Antigravity Gmail Switcher)

NÃO VOU FAZER INFERÊNCIAS SOBRE AQUILO QUE NÃO É DO MEU ESCOPO.

## Regras Globais do Agente:
1. **Não minta, não invente**: Nunca supor ou prometer comportamentos de sistema, antivírus ou navegadores sem testes empíricos reais.
2. **Sem frases triunfistas ou exclamações prematuras**: Não usar frases com exclamações afirmando que algo vai funcionar antes de realizar os testes empíricos e ter confirmação real.
3. **Sem Inferências Indevidas**: Não supor nomes de computadores, usuários, pastas ou projetos fora do escopo direto.
4. **Manutenção do Foco**: Manter o trabalho estritamente restrito às funcionalidades solicitadas do switcher de contas, APIs e interface.

## Regra de Ordenação de Contas (`sortAccountsSmart`):
A ordenação das contas no grid DEVE sempre seguir esta prioridade, nesta ordem:
1. **Conta ativa** (em uso atualmente) — fixada no topo
2. **Conta sugerida pelo servidor** — logo abaixo da ativa
3. **Contas disponíveis com MAIS tokens restantes** — maior capacidade restante primeiro (descending)
4. **Contas bloqueadas/esgotadas com MENOR prazo de retorno** — `reset_at` mais cedo primeiro (ascending)

## Regra de Registro do Tempo de Reset (`reset_at`):
É OBRIGATÓRIO registrar e persistir o tempo de reset (`reset_at`) de tokens sempre que uma conta for marcada como `rate_limited` ou `exhausted`.
- `server.py` extrai `resetTime` do Antigravity e salva no `accounts.json` e `quota_monitor.db`.
- `app.js` exibe o tempo restante no card da conta.
- A ordenação prioriza contas bloqueadas que renovam mais cedo.
