(() => {
  const app = document.getElementById('app');
  const feedEl = document.getElementById('feed');
  const playersEl = document.getElementById('players');
  const shadowEl = document.getElementById('shadowban');
  const bansEl = document.getElementById('bans');
  const casesEl = document.getElementById('cases');
  const timelineEl = document.getElementById('timeline');
  const watchEl = document.getElementById('watchlist');
  const tierBadge = document.getElementById('tierBadge');
  const safeBadge = document.getElementById('safeBadge');
  const onlineCount = document.getElementById('onlineCount');
  const safeToggle = document.getElementById('safeToggle');
  const toastBar = document.getElementById('toastBar');
  const idResult = document.getElementById('idResult');

  let state = {
    feed: [], players: [], shadowban: [], bans: [], cases: [], watchlist: [],
    safeMode: true, tier: 'FREE', stats: {}
  };
  let sevFilter = 'ALL';

  function nui(name, data = {}) {
    return fetch(`https://lucidguard/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data)
    }).catch(() => {});
  }

  function showToast(msg) {
    if (!toastBar) return;
    toastBar.textContent = msg || '';
    toastBar.hidden = !msg;
    if (msg) setTimeout(() => { toastBar.hidden = true; toastBar.textContent = ''; }, 4000);
  }

  function sevClass(sev) {
    return String(sev || 'INFO').toUpperCase();
  }

  function escapeHtml(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function fmtTime(ts) {
    if (!ts) return '';
    return new Date(ts * 1000).toLocaleTimeString();
  }

  function updateStats() {
    const n = (state.stats && state.stats.online) || (state.players && state.players.length) || 0;
    onlineCount.textContent = `${n} online`;
    document.getElementById('statOnline').textContent = n;
    document.getElementById('statFeed').textContent = (state.stats && state.stats.feedSize) || (state.feed || []).length || 0;
    document.getElementById('statCases').textContent = (state.stats && state.stats.cases) || (state.cases || []).length || 0;
    document.getElementById('statSb').textContent = (state.stats && state.stats.shadowban) || (state.shadowban || []).length || 0;
    const watchedOnline = (state.players || []).filter((p) => p.watched).length;
    document.getElementById('statWatch').textContent =
      (state.stats && state.stats.watched) || Math.max(watchedOnline, (state.watchlist || []).length) || 0;
  }

  function renderFeed() {
    let items = (state.feed || []).slice().reverse();
    if (sevFilter !== 'ALL') {
      items = items.filter((e) => {
        if (sevFilter === 'SYSTEM') return e.type !== 'detection';
        return String(e.severity || '').toUpperCase() === sevFilter;
      });
    }
    feedEl.innerHTML = items.map((e) => {
      if (e.type === 'detection') {
        return `<div class="feed-item">
          <div class="sev ${sevClass(e.severity)}">${escapeHtml(e.severity || 'INFO')}</div>
          <div class="body">
            <strong>${escapeHtml(e.detection || 'DETECTION')} — ${escapeHtml(e.player || '?')} (#${e.id ?? '?'})</strong>
            <span>${escapeHtml(e.details || '')}</span>
          </div>
          <div class="meta-r">risk ${e.risk ?? 0}<br/>${fmtTime(e.ts)}</div>
        </div>`;
      }
      return `<div class="feed-item">
        <div class="sev SYSTEM">${escapeHtml((e.type || 'system').toUpperCase())}</div>
        <div class="body"><strong>${escapeHtml(e.message || e.player || JSON.stringify(e))}</strong></div>
        <div class="meta-r">${fmtTime(e.ts)}</div>
      </div>`;
    }).join('') || '<div class="feed-item"><div class="sev INFO">IDLE</div><div class="body"><strong>No detections yet</strong><span>Live stream while the panel is open.</span></div></div>';
  }

  function renderPlayers() {
    const watchOnly = document.getElementById('watchOnly')?.checked;
    const list = (state.players || []).filter((p) => !watchOnly || p.watched);
    playersEl.innerHTML = list.map((p) => `
      <div class="player-row">
        <div>#${p.id}</div>
        <div>
          <strong>${escapeHtml(p.name || 'unknown')}</strong>
          ${p.admin ? '<span class="tag">admin</span>' : ''}
          ${p.watched ? '<span class="tag">WATCH</span>' : ''}
        </div>
        <div class="risk">R ${p.risk || 0}${p.trust != null ? ` · T ${p.trust}` : ''}</div>
        <div class="muted">${p.ping || 0}ms</div>
        <div class="actions">
          <button class="btn sm" data-act="ss" data-id="${p.id}" type="button">Shot</button>
          <button class="btn sm" data-act="spec" data-id="${p.id}" type="button">Spec</button>
          <button class="btn sm" data-act="freeze" data-id="${p.id}" type="button">Freeze</button>
          <button class="btn sm" data-act="warn" data-id="${p.id}" type="button">Warn</button>
          <button class="btn sm" data-act="watch" data-id="${p.id}" type="button">Watch</button>
          <button class="btn sm" data-act="timeline" data-id="${p.id}" type="button">TL</button>
          <button class="btn sm" data-act="clear" data-id="${p.id}" type="button">Clr</button>
          <button class="btn sm" data-act="kick" data-id="${p.id}" type="button">Kick</button>
          <button class="btn sm danger" data-act="ban" data-id="${p.id}" type="button">Ban</button>
        </div>
      </div>
    `).join('') || '<div class="player-row"><div></div><div>No players</div></div>';
  }

  function renderOps() {
    shadowEl.innerHTML = (state.shadowban || []).map((s) => `
      <div class="feed-item">
        <div class="sev SB">SB</div>
        <div class="body">
          <strong>${escapeHtml(s.name || '?')} (#${s.id})</strong>
          <span>${escapeHtml(s.detection || '')} · ${s.remaining || 0}s left</span>
        </div>
      </div>
    `).join('') || '<div class="feed-item"><div class="sev INFO">IDLE</div><div class="body"><strong>No shadowbans queued</strong></div></div>';

    bansEl.innerHTML = (state.bans || []).map((b) => `
      <div class="feed-item">
        <div class="sev BAN">BAN</div>
        <div class="body">
          <strong>#${b.id} ${escapeHtml(b.detection || 'BAN')}</strong>
          <span>${escapeHtml(b.reason || '')} · ${escapeHtml(b.license || b.discord || '')}</span>
        </div>
      </div>
    `).join('') || '<div class="feed-item"><div class="sev INFO">IDLE</div><div class="body"><strong>No recent bans</strong></div></div>';
  }

  function renderCases() {
    if (!casesEl) return;
    casesEl.innerHTML = (state.cases || []).map((c) => `
      <div class="feed-item">
        <div class="sev ${sevClass(c.severity)}">#${c.id}</div>
        <div class="body">
          <strong>${escapeHtml(c.detection || '?')} — ${escapeHtml(c.player || '?')} (#${c.playerId ?? '?'})</strong>
          <span>${escapeHtml(c.details || '')} · ${escapeHtml(c.status || 'open')} · shots ${c.screenshots || 0}</span>
        </div>
        <div class="actions">
          <button class="btn sm" data-case="note" data-id="${c.id}" type="button">Note</button>
          <button class="btn sm" data-case="close" data-id="${c.id}" type="button">Close</button>
          <button class="btn sm" data-case="spec" data-id="${c.playerId}" type="button">Spec</button>
          <button class="btn sm" data-case="ss" data-id="${c.playerId}" type="button">Shot</button>
        </div>
      </div>
    `).join('') || '<div class="feed-item"><div class="sev INFO">IDLE</div><div class="body"><strong>No evidence cases</strong><span>HIGH/CRITICAL open cases automatically.</span></div></div>';
  }

  function renderWatch() {
    if (!watchEl) return;
    const list = state.watchlist || [];
    watchEl.innerHTML = list.map((w) => `
      <div class="feed-item">
        <div class="sev WATCH">WATCH</div>
        <div class="body">
          <strong>${escapeHtml(w.name || '?')} (#${w.id ?? w.playerId ?? '?'})</strong>
          <span>${escapeHtml(w.reason || '')}</span>
        </div>
      </div>
    `).join('') || '<div class="feed-item"><div class="sev INFO">IDLE</div><div class="body"><strong>Watchlist empty</strong><span>Add players from Tools or Players.</span></div></div>';
  }

  function renderTimeline(events, targetId) {
    if (!timelineEl) return;
    const list = events || [];
    timelineEl.innerHTML = `<div class="feed-item"><div class="sev INFO">TL</div><div class="body"><strong>Timeline #${targetId || '?'}</strong></div></div>` +
      (list.map((e) => `
        <div class="feed-item">
          <div class="sev ${sevClass(e.severity)}">${escapeHtml(e.severity || 'EVT')}</div>
          <div class="body">
            <strong>${escapeHtml(e.detection || '')}</strong>
            <span>${escapeHtml(e.details || '')}</span>
          </div>
          <div class="meta-r">${fmtTime(e.ts)}</div>
        </div>
      `).join('') || '<div class="feed-item"><div class="body"><span>No events</span></div></div>');
  }

  function applyState(data) {
    if (!data) return;
    state = Object.assign(state, data);
    tierBadge.textContent = state.tier || 'FREE';
    const safe = !!state.safeMode;
    safeBadge.textContent = safe ? 'SAFE MODE' : 'ENFORCE';
    safeBadge.classList.toggle('warn', safe);
    safeBadge.classList.toggle('off', !safe);
    safeToggle.checked = safe;
    updateStats();
    renderFeed();
    renderPlayers();
    renderOps();
    renderCases();
    renderWatch();
  }

  function num(id) {
    return Number(document.getElementById(id)?.value);
  }

  document.querySelectorAll('.tab').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach((b) => b.classList.remove('active'));
      document.querySelectorAll('.panel').forEach((p) => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
    });
  });

  document.querySelectorAll('.chip').forEach((chip) => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.chip').forEach((c) => c.classList.remove('active'));
      chip.classList.add('active');
      sevFilter = chip.dataset.sev || 'ALL';
      renderFeed();
    });
  });

  document.getElementById('btnClose').addEventListener('click', () => nui('close'));
  document.getElementById('btnRefresh').addEventListener('click', () => nui('refresh'));
  document.getElementById('btnClearFeed').addEventListener('click', () => nui('clearFeed'));
  safeToggle.addEventListener('change', () => nui('setSafeMode', { enabled: safeToggle.checked }));
  document.getElementById('watchOnly')?.addEventListener('change', renderPlayers);

  document.getElementById('btnAnnounce')?.addEventListener('click', () => {
    const message = document.getElementById('announceText').value.trim();
    if (!message) return showToast('Enter an announce message');
    nui('announce', { message });
    document.getElementById('announceText').value = '';
    showToast('Announce sent');
  });

  document.getElementById('btnQuickKick')?.addEventListener('click', () => {
    const id = num('quickId');
    const reason = document.getElementById('quickReason').value || 'Kicked by LucidGuard';
    if (!id) return showToast('Need player ID');
    nui('kick', { id, reason });
  });

  document.getElementById('btnQuickBan')?.addEventListener('click', () => {
    const id = num('quickId');
    const reason = document.getElementById('quickReason').value || 'Banned by LucidGuard';
    if (!id) return showToast('Need player ID');
    nui('ban', { id, reason });
  });

  document.getElementById('btnQuickWarn')?.addEventListener('click', () => {
    const id = num('quickId');
    const reason = document.getElementById('quickReason').value || 'Warned by staff';
    if (!id) return showToast('Need player ID');
    nui('warn', { id, reason });
    showToast(`Warned #${id}`);
  });

  document.getElementById('btnShadow')?.addEventListener('click', () => {
    const id = num('sbId');
    if (!id) return showToast('Need player ID');
    nui('shadowban', { id });
    showToast(`Shadowban queued #${id}`);
  });

  document.getElementById('btnWatch')?.addEventListener('click', () => {
    const id = num('watchId');
    const reason = document.getElementById('watchReason').value || 'F7 panel';
    if (!id) return showToast('Need player ID');
    nui('watch', { id, reason });
    showToast(`Watching #${id}`);
    nui('refresh');
  });

  document.getElementById('btnFreeze')?.addEventListener('click', () => {
    const id = num('freezeId');
    if (!id) return showToast('Need player ID');
    nui('evidenceFreeze', { id, freeze: true });
    showToast(`Froze #${id}`);
  });

  document.getElementById('btnUnfreeze')?.addEventListener('click', () => {
    const id = num('freezeId');
    if (!id) return showToast('Need player ID');
    nui('evidenceFreeze', { id, freeze: false });
    showToast(`Unfroze #${id}`);
  });

  document.getElementById('btnShot')?.addEventListener('click', () => {
    const id = num('ssId');
    if (!id) return showToast('Need player ID');
    nui('evidenceScreenshot', { id });
    showToast('Screenshot requested');
  });

  document.getElementById('btnIds')?.addEventListener('click', () => {
    const id = num('idLookup');
    if (!id) return showToast('Need player ID');
    nui('lookupIds', { id });
  });

  document.getElementById('btnClearRisk')?.addEventListener('click', () => {
    const id = num('clearRiskId') || num('recheckId');
    const target = num('clearRiskId');
    if (!target) return showToast('Need player ID');
    nui('clearRisk', { id: target });
    showToast(`Cleared risk #${target}`);
    nui('refresh');
  });

  document.getElementById('btnRecheck')?.addEventListener('click', () => {
    const id = num('clearRiskId');
    if (!id) return showToast('Need player ID in risk field');
    nui('forceRecheck', { id });
    showToast(`Force recheck #${id}`);
  });

  document.getElementById('btnTestCaseHook')?.addEventListener('click', () => {
    nui('testCaseWebhook', {});
    showToast('Test case webhook requested');
  });

  playersEl.addEventListener('click', (ev) => {
    const btn = ev.target.closest('button[data-act]');
    if (!btn) return;
    const id = Number(btn.dataset.id);
    const act = btn.dataset.act;
    if (act === 'kick') {
      const reason = prompt('Kick reason', 'Kicked by LucidGuard') || 'Kicked by LucidGuard';
      nui('kick', { id, reason });
    } else if (act === 'ban') {
      const reason = prompt('Ban reason', 'Banned by LucidGuard') || 'Banned by LucidGuard';
      nui('ban', { id, reason });
    } else if (act === 'warn') {
      const reason = prompt('Warn message', 'Warned by staff') || 'Warned by staff';
      nui('warn', { id, reason });
      showToast(`Warned #${id}`);
    } else if (act === 'watch') {
      nui('watch', { id, reason: 'F7 players tab' });
      showToast(`Watching #${id}`);
      nui('refresh');
    } else if (act === 'ss') {
      nui('evidenceScreenshot', { id });
      showToast('Screenshot requested');
    } else if (act === 'spec') {
      nui('evidenceSpectate', { id });
      showToast(`Spectate #${id}`);
    } else if (act === 'freeze') {
      nui('evidenceFreeze', { id, freeze: true });
      showToast(`Froze #${id}`);
    } else if (act === 'timeline') {
      nui('evidenceTimeline', { id });
      document.querySelector('.tab[data-tab="cases"]')?.click();
    } else if (act === 'clear') {
      nui('clearRisk', { id });
      showToast(`Cleared risk #${id}`);
      nui('refresh');
    }
  });

  casesEl?.addEventListener('click', (ev) => {
    const btn = ev.target.closest('button[data-case]');
    if (!btn) return;
    const id = Number(btn.dataset.id);
    const act = btn.dataset.case;
    if (act === 'note') {
      const note = prompt('Case note') || '';
      if (note) nui('evidenceNote', { id, note });
    } else if (act === 'close') {
      nui('evidenceClose', { id });
    } else if (act === 'spec') {
      nui('evidenceSpectate', { id });
    } else if (act === 'ss') {
      nui('evidenceScreenshot', { id });
    }
  });

  document.getElementById('btnCasesRefresh')?.addEventListener('click', () => nui('evidenceList'));

  window.addEventListener('message', (event) => {
    const msg = event.data || {};
    if (msg.action === 'open') {
      app.classList.remove('hidden');
      applyState(msg.data || {});
      nui('evidenceList');
    } else if (msg.action === 'close') {
      app.classList.add('hidden');
    } else if (msg.action === 'data') {
      applyState(msg.data || {});
    } else if (msg.action === 'feed') {
      state.feed = state.feed || [];
      state.feed.push(msg.entry);
      if (state.feed.length > 200) state.feed.shift();
      updateStats();
      renderFeed();
    } else if (msg.action === 'toast') {
      showToast(msg.message || '');
    } else if (msg.action === 'cases') {
      state.cases = msg.cases || [];
      renderCases();
      updateStats();
    } else if (msg.action === 'timeline') {
      renderTimeline(msg.events, msg.targetId);
    } else if (msg.action === 'identifiers') {
      const d = msg.data || {};
      const ids = d.identifiers || {};
      idResult.textContent = Object.keys(ids).length
        ? Object.entries(ids).map(([k, v]) => `${k}: ${v}`).join('\n')
        : (msg.message || 'No identifiers');
      showToast(d.name ? `IDs for ${d.name}` : 'Lookup done');
    }
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') nui('close');
  });
})();
