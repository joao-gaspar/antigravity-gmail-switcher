# Diretrizes do Projeto AGS (Antigravity Gmail Switcher)

NÃO VOU FAZER INFERÊNCIAS SOBRE AQUILO QUE NÃO É DO MEU ESCOPO.

## Regras Globais do Agente:
1. **Não minta, não invente**: Nunca supor ou prometer comportamentos de sistema, antivírus ou navegadores sem testes empíricos reais.
2. **Sem frases triunfistas ou exclamações prematuras**: Não usar frases com exclamações afirmando que as coisas vão funcionar quando você não fez os testes de verdade.
3. **Não declare sucesso sem verificação concreta**: Nunca declarar que uma tarefa foi concluída sem verificação concreta em tempo de execução.
4. **PROIBIDO DEPENDER OU PROCURAR PYTHON**: O aplicativo e seus instaladores/scripts (.bat / PowerShell) DEVEM ser 100% nativos para Windows (PowerShell 5.1+). É proibido incluir busca por Python, download de Python ou exigir Python no computador do usuário.
5. **Sem Inferências Indevidas**: Não supor nomes de computadores, usuários, pastas ou projetos fora do escopo direto.
6. **Manutenção do Foco**: Manter o trabalho estritamente restrito às funcionalidades solicitadas do switcher de contas, APIs e interface.
7. **PROIBIDO DESFAZER OU ALTERAR ORDENS DO USUÁRIO SEM PERMISSÃO**: É estritamente proibido alterar textos, rótulos, botões ou qualquer escolha/diretriz definida pelo usuário sem perguntar primeiro e obter autorização expressa.
8. **PROIBIDO INVENTAR COTAS OU CONSUMO DE TOKEN**: Se o consumo de token de um modelo não puder ser medido ou obtido, é proibido exibir 100% ou 0%. Deve-se obrigatoriamente exibir o texto "Sem informação".
9. **PROIBIDO USAR SERVIÇOS DE TERCEIROS SEM CONSULTAR O USUÁRIO**: É estritamente proibido utilizar, integrar, enviar dados ou fazer chamadas para qualquer API ou serviço de terceiros sem perguntar primeiro e receber autorização prévia e expressa do usuário.

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
