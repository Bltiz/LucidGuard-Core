(() => {
  const login = document.getElementById('login');
  const app = document.getElementById('app');
  const drawer = document.getElementById('drawer');
  const titles = {
    live: ['Live feed', 'Streaming detections · risk · trust'],
    players: ['Players', 'Click a row for quick actions'],
    tools: ['Staff tools', 'Announce · punish · watch · capture'],
    ops: ['Ops', 'Shadowban queue and BanStore'],
    cases: ['Cases', 'Evidence workflow'],
    watch: ['Watchlist', 'Players under tighter scrutiny'],
    controls: ['Controls', 'Safe Mode · ambience · connection']
  };

  let token = sessionStorage.getItem('lg_web_token') || '';
  let demo = sessionStorage.getItem('lg_web_demo') === '1';
  let state = emptyState();
  let pollTimer = null;
  let sevFilter = 'ALL';
  let query = '';
  let selected = null;

  function emptyState() {
    return { feed: [], players: [], shadowban: [], bans: [], cases: [], watchlist: [], safeMode: true, tier: 'ADVANCED', stats: {} };
  }

  function applyTheme(theme) {
    const snow = (theme && theme.snow) || 'orange';
    const accents = {
      orange: '#f97316',
      gold: '#fbbf24',
      purple: '#c084fc',
      teal: '#2dd4bf',
      rose: '#fb7185'
    };
    document.documentElement.style.setProperty('--accent', accents[snow] || accents.orange);
    document.documentElement.style.setProperty('--accent2', accents[snow] || accents.orange);
    if (window.LucidSnow) window.LucidSnow.setPalette(snow);
    const sel = document.getElementById('themeSnow');
    if (sel) sel.value = snow;
  }

  function demoState() {
    const now = Math.floor(Date.now() / 1000);
    return {
      tier: 'ADVANCED',
      safeMode: true,
      version: '2.0.1',
      theme: { snow: 'orange', accent: '#f97316' },
      stats: { online: 4, feedSize: 6, cases: 2, shadowban: 1, watched: 2 },
      feed: [
        { type: 'detection', ts: now - 40, severity: 'CRITICAL', detection: 'MONEY_MENU_TRAP', player: 'xCheater', id: 12, details: 'Client fired money/menu trap event', risk: 24 },
        { type: 'detection', ts: now - 90, severity: 'HIGH', detection: 'ESP_WALL_INTEREST', player: 'SilentAimGod', id: 7, details: 'Looked at occluded players', risk: 18 },
        { type: 'detection', ts: now - 120, severity: 'HIGH', detection: 'SMOOTH_AIMBOT', player: 'SilentAimGod', id: 7, details: 'Aim lock ratio 78%', risk: 12 },
        { type: 'system', ts: now - 150, message: 'AUTO-WATCH SilentAimGod trust=48 (SMOOTH_AIMBOT)' },
        { type: 'shadowban', ts: now - 200, message: 'Shadowban queued xCheater (#12) in 72s — MONEY_MENU_TRAP' },
        { type: 'case', ts: now - 210, message: 'Case #2 opened: MONEY_MENU_TRAP on xCheater (CRITICAL)' }
      ],
      players: [
        { id: 12, name: 'xCheater', ping: 62, risk: 24, trust: 18, watched: true, admin: false, violations: 5 },
        { id: 7, name: 'SilentAimGod', ping: 41, risk: 18, trust: 48, watched: true, admin: false, violations: 3 },
        { id: 3, name: 'OnlyLucidVibes', ping: 28, risk: 0, trust: 100, watched: false, admin: true, violations: 0 },
        { id: 9, name: 'NeighborhoodKid', ping: 55, risk: 3, trust: 94, watched: false, admin: false, violations: 1 }
      ],
      shadowban: [{ id: 12, name: 'xCheater', detection: 'MONEY_MENU_TRAP', remaining: 72 }],
      bans: [{ id: 1042, detection: 'RESOURCE_INJECTION', reason: 'New started resources mid-session', license: 'license:a1b2c3...' }],
      cases: [
        { id: 2, playerId: 12, player: 'xCheater', detection: 'MONEY_MENU_TRAP', severity: 'CRITICAL', details: 'Trap event', status: 'open', screenshots: 1 },
        { id: 1, playerId: 7, player: 'SilentAimGod', detection: 'ESP_WALL_INTEREST', severity: 'HIGH', details: 'Wall interest', status: 'open', screenshots: 0 }
      ],
      watchlist: [
        { license: 'license:aaa', reason: 'auto:SMOOTH_AIMBOT', hits: 3, name: 'SilentAimGod' },
        { license: 'license:bbb', reason: 'manual:staff', hits: 1, name: 'xCheater' }
      ]
    };
  }

  function api(path, opts = {}) {
    const headers = Object.assign({ 'Content-Type': 'application/json' }, opts.headers || {});
    if (token) headers['X-LG-Token'] = token;
    return fetch(path, Object.assign({}, opts, { headers })).then(async (r) => {
      const text = await r.text();
      let data = null;
      try { data = text ? JSON.parse(text) : null; } catch (_) { data = { raw: text }; }
      if (!r.ok) throw Object.assign(new Error((data && data.error) || r.statusText), { status: r.status, data });
      return data;
    });
  }

  function showToast(msg) {
    const el = document.getElementById('toast');
    if (!el) return;
    el.textContent = msg || '';
    if (msg) setTimeout(() => { el.textContent = ''; }, 3500);
  }

  function esc(s) {
    return String(s ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function fmt(ts) {
    if (!ts) return '';
    return new Date(ts * 1000).toLocaleTimeString();
  }

  function matchQuery(text) {
    if (!query) return true;
    return String(text || '').toLowerCase().includes(query);
  }

  async function action(path, body) {
    if (demo) {
      showToast(`Demo: ${path}`);
      return;
    }
    await api(path, { method: 'POST', body: JSON.stringify(body || {}) });
    showToast('Done');
    refresh();
  }

  function openDrawer(p) {
    selected = p;
    drawer.classList.remove('hidden');
    document.getElementById('drawerTitle').textContent = `${p.name} (#${p.id})`;
    document.getElementById('drawerBody').innerHTML = `
      <div><strong>Risk</strong> ${p.risk || 0} · <strong>Trust</strong> ${p.trust ?? '—'} · <strong>Ping</strong> ${p.ping || 0}ms</div>
      <div><strong>Violations</strong> ${p.violations || 0}${p.watched ? ' · <span class="tag">WATCH</span>' : ''}${p.admin ? ' · admin' : ''}</div>
    `;
    document.getElementById('drawerActions').innerHTML = `
      <button class="btn sm" data-d="kick" type="button">Kick</button>
      <button class="btn sm danger" data-d="ban" type="button">Ban</button>
      <button class="btn sm" data-d="warn" type="button">Warn</button>
      <button class="btn sm" data-d="watch" type="button">Watch</button>
      <button class="btn sm" data-d="shadow" type="button">Shadowban</button>
      <button class="btn sm" data-d="shot" type="button">Screenshot</button>
      <button class="btn sm" data-d="freeze" type="button">Freeze</button>
      <button class="btn sm ghost" data-d="unfreeze" type="button">Unfreeze</button>
    `;
  }

  function render() {
    document.getElementById('sideTier').textContent = state.tier || 'ADVANCED';
    document.getElementById('sideSafe').textContent = state.safeMode ? 'SAFE MODE' : 'ENFORCE';
    document.getElementById('sideSafe').classList.toggle('warn', !!state.safeMode);
    document.getElementById('sideOnline').textContent = `${(state.stats && state.stats.online) || (state.players || []).length} online`;
    document.getElementById('modeBadge').textContent = demo ? 'DEMO' : 'LIVE';
    document.getElementById('safeToggle').checked = !!state.safeMode;
    document.getElementById('statOnline').textContent = (state.stats && state.stats.online) || (state.players || []).length || 0;
    document.getElementById('statFeed').textContent = (state.stats && state.stats.feedSize) || (state.feed || []).length || 0;
    document.getElementById('statCases').textContent = (state.stats && state.stats.cases) || (state.cases || []).length || 0;
    document.getElementById('statSb').textContent = (state.stats && state.stats.shadowban) || (state.shadowban || []).length || 0;
    document.getElementById('statWatch').textContent = (state.stats && state.stats.watched) || (state.watchlist || []).length || 0;

    let feed = (state.feed || []).slice().reverse();
    feed = feed.filter((e) => {
      const sev = e.severity || (e.type === 'detection' ? 'INFO' : (e.type || 'SYSTEM').toUpperCase());
      if (sevFilter === 'SYSTEM') return e.type !== 'detection';
      if (sevFilter !== 'ALL' && e.type === 'detection' && sev !== sevFilter) return false;
      if (sevFilter !== 'ALL' && sevFilter !== 'SYSTEM' && e.type !== 'detection') return false;
      return matchQuery(`${e.detection || ''} ${e.player || ''} ${e.message || ''} ${e.details || ''}`);
    });

    document.getElementById('feed').innerHTML = feed.map((e) => {
      if (e.type === 'detection') {
        return `<div class="row"><div class="sev ${esc(e.severity)}">${esc(e.severity)}</div><div class="body"><strong>${esc(e.detection)} — ${esc(e.player)} (#${e.id})</strong><span>${esc(e.details)}</span></div><div class="meta">risk ${e.risk ?? 0}<br/>${fmt(e.ts)}</div></div>`;
      }
      return `<div class="row"><div class="sev SYSTEM">${esc((e.type || 'system').toUpperCase())}</div><div class="body"><strong>${esc(e.message || JSON.stringify(e))}</strong></div><div class="meta">${fmt(e.ts)}</div></div>`;
    }).join('') || '<div class="row"><div class="sev INFO">IDLE</div><div class="body"><strong>No matching detections</strong></div></div>';

    const watchOnly = document.getElementById('watchOnly').checked;
    let players = (state.players || []).filter((p) => {
      if (watchOnly && !p.watched) return false;
      return matchQuery(`${p.name} ${p.id}`);
    });

    document.getElementById('players').innerHTML = players.map((p) => `
      <div class="row player" data-player="${p.id}">
        <div>#${p.id}</div>
        <div><strong>${esc(p.name)}</strong>${p.admin ? '<span class="tag">admin</span>' : ''}${p.watched ? '<span class="tag">WATCH</span>' : ''}</div>
        <div class="risk">R ${p.risk || 0} · T ${p.trust ?? '—'}</div>
        <div class="muted">${p.ping || 0}ms</div>
        <div class="actions">
          <button class="btn sm" data-act="kick" data-id="${p.id}" type="button">Kick</button>
          <button class="btn sm danger" data-act="ban" data-id="${p.id}" type="button">Ban</button>
          <button class="btn sm" data-act="watch" data-id="${p.id}" type="button">Watch</button>
        </div>
      </div>
    `).join('') || '<div class="row"><div class="body"><strong>No players</strong></div></div>';

    document.getElementById('shadowban').innerHTML = (state.shadowban || []).map((s) => `
      <div class="row"><div class="sev HIGH">SB</div><div class="body"><strong>${esc(s.name)} (#${s.id})</strong><span>${esc(s.detection)} · ${s.remaining || 0}s</span></div></div>
    `).join('') || '<div class="row"><div class="sev INFO">IDLE</div><div class="body"><strong>Empty queue</strong></div></div>';

    document.getElementById('bans').innerHTML = (state.bans || []).map((b) => `
      <div class="row"><div class="sev CRITICAL">BAN</div><div class="body"><strong>#${b.id} ${esc(b.detection)}</strong><span>${esc(b.reason)} · ${esc(b.license || '')}</span></div></div>
    `).join('') || '<div class="row"><div class="sev INFO">IDLE</div><div class="body"><strong>No bans</strong></div></div>';

    document.getElementById('cases').innerHTML = (state.cases || []).map((c) => `
      <div class="row"><div class="sev ${esc(c.severity)}">#${c.id}</div><div class="body"><strong>${esc(c.detection)} — ${esc(c.player)}</strong><span>${esc(c.details)} · ${esc(c.status)} · shots ${c.screenshots || 0}</span></div>
      <div class="actions"><button class="btn sm" data-case-ss="${c.playerId}" type="button">Shot</button></div></div>
    `).join('') || '<div class="row"><div class="sev INFO">IDLE</div><div class="body"><strong>No cases</strong></div></div>';

    document.getElementById('watchlist').innerHTML = (state.watchlist || []).map((w) => `
      <div class="row"><div class="sev MEDIUM">WATCH</div><div class="body"><strong>${esc(w.name || w.license)}</strong><span>${esc(w.reason)} · hits ${w.hits || 0}</span></div></div>
    `).join('') || '<div class="row"><div class="sev INFO">IDLE</div><div class="body"><strong>Watchlist empty</strong></div></div>';
  }

  async function refresh() {
    if (demo) {
      state = demoState();
      applyTheme(state.theme);
      render();
      return;
    }
    try {
      state = await api('./api/state');
      applyTheme(state.theme);
      render();
    } catch (e) {
      showToast(e.message || 'Refresh failed');
    }
  }

  function enterConsole(isDemo) {
    demo = !!isDemo;
    sessionStorage.setItem('lg_web_demo', demo ? '1' : '0');
    login.classList.add('hidden');
    app.classList.remove('hidden');
    refresh();
    if (pollTimer) clearInterval(pollTimer);
    pollTimer = setInterval(refresh, demo ? 10000 : 4000);
  }

  document.getElementById('btnDemo').addEventListener('click', () => enterConsole(true));
  document.getElementById('btnLogin').addEventListener('click', async () => {
    const password = document.getElementById('password').value || '';
    try {
      const res = await api('./api/login', { method: 'POST', body: JSON.stringify({ password }) });
      token = res.token || password;
      sessionStorage.setItem('lg_web_token', token);
      enterConsole(false);
    } catch (e) {
      alert((e.data && e.data.error) || e.message || 'Login failed — try Demo if server is offline');
    }
  });

  document.getElementById('btnLogout').addEventListener('click', () => {
    sessionStorage.removeItem('lg_web_token');
    sessionStorage.removeItem('lg_web_demo');
    token = '';
    demo = false;
    if (pollTimer) clearInterval(pollTimer);
    app.classList.add('hidden');
    login.classList.remove('hidden');
  });

  document.getElementById('btnRefresh').addEventListener('click', refresh);
  document.getElementById('globalSearch').addEventListener('input', (e) => {
    query = (e.target.value || '').toLowerCase();
    render();
  });
  document.getElementById('watchOnly').addEventListener('change', render);

  document.querySelectorAll('.chip').forEach((chip) => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.chip').forEach((c) => c.classList.remove('active'));
      chip.classList.add('active');
      sevFilter = chip.dataset.sev;
      render();
    });
  });

  document.querySelectorAll('.nav').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.nav').forEach((b) => b.classList.remove('active'));
      document.querySelectorAll('.panel').forEach((p) => p.classList.remove('active'));
      btn.classList.add('active');
      document.getElementById(`tab-${btn.dataset.tab}`).classList.add('active');
      const t = titles[btn.dataset.tab] || ['LucidGuard', ''];
      document.getElementById('pageTitle').textContent = t[0];
      document.getElementById('pageSub').textContent = t[1];
    });
  });

  document.getElementById('safeToggle').addEventListener('change', async (ev) => {
    if (demo) { state.safeMode = ev.target.checked; render(); showToast('Demo only'); return; }
    try {
      await api('./api/safemode', { method: 'POST', body: JSON.stringify({ enabled: ev.target.checked }) });
      showToast('Safe Mode updated');
      refresh();
    } catch (e) {
      showToast(e.message || 'Failed');
      ev.target.checked = !ev.target.checked;
    }
  });

  document.getElementById('snowToggle').addEventListener('change', (ev) => {
    if (window.LucidSnow) window.LucidSnow.setEnabled(ev.target.checked);
  });

  document.getElementById('btnClearFeed').addEventListener('click', () => action('./api/clearfeed', {}));
  document.getElementById('btnAnnounce').addEventListener('click', () => {
    const message = document.getElementById('announceText').value.trim();
    if (!message) return showToast('Enter a message');
    action('./api/announce', { message });
  });
  document.getElementById('btnQuickKick').addEventListener('click', () => {
    action('./api/kick', { id: Number(document.getElementById('quickId').value), reason: document.getElementById('quickReason').value || 'Kicked by staff' });
  });
  document.getElementById('btnQuickBan').addEventListener('click', () => {
    action('./api/ban', { id: Number(document.getElementById('quickId').value), reason: document.getElementById('quickReason').value || 'Banned by staff' });
  });
  document.getElementById('btnQuickWarn').addEventListener('click', () => {
    action('./api/warn', { id: Number(document.getElementById('quickId').value), reason: document.getElementById('quickReason').value || 'Warned by staff' });
  });
  document.getElementById('btnShadow').addEventListener('click', () => {
    action('./api/shadowban', { id: Number(document.getElementById('sbId').value) });
  });
  document.getElementById('btnWatch').addEventListener('click', () => {
    action('./api/watch', { id: Number(document.getElementById('watchId').value), reason: document.getElementById('watchReason').value || 'web panel' });
  });
  document.getElementById('btnShot').addEventListener('click', () => {
    action('./api/screenshot', { id: Number(document.getElementById('ssId').value) });
  });
  document.getElementById('btnFreeze').addEventListener('click', () => {
    action('./api/freeze', { id: Number(document.getElementById('freezeId').value), freeze: true });
  });
  document.getElementById('btnUnfreeze').addEventListener('click', () => {
    action('./api/freeze', { id: Number(document.getElementById('freezeId').value), freeze: false });
  });

  document.getElementById('btnIds').addEventListener('click', async () => {
    const id = Number(document.getElementById('idLookup').value);
    const out = document.getElementById('idResult');
    if (demo) {
      out.textContent = `DEMO #${id}\nlicense: license:demo...\ndiscord: discord:demo...\nsteam: steam:demo...`;
      return;
    }
    try {
      const res = await api('./api/identifiers', { method: 'POST', body: JSON.stringify({ id }) });
      const ids = res.identifiers || {};
      out.textContent = Object.keys(ids).map((k) => `${k}: ${ids[k]}`).join('\n') || 'No identifiers';
    } catch (e) {
      out.textContent = e.message || 'Lookup failed';
    }
  });

  document.getElementById('btnClearRisk').addEventListener('click', () => {
    action('./api/clearrisk', { id: Number(document.getElementById('clearRiskId').value) });
  });
  document.getElementById('btnRecheck').addEventListener('click', () => {
    action('./api/recheck', { id: Number(document.getElementById('recheckId').value) });
  });
  document.getElementById('btnTestCaseHook').addEventListener('click', () => {
    action('./api/testcase', {});
  });

  document.getElementById('btnTheme').addEventListener('click', async () => {
    const snow = document.getElementById('themeSnow').value;
    const pin = document.getElementById('themePin').value;
    if (demo) {
      if (pin !== 'lucidowner' && pin !== '') {
        // allow empty in demo with toast
      }
      applyTheme({ snow });
      showToast(`Demo theme → ${snow} (live needs owner PIN)`);
      return;
    }
    try {
      await api('./api/theme', { method: 'POST', body: JSON.stringify({ snow, pin }) });
      applyTheme({ snow });
      showToast(`Theme set to ${snow}`);
    } catch (e) {
      showToast(e.message || 'Theme PIN rejected');
    }
  });

  document.getElementById('players').addEventListener('click', async (ev) => {
    const btn = ev.target.closest('button[data-act]');
    const row = ev.target.closest('[data-player]');
    if (btn) {
      ev.stopPropagation();
      const id = Number(btn.dataset.id);
      const act = btn.dataset.act;
      if (act === 'watch') return action('./api/watch', { id, reason: 'web players tab' });
      const reason = prompt(`${act} reason`, `${act} by LucidGuard web`) || `${act} by LucidGuard web`;
      return action(`./api/${act}`, { id, reason });
    }
    if (row) {
      const id = Number(row.dataset.player);
      const p = (state.players || []).find((x) => x.id === id);
      if (p) openDrawer(p);
    }
  });

  document.getElementById('cases').addEventListener('click', (ev) => {
    const btn = ev.target.closest('[data-case-ss]');
    if (!btn) return;
    action('./api/screenshot', { id: Number(btn.dataset.caseSs) });
  });

  document.getElementById('drawerClose').addEventListener('click', () => drawer.classList.add('hidden'));
  document.getElementById('drawerActions').addEventListener('click', async (ev) => {
    const btn = ev.target.closest('[data-d]');
    if (!btn || !selected) return;
    const id = selected.id;
    const d = btn.dataset.d;
    if (d === 'kick' || d === 'ban' || d === 'warn') {
      const reason = prompt('Reason', `${d} by LucidGuard web`) || `${d} by LucidGuard web`;
      await action(`./api/${d}`, { id, reason });
    } else if (d === 'watch') {
      await action('./api/watch', { id, reason: 'drawer' });
    } else if (d === 'shadow') {
      await action('./api/shadowban', { id });
    } else if (d === 'shot') {
      await action('./api/screenshot', { id });
    } else if (d === 'freeze') {
      await action('./api/freeze', { id, freeze: true });
    } else if (d === 'unfreeze') {
      await action('./api/freeze', { id, freeze: false });
    }
    drawer.classList.add('hidden');
  });

  const params = new URLSearchParams(location.search);
  if (params.get('demo') === '1' || sessionStorage.getItem('lg_web_demo') === '1') {
    enterConsole(true);
  } else if (token) {
    enterConsole(false);
  }
})();
