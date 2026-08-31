# 📬 Antigravity Gmail Switcher & Live Quota Monitor

Painel inteligente e alternador rápido de contas Google projetado especificamente para o **Antigravity IDE**, com monitoramento em tempo real de quotas por modelo de IA (**Gemini**, **Claude**, **GPT**), auto-detecção de logins e seleção preditiva da melhor conta.

![Vercel](https://img.shields.io/badge/Deploy-Vercel-black?style=flat-square&logo=vercel)
![GitHub](https://img.shields.io/badge/Repository-GitHub-181717?style=flat-square&logo=github)
![Status](https://img.shields.io/badge/Antigravity-IDE%20Ready-6366f1?style=flat-square)

---

## 🌟 Funcionalidades Principais

1. **⚡ Alternador Instantâneo via Account Chooser:**
   - Redirecionamento inteligente usando o mecanismo nativo do Google (`AccountChooser?Email=...`) para abrir a sessão certa diretamente no navegador sem conflito de `/u/0/` ou `/u/1/`.

2. **📡 Monitoramento de Cota em Tempo Real (Live API):**
   - Comunicação direta com a API interna do Language Server do Antigravity IDE (`language_server_windows_x64.exe`).
   - Barras de progresso ao vivo com a fração exata de quota restante por família de modelo:
     - ✦ **Gemini** (Flash, Pro)
     - ✦ **Claude** (Sonnet 4.6 Thinking, Opus 4.6)
     - ✦ **GPT** (GPT-OSS)

3. **🪄 Auto-Inclusão Universal de Logins:**
   - Qualquer conta Google utilizada para login no Antigravity IDE (mesmo que nunca cadastrada previamente) é detectada em segundos e inserida no carrossel automaticamente.

4. **🔀 Ordenação Inteligente:**
   - **Topo:** Conta ativa no momento.
   - **2º Lugar:** ⭐ Próxima melhor recomendação para troca.
   - **Disponíveis:** Contas 100% limpas ou com menor consumo.
   - **Fim da lista:** Contas sem cota / bloqueadas, ordenadas pela data de renovação mais próxima (`⏳ Renova em ...`).

---

## 🚀 Como Executar Localmente

### Pré-requisitos
- Python 3.10+
- Antigravity IDE instalado e em execução no Windows

### Inicialização
```powershell
# 1. Iniciar o servidor local de monitoramento
python server.py

# 2. Acessar no navegador ou no painel do IDE
http://localhost:8000
```

---

## ☁️ Deploy no Vercel

O frontend estático é compatível com deploy instantâneo no **Vercel**:
```bash
npx vercel --prod
```
Quando hospedado no Vercel, o frontend conecta-se dinamicamente ao backend local (`http://localhost:8000/api/live`) quando executado na máquina de desenvolvimento.

---

## 🛠️ CLI do Switcher (`scripts/gmail-switcher.ps1`)

O repositório inclui um script PowerShell completo para automações e verificação via terminal:

| Comando | Descrição |
|---|---|
| `.\gmail-switcher.ps1 check` | Verifica e sincroniza a conta ativa e quotas agora |
| `.\gmail-switcher.ps1 quota` | Exibe a tabela detalhada de quotas por modelo |
| `.\gmail-switcher.ps1 suggest` | Recomenda a próxima conta disponível |
| `.\gmail-switcher.ps1 best` | Abre no navegador a melhor conta recomendada |
| `.\gmail-switcher.ps1 whoami` | Inspeciona processos do Language Server ao vivo |
| `.\gmail-switcher.ps1 monitor` | Loop contínuo de monitoramento |

---

## 📄 Licença
Distribuído sob licença MIT. Desenvolvido para máxima produtividade no Antigravity IDE.
