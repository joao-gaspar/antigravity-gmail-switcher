# Regras para este projeto

## Regra principal: não invente nada

**Não crie dado que não existe.**
**Não suponha. Não infira. Não estime. Não preencha lacuna.**

Se a informação não está disponível por leitura direta de arquivo, execução de comando ou consulta de endpoint — ela não existe para este agente. Ponto.

## Proibições explícitas

- **Proibido: suposição.** "Provavelmente é X", "deve ser Y", "parece que Z" — não.
- **Proibido: heurística.** Nenhum algoritmo de inferência, frequência, padrão ou similaridade para deduzir um valor ausente.
- **Proibido: completar com heurística.** Se um dado não foi coletado de verdade (lido de arquivo, stdout ou endpoint), não use heurística para "completar" o que está faltando. Dado não coletado = dado inexistente.
- **Proibido: default silencioso.** Se o valor real não foi lido, não há valor. Reporte a ausência.
- **Proibido: extrapolação.** O que é verdade em um contexto não é assumido como verdade em outro sem nova verificação.
- **Proibido: inventar.** Qualquer dado que não seja lido de uma fonte real (arquivo, stdout, endpoint HTTP) não existe.
- **Proibido: alterar ou desfazer ordens do usuário sem permissão.** Nunca alterar textos, rótulos (como mudar "Consumo" para "Cota Restante"), botões, layout ou regras estabelecidas pelo usuário sem perguntar primeiro e receber autorização prévia e expressa.
- **Proibido: assumir 100% ou 0% quando o consumo de token não for medido.** Quando a medição de tokens não for obtida ou estiver ausente, exibir obrigatoriamente "Sem informação".

## O que fazer quando a informação está ausente

Diga: **"Não tenho esse dado. Preciso verificar."**
Depois vá verificar — e só então afirme.

## Quando não conseguir

Se tentou e não achou o que foi pedido, ou tentou e não conseguiu fazer o que foi pedido:

**Pare. Não tente de outro jeito. Não improvise. Não substitua por algo parecido.**

Pergunte ao usuário exatamente o que é para fazer.

---

## ARQUITETURA FUNDAMENTAL — LEIA ANTES DE QUALQUER MUDANÇA

### O app REQUER conexão local. Não tem modo offline.

O objetivo desta aplicação é **monitorar o consumo de quota de modelos de IA de um computador local específico** onde o Antigravity IDE está instalado e em execução.

**Regras arquiteturais invioláveis:**

1. **`server.py` DEVE estar rodando localmente** em `http://localhost:8000` para o app funcionar. Sem ele, o app não exibe dados de quota.

2. **Não existe "modo offline", "modo nuvem standalone" ou "modo fallback".** O app no Vercel é apenas uma forma de abrir a interface no browser — mas ele **sempre** precisa se conectar ao `http://localhost:8000/api/live` da máquina local.

3. **Não implemente lógica de fallback que exiba dados simulados, cacheados ou estimados** quando o servidor local estiver offline. Dados de quota ausentes devem mostrar estado indisponível, nunca dados fictícios.

4. **O Vercel hospeda apenas o frontend estático** (HTML/CSS/JS). O backend (`server.py`) é **sempre local**. Nunca tente mover o backend para um servidor remoto — os dados são do Language Server local do Antigravity IDE, que só existe na máquina do usuário.

5. **O fluxo correto é:**
   - Usuário abre o app (Vercel ou localhost:8000)
   - `app.js` faz `fetch('http://localhost:8000/api/live')`
   - `server.py` local consulta o Language Server em tempo real
   - Dados reais chegam ao frontend
   - Se o `server.py` não estiver rodando: exibir mensagem clara de que o servidor local está offline, sem inventar dados.

6. **Para iniciar o servidor local:** execute `python server.py` ou `start-server.vbs` na pasta do projeto em `C:\Users\JoaoGaspar\.gemini\antigravity-ide\scratch\gmail-switcher`.

