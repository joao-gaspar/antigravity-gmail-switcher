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
    loadAccounts();
    setupEventListeners();
    renderAccounts();
    setInterval(updateTimers, 1000);
    fetchLive();
    setInterval(fetchLive, 5000);
});

function loadAccounts() {
    const saved = localStorage.getItem('antigravity_gmail_switcher_accounts_v6');
    if (saved) {
        try {
            state.accounts = JSON.parse(saved);
            state.accounts.forEach(a => {
                if (a.email === 'aluno10@tilab.com.br' && a.tokenGemini === 368) {
                    a.tokenGemini = 0;
                }
            });
        } catch (e) {
            state.accounts = [];
        }
    } else {
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
                        "tokenGemini": 0,
                        "tokenClaude": 36,
                        "tokenGpt": 36,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
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
                        "tokenGemini": 0,
                        "tokenClaude": 0,
                        "tokenGpt": 0,
                        "reset_at": null,
                        "exhausted_models": []
            }
];
        saveAccounts();
    }
    state.activeAccountId = localStorage.getItem('antigravity_active_account_id') || 'tilab-aluno10';
}

function saveAccounts() {
    localStorage.setItem('antigravity_gmail_switcher_accounts_v6', JSON.stringify(state.accounts));
    localStorage.setItem('antigravity_active_account_id', state.activeAccountId);
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
    elements.btnShowAccounts.addEventListener('click', () => switchView('accounts'));
    elements.btnShowGuide.addEventListener('click', () => switchView('guide'));
    elements.btnAddAccount.addEventListener('click', () => openModal());
    elements.btnEmptyAdd.addEventListener('click', () => openModal());
    elements.btnCloseModal.addEventListener('click', closeModal);
    elements.btnCancelModal.addEventListener('click', closeModal);
    elements.accountForm.addEventListener('submit', handleFormSubmit);

    elements.colorPresets.addEventListener('click', (e) => {
        const target = e.target.closest('.color-preset');
        if (!target) return;
        document.querySelectorAll('.color-preset').forEach(p => p.classList.remove('active'));
        target.classList.add('active');
        state.selectedPresetTheme = target.dataset.theme;
    });

    elements.searchInput.addEventListener('input', (e) => {
        state.searchQuery = e.target.value.toLowerCase().trim();
        renderAccounts();
    });

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

    elements.btnCloseDrawer.addEventListener('click', closeNotesDrawer);
    elements.drawerNotesTextarea.addEventListener('input', (e) => {
        if (!state.activeNoteAccountId) return;
        const account = state.accounts.find(a => a.id === state.activeNoteAccountId);
        if (account) {
            account.notes = e.target.value;
            saveAccounts();
        }
    });

    elements.accountModal.addEventListener('click', (e) => {
        if (e.target === elements.accountModal) closeModal();
    });
}

function getChooserUrl(email, service) {
    let continueUrl = 'https://mail.google.com/mail/';
    if (service === 'calendar') continueUrl = 'https://calendar.google.com/calendar/';
    else if (service === 'drive') continueUrl = 'https://drive.google.com/';
    else if (service === 'meet') continueUrl = 'https://meet.google.com/';
    return `https://accounts.google.com/AccountChooser?Email=${encodeURIComponent(email)}&continue=${encodeURIComponent(continueUrl)}`;
}

// Smart Sorting:
// 1. Active account at position 0
// 2. 100% Unconsumed / Clean available accounts
// 3. Partially consumed available accounts (highest remaining quota first)
// 4. Rate-limited/Exhausted accounts ordered by reset_at ascending (the one renewing soonest comes first!)
// Smart Sorting:
// Rank 0: Active Account (pinned at very top)
// Rank 1: Recommended Next Candidate (e.g. drive@tilab.com.br) -> immediately below active!
// Rank 2: 100% Clean / Unused available accounts
// Rank 3: Partially consumed available accounts (lowest usage first)
// Rank 4: Blocked / Rate-limited accounts ordered by reset_at ascending (renewing soonest first!)
function sortAccountsSmart(accountsList) {
    let activeEmailForSel = null;
    let suggestEmailForSel = null;

    const isLocalMachineSelected = !state.selectedMachineId || 
        (state.currentMachine && state.selectedMachineId === state.currentMachine.machine_id);

    if (isLocalMachineSelected) {
        // Direct live API data for local computer (updated every 5s)
        activeEmailForSel = state.accounts.find(a => a.id === state.activeAccountId)?.email;
        suggestEmailForSel = state.liveSuggestEmail;
    } else {
        // Read from DB snapshot for other computers
        if (state.snapshots && state.selectedMachineId) {
            const snap = state.snapshots.find(s => s.machine_id === state.selectedMachineId);
            if (snap) activeEmailForSel = snap.email;
        }
    }

    return [...accountsList].sort((a, b) => {
        const aActive = activeEmailForSel && a.email === activeEmailForSel;
        const bActive = activeEmailForSel && b.email === activeEmailForSel;
        if (aActive && !bActive) return -1;
        if (!aActive && bActive) return 1;

        // Rank 1: Recommended Candidate
        const aSuggest = suggestEmailForSel && a.email === suggestEmailForSel;
        const bSuggest = suggestEmailForSel && b.email === suggestEmailForSel;
        if (aSuggest && !bSuggest) return -1;
        if (!aSuggest && bSuggest) return 1;

        const aBlocked = a.status === 'exhausted' || a.status === 'rate_limited';
        const bBlocked = b.status === 'exhausted' || b.status === 'rate_limited';

        if (!aBlocked && bBlocked) return -1;
        if (aBlocked && !bBlocked) return 1;

        if (aBlocked && bBlocked) {
            const aReset = a.reset_at ? new Date(a.reset_at).getTime() : Infinity;
            const bReset = b.reset_at ? new Date(b.reset_at).getTime() : Infinity;
            return aReset - bReset;
        }

        const aTokens = (a.tokenGemini || 0) + (a.tokenClaude || 0) + (a.tokenGpt || 0);
        const bTokens = (b.tokenGemini || 0) + (b.tokenClaude || 0) + (b.tokenGpt || 0);
        const aExh = (a.exhausted_models || []).length;
        const bExh = (b.exhausted_models || []).length;

        if (aExh !== bExh) return aExh - bExh;
        if (aTokens !== bTokens) return aTokens - bTokens;

        return a.name.localeCompare(b.name);
    });
}

function formatResetRemaining(resetAtStr) {
    if (!resetAtStr) return null;
    try {
        const target = new Date(resetAtStr);
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

    const filtered = state.accounts.filter(acc => {
        const matchesCategory = state.currentFilter === 'all' || acc.category === state.currentFilter;
        const matchesSearch = acc.name.toLowerCase().includes(state.searchQuery) || acc.email.toLowerCase().includes(state.searchQuery);
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
    const isLocalMachineSelected = !state.selectedMachineId || 
        (state.currentMachine && state.selectedMachineId === state.currentMachine.machine_id);

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
        card.dataset.id = acc.id;
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
        let quotaBarsHtml = '';
        let qG = 0.0, qC = 0.0, qP = 0.0, hasLiveQuota = false;

        if (isActive) {
            if (isLocalMachineSelected && state.liveQuota) {
                qG = state.liveQuota.gemini ?? 1.0;
                qC = state.liveQuota.claude ?? 0.0;
                qP = state.liveQuota.gpt    ?? 0.0;
                hasLiveQuota = true;
            } else if (selectedSnap) {
                qG = (selectedSnap.gemini_pct ?? 100) / 100;
                qC = (selectedSnap.claude_pct ?? 0) / 100;
                qP = (selectedSnap.gpt_pct ?? 0) / 100;
                hasLiveQuota = true;
            }
        }

        if (hasLiveQuota) {
            const renderBar = (frac, label) => {
                const pct = Math.round(frac * 100);
                const col = pct > 50 ? '#34d399' : pct > 15 ? '#f59e0b' : '#ef4444';
                return `
                <div style="display:flex; align-items:center; gap:4px; margin-bottom:2px;">
                    <span style="font-size:0.58rem; color:${col}; width:44px; font-weight:600;">${label}</span>
                    <div style="flex:1; height:4px; background:rgba(255,255,255,0.08); border-radius:2px; overflow:hidden;">
                        <div style="height:100%; width:${pct}%; background:${col}; border-radius:2px; transition:width 0.4s;"></div>
                    </div>
                    <span style="font-size:0.55rem; color:${col}; width:30px; text-align:right; font-family:monospace; font-weight:bold;">${pct}%</span>
                </div>`;
            };

            quotaBarsHtml = `
            <div style="margin-top:4px; padding-top:4px; border-top:1px solid rgba(255,255,255,0.06);">
                <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:3px;">
                    <span style="font-size:0.54rem; color:#9ca3af; font-weight:600;"><i class="fa-solid fa-database" style="font-size:0.5rem;"></i> Quota no SQLite</span>
                    <span style="font-size:0.5rem; color:#6b7280;">Histórico</span>
                </div>
                ${renderBar(qG, 'Gemini')}
                ${renderBar(qC, 'Claude')}
                ${renderBar(qP, 'GPT')}
            </div>`;
        }

        const isSuggest = state.liveSuggestEmail && acc.email === state.liveSuggestEmail && !isActive;
        const resetLabel = isBlocked && acc.reset_at ? formatResetRemaining(acc.reset_at) : null;
        const resetBadge = resetLabel ? `<span style="font-size:0.56rem; color:#f87171; background:rgba(239,68,68,0.12); padding:1px 5px; border-radius:3px; margin-left:4px;">${resetLabel}</span>` : '';
        const suggestBadge = isSuggest ? `<span style="font-size:0.56rem; color:#34d399; background:rgba(52,211,153,0.15); border:1px solid rgba(52,211,153,0.3); padding:1px 6px; border-radius:3px; margin-left:4px; font-weight:600;"><i class="fa-solid fa-star" style="font-size:0.5rem;"></i> Sugerida</span>` : '';

        card.innerHTML = `
            <div class="card-header" style="margin-bottom:0; align-items:center; display:flex; justify-content:space-between;">
                <div style="display:flex; align-items:center; gap:5px; overflow:hidden; flex:1; min-width:0;">
                    ${avatarHtml}
                    <a href="${getChooserUrl(acc.email, 'gmail')}" target="_blank" class="launch-btn btn-gmail" title="Abrir Gmail" style="flex-shrink:0; width:20px; height:20px; padding:0; display:flex; align-items:center; justify-content:center; border-radius:4px; font-size:0.7rem;">
                        <i class="fa-solid fa-envelope"></i>
                    </a>
                    <span style="font-size:0.75rem; font-weight:500; color:var(--text-primary); white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${acc.email}</span>
                </div>
                <div style="display:flex; gap:2px; align-items:center; flex-shrink:0; margin-left:4px;">
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

        card.querySelector('.btn-edit').addEventListener('click', (e) => { e.stopPropagation(); openModal(acc.id); });
        card.querySelector('.btn-delete').addEventListener('click', (e) => {
            e.stopPropagation();
            if (confirm(`Remover "${acc.email}"?`)) deleteAccount(acc.id);
        });
        card.querySelector('.btn-activate').addEventListener('click', (e) => {
            e.stopPropagation(); setActiveAccount(e.currentTarget.dataset.id);
        });
        card.querySelector('.status-pill').addEventListener('click', (e) => {
            e.stopPropagation(); toggleAccountStatus(e.currentTarget.dataset.id);
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

function fetchLive() {
    // When served from Vercel (https://), connect to the local server (http://localhost:8000)
    // Chrome/Edge allow https → http://localhost as a special case (localhost is considered secure).
    const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
    const liveEndpoint = isLocal ? '/api/live' : 'http://localhost:8000/api/live';

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 4000);

    fetch(liveEndpoint, { signal: controller.signal })
        .then(res => { clearTimeout(timeoutId); return res.json(); })
        .then(data => {
            const agentEmail = data.agent && data.agent.email;
            const agentName = data.agent && data.agent.name;
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
                    localStorage.setItem('antigravity_active_account_id', state.activeAccountId);
                }
            }

            let geminiMax = 0, claudeMin = 1.0, gptMin = 1.0;
            let hasGemini = false, hasClaude = false, hasGpt = false;

            for (const [lbl, info] of Object.entries(modelQuotas)) {
                const rem = typeof info === 'object' ? info.remaining : info;
                if (/gemini/i.test(lbl)) {
                    geminiMax = Math.max(geminiMax, rem);
                    hasGemini = true;
                } else if (/claude/i.test(lbl)) {
                    claudeMin = Math.min(claudeMin, rem);
                    hasClaude = true;
                } else if (/gpt|openai/i.test(lbl)) {
                    gptMin = Math.min(gptMin, rem);
                    hasGpt = true;
                }
            }

            state.liveQuota = {
                gemini: hasGemini ? geminiMax : 1.0,
                claude: hasClaude ? claudeMin : 0.0,
                gpt:    hasGpt    ? gptMin    : 0.0
            };
            state.liveModelQuotas = modelQuotas;
            state.liveSuggestEmail = suggestEmail;
            state.liveLastCheck = lastCheck;

            // Save active machine details
            if (data.machine) {
                state.currentMachine = data.machine;
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

            // Fetch other machines and snapshots for multi-desktop selector
            const machinesUrl = isLocal ? '/api/machines' : 'http://localhost:8000/api/machines';
            const snapshotsUrl = isLocal ? '/api/snapshots' : 'http://localhost:8000/api/snapshots';

            Promise.all([
                fetch(machinesUrl).then(r => r.json()),
                fetch(snapshotsUrl).then(r => r.json())
            ])
            .then(([machines, snapshots]) => {
                state.machines = machines;
                state.snapshots = snapshots;
                renderAccounts();
                updateLiveBanner(agentEmail, suggestEmail, lastCheck, false, data.suggestReason);
            })
            .catch(() => {
                renderAccounts();
                updateLiveBanner(agentEmail, suggestEmail, lastCheck, false, data.suggestReason);
            });
        })
        .catch(err => {
            clearTimeout(timeoutId);
            updateLiveBanner(null, null, null, true);
        });
}

function updateLiveBanner(agentEmail, suggestEmail, lastCheck, isOffline = false, suggestReason = '') {
    let banner = document.getElementById('live-banner');
    if (!banner) {
        banner = document.createElement('div');
        banner.id = 'live-banner';
        banner.style.cssText = 'position:sticky; top:0; z-index:50; padding:6px 12px; font-size:0.65rem; display:flex; align-items:center; justify-content:space-between; gap:8px; border-bottom: 1px solid rgba(255,255,255,0.06); transition: all 0.3s;';
        const grid = document.getElementById('accounts-grid');
        if (grid && grid.parentNode) grid.parentNode.insertBefore(banner, grid);
    }
    
    if (isOffline) {
        banner.style.background = 'rgba(239, 68, 68, 0.1)';
        banner.innerHTML = `
            <div style="display:flex; align-items:center; gap:8px;">
                <span style="color:#f87171; font-size:0.6rem; font-weight:700;">⚠ Servidor local offline</span>
                <span style="color:#9ca3af; font-size:0.6rem;">Execute o start-server.vbs para reativar o monitoramento</span>
            </div>
            <span style="color:#6b7280; font-size:0.56rem; font-weight:bold;">DESKTOP DISCONNECTED</span>
        `;
        return;
    }

    const ts = lastCheck ? new Date(lastCheck).toLocaleTimeString('pt-BR', {hour:'2-digit', minute:'2-digit'}) : '--:--';
    
    // Build machine selector dropdown
    let machineOptions = '';
    if (state.machines && state.machines.length > 0) {
        state.machines.forEach(m => {
            const isSel = m.machine_id === state.selectedMachineId ? 'selected' : '';
            const activeMark = m.machine_id === (state.currentMachine && state.currentMachine.machine_id) ? ' (Este PC)' : '';
            machineOptions += `<option value="${m.machine_id}" ${isSel}>💻 ${m.hostname}${activeMark}</option>`;
        });
    } else {
        const curHost = (state.currentMachine && state.currentMachine.hostname) || 'Localhost';
        machineOptions = `<option value="local">💻 ${curHost}</option>`;
    }

    const selectorHtml = `
        <select id="machine-selector" style="background:rgba(255,255,255,0.06); border:1px solid rgba(255,255,255,0.1); color:#fff; font-size:0.6rem; padding:2px 6px; border-radius:4px; outline:none; font-weight:600; cursor:pointer;">
            ${machineOptions}
        </select>
    `;

    const agentPart = agentEmail
        ? `<span style="color:#a78bfa; font-weight:600;"><i class="fa-solid fa-robot" style="font-size:0.6rem;"></i> Ativa: ${agentEmail}</span>`
        : `<span style="color:#6b7280;">Nenhum agente ativo</span>`;

    const sugTitle = suggestReason ? `title="${suggestReason}"` : '';
    const suggestPart = suggestEmail
        ? `<span style="color:#34d399; font-weight:600; cursor:pointer;" onclick="openSuggestLogin('${suggestEmail}')" ${sugTitle}><i class="fa-solid fa-forward-step"></i> ⭐ Sugestão: ${suggestEmail}</span>`
        : '';

    banner.innerHTML = `
        <div style="display:flex; align-items:center; gap:12px; flex-wrap:wrap;">
            ${selectorHtml}
            <span style="color:#6b7280; font-size:0.6rem;">⚡ ${ts}</span>
            ${agentPart}
            ${suggestPart}
        </div>
        <span style="color:#10b981; font-size:0.56rem; font-weight:bold;">LIVE DATABASE</span>
    `;

    // Dropdown change listener
    const selEl = document.getElementById('machine-selector');
    if (selEl) {
        selEl.addEventListener('change', (e) => {
            state.selectedMachineId = e.target.value;
            renderAccounts();
        });
    }

    const agentAcc = agentEmail ? state.accounts.find(a => a.email === agentEmail) : null;
    if (agentAcc && (agentAcc.status === 'exhausted' || agentAcc.status === 'rate_limited')) {
        banner.style.background = 'rgba(239,68,68,0.12)';
    } else {
        banner.style.background = 'rgba(16,185,129,0.06)';
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
