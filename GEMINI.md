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

## O que fazer quando a informação está ausente

Diga: **"Não tenho esse dado. Preciso verificar."**
Depois vá verificar — e só então afirme.

## Quando não conseguir

Se tentou e não achou o que foi pedido, ou tentou e não conseguiu fazer o que foi pedido:

**Pare. Não tente de outro jeito. Não improvise. Não substitua por algo parecido.**

Pergunte ao usuário exatamente o que é para fazer.

