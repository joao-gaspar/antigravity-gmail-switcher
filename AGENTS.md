# Diretrizes do Projeto AGS (Antigravity Gmail Switcher)

NÃO VOU FAZER INFERÊNCIAS SOBRE AQUILO QUE NÃO É DO MEU ESCOPO.

## Regras Globais do Agente:
1. **Sem Inferências Indevidas**: Não supor nomes de computadores, usuários, pastas ou projetos que estejam fora do escopo direto da tarefa.
2. **Manutenção do Foco**: Manter o trabalho estritamente restrito às funcionalidades solicitadas do switcher de contas, APIs e interface.

## Regra de Ordenação de Contas (`sortAccountsSmart`):
A ordenação das contas no grid DEVE sempre seguir esta prioridade, nesta ordem:
1. **Conta ativa** (em uso atualmente) — fixada no topo
2. **Conta sugerida pelo servidor** — logo abaixo da ativa
3. **Contas disponíveis com MAIS tokens restantes** — maior capacidade restante primeiro (descending)
4. **Contas bloqueadas/esgotadas com MENOR prazo de retorno** — `reset_at` mais cedo primeiro (ascending)

> Esta regra é PERMANENTE. Qualquer refatoração do `sortAccountsSmart` em `app.js` deve preservar esta lógica.
