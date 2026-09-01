// ==========================================================================
// Gmail Fast Switcher - Logic & State Management with Live Quota Tracking & Smart Sorting
// ==========================================================================

let state = {
    accounts: [],
    currentFilter: 'all',
    searchQuery: '',
    activeNoteAccountId: null,
    selectedPresetTheme: 'gradient-blue',
    activeAccountId: 'tilab-drive',
    liveQuota: null,
    liveModelQuotas: null,
    liveSuggestEmail: null,
    liveLastCheck: null
};

const themeGradients = {
    'gradient-blue': { gradient: 'linear-gradient(135deg, #00f2fe 0%, #4facfe 100%)', glow: 'rgba(0, 210, 255, 0.25)' },
    'gradient-purple': { gradient: 'linear-gradient(135deg, #9d4edd 0%, #7b2ff7 100%)', glow: 'rgba(123, 47, 247, 0.25)' },
    'gradient-sunset': { gradient: 'linear-gradient(135deg, #ff416c 0%, #ff4b2b 100%)', glow: 'rgba(255, 75, 43, 0.25)' },
    'gradient-emerald': { gradient: 'linear-gradient(135deg, #0ba360 0%, #3cba92 100%)', glow: 'rgba(60, 186, 146, 0.25)' },
    'gradient-amber': { gradient: 'linear-gradient(135deg, #f857a6 0%, #ff5858 100%)', glow: 'rgba(248, 87, 166, 0.25)' },
    'gradient-cyber': { gradient: 'linear-gradient(135deg, #f107a3 0%, #7b2ff7 100%)', glow: 'rgba(241, 7, 163, 0.25)' },
    'gradient-nordic': { gradient: 'linear-gradient(135deg, #2c3e50 0%, #3498db 100%)', glow: 'rgba(52, 152, 219, 0.25)' }
};

const elements = {
    accountsGrid: document.getElementById('accounts-grid'),
    emptyState: document.getElementById('empty-state'),
    searchInput: document.getElementById('search-input'),
    filterPills: document.querySelectorAll('.filter-pill'),
    btnShowAccounts: document.getElementById('btn-show-accounts'),
    btnShowGuide: document.getElementById('btn-show-guide'),
    viewAccounts: document.getElementById('view-accounts'),
    viewGuide: document.getElementById('view-guide'),
    controlsSection: document.getElementById('controls-section'),
    btnNextAccount: document.getElementById('btn-next-account'),
    accountModal: document.getElementById('account-modal'),
    modalTitle: document.getElementById('modal-title'),
    accountForm: document.getElementById('account-form'),
    accountIdInput: document.getElementById('account-id'),
    accountNameInput: document.getElementById('account-name'),
    accountEmailInput: document.getElementById('account-email'),
    accountCategorySelect: document.getElementById('account-category'),
    accountAvatarUrlInput: document.getElementById('account-avatar-url'),
    colorPresets: document.getElementById('color-presets'),
    btnAddAccount: document.getElementById('btn-add-account'),
    btnEmptyAdd: document.getElementById('btn-empty-add'),
    btnCloseModal: document.getElementById('btn-close-modal'),
    btnCancelModal: document.getElementById('btn-cancel-modal'),
    appContainer: document.querySelector('.app-container'),
    notesDrawer: document.getElementById('notes-drawer'),
    btnCloseDrawer: document.getElementById('btn-close-drawer'),
    drawerAvatar: document.getElementById('drawer-avatar'),
    drawerAccountName: document.getElementById('drawer-account-name'),
    drawerAccountEmail: document.getElementById('drawer-account-email'),
    drawerNotesTextarea: document.getElementById('drawer-notes'),
    toast: document.getElementById('toast-notification'),
    toastMessage: document.getElementById('toast-message')
};

document.addEventListener('DOMContentLoaded', () => {
    checkAuth();
    loadAccounts();
    setupEventListeners();
    renderAccounts();
    updateLiveBanner(null, null, null, true);
    setInterval(updateTimers, 1000);
    fetchLive();
    setInterval(fetchLive, 3000);
});

function safeGetStorage(key) {
    try {
        if (typeof window !== 'undefined' && window.localStorage) {
            return window.localStorage.getItem(key);
        }
    } catch (e) {}
    return null;
}

function safeSetStorage(key, val) {
    try {
        if (typeof window !== 'undefined' && window.localStorage) {
            window.localStorage.setItem(key, val);
        }
    } catch (e) {}
}

function loadAccounts() {
    const saved = safeGetStorage('antigravity_gmail_switcher_accounts_v6');
    let loaded = false;
    if (saved) {
        try {
            const parsed = JSON.parse(saved);
            if (Array.isArray(parsed) && parsed.length > 0) {
                state.accounts = parsed;
                state.accounts.forEach(a => {
                    // Migrate legacy unmeasured 0 / integer defaults to null
                    if (!a.lastMeasuredAt && (a.tokenGemini === 0 || a.tokenGemini === 368)) a.tokenGemini = null;
                    if (!a.lastMeasuredAt && (a.tokenClaude === 0 || a.tokenClaude === 36))  a.tokenClaude = null;
                    if (!a.lastMeasuredAt && (a.tokenGpt    === 0 || a.tokenGpt    === 36))  a.tokenGpt    = null;
                });
                loaded = true;
            }
        } catch (e) {}
    }

    if (!loaded) {
        state.accounts = [
            {
                        "id": "tilab-drive",
                        "name": "TI Lab Drive",
                        "email": "drive@tilab.com.br",
                        "category": "work",
                        "avatarUrl": "",
                        "theme": "gradient-blue",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-geral",
                        "name": "TI Lab Geral",
                        "email": "tilab@tilab.com.br",
                        "category": "work",
                        "avatarUrl": "",
                        "theme": "gradient-purple",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno01",
                        "name": "TI Lab Aluno 01",
                        "email": "aluno01@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-sunset",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno02",
                        "name": "TI Lab Aluno 02",
                        "email": "aluno02@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-emerald",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno03",
                        "name": "TI Lab Aluno 03",
                        "email": "aluno03@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-amber",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno04",
                        "name": "TI Lab Aluno 04",
                        "email": "aluno04@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-cyber",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno05",
                        "name": "TI Lab Aluno 05",
                        "email": "aluno05@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-nordic",
                        "notes": "",
                        "status": "exhausted",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": "2026-09-06 23:58:08",
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno06",
                        "name": "TI Lab Aluno 06",
                        "email": "aluno06@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-blue",
                        "notes": "",
                        "status": "exhausted",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": "2026-09-07 00:42:10",
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno07",
                        "name": "TI Lab Aluno 07",
                        "email": "aluno07@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-purple",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno08",
                        "name": "TI Lab Aluno 08",
                        "email": "aluno08@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-sunset",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno09",
                        "name": "TI Lab Aluno 09",
                        "email": "aluno09@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-emerald",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "tilab-aluno10",
                        "name": "TI Lab Aluno 10",
                        "email": "aluno10@tilab.com.br",
                        "category": "clients",
                        "avatarUrl": "",
                        "theme": "gradient-amber",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            },
            {
                        "id": "acc-joaogaspar-gmail-com",
                        "name": "Joaogaspar",
                        "email": "joaogaspar@gmail.com",
                        "category": "work",
                        "avatarUrl": "",
                        "theme": "gradient-cyber",
                        "notes": "",
                        "status": "available",
                        "tokenGemini": null,
                        "tokenClaude": null,
                        "tokenGpt": null,
                        "reset_at": null,
                        "exhausted_models": []
            }
];
        saveAccounts();
    }
    state.activeAccountId = safeGetStorage('antigravity_active_account_id') || 'tilab-aluno10';
}

function saveAccounts() {
    safeSetStorage('antigravity_gmail_switcher_accounts_v6', JSON.stringify(state.accounts));
    safeSetStorage('antigravity_active_account_id', state.activeAccountId);
}

function showToast(message) {
    elements.toastMessage.textContent = message;
    elements.toast.classList.add('active');
    setTimeout(() => elements.toast.classList.remove('active'), 2500);
}

function switchView(tab) {
    if (tab === 'accounts') {
        elements.btnShowAccounts.classList.add('active');
        elements.btnShowGuide.classList.remove('active');
        elements.viewAccounts.classList.remove('hidden');
        elements.controlsSection.classList.remove('hidden');
        elements.viewGuide.classList.add('hidden');
    } else {
        elements.btnShowAccounts.classList.remove('active');
        elements.btnShowGuide.classList.add('active');
        elements.viewAccounts.classList.add('hidden');
        elements.controlsSection.classList.add('hidden');
        elements.viewGuide.classList.remove('hidden');
    }
}

function setupEventListeners() {
    if (elements.btnShowAccounts) elements.btnShowAccounts.addEventListener('click', () => switchView('accounts'));
    if (elements.btnShowGuide) elements.btnShowGuide.addEventListener('click', () => switchView('guide'));
    if (elements.btnAddAccount) elements.btnAddAccount.addEventListener('click', () => openModal());
    if (elements.btnEmptyAdd)   elements.btnEmptyAdd.addEventListener('click', () => openModal());

    if (elements.btnCloseModal) elements.btnCloseModal.addEventListener('click', closeModal);
    if (elements.btnCancelModal) elements.btnCancelModal.addEventListener('click', closeModal);
    if (elements.accountForm) elements.accountForm.addEventListener('submit', handleFormSubmit);

    if (elements.colorPresets) {
        elements.colorPresets.addEventListener('click', (e) => {
            const target = e.target.closest('.color-preset');
            if (!target) return;
            document.querySelectorAll('.color-preset').forEach(p => p.classList.remove('active'));
            target.classList.add('active');
            state.selectedPresetTheme = target.dataset.theme;
        });
    }

    if (elements.searchInput) {
        elements.searchInput.addEventListener('input', (e) => {
            state.searchQuery = e.target.value.toLowerCase().trim();
            renderAccounts();
        });
    }

    const filterSelect = document.getElementById('category-filter-select');
    if (filterSelect) {
        filterSelect.addEventListener('change', (e) => {
            state.currentFilter = e.target.value;
            renderAccounts();
        });
    }

    if (elements.btnNextAccount) {
        elements.btnNextAccount.addEventListener('click', handleNextAccount);
    }

    if (elements.btnCloseDrawer) elements.btnCloseDrawer.addEventListener('click', closeNotesDrawer);
    if (elements.drawerNotesTextarea) {
        elements.drawerNotesTextarea.addEventListener('input', (e) => {
            if (!state.activeNoteAccountId) return;
            const account = state.accounts.find(a => a.id === state.activeNoteAccountId);
            if (account) {
                account.notes = e.target.value;
                saveAccounts();
            }
        });
    }

    if (elements.accountModal) {
        elements.accountModal.addEventListener('click', (e) => {
            if (e.target === elements.accountModal) closeModal();
        });
    }
}

function getChooserUrl(email, service) {
    let continueUrl = 'https://mail.google.com/mail/';
    if (service === 'calendar') continueUrl = 'https://calendar.google.com/calendar/';
    else if (service === 'drive') continueUrl = 'https://drive.google.com/';
    else if (service === 'meet') continueUrl = 'https://meet.google.com/';
    return `https://accounts.google.com/AccountChooser?Email=${encodeURIComponent(email)}&continue=${encodeURIComponent(continueUrl)}`;
}

// // Smart Sorting Priority Rules:
// Rank 0: Conta ativa (fixada no topo)
// Rank 1: Conta sugerida (indicada pelo servidor como próxima melhor)
// Rank 2: Contas disponíveis com MAIS tokens restantes (maior capacidade restante primeiro)
// Rank 3: Contas bloqueadas/esgotadas com MENOR prazo de retorno (renovando mais cedo primeiro)
function sortAccountsSmart(accountsList) {
    let activeEmailForSel = null;
    let suggestEmailForSel = null;

    const isLocalMachineSelected = !state.selectedMachineId || 
        (state.currentMachine && state.selectedMachineId === state.currentMachine.machine_id);

    if (isLocalMachineSelected) {
        activeEmailForSel  = state.accounts.find(a => a.id === state.activeAccountId)?.email;
        suggestEmailForSel = state.liveSuggestEmail;
    } else {
        if (state.snapshots && state.selectedMachineId) {
            const snap = state.snapshots.find(s => s.machine_id === state.selectedMachineId);
            if (snap) activeEmailForSel = snap.email;
        }
    }

    // Remaining capacity: tokens not yet consumed (higher = better)
    // tokenGemini/tokenClaude/tokenGpt are stored as 0..1 (fraction consumed)
    // remaining = (1 - gemini) + (1 - claude) + (1 - gpt) = 3 - total_consumed
    const remaining = acc => {
        const g = acc.tokenGemini ?? 0;
        const c = acc.tokenClaude ?? 0;
        const p = acc.tokenGpt   ?? 0;
        return 3 - (g + c + p); // higher = more tokens available
    };
    const parseResetTs = val => {
        if (!val || typeof val !== 'string') return null;
        const formattedStr = val.includes(' ') ? val.replace(' ', 'T') : val;
        const ts = new Date(formattedStr).getTime();
        return isNaN(ts) ? null : ts;
    };

    const resetTs = acc => parseResetTs(acc.reset_at) ?? Infinity;
    const hasFutureReset = acc => {
        const ts = parseResetTs(acc.reset_at);
        return ts !== null && ts > Date.now();
    };
    const isBlocked = acc =>
        acc.status === 'exhausted' ||
        acc.status === 'rate_limited' ||
        hasFutureReset(acc);

    return [...accountsList].sort((a, b) => {
        // 0. Active account always first
        const aActive = activeEmailForSel && a.email === activeEmailForSel;
        const bActive = activeEmailForSel && b.email === activeEmailForSel;
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;

        // 1. Suggested account second
        const aSuggest = suggestEmailForSel && a.email === suggestEmailForSel;
        const bSuggest = suggestEmailForSel && b.email === suggestEmailForSel;
        if (aSuggest && !bSuggest) return -1;
        if (!aSuggest && bSuggest) return 1;

        // 2. Available before blocked
        const aBlocked = isBlocked(a);
        const bBlocked = isBlocked(b);
        if (!aBlocked && bBlocked) return -1;
        if (aBlocked && !bBlocked) return 1;

        // 3a. Both available → MOST remaining tokens first (highest capacity)
        if (!aBlocked && !bBlocked) {
            const diff = remaining(b) - remaining(a); // descending: more tokens = top
            if (diff !== 0) return diff;
            return (a.name || a.email || '').localeCompare(b.name || b.email || '');
        }

        // 3b. Both blocked → EARLIEST reset first (shortest wait = top)
        const diff = resetTs(a) - resetTs(b);
        if (diff !== 0) return diff;
        return (a.name || a.email || '').localeCompare(b.name || b.email || '');
    });
}

function formatResetRemaining(resetAtStr) {
    if (!resetAtStr || typeof resetAtStr !== 'string') return null;
    try {
        let formattedStr = resetAtStr.trim();
        // Replace space with T for ISO compliance
        if (!formattedStr.includes('T') && formattedStr.includes(' ')) {
            formattedStr = formattedStr.replace(' ', 'T');
        }
        // If it doesn't specify fuso, treat as local/UTC fallback safely
        const target = new Date(formattedStr);
        if (isNaN(target.getTime())) return null;

        const diffMs = target.getTime() - Date.now();
        if (diffMs <= 0) return "Renovando...";
        const diffSecs = Math.floor(diffMs / 1000);
        const days = Math.floor(diffSecs / 86400);
        const hours = Math.floor((diffSecs % 86400) / 3600);
        const mins = Math.floor((diffSecs % 3600) / 60);
        if (days > 0) return `⏳ ${days}d ${hours}h`;
        if (hours > 0) return `⏳ ${hours}h ${mins}m`;
        return `⏳ ${mins}m`;
    } catch {
        return null;
    }
}

function renderAccounts() {
    elements.accountsGrid.innerHTML = '';

    const isLocalMachineSelected = !state.selectedMachineId || 
        (state.currentMachine && state.selectedMachineId === state.currentMachine.machine_id);

    let targetAccountPool = state.accounts;

    if (!isLocalMachineSelected && state.machines && state.machines.length > 0) {
        const selMachine = state.machines.find(m => m.machine_id === state.selectedMachineId);
        if (selMachine && selMachine.accounts && selMachine.accounts.length > 0) {
            targetAccountPool = selMachine.accounts.map(ma => ({
                id: 'acc-' + (ma.email || 'unknown').replace(/[@.]/g, '-'),
                name: ma.name || (ma.email ? ma.email.split('@')[0] : 'Conta'),
                email: ma.email || '',
                category: ma.category || 'work',
                avatarUrl: ma.avatar_url || '',
                theme: ma.theme || 'gradient-blue',
                notes: ma.notes || '',
                status: ma.status || 'available',
                reset_at: ma.reset_at
            }));
        }
    }

    // Safety fallback: if target pool is empty, use default base accounts
    if (!targetAccountPool || targetAccountPool.length === 0) {
        targetAccountPool = state.accounts;
    }

    const filtered = targetAccountPool.filter(acc => {
        if (!acc || !acc.email) return false;
        const accName  = (acc.name || acc.email || '').toLowerCase();
        const accEmail = (acc.email || '').toLowerCase();
        const matchesCategory = state.currentFilter === 'all' || acc.category === state.currentFilter;
        const matchesSearch   = accName.includes(state.searchQuery) || accEmail.includes(state.searchQuery);
        return matchesCategory && matchesSearch;
    });

    if (filtered.length === 0) {
        elements.emptyState.classList.remove('hidden');
        elements.accountsGrid.classList.add('hidden');
        return;
    }

    elements.emptyState.classList.add('hidden');
    elements.accountsGrid.classList.remove('hidden');

    const sorted = sortAccountsSmart(filtered);

    // Selected machine active email for UI badges
    let selectedActiveEmail = null;
    let selectedSnap = null;

    if (isLocalMachineSelected) {
        selectedActiveEmail = state.accounts.find(a => a.id === state.activeAccountId)?.email;
    } else {
        if (state.snapshots && state.selectedMachineId) {
            selectedSnap = state.snapshots.find(s => s.machine_id === state.selectedMachineId);
            if (selectedSnap) {
                selectedActiveEmail = selectedSnap.email;
            }
        }
    }

    sorted.forEach((acc) => {
        const isActive = acc.email === selectedActiveEmail;
        const isBlocked = acc.status === 'exhausted' || acc.status === 'rate_limited';
        const cardTheme = isActive ? 'gradient-purple' : 'gradient-blue';
        const themeConfig = themeGradients[cardTheme] || themeGradients['gradient-blue'];

        const card = document.createElement('div');
        card.className = `account-card ${isActive ? 'active-account' : ''} ${isBlocked ? 'blocked-account' : ''}`;
        card.setAttribute('data-id', acc.id);
        card.style.setProperty('--theme-gradient', themeConfig.gradient);
        card.style.setProperty('--theme-glow', themeConfig.glow);

        if (isActive) {
            card.style.border = '2px solid #a855f7';
            card.style.boxShadow = '0 0 15px rgba(168, 85, 247, 0.25)';
        } else if (isBlocked) {
            card.style.border = '1px solid rgba(239, 68, 68, 0.35)';
            card.style.opacity = '0.78';
        } else {
            card.style.border = '1px solid var(--border-color)';
            card.style.opacity = '1';
        }

        const emailPrefix = acc.email.split('@')[0];
        const avatarInitials = emailPrefix.slice(0, 2).toUpperCase();
        const avatarHtml = `<div class="account-avatar" style="width: 28px; height: 28px; font-size: 0.8rem;">${avatarInitials}</div>`;

        // Live Quota Bars: pull either from local live state OR from database snapshots for the selected machine
        const getFrac = val => {
            if (val === undefined || val === null || isNaN(val)) return null;
            const n = Number(val);
            return n > 1 ? n / 100 : Math.max(0, Math.min(1, n));
        };

        let qG = null, qC = null, qP = null;

        if (isBlocked) {
            qG = 0.0;
            qC = 0.0;
            qP = 0.0;
        } else if (isActive && isLocalMachineSelected && state.liveQuota) {
            qG = getFrac(state.liveQuota.gemini);
            qC = getFrac(state.liveQuota.claude);
            qP = getFrac(state.liveQuota.gpt);
        } else {
            const accSnap = state.snapshots && state.snapshots.find(s => 
                s.email.toLowerCase() === acc.email.toLowerCase() && 
                (!state.selectedMachineId || s.machine_id === state.selectedMachineId)
            );
            if (accSnap) {
                qG = getFrac(accSnap.gemini_pct !== undefined ? accSnap.gemini_pct / 100 : null);
                qC = getFrac(accSnap.claude_pct !== undefined ? accSnap.claude_pct / 100 : null);
                qP = getFrac(accSnap.gpt_pct !== undefined ? accSnap.gpt_pct / 100 : null);
            } else if (acc.tokenGemini !== undefined || acc.tokenClaude !== undefined || acc.tokenGpt !== undefined) {
                qG = getFrac(acc.tokenGemini);
                qC = getFrac(acc.tokenClaude);
                qP = getFrac(acc.tokenGpt);
            }
        }

        const renderBar = (frac, label) => {
            if (frac === null || frac === undefined) {
                return `
                <div style="display:flex; align-items:center; gap:4px; margin-bottom:2px;">
                    <span style="font-size:0.58rem; color:#9ca3af; min-width:68px; font-weight:600;">${label}</span>
                    <div style="flex:1; height:4px; background:rgba(255,255,255,0.08); border-radius:2px; overflow:hidden;">
                        <div style="height:100%; width:0%; background:#9ca3af; border-radius:2px;"></div>
                    </div>
                    <span style="font-size:0.52rem; color:#9ca3af; width:65px; text-align:right; font-family:sans-serif; font-weight:500;">Sem informação</span>
                </div>`;
            }
            const safeFrac = Math.max(0, Math.min(1, frac));
            const pct = Math.round(safeFrac * 100);
            const col = pct > 50 ? '#34d399' : pct > 15 ? '#f59e0b' : '#ef4444';
            return `
            <div style="display:flex; align-items:center; gap:4px; margin-bottom:2px;">
                <span style="font-size:0.58rem; color:${col}; min-width:68px; font-weight:600;">${label}</span>
                <div style="flex:1; height:4px; background:rgba(255,255,255,0.08); border-radius:2px; overflow:hidden;">
                    <div style="height:100%; width:${pct}%; background:${col}; border-radius:2px; transition:width 0.4s;"></div>
                </div>
                <span style="font-size:0.55rem; color:${col}; width:30px; text-align:right; font-family:monospace; font-weight:bold;">${pct}%</span>
            </div>`;
        };

        const qCG = (qC !== null || qP !== null) ? Math.max(qC ?? 0, qP ?? 0) : null;
        const quotaBarsHtml = `
        <div style="margin-top:4px; padding-top:4px; border-top:1px solid rgba(255,255,255,0.06);">
            <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:3px;">
                <span style="font-size:0.54rem; color:#9ca3af; font-weight:600;">Modelo</span>
                <span style="font-size:0.54rem; color:#9ca3af; font-weight:600;">Consumo</span>
            </div>
            ${renderBar(qG, 'Gemini')}
            ${renderBar(qCG, 'Claude / GPT')}
        </div>`;

        const isSuggest = state.liveSuggestEmail && acc.email === state.liveSuggestEmail && !isActive;
        const resetLabel = isBlocked && acc.reset_at ? formatResetRemaining(acc.reset_at) : null;
        const resetBadge = resetLabel ? `<span style="font-size:0.56rem; color:#f87171; background:rgba(239,68,68,0.12); padding:1px 5px; border-radius:3px; margin-left:4px;">${resetLabel}</span>` : '';
        const suggestBadge = isSuggest ? `<span style="font-size:0.56rem; color:#34d399; background:rgba(52,211,153,0.15); border:1px solid rgba(52,211,153,0.3); padding:1px 6px; border-radius:3px; margin-left:4px; font-weight:600;"><i class="fa-solid fa-star" style="font-size:0.5rem;"></i> Sugerida</span>` : '';

        card.innerHTML = `
            <div class="card-header" style="margin-bottom:0; align-items:center; display:flex; justify-content:space-between;">
                <div style="display:flex; align-items:center; gap:5px; overflow:hidden; flex:1; min-width:0;">
                    ${avatarHtml}
                    <span style="font-size:0.75rem; font-weight:500; color:var(--text-primary); white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${acc.email}</span>
                </div>
                <div style="display:flex; gap:2px; align-items:center; flex-shrink:0; margin-left:4px;">
                    <button class="btn-ctrl btn-switch" data-email="${acc.email}" title="Trocar para esta conta (logout + login)" style="width:18px; height:18px; font-size:0.7rem; color:#60a5fa;" ${isActive ? 'disabled style="width:18px; height:18px; font-size:0.7rem; color:#374151; cursor:not-allowed;"' : ''}><i class="fa-solid fa-arrow-right-arrow-left"></i></button>
                    <button class="btn-ctrl btn-activate" title="${isActive ? 'Conta ativa' : 'Marcar como ativa'}" data-id="${acc.id}" style="width:18px; height:18px; font-size:0.7rem; color:${isActive ? '#10b981' : 'var(--text-muted)'};"><i class="${isActive ? 'fa-solid fa-circle-check' : 'fa-regular fa-circle'}"></i></button>
                    <button class="btn-ctrl btn-edit"      data-id="${acc.id}" style="width:18px; height:18px; font-size:0.65rem;"><i class="fa-solid fa-pen"></i></button>
                    <button class="btn-ctrl btn-delete"    data-id="${acc.id}" style="width:18px; height:18px; font-size:0.65rem;"><i class="fa-solid fa-trash-can"></i></button>
                </div>
            </div>

            <div style="margin-top:4px; padding-top:4px; border-top:1px solid rgba(255,255,255,0.04);">
                <div style="display:flex; align-items:center; gap:4px; margin-bottom:2px; flex-wrap:wrap;">
                    <span class="status-pill ${isBlocked ? 'exhausted' : 'available'}" data-id="${acc.id}" title="Clique para alternar status" style="font-size:0.58rem; padding:1px 4px; border-radius:3px; cursor:pointer;">
                        ${isBlocked ? 'Sem Cota' : 'Disponível'}
                    </span>
                    ${suggestBadge}${resetBadge}
                </div>

                ${quotaBarsHtml}
            </div>
        `;

        const btnSwitch = card.querySelector('.btn-switch');
        if (btnSwitch) btnSwitch.addEventListener('click', (e) => {
            e.stopPropagation();
            const email = e.currentTarget.getAttribute('data-email');
            if (email) switchToAccount(email);
        });

        const btnEdit = card.querySelector('.btn-edit');
        if (btnEdit) btnEdit.addEventListener('click', (e) => { e.stopPropagation(); openModal(acc.id); });

        const btnDelete = card.querySelector('.btn-delete');
        if (btnDelete) btnDelete.addEventListener('click', (e) => {
            e.stopPropagation();
            if (confirm(`Remover "${acc.email}"?`)) deleteAccount(acc.id);
        });

        const btnActivate = card.querySelector('.btn-activate');
        if (btnActivate) btnActivate.addEventListener('click', (e) => {
            e.stopPropagation();
            const id = e.currentTarget.getAttribute('data-id');
            if (id) setActiveAccount(id);
        });

        const statusPill = card.querySelector('.status-pill');
        if (statusPill) statusPill.addEventListener('click', (e) => {
            e.stopPropagation();
            const id = e.currentTarget.getAttribute('data-id');
            if (id) toggleAccountStatus(id);
        });


        elements.accountsGrid.appendChild(card);
    });
}

function setActiveAccount(id) {
    state.activeAccountId = id;
    saveAccounts();
    renderAccounts();
    const acc = state.accounts.find(a => a.id === id);
    if (acc) showToast(`Conta ativa: ${acc.email}`);
}

// Navega o Simple Browser (janela do agente) para logout do Google
// e depois para o AccountChooser com o email alvo pré-preenchido.
// O usuário só precisa digitar a senha da nova conta.
function switchToAccount(email) {
    if (!email) return;
    const continueAfterLogin = encodeURIComponent(
        `https://accounts.google.com/AccountChooser?Email=${encodeURIComponent(email)}&continue=${encodeURIComponent(window.location.href)}`
    );
    const logoutAndLoginUrl = `https://accounts.google.com/Logout?continue=${continueAfterLogin}`;
    showToast(`🔄 Trocando para ${email}...`);
    // Navega a janela atual (Simple Browser = janela do agente) para fazer logout
    window.location.href = logoutAndLoginUrl;
}

function toggleAccountStatus(id) {
    const acc = state.accounts.find(a => a.id === id);
    if (!acc) return;
    if (acc.status === 'exhausted' || acc.status === 'rate_limited') {
        acc.status = 'available';
        acc.exhaustedTime = null;
        acc.reset_at = null;
        showToast(`${acc.name} DISPONÍVEL.`);
    } else {
        acc.status = 'exhausted';
        acc.exhaustedTime = Date.now();
        showToast(`${acc.name} marcada SEM COTA.`);
    }
    saveAccounts();
    renderAccounts();
}

function logTokenUsage(id, amount, model) {
    const acc = state.accounts.find(a => a.id === id);
    if (!acc) return;
    const fieldMap = { gemini: 'tokenGemini', claude: 'tokenClaude', gpt: 'tokenGpt' };
    const field = fieldMap[model] || 'tokenGemini';
    const label = model ? model[0].toUpperCase() + model.slice(1) : 'Gemini';
    if (amount === 0) {
        acc[field] = 0;
        showToast(`${label}: zerado para ${acc.email}.`);
    } else {
        acc[field] = (acc[field] || 0) + amount;
        showToast(`+${(amount/1000)}k tokens ${label} → ${acc.email}`);
    }
    saveAccounts();
    renderAccounts();
}

function updateTimers() {
    renderAccounts();
}

function fetchSingleEndpoint(url) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 3500);
    return fetch(url, { signal: controller.signal })
        .then(res => { clearTimeout(timeoutId); return res.json(); });
}

function fetchLive() {
    const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    const ports = [8000, 8999, 8998, 8997, 8996, 8995];
    
    let fetchPromise;
    if (isLocal) {
        fetchPromise = fetchSingleEndpoint('/api/live');
    } else {
        // Try candidate ports dynamically: 8000 -> 8999 -> 8998 -> 8997 -> 8996 -> 8995
        let p = Promise.reject();
        ports.forEach(port => {
            p = p.catch(() => fetchSingleEndpoint(`http://127.0.0.1:${port}/api/live`));
        });
        fetchPromise = p;
    }

    fetchPromise
        .then(data => {
            const agentEmail = (data.agent && data.agent.email) || 
                               (data.live && data.live.user && data.live.user.email) || 
                               (data.live && data.live.email) || null;
            const agentName = (data.agent && data.agent.name) || 
                              (data.live && data.live.user && data.live.user.name) || null;
            const modelQuotas = data.modelQuotas || {};
            const suggestEmail = data.suggestEmail;
            const lastCheck = data.lastCheck;

            // 1. Auto-include ANY active account even if never seen before
            if (agentEmail) {
                let detectedAcc = state.accounts.find(a => a.email.toLowerCase() === agentEmail.toLowerCase());
                if (!detectedAcc) {
                    const newId = 'acc-' + agentEmail.replace(/[@.]/g, '-');
                    detectedAcc = {
                        id: newId,
                        name: agentName || agentEmail.split('@')[0],
                        email: agentEmail,
                        category: (agentEmail.includes('aluno')) ? 'clients' : 'work',
                        avatarUrl: '',
                        theme: 'gradient-purple',
                        notes: '',
                        status: 'available',
                        tokenGemini: 0,
                        tokenClaude: 0,
                        tokenGpt: 0,
                        reset_at: null,
                        exhausted_models: []
                    };
                    state.accounts.unshift(detectedAcc);
                    saveAccounts();
                }
                if (detectedAcc && detectedAcc.id !== state.activeAccountId) {
                    state.activeAccountId = detectedAcc.id;
                    safeSetStorage('antigravity_active_account_id', state.activeAccountId);
                }
            }

            let geminiMax = null, claudeMin = null, gptMin = null;
            let hasGemini = false, hasClaude = false, hasGpt = false;

            if (modelQuotas && typeof modelQuotas === 'object' && Object.keys(modelQuotas).length > 0) {
                for (const [lbl, info] of Object.entries(modelQuotas)) {
                    const rem = typeof info === 'object' ? info.remaining : (typeof info === 'number' ? info : null);
                    if (rem !== null && rem !== undefined) {
                        if (/gemini/i.test(lbl)) {
                            geminiMax = hasGemini ? Math.max(geminiMax, rem) : rem;
                            hasGemini = true;
                        } else if (/claude/i.test(lbl)) {
                            claudeMin = hasClaude ? Math.min(claudeMin, rem) : rem;
                            hasClaude = true;
                        } else if (/gpt|openai/i.test(lbl)) {
                            gptMin = hasGpt ? Math.min(gptMin, rem) : rem;
                            hasGpt = true;
                        }
                    }
                }
            }

            state.liveQuota = {
                gemini: hasGemini ? geminiMax : null,
                claude: hasClaude ? claudeMin : null,
                gpt:    hasGpt    ? gptMin    : null
            };
            state.liveModelQuotas = modelQuotas;
            state.liveSuggestEmail = suggestEmail;
            state.liveLastCheck = lastCheck;

            // ── Write live quota back into the active account card ──────────
            if (agentEmail && state.liveQuota) {
                const liveAcc = state.accounts.find(a =>
                    a.email && a.email.toLowerCase() === agentEmail.toLowerCase());
                if (liveAcc) {
                    liveAcc.tokenGemini = state.liveQuota.gemini;
                    liveAcc.tokenClaude = state.liveQuota.claude;
                    liveAcc.tokenGpt    = state.liveQuota.gpt;
                    if (state.liveQuota.gemini === 0 && state.liveQuota.claude === 0 && state.liveQuota.gpt === 0) {
                        liveAcc.status = 'exhausted';
                    }
                    saveAccounts();
                }
            }

            // ── POST all accounts (with token data) to cloud /api/sync ─────
            const machInfo = data.machine || {};
            const syncPayload = {
                machine_id:   machInfo.machine_id || 'unknown',
                hostname:     machInfo.hostname   || '',
                username:     machInfo.username   || '',
                active_email: agentEmail,
                suggest_email: suggestEmail,
                last_seen:    new Date().toISOString(),
                accounts: state.accounts.map(a => ({
                    email:       a.email,
                    tokenGemini: a.tokenGemini || 0,
                    tokenClaude: a.tokenClaude || 0,
                    tokenGpt:    a.tokenGpt    || 0,
                    status:      a.status      || 'available',
                    reset_at:    a.reset_at    || null
                }))
            };
            fetch('/api/sync', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(syncPayload)
            }).catch(() => {});

    // Save active machine details
    if (data.machine) {
        state.currentMachine = data.machine;
        if (data.machine.hostname) safeSetStorage('antigravity_last_hostname', data.machine.hostname);
        if (data.machine.username) safeSetStorage('antigravity_last_username', data.machine.username);
        if (!state.selectedMachineId) {
            state.selectedMachineId = data.machine.machine_id;
        }
    }

            if (data.pool && data.pool.length > 0) {
                data.pool.forEach(poolAcc => {
                    let local = state.accounts.find(a => a.email === poolAcc.email);
                    const blocked = poolAcc.status === 'rate_limited';
                    if (!local) {
                        local = {
                            id: 'acc-' + poolAcc.email.replace(/[@.]/g, '-'),
                            name: poolAcc.label || poolAcc.email,
                            email: poolAcc.email,
                            category: (poolAcc.group === 'alunos' || poolAcc.email.includes('aluno')) ? 'clients' : 'work',
                            avatarUrl: '',
                            theme: poolAcc.email.includes('drive') ? 'gradient-blue' : (poolAcc.email.includes('tilab') ? 'gradient-purple' : 'gradient-emerald'),
                            notes: '',
                            status: blocked ? 'exhausted' : 'available',
                            tokenGemini: 0,
                            tokenClaude: 0,
                            tokenGpt: 0,
                            reset_at: poolAcc.reset_at || null,
                            exhausted_models: poolAcc.exhausted_models || []
                        };
                        state.accounts.push(local);
                    } else {
                        local.status = blocked ? 'exhausted' : 'available';
                        local.reset_at = poolAcc.reset_at || null;
                        local.exhausted_models = poolAcc.exhausted_models || [];
                        if (poolAcc.label && !local.name) local.name = poolAcc.label;
                    }
                });
                saveAccounts();
            }

            // Fetch local & cloud synced machines using discovered active port
            const activePort = data.activePort || 8999;
            const machinesUrl  = isLocal ? '/api/machines'  : `http://127.0.0.1:${activePort}/api/machines`;
            const snapshotsUrl = isLocal ? '/api/snapshots' : `http://127.0.0.1:${activePort}/api/snapshots`;

            Promise.all([
                fetch(machinesUrl).then(r => r.json()).catch(() => []),
                fetch(snapshotsUrl).then(r => r.json()).catch(() => []),
                fetch('/api/sync').then(r => r.json()).catch(() => ({ machines: [] }))
            ])
            .then(([localMachines, snapshots, cloudData]) => {
                const combined = [...(localMachines || [])];
                if (cloudData && cloudData.machines) {
                    cloudData.machines.forEach(cm => {
                        let match = combined.find(m => m.machine_id === cm.machine_id);
                        if (!match) {
                            combined.push(cm);
                        } else {
                            Object.assign(match, cm);
                        }
                    });
                }

                // ── Merge cloud token data into local accounts ────────────
                if (cloudData && cloudData.accounts && cloudData.accounts.length > 0) {
                    let tokensMerged = false;
                    cloudData.accounts.forEach(ca => {
                        if (!ca.email) return;
                        // Skip updating the account that belongs to THIS machine's
                        // active email — our local liveQuota is more accurate.
                        if (agentEmail && ca.email.toLowerCase() === agentEmail.toLowerCase()) return;
                        const local = state.accounts.find(a =>
                            a.email && a.email.toLowerCase() === ca.email.toLowerCase());
                        if (local) {
                            if (ca.tokenGemini != null) local.tokenGemini = ca.tokenGemini;
                            if (ca.tokenClaude != null) local.tokenClaude = ca.tokenClaude;
                            if (ca.tokenGpt    != null) local.tokenGpt    = ca.tokenGpt;
                            if (ca.status)              local.status      = ca.status;
                            if (ca.reset_at !== undefined) local.reset_at  = ca.reset_at;
                            tokensMerged = true;
                        }
                    });
                    if (tokensMerged) saveAccounts();
                }
                state.machines = combined;
                state.snapshots = snapshots;
                renderAccounts();
                updateLiveBanner(agentEmail, suggestEmail, lastCheck, false, data.suggestReason);
            });
        })
        .catch(err => {
            clearTimeout(timeoutId);
            // Even if offline, try fetching cloud synced machines
            fetch('/api/sync')
                .then(r => r.json())
                .then(cloudData => {
                    if (cloudData && cloudData.machines && cloudData.machines.length > 0) {
                        state.machines = cloudData.machines;
                        renderAccounts();
                    }
                    updateLiveBanner(null, null, null, true);
                })
                .catch(() => {
                    updateLiveBanner(null, null, null, true);
                });
        });
}

function updateLiveBanner(agentEmail, suggestEmail, lastCheck, isOffline = false, suggestReason = '') {
    let banner = document.getElementById('live-banner');
    if (!banner) {
        banner = document.createElement('div');
        banner.id = 'live-banner';
        banner.style.cssText = 'position:relative; z-index:10; padding:7px 12px; font-size:0.65rem; border-radius:8px; border: 1px solid rgba(255,255,255,0.07); transition: background 0.3s; display:block;';
        const slot = document.getElementById('live-banner-slot');
        if (slot) slot.appendChild(banner);
    }
    banner.style.display = 'block';
    
    // Build machine selector dropdown (ALWAYS rendered)
    let machineOptions = '';
    if (state.machines && state.machines.length > 0) {
        state.machines.forEach(m => {
            const isSel = m.machine_id === state.selectedMachineId ? 'selected' : '';
            const userPart = m.username ? ` (${m.username})` : '';
            const activeMark = m.machine_id === (state.currentMachine && state.currentMachine.machine_id) ? ' ⭐ (Este PC)' : '';
            machineOptions += `<option value="${m.machine_id}" ${isSel}>💻 ${m.hostname}${userPart}${activeMark}</option>`;
        });
    } else {
        const savedHost = safeGetStorage('antigravity_last_hostname') || (state.currentMachine && state.currentMachine.hostname);
        const savedUser = safeGetStorage('antigravity_last_username') || (state.currentMachine && state.currentMachine.username);
        const curHost = savedHost || 'Este Computador';
        const curUser = savedUser ? ` (${savedUser})` : '';
        machineOptions = `<option value="local">💻 ${curHost}${curUser}</option>`;
    }

    const selectorHtml = `
        <select id="machine-selector" style="background:rgba(255,255,255,0.08); border:1px solid rgba(255,255,255,0.12); color:#e2e8f0; font-size:0.6rem; padding:3px 8px; border-radius:5px; outline:none; font-weight:600; cursor:pointer; max-width:160px;">
            ${machineOptions}
        </select>
    `;

    const grid = document.getElementById('accounts-grid');
    let lockOverlay = document.getElementById('offline-lock-overlay');

    if (isOffline) {
        if (grid) {
            grid.style.filter = 'grayscale(0.85) opacity(0.38)';
            grid.style.pointerEvents = 'none';
            grid.style.userSelect = 'none';
            grid.style.transition = 'filter 0.4s ease, opacity 0.4s ease';
        }

        if (!lockOverlay) {
            lockOverlay = document.createElement('div');
            lockOverlay.id = 'offline-lock-overlay';
            lockOverlay.style.cssText = 'margin:10px 0 14px 0; padding:16px; background:rgba(239,68,68,0.08); border:1px dashed rgba(239,68,68,0.4); border-radius:12px; text-align:center; display:flex; flex-direction:column; align-items:center; gap:8px; box-shadow:0 8px 24px rgba(0,0,0,0.3); backdrop-filter:blur(4px);';
            const section = document.getElementById('view-accounts');
            if (section && grid) section.insertBefore(lockOverlay, grid);
        }
        lockOverlay.style.display = 'flex';
        lockOverlay.innerHTML = `
            <div style="display:flex; align-items:center; gap:8px;">
                <span style="font-size:1.2rem; color:#f87171;"><i class="fa-solid fa-plug-circle-xmark"></i></span>
                <span style="font-size:0.82rem; font-weight:700; color:#f87171;">Servidor Local Offline neste Computador</span>
            </div>
            <p style="font-size:0.68rem; color:#9ca3af; max-width:380px; margin:0; line-height:1.4;">
                As contas abaixo estão <strong style="color:#ef4444;">esmaecidas e travadas</strong> porque o assistente local do AGS não está rodando nesta máquina.
            </p>
            <button onclick="openSetupModal()" style="background:linear-gradient(135deg, #00f2fe 0%, #4facfe 100%); border:none; color:#0f172a; font-size:0.72rem; padding:7px 16px; border-radius:8px; font-weight:800; cursor:pointer; display:flex; align-items:center; gap:6px; box-shadow:0 0 15px rgba(0,242,254,0.4); margin-top:4px; outline:none;">
                <i class="fa-solid fa-wand-magic-sparkles"></i> ✨ Ativar Assistente do AGS neste PC
            </button>
        `;

        banner.style.background = 'rgba(239, 68, 68, 0.1)';
        banner.innerHTML = `
            <div style="display:flex; align-items:center; justify-content:space-between; gap:8px; margin-bottom:4px;">
                ${selectorHtml}
                <button onclick="openSetupModal()" style="background:linear-gradient(135deg, rgba(0,242,254,0.2) 0%, rgba(79,172,254,0.2) 100%); border:1px solid rgba(0,210,255,0.5); color:#00f2fe; font-size:0.58rem; padding:2px 8px; border-radius:5px; font-weight:700; cursor:pointer; display:flex; align-items:center; gap:4px; outline:none; box-shadow:0 0 10px rgba(0,242,254,0.2);">
                    <i class="fa-solid fa-wand-magic-sparkles"></i> ✨ Ativar Assistente
                </button>
                <span style="color:#ef4444; font-size:0.56rem; font-weight:bold; margin-left:auto;">DISCONNECTED</span>
            </div>
            <div style="display:flex; align-items:center; gap:8px; padding-top:4px; border-top:1px solid rgba(255,255,255,0.05);">
                <span style="color:#f87171; font-size:0.6rem; font-weight:600;">⚠ Servidor local offline nesta máquina</span>
                <span style="color:#6b7280; font-size:0.56rem;">(Selecione outro PC acima ou ative o assistente)</span>
            </div>
        `;
        const selElOffline = document.getElementById('machine-selector');
        if (selElOffline) {
            selElOffline.addEventListener('change', (e) => {
                state.selectedMachineId = e.target.value;
                renderAccounts();
            });
        }
        return;
    }

    // Restore online state: remove dimming & hide lock overlay
    if (grid) {
        grid.style.filter = 'none';
        grid.style.opacity = '1';
        grid.style.pointerEvents = 'auto';
        grid.style.userSelect = 'auto';
    }
    if (lockOverlay) {
        lockOverlay.style.display = 'none';
    }

    // Determine active account display (probe > local selection > fallback)
    const activeAccObj = state.accounts.find(a => a.id === state.activeAccountId);
    const displayActiveEmail = agentEmail || (activeAccObj ? activeAccObj.email : null);

    const agentPart = displayActiveEmail
        ? `<span style="color:#a78bfa; font-weight:700; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:200px;" title="${displayActiveEmail}"><i class="fa-solid fa-user-check" style="font-size:0.6rem;"></i> ${displayActiveEmail}</span>`
        : `<span style="color:#6b7280;">Nenhuma selecionada</span>`;

    // Determine next suggested account display (server suggest > next available local account)
    let displaySuggestEmail = suggestEmail;
    if (!displaySuggestEmail && state.accounts && state.accounts.length > 0) {
        const nextAvail = state.accounts.find(a => (a.status === 'available' || !a.status) && a.id !== state.activeAccountId);
        if (nextAvail) displaySuggestEmail = nextAvail.email;
    }

    const sugTitle = suggestReason ? `title="${suggestReason}"` : '';
    const suggestPart = displaySuggestEmail
        ? `<span style="color:#34d399; font-weight:700; cursor:pointer; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:200px;" onclick="openSuggestLogin('${displaySuggestEmail}')" ${sugTitle} title="${displaySuggestEmail}"><i class="fa-solid fa-angles-right"></i> ⭐ ${displaySuggestEmail}</span>`
        : `<span style="color:#6b7280; font-style:italic;">Sem alternativa</span>`;

    banner.innerHTML = `
        <div style="display:flex; align-items:center; justify-content:space-between; gap:8px; margin-bottom:5px;">
            ${selectorHtml}
            <span style="color:#10b981; font-size:0.6rem; font-weight:700; display:inline-flex; align-items:center; gap:4px; margin-left:auto;">
                <span style="width:6px; height:6px; background:#10b981; border-radius:50%; display:inline-block; box-shadow:0 0 8px #10b981;"></span> Online
            </span>
        </div>
        <div style="display:flex; align-items:center; gap:10px; padding-top:4px; border-top:1px solid rgba(255,255,255,0.05); font-size:0.65rem;">
            <span style="color:#6b7280; font-size:0.56rem; font-weight:700; flex-shrink:0;">ATIVA</span>
            ${agentPart}
            <span style="color:#374151; font-size:0.7rem; flex-shrink:0;">→</span>
            <span style="color:#6b7280; font-size:0.56rem; font-weight:700; flex-shrink:0;">PRÓXIMA</span>
            ${suggestPart}
        </div>
    `;

    // Dropdown change listener
    const selEl = document.getElementById('machine-selector');
    if (selEl) {
        selEl.addEventListener('change', (e) => {
            state.selectedMachineId = e.target.value;
            renderAccounts();
        });
    }

    const agentAcc = displayActiveEmail ? state.accounts.find(a => a.email === displayActiveEmail) : null;
    if (agentAcc && (agentAcc.status === 'exhausted' || agentAcc.status === 'rate_limited')) {
        banner.style.background = 'rgba(239,68,68,0.10)';
    } else {
        banner.style.background = 'rgba(16,185,129,0.05)';
    }
}


function openSuggestLogin(email) {
    const url = `https://accounts.google.com/AccountChooser?Email=${encodeURIComponent(email)}&continue=${encodeURIComponent('https://accounts.google.com/')}`;
    window.open(url, '_blank');
    showToast(`Abrindo login: ${email}`);
}

function handleNextAccount() {
    const sorted = sortAccountsSmart(state.accounts);
    const nextAcc = sorted.find(acc => acc.id !== state.activeAccountId && acc.status !== 'exhausted' && acc.status !== 'rate_limited');
    if (nextAcc) {
        setActiveAccount(nextAcc.id);
        navigator.clipboard.writeText(nextAcc.email).then(() => {
            showToast(`Copiada: ${nextAcc.email}`);
            openSuggestLogin(nextAcc.email);
        });
    } else {
        alert('Todas as contas estão esgotadas no momento!');
    }
}

function deleteAccount(id) {
    state.accounts = state.accounts.filter(acc => acc.id !== id);
    saveAccounts();
    renderAccounts();
    showToast('Conta excluída.');
}

function openModal(id = null) {
    elements.accountForm.reset();
    if (id) {
        const acc = state.accounts.find(a => a.id === id);
        if (!acc) return;
        elements.modalTitle.textContent = 'Editar Conta';
        elements.accountIdInput.value = acc.id;
        elements.accountNameInput.value = acc.name;
        elements.accountEmailInput.value = acc.email;
        elements.accountCategorySelect.value = acc.category;
        elements.accountAvatarUrlInput.value = acc.avatarUrl || '';
        state.selectedPresetTheme = acc.theme || 'gradient-blue';
    } else {
        elements.modalTitle.textContent = 'Adicionar Conta';
        elements.accountIdInput.value = '';
        state.selectedPresetTheme = 'gradient-blue';
    }
    document.querySelectorAll('.color-preset').forEach(p => {
        if (p.dataset.theme === state.selectedPresetTheme) p.classList.add('active');
        else p.classList.remove('active');
    });
    elements.accountModal.classList.add('active');
}

function closeModal() {
    elements.accountModal.classList.remove('active');
}

function openSetupModal() {
    const modal = document.getElementById('setup-modal');
    if (modal) modal.classList.add('active');
}

function closeSetupModal() {
    const modal = document.getElementById('setup-modal');
    if (modal) modal.classList.remove('active');
}

document.addEventListener('DOMContentLoaded', () => {
    const btnCloseSetup = document.getElementById('btn-close-setup-modal');
    const btnCancelSetup = document.getElementById('btn-cancel-setup-modal');
    const btnCopySetup = document.getElementById('btn-copy-setup-cmd');

    if (btnCloseSetup) btnCloseSetup.addEventListener('click', closeSetupModal);
    if (btnCancelSetup) btnCancelSetup.addEventListener('click', closeSetupModal);
    if (btnCopySetup) {
        btnCopySetup.addEventListener('click', () => {
            const cmd = 'irm https://antigravity-gmail-switcher.vercel.app/setup.ps1 | iex';
            navigator.clipboard.writeText(cmd).then(() => {
                showToast('Comando copiado!');
            });
        });
    }
});

function handleFormSubmit(e) {
    e.preventDefault();
    const id = elements.accountIdInput.value;
    const name = elements.accountNameInput.value.trim();
    const email = elements.accountEmailInput.value.trim();
    const category = elements.accountCategorySelect.value;
    const avatarUrl = elements.accountAvatarUrlInput.value.trim();

    if (id) {
        const accIdx = state.accounts.findIndex(a => a.id === id);
        if (accIdx !== -1) {
            state.accounts[accIdx].name = name;
            state.accounts[accIdx].email = email;
            state.accounts[accIdx].category = category;
            state.accounts[accIdx].avatarUrl = avatarUrl;
            state.accounts[accIdx].theme = state.selectedPresetTheme;
        }
        showToast('Conta atualizada!');
    } else {
        state.accounts.push({
            id: 'acc-' + Date.now(),
            name, email, category, avatarUrl,
            theme: state.selectedPresetTheme,
            notes: '', status: 'available',
            tokenGemini: 0, tokenClaude: 0, tokenGpt: 0
        });
        showToast('Nova conta adicionada!');
    }
    saveAccounts();
    closeModal();
    renderAccounts();
}

function closeNotesDrawer() {
    elements.appContainer.classList.remove('drawer-open');
    state.activeNoteAccountId = null;
}

const AUTH_CRED_KEY = 'antigravity_creds_v1';

function doLogin(email, pass) {
    const cleanEmail = (email || '').trim().toLowerCase();
    const cleanPass  = (pass || '').trim();
    return cleanEmail === 'joaogaspar@gmail.com' && cleanPass === '2025@Switcher';
}

function applyLogin(overlay) {
    safeSetStorage('antigravity_authenticated', 'true');
    if (overlay) overlay.style.display = 'none';
    showToast('Acesso concedido!');
}

function checkAuth() {
    const overlay = document.getElementById('login-overlay');

    // 0. Local machine access (localhost / 127.0.0.1) NEVER requires login!
    const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    if (isLocal) {
        safeSetStorage('antigravity_authenticated', 'true');
        if (overlay) overlay.style.display = 'none';
        return;
    }

    // 1. Try auto-login from saved credentials or authenticated flag
    if (safeGetStorage('antigravity_authenticated') === 'true') {
        if (overlay) overlay.style.display = 'none';
        return;
    }

    try {
        const saved = safeGetStorage(AUTH_CRED_KEY);
        if (saved) {
            const { e, p } = JSON.parse(saved);
            if (doLogin(e, p)) {
                safeSetStorage('antigravity_authenticated', 'true');
                if (overlay) overlay.style.display = 'none';
                return;
            }
        }
    } catch (_) {}

    // 2. Show login form on remote (Vercel) access if not authenticated
    if (overlay) overlay.style.display = 'flex';

    // Pre-fill inputs with default credentials if empty
    const emailEl = document.getElementById('login-email');
    const passEl  = document.getElementById('login-password');
    if (emailEl && !emailEl.value) emailEl.value = 'joaogaspar@gmail.com';
    if (passEl  && !passEl.value) passEl.value  = '2025@Switcher';

    const btnTogglePass = document.getElementById('btn-toggle-password');
    const passInput = document.getElementById('login-password');
    const passIcon = document.getElementById('toggle-password-icon');
    if (btnTogglePass && passInput && passIcon && !btnTogglePass._bound) {
        btnTogglePass._bound = true;
        btnTogglePass.addEventListener('click', () => {
            const isPass = passInput.type === 'password';
            passInput.type = isPass ? 'text' : 'password';
            passIcon.className = isPass ? 'fa-solid fa-eye-slash' : 'fa-solid fa-eye';
            passIcon.style.color = isPass ? '#a78bfa' : '#9ca3af';
        });
    }

    const form = document.getElementById('login-form');
    if (form && !form._authBound) {
        form._authBound = true;
        form.addEventListener('submit', (e) => {
            e.preventDefault();
            const email  = document.getElementById('login-email').value;
            const pass   = document.getElementById('login-password').value;
            const errDiv = document.getElementById('login-error');

            if (doLogin(email, pass)) {
                safeSetStorage(AUTH_CRED_KEY, JSON.stringify({ e: email.trim(), p: pass.trim() }));
                applyLogin(overlay);
                if (errDiv) errDiv.style.display = 'none';
            } else {
                if (errDiv) errDiv.style.display = 'block';
            }
        });
    }
}

