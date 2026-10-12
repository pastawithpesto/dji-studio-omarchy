(() => {
  'use strict';

  const API_ROOT = '';
  const POLL_MS = 8000;
  const MODEL_OPTIONS = [
    { id: 'luna', name: 'Luna' },
    { id: 'sol', name: 'Sol' },
    { id: 'astra', name: 'Astra' },
    { id: 'kimi', name: 'Kimi' },
  ];
  const PHASES = [
    { key: 'research', label: 'Research', allowed: ['reviewed', 'unreviewed', 'missing', 'running', 'blocked'] },
    { key: 'implementation', label: 'Implementation', allowed: ['missing', 'branch', 'integrated'] },
    { key: 'reference', label: 'Reference', allowed: ['missing', 'wine', 'validated'] },
  ];

  const $ = (id) => document.getElementById(id);
  const ui = {
    connection: $('connection-state'), usageTotal: $('usage-total'), slots: $('slot-count'), limits: $('rate-limits'),
    moduleCount: $('module-count'), moduleSearch: $('module-search'), moduleList: $('module-list'), updatedAt: $('updated-at'),
    activeName: $('active-module-name'), activeCategory: $('active-category'), activeMeta: $('active-module-meta'), activeHash: $('active-hash'),
    exportCount: $('export-count'), selectionReadout: $('selection-readout'), viewPanel: $('view-panel'), viewTitle: $('view-title'), viewKicker: $('view-kicker'),
    scopeSearchWrap: $('scope-search-wrap'), scopeSearch: $('scope-search'), legend: $('map-legend'), scopeCanvas: $('scope-canvas'),
    detailTitle: $('detail-title'), detailContent: $('detail-content'), clearSelection: $('clear-selection'),
    activity: $('activity-list'), usageSummary: $('usage-summary'), workers: $('worker-list'), jobs: $('job-list'), jobCount: $('job-count'),
    drawerSelection: $('drawer-selection'), modelSelect: $('model-select'), actionSelect: $('action-select'), notes: $('task-notes'),
    previewState: $('preview-state'), prompt: $('prompt-preview'), copyPrompt: $('copy-prompt'),
    queue: $('queue-task'), formError: $('form-error'), refresh: $('refresh-button'),
    artifactDialog: $('artifact-dialog'), artifactTitle: $('artifact-title'), artifactContent: $('artifact-content'), closeArtifact: $('close-artifact'), toast: $('toast-region'),
  };

  const modelState = {
    project: null,
    module: null,
    moduleId: null,
    moduleRequest: 0,
    selected: new Set(),
    detailSelection: null,
    view: 'work',
    moduleFilter: 'all',
    moduleQuery: '',
    scopeQuery: '',
    csrf: null,
    preview: null,
    previewDirty: false,
    previewRequest: 0,
    previewTimer: null,
    previewError: null,
    error: null,
    lastUpdated: null,
    lastApiError: null,
    polling: false,
  };

  function node(tag, className, text) {
    const el = document.createElement(tag);
    if (className) el.className = className;
    if (text !== undefined && text !== null) el.textContent = String(text);
    return el;
  }

  function clear(el) {
    while (el.firstChild) el.removeChild(el.firstChild);
  }

  function iconSvg(name, cls = '') {
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.setAttribute('viewBox', '0 0 24 24');
    svg.setAttribute('aria-hidden', 'true');
    if (cls) svg.setAttribute('class', cls);
    const shape = (tag, attrs) => {
      const el = document.createElementNS('http://www.w3.org/2000/svg', tag);
      for (const [key, value] of Object.entries(attrs)) el.setAttribute(key, value);
      return el;
    };
    const paths = {
      search: [shape('circle', { cx: '10.8', cy: '10.8', r: '6.5' }), shape('path', { d: 'm16 16 4.5 4.5' })],
      arrow: [shape('path', { d: 'M4 12h15M13 6l6 6-6 6' })],
      copy: [shape('rect', { x: '8', y: '8', width: '12', height: '12', rx: '2' }), shape('path', { d: 'M16 8V5a1 1 0 0 0-1-1H5a1 1 0 0 0-1 1v10a1 1 0 0 0 1 1h3' })],
      pause: [shape('path', { d: 'M8 5h3v14H8zM15 5h3v14h-3z' })],
      play: [shape('path', { d: 'm8 5 11 7-11 7z' })],
      open: [shape('path', { d: 'M14 4h6v6M20 4l-9 9' }), shape('path', { d: 'M18 13v6a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h6' })],
    };
    for (const el of paths[name] || []) svg.append(el);
    return svg;
  }

  async function requestJson(path, options = {}) {
    const headers = new Headers(options.headers || {});
    if (options.body !== undefined) headers.set('Content-Type', 'application/json');
    if (options.method && options.method !== 'GET') {
      if (modelState.csrf) headers.set('X-Console-Token', modelState.csrf);
    }
    let response;
    try {
      response = await fetch(`${API_ROOT}${path}`, { ...options, headers, cache: 'no-store' });
    } catch (error) {
      throw new Error(`Cannot reach the local console API: ${error.message || 'network error'}`);
    }
    let payload = null;
    try { payload = await response.json(); } catch (_) { /* Non-JSON error below. */ }
    if (!response.ok) {
      const message = payload && typeof payload.error === 'string' ? payload.error : `Request failed (${response.status})`;
      throw new Error(message);
    }
    if (!payload || typeof payload !== 'object') throw new Error('The console API returned an invalid response.');
    return payload;
  }

  function reportedNumber(value) {
    return value !== undefined && value !== null && value !== '' && Number.isFinite(Number(value));
  }

  function bytes(value) {
    if (!reportedNumber(value)) return 'Unknown size';
    const n = Number(value);
    if (n < 1000) return `${n.toLocaleString()} B`;
    const units = ['KB', 'MB', 'GB', 'TB'];
    let v = n / 1000;
    let i = 0;
    while (v >= 1000 && i < units.length - 1) { v /= 1000; i += 1; }
    return `${v.toFixed(v >= 10 ? 1 : 2)} ${units[i]}`;
  }

  function count(value) {
    return Number.isFinite(Number(value)) ? Number(value).toLocaleString() : 'Unknown';
  }

  function safeArray(value) { return Array.isArray(value) ? value : []; }
  function normalizedStatus(value, allowed) {
    const s = typeof value === 'string' ? value.toLowerCase() : 'missing';
    return allowed.includes(s) ? s : 'unknown';
  }
  function humanStatus(value) {
    const labels = { reviewed: 'Reviewed static', unreviewed: 'Unreviewed', missing: 'Missing', running: 'Running', blocked: 'Blocked', branch: 'Branch', integrated: 'Integrated', wine: 'Wine', validated: 'Validated', unknown: 'Unknown' };
    return labels[value] || 'Unknown';
  }
  function prettyTime(value) {
    if (typeof value !== 'string' || !value) return 'Time not reported';
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return value;
    return new Intl.DateTimeFormat(undefined, { hour: '2-digit', minute: '2-digit', second: '2-digit' }).format(d);
  }
  function fullDate(value) {
    if (typeof value !== 'string' || !value) return 'Not reported';
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? value : d.toLocaleString();
  }
  function rateWindowLabel(minutes) {
    if (!reportedNumber(minutes) || Number(minutes) <= 0) return 'window';
    const value = Number(minutes);
    if (value % 1440 === 0) return `${value / 1440}d`;
    if (value % 60 === 0) return `${value / 60}h`;
    if (value < 60) return `${value}m`;
    return `${Math.floor(value / 60)}h ${value % 60}m`;
  }
  function resetDate(value) {
    if (typeof value === 'number' && Number.isFinite(value)) {
      const milliseconds = value < 1e12 ? value * 1000 : value;
      const date = new Date(milliseconds);
      return Number.isNaN(date.getTime()) ? 'Not reported' : date.toLocaleString();
    }
    return fullDate(value);
  }
  function moduleCategory(module) {
    return typeof module?.category === 'string' ? module.category.toLowerCase() : 'unknown';
  }
  function selectedIds() { return Array.from(modelState.selected); }

  function setConnection(online, message) {
    clear(ui.connection);
    const dot = node('span', `status-dot ${online ? 'online' : 'offline'}`);
    const text = node('span', '', message);
    ui.connection.append(dot, text);
  }

  function renderUsageTop() {
    const state = modelState.project;
    const usage = state?.usage;
    ui.usageTotal.textContent = reportedNumber(usage?.total_tokens) ? `${count(usage.total_tokens)} tokens` : 'Unknown';
    const slots = state?.slots;
    ui.slots.textContent = reportedNumber(slots?.active) && reportedNumber(slots?.limit)
      ? `${count(slots.active)} / ${count(slots.limit)}` : 'Unknown';
    const limit = usage?.limits;
    if (limit && typeof limit === 'object') {
      const windows = ['primary', 'secondary'].flatMap((key) => {
        const window = limit[key];
        if (!window || typeof window !== 'object') return [];
        const label = rateWindowLabel(window.windowDurationMins);
        const percent = reportedNumber(window.usedPercent)
          ? `${Number(window.usedPercent).toLocaleString(undefined, { maximumFractionDigits: 1 })}% used`
          : 'usage unknown';
        return [{ key, text: `${label} ${percent}`, reset: resetDate(window.resetsAt) }];
      });
      if (windows.length) {
        ui.limits.textContent = windows.map((window) => window.text).join(' · ');
        ui.limits.title = windows.map((window) => `${window.key} window resets ${window.reset}`).join('\n');
      } else {
        const bits = [];
        if (limit.remaining !== undefined) bits.push(`${count(limit.remaining)} remaining`);
        if (limit.limit !== undefined) bits.push(`${count(limit.limit)} limit`);
        if (limit.status) bits.push(String(limit.status));
        ui.limits.textContent = bits.length ? bits.join(' · ') : 'Reported, details unknown';
        ui.limits.title = usage.limits_updated_at ? `Updated ${fullDate(usage.limits_updated_at)}` : 'Reported by project';
      }
    } else {
      ui.limits.textContent = 'Unknown';
      ui.limits.removeAttribute('title');
    }
    const when = state?.updated_at || modelState.lastUpdated;
    ui.updatedAt.textContent = when ? `Updated ${prettyTime(when)}` : 'Waiting for live project data';
  }

  function renderModules() {
    const modules = safeArray(modelState.project?.modules);
    const filtered = modules.filter((m) => {
      const category = moduleCategory(m);
      const matchesFilter = modelState.moduleFilter === 'all' || category === modelState.moduleFilter;
      const query = modelState.moduleQuery.trim().toLowerCase();
      const matchesQuery = !query || `${m.name || ''} ${m.id || ''}`.toLowerCase().includes(query);
      return matchesFilter && matchesQuery;
    });
    ui.moduleCount.textContent = String(filtered.length);
    clear(ui.moduleList);
    if (!filtered.length) {
      const empty = node('div', 'empty-state compact');
      empty.append(node('strong', '', modules.length ? 'No matching DLLs' : 'No DLLs reported'), node('p', '', modules.length ? 'Try a different filter or search.' : 'The project API has not reported a DLL catalog yet.'));
      ui.moduleList.append(empty);
      return;
    }
    for (const module of filtered) {
      const id = String(module.id || module.name || '');
      const button = node('button', `module-entry${id === modelState.moduleId ? ' active' : ''}`);
      button.type = 'button';
      button.setAttribute('aria-pressed', String(id === modelState.moduleId));
      const glyph = node('span', 'module-entry-icon', (module.name || id || '?').slice(0, 1).toUpperCase());
      const copy = node('span', 'module-entry-copy');
      copy.append(node('strong', '', module.name || id || 'Unnamed module'), node('small', '', `${bytes(module.bytes)} · ${module.category || 'Category not reported'}`));
      const chevron = node('span', 'entry-chevron', '›');
      button.append(glyph, copy, chevron);
      button.addEventListener('click', () => loadModule(id));
      ui.moduleList.append(button);
    }
  }

  function renderModuleHeader() {
    const m = modelState.module;
    if (!m) {
      ui.activeName.textContent = modelState.moduleId || 'Select a DLL';
      ui.activeCategory.textContent = '—';
      ui.activeMeta.textContent = modelState.error || 'Module details appear when project data is available.';
      ui.activeHash.textContent = 'Unknown';
      ui.exportCount.textContent = '—';
      return;
    }
    ui.activeName.textContent = m.name || m.id || 'Unnamed module';
    ui.activeCategory.textContent = m.category || 'Unknown category';
    ui.activeMeta.textContent = `${bytes(m.bytes)} · ${safeArray(m.parts).length.toLocaleString()} tracked scopes · ${safeArray(m.exports).length.toLocaleString()} exports`;
    ui.activeHash.textContent = m.sha256 || 'Not reported';
    ui.activeHash.title = m.sha256 || '';
    ui.exportCount.textContent = String(safeArray(m.exports).length);
  }

  function phaseValues(part) {
    const values = {};
    for (const phase of PHASES) values[phase.key] = normalizedStatus(part?.[phase.key], phase.allowed);
    return values;
  }

  function renderPhaseChips(part) {
    const row = node('div', 'phase-row');
    const phases = phaseValues(part);
    for (const p of PHASES) {
      const chip = node('span', `phase-chip phase-${phases[p.key]}`);
      chip.append(node('span', 'phase-marker'), node('span', '', `${p.label}: ${humanStatus(phases[p.key])}`));
      row.append(chip);
    }
    return row;
  }

  function renderWorkMap() {
    ui.viewTitle.textContent = 'Work map';
    ui.viewKicker.textContent = 'Coverage by source scope';
    ui.scopeCanvas.classList.add('work-map-canvas');
    ui.scopeSearchWrap.hidden = false;
    ui.legend.hidden = false;
    const parts = safeArray(modelState.module?.parts);
    const query = modelState.scopeQuery.trim().toLowerCase();
    const filtered = parts.filter((part) => !query || `${part.label || ''} ${part.id || ''} ${part.group || ''} ${safeArray(part.addresses).join(' ')}`.toLowerCase().includes(query));
    clear(ui.scopeCanvas);
    if (!parts.length) {
      ui.scopeCanvas.append(emptyState('No source scopes reported', 'The module endpoint has not supplied bounded work records.', 'outline'));
      return;
    }
    if (!filtered.length) {
      ui.scopeCanvas.append(emptyState('No matching scopes', 'Change the scope search to see more work areas.', 'outline'));
      return;
    }
    const groups = new Map();
    for (const part of filtered) {
      const label = typeof part.group === 'string' && part.group.trim() ? part.group : 'Unassigned source scope';
      if (!groups.has(label)) groups.set(label, []);
      groups.get(label).push(part);
    }
    const grid = node('div', 'scope-grid');
    for (const [label, grouped] of groups) {
      for (const part of grouped) {
        const id = String(part.id || '');
        const selected = modelState.selected.has(id);
        const status = phaseValues(part).research;
        const tile = node('button', `scope-block scope-${status}${selected ? ' selected' : ''}`);
        tile.type = 'button';
        tile.setAttribute('aria-pressed', String(selected));
        tile.setAttribute('aria-label', `${part.label || id || 'Unnamed scope'}, group ${label}, ${humanStatus(status)}. ${selected ? 'Selected.' : 'Not selected.'}`);
        const top = node('span', 'scope-block-top');
        top.append(node('span', 'scope-mark', selected ? '✓' : ''), node('span', `scope-status status-${status}`, humanStatus(status)));
        const title = node('strong', 'scope-block-title', part.label || id || 'Unnamed scope');
        const addresses = safeArray(part.addresses);
        const address = node('code', 'scope-address', addresses.length ? addresses.join(' · ') : 'Address not reported');
        const bottom = node('span', 'scope-block-bottom');
        bottom.append(node('span', 'scope-group-tag', label), node('span', '', `${addresses.length || '—'} address${addresses.length === 1 ? '' : 'es'}`));
        const phases = renderPhaseChips(part);
        tile.append(top, title, address, phases, bottom);
        tile.addEventListener('click', (event) => selectItem(id, part, event.shiftKey));
        grid.append(tile);
      }
    }
    ui.scopeCanvas.append(grid);
  }

  function emptyState(title, message, variant = '') {
    const box = node('div', `empty-state ${variant}`);
    box.append(node('div', 'empty-symbol', '?'), node('strong', '', title), node('p', '', message));
    return box;
  }

  function renderBinaryMap() {
    ui.scopeCanvas.classList.remove('work-map-canvas');
    ui.viewTitle.textContent = 'Binary map';
    ui.viewKicker.textContent = 'PE section sizes';
    ui.scopeSearchWrap.hidden = true;
    ui.legend.hidden = true;
    clear(ui.scopeCanvas);
    const sections = safeArray(modelState.module?.sections);
    if (!sections.length) {
      ui.scopeCanvas.append(emptyState('No section table reported', 'Section names, ranges, and sizes will appear when the module record provides them.', 'outline'));
      return;
    }
    const totalRaw = sections.reduce((sum, s) => sum + (reportedNumber(s.raw_size) ? Math.max(0, Number(s.raw_size)) : 0), 0);
    const intro = node('div', 'binary-intro');
    intro.append(node('strong', '', `${sections.length} sections`), node('span', '', `Raw bytes across reported sections: ${bytes(totalRaw)}`));
    ui.scopeCanvas.append(intro);
    const list = node('div', 'section-list');
    for (const section of sections) {
      const raw = reportedNumber(section.raw_size) ? Math.max(0, Number(section.raw_size)) : 0;
      const virtual = reportedNumber(section.virtual_size) ? Number(section.virtual_size) : null;
      const pct = totalRaw > 0 ? (raw / totalRaw) * 100 : 0;
      const card = node('button', 'section-card');
      card.type = 'button';
      card.setAttribute('aria-label', `${section.name || 'Unnamed section'}, raw ${bytes(raw)}, virtual ${bytes(virtual)}`);
      const head = node('span', 'section-head');
      head.append(node('strong', '', section.name || 'Unnamed section'), node('code', '', `RVA ${formatHex(section.rva)}`));
      const track = node('span', 'section-track');
      const fill = node('span', 'section-fill');
      fill.style.width = `${Math.max(0, Math.min(100, pct))}%`;
      track.append(fill);
      const meta = node('span', 'section-meta');
      meta.append(node('span', '', `Raw ${bytes(raw)}`), node('span', '', `Virtual ${virtual === null ? 'Unknown' : bytes(virtual)}`));
      if (section.va) meta.append(node('code', '', String(section.va)));
      card.append(head, track, meta);
      card.addEventListener('click', () => {
        modelState.detailSelection = { kind: 'section', id: `section:${section.name || ''}`, data: section };
        renderDetail();
      });
      list.append(card);
    }
    ui.scopeCanvas.append(list);
  }

  function renderExports() {
    ui.scopeCanvas.classList.remove('work-map-canvas');
    ui.viewTitle.textContent = 'Exports';
    ui.viewKicker.textContent = 'Original export table';
    ui.scopeSearchWrap.hidden = false;
    ui.scopeSearch.placeholder = 'Search exports';
    ui.scopeSearch.setAttribute('aria-label', 'Search exports');
    ui.legend.hidden = true;
    clear(ui.scopeCanvas);
    const exportsList = safeArray(modelState.module?.exports);
    const query = modelState.scopeQuery.trim().toLowerCase();
    const filtered = exportsList.filter((item) => !query || `${item.name || ''} ${item.ordinal || ''} ${item.va || ''} ${item.forwarder || ''}`.toLowerCase().includes(query));
    if (!exportsList.length) {
      ui.scopeCanvas.append(emptyState('No exports reported', 'The module endpoint has not supplied an export table.', 'outline'));
      return;
    }
    if (!filtered.length) {
      ui.scopeCanvas.append(emptyState('No matching exports', 'Change the export search to see more entries.', 'outline'));
      return;
    }
    const table = node('div', 'export-table');
    const head = node('div', 'export-row export-header');
    for (const label of ['Name', 'Ordinal', 'Address', 'Forwarder']) head.append(node('span', '', label));
    table.append(head);
    for (const exp of filtered) {
      const va = typeof exp.va === 'string' ? exp.va : String(exp.va ?? 'unknown');
      const key = `export:${va}`;
      const row = node('button', `export-row${modelState.selected.has(key) ? ' selected' : ''}`);
      row.type = 'button';
      row.setAttribute('aria-pressed', String(modelState.selected.has(key)));
      row.append(node('strong', 'export-name', exp.name || 'Unnamed export'), node('span', 'export-ordinal', exp.ordinal === undefined ? '—' : String(exp.ordinal)), node('code', 'export-va', va), node('span', 'export-forwarder', exp.forwarder || '—'));
      row.addEventListener('click', (event) => selectItem(key, { ...exp, id: key, label: exp.name || 'Unnamed export', kind: 'export', addresses: [va] }, event.shiftKey));
      table.append(row);
    }
    ui.scopeCanvas.append(table);
  }

  function formatHex(value) {
    if (typeof value === 'string' && /^0x[0-9a-f]+$/i.test(value)) return value;
    if (reportedNumber(value)) return `0x${Number(value).toString(16)}`;
    return 'Unknown';
  }

  function renderView() {
    if (modelState.view === 'binary') renderBinaryMap();
    else if (modelState.view === 'exports') renderExports();
    else renderWorkMap();
    document.querySelectorAll('.view-tab').forEach((tab) => {
      const active = tab.dataset.view === modelState.view;
      tab.classList.toggle('active', active);
      tab.setAttribute('aria-current', active ? 'page' : 'false');
    });
  }

  function selectItem(key, data, toggle) {
    modelState.detailSelection = { kind: data.kind || 'part', id: key, data };
    if (toggle) {
      if (modelState.selected.has(key)) modelState.selected.delete(key);
      else modelState.selected.add(key);
    } else {
      modelState.selected.clear();
      modelState.selected.add(key);
    }
    renderView();
    renderDetail();
    renderSelection();
    schedulePreview();
  }

  function selectedData() {
    const module = modelState.module;
    const parts = safeArray(module?.parts);
    const exportsList = safeArray(module?.exports);
    return selectedIds().map((id) => {
      if (id.startsWith('export:')) {
        const va = id.slice('export:'.length);
        const exp = exportsList.find((e) => String(e.va) === va);
        return exp ? { ...exp, id, label: exp.name || 'Unnamed export', kind: 'export', addresses: [va] } : { id, label: va, kind: 'export' };
      }
      return parts.find((p) => String(p.id) === id) || (modelState.detailSelection?.id === id ? modelState.detailSelection.data : { id, label: id });
    });
  }

  function appendFact(container, label, value, code = false) {
    const row = node('div', 'fact-row');
    row.append(node('span', 'fact-label', label));
    const val = node(code ? 'code' : 'span', 'fact-value');
    val.textContent = value === undefined || value === null || value === '' ? 'Not reported' : String(value);
    row.append(val);
    container.append(row);
  }

  function renderDetail() {
    const selection = modelState.detailSelection;
    const items = selectedData();
    clear(ui.detailContent);
    if (!selection) {
      ui.detailTitle.textContent = 'Scope details';
      ui.detailContent.append(emptyState('Choose a scope', 'Select a work area, binary section, or export to inspect its source facts and evidence.', 'detail-empty outline'));
      return;
    }
    const data = selection.data || {};
    ui.detailTitle.textContent = data.label || data.name || selection.id;
    if (items.length > 1) {
      const selected = node('div', 'selected-stack');
      selected.append(node('div', 'detail-caption', `${items.length} queued scopes`));
      for (const item of items) selected.append(node('span', 'selected-item', item.label || item.name || item.id));
      ui.detailContent.append(selected);
    }
    const statusBlock = node('div', 'detail-statuses');
    if (selection.kind === 'part' || !selection.kind) statusBlock.append(renderPhaseChips(data));
    else statusBlock.append(node('span', 'detail-caption', selection.kind === 'export' ? 'Original export entry' : 'PE section record'));
    ui.detailContent.append(statusBlock);

    const facts = node('div', 'detail-facts');
    if (selection.kind === 'export' || data.kind === 'export') {
      appendFact(facts, 'Export name', data.name || 'Unnamed export');
      appendFact(facts, 'Ordinal', data.ordinal === undefined ? null : String(data.ordinal));
      appendFact(facts, 'VA', data.va || selection.id.replace('export:', ''), true);
      appendFact(facts, 'Forwarder', data.forwarder || 'None reported');
    } else if (selection.kind === 'section') {
      appendFact(facts, 'Section', data.name);
      appendFact(facts, 'Virtual address', data.va || formatHex(data.rva), true);
      appendFact(facts, 'RVA', formatHex(data.rva), true);
      appendFact(facts, 'Virtual size', data.virtual_size === undefined ? null : bytes(data.virtual_size));
      appendFact(facts, 'Raw size', data.raw_size === undefined ? null : bytes(data.raw_size));
      appendFact(facts, 'Flags', data.flags === undefined ? null : formatHex(data.flags), true);
    } else {
      appendFact(facts, 'Source scope', data.group);
      appendFact(facts, 'Addresses', safeArray(data.addresses).join(' · ') || null, true);
      appendFact(facts, 'Owner', data.owner || null);
      appendFact(facts, 'Status source', data.statusSource || null);
    }
    ui.detailContent.append(facts);

    if (Array.isArray(data.missing) && data.missing.length) {
      const missing = node('section', 'detail-section');
      missing.append(node('h4', '', 'Missing facts'), node('ul', 'missing-list'));
      for (const item of data.missing) missing.querySelector('ul').append(node('li', '', item));
      ui.detailContent.append(missing);
    }
    const evidence = safeArray(data.evidence);
    if (evidence.length) {
      const list = node('section', 'detail-section');
      list.append(node('h4', '', `Evidence · ${evidence.length}`));
      const evidenceList = node('div', 'evidence-list');
      for (const item of evidence) {
        const btn = node('button', 'evidence-link');
        btn.type = 'button';
        btn.append(iconSvg('open'), node('span', '', item.label || item.path || 'Evidence artifact'));
        btn.addEventListener('click', () => openArtifact(item.path, item.label));
        evidenceList.append(btn);
      }
      list.append(evidenceList);
      ui.detailContent.append(list);
    }
    if (data.detail || data.research || data.implementation || data.reference) {
      const text = node('section', 'detail-section');
      text.append(node('h4', '', 'Scope notes'));
      for (const phase of PHASES) {
        if (typeof data[phase.key] === 'string') {
          const row = node('p', 'detail-note');
          row.append(node('strong', '', `${phase.label}: `), document.createTextNode(humanStatus(normalizedStatus(data[phase.key], phase.allowed))));
          text.append(row);
        }
      }
      if (typeof data.detail === 'string') text.append(node('p', 'detail-note', data.detail));
      ui.detailContent.append(text);
    }
  }

  function renderSelection() {
    const items = selectedData();
    const n = items.length;
    ui.selectionReadout.textContent = `${n} selected`;
    clear(ui.drawerSelection);
    ui.drawerSelection.append(node('span', 'selection-count', String(n)), node('span', '', n ? items.map((x) => x.label || x.name || x.id).join(' · ') : 'Select one or more scopes above'));
    ui.clearSelection.disabled = n === 0;
    if (n === 0) {
      modelState.preview = null;
      modelState.previewDirty = false;
      modelState.previewError = null;
      ui.formError.textContent = '';
      ui.prompt.value = '';
      ui.previewState.textContent = 'Select a scope to preview';
      ui.copyPrompt.disabled = true;
      updateQueueButton();
    }
  }

  function renderActivity() {
    const activity = safeArray(modelState.project?.activity);
    clear(ui.activity);
    if (!activity.length) { ui.activity.append(node('div', 'empty-inline', 'No activity reported yet.')); return; }
    for (const item of activity.slice(0, 8)) {
      const row = node('article', 'activity-item');
      const icon = node('span', `activity-kind kind-${String(item.kind || 'event').toLowerCase()}`, (item.kind || '•').slice(0, 1).toUpperCase());
      const body = node('div', 'activity-copy');
      const headline = node('div', 'activity-headline');
      headline.append(node('strong', '', item.sender || 'Project'), node('span', 'activity-time', prettyTime(item.time)));
      body.append(headline, node('p', '', item.body || `${item.kind || 'Event'} · ${item.feature || 'Project activity'}`));
      row.append(icon, body);
      ui.activity.append(row);
    }
  }

  function renderUsage() {
    const usage = modelState.project?.usage;
    clear(ui.usageSummary);
    if (!usage || !reportedNumber(usage.total_tokens)) {
      ui.usageSummary.append(node('div', 'empty-inline', 'Usage details are unknown until reported by the project.'));
      return;
    }
    const total = node('div', 'usage-total-row');
    total.append(node('span', 'usage-big-number', count(usage.total_tokens)), node('span', 'usage-unit', 'reported tokens'));
    ui.usageSummary.append(total);
    const rows = [
      ['Input', usage.input_tokens], ['Output', usage.output_tokens], ['Cached', usage.cached_tokens],
    ];
    const grid = node('div', 'usage-breakdown');
    for (const [label, value] of rows) {
      const item = node('div', 'usage-cell');
      item.append(node('span', '', label), node('strong', '', value === undefined ? 'Unknown' : count(value)));
      grid.append(item);
    }
    ui.usageSummary.append(grid);
    if (Array.isArray(usage.sessions) && usage.sessions.length) {
      const sessionList = node('div', 'session-list');
      for (const session of usage.sessions.slice(0, 5)) {
        const row = node('div', 'session-row');
        row.append(node('span', '', session.name || session.model || 'Reported session'), node('strong', '', session.total_tokens === undefined ? 'Usage unknown' : `${count(session.total_tokens)} tokens`));
        sessionList.append(row);
      }
      ui.usageSummary.append(sessionList);
    }
    if (usage.note) ui.usageSummary.append(node('p', 'usage-note', usage.note));
  }

  function renderJobs() {
    const jobs = safeArray(modelState.project?.jobs);
    const active = document.activeElement;
    const focusedJob = active && ui.jobs.contains(active) && active.classList.contains('job-control')
      ? { id: active.dataset.jobId, action: active.dataset.action }
      : null;
    ui.jobCount.textContent = `${jobs.length} ${jobs.length === 1 ? 'job' : 'jobs'}`;
    clear(ui.jobs);
    if (!jobs.length) {
      ui.jobs.append(node('div', 'empty-inline', 'No queued jobs reported.'));
      if (focusedJob) { ui.jobs.tabIndex = -1; ui.jobs.focus({ preventScroll: true }); }
      return;
    }
    for (const job of jobs.slice(0, 6)) {
      const row = node('article', 'job-item');
      const status = String(job.status || 'unknown').toLowerCase();
      const copy = node('div', 'job-copy');
      copy.append(node('strong', '', job.summary || job.dll || 'Queued task'));
      const scope = [...safeArray(job.parts), job.model, job.action].filter(Boolean).join(' · ');
      copy.append(node('span', '', scope || 'Task details not reported'));
      const artifacts = safeArray(job.artifacts).slice(0, 4).flatMap((artifact) => {
        if (!artifact || typeof artifact.url !== 'string' || typeof artifact.label !== 'string') return [];
        try {
          const url = new URL(artifact.url, window.location.href);
          if (!['http:', 'https:'].includes(url.protocol) || url.origin !== window.location.origin) return [];
          const link = node('a', 'job-artifact-link', artifact.label);
          link.href = url.href;
          link.target = '_blank';
          link.rel = 'noopener noreferrer';
          return [link];
        } catch { return []; }
      });
      if (artifacts.length) {
        const links = node('div', 'job-artifacts');
        links.append(...artifacts);
        copy.append(links);
      }
      const right = node('div', 'job-actions');
      right.append(node('span', `job-status job-${status}`, job.status || 'Unknown'));
      if (job.owned === true) {
        const action = status === 'paused' || status === 'failed' || status === 'interrupted' ? 'resume' : status === 'queued' || status === 'running' ? 'pause' : null;
        if (action) {
          const button = node('button', 'job-control');
          button.type = 'button';
          button.dataset.jobId = String(job.id || '');
          button.dataset.action = action;
          button.setAttribute('aria-label', `${action} ${job.summary || job.id}`);
          button.append(iconSvg(action));
          button.addEventListener('click', () => changeJob(job.id, action));
          right.append(button);
        }
      } else if (job.owned === false) {
        right.append(node('span', 'read-only-label', 'Read only'));
      }
      row.append(copy, right);
      ui.jobs.append(row);
    }
    if (focusedJob) {
      const controls = Array.from(ui.jobs.querySelectorAll('.job-control'));
      const nextFocus = controls.find((button) => button.dataset.jobId === focusedJob.id && button.dataset.action === focusedJob.action)
        || controls.find((button) => button.dataset.jobId === focusedJob.id);
      if (nextFocus) nextFocus.focus({ preventScroll: true });
      else { ui.jobs.tabIndex = -1; ui.jobs.focus({ preventScroll: true }); }
    }
  }

  function renderWorkers() {
    const workers = safeArray(modelState.project?.workers);
    clear(ui.workers);
    if (!workers.length) { ui.workers.append(node('div', 'empty-inline', 'No workers reported by the project.')); return; }
    for (const worker of workers.slice(0, 4)) {
      const row = node('div', 'worker-row');
      const copy = node('div', 'worker-copy');
      copy.append(node('strong', '', worker.model || 'Model not reported'));
      const meta = [worker.kind, worker.scope].filter(Boolean).join(' · ') || 'Worker details not reported';
      copy.append(node('span', '', meta));
      const ownership = worker.owned === true ? 'Console-owned' : worker.owned === false ? 'Read only' : 'Ownership unknown';
      row.append(node('span', `worker-led${worker.owned === true ? ' owned' : ''}`), copy, node('span', `worker-ownership${worker.owned === false ? ' external' : ''}`, ownership));
      ui.workers.append(row);
    }
  }

  function renderModelAvailability() {
    const models = safeArray(modelState.project?.models);
    for (const option of Array.from(ui.modelSelect.options)) {
      const record = models.find((item) => item.id === option.value);
      option.disabled = record ? record.available === false : false;
      const choice = MODEL_OPTIONS.find((item) => item.id === option.value);
      const reportedName = record?.name || choice?.name || option.value;
      const availability = record ? (record.available === true ? '' : ' · unavailable') : ' · status not reported';
      option.textContent = `${reportedName}${availability}`;
    }
    updateQueueButton();
  }

  function renderAll() {
    renderUsageTop();
    renderModules();
    renderModuleHeader();
    renderView();
    renderDetail();
    renderSelection();
    renderActivity();
    renderUsage();
    renderWorkers();
    renderJobs();
    renderModelAvailability();
  }

  async function loadModule(id) {
    if (!id) return;
    modelState.moduleId = id;
    modelState.module = null;
    modelState.error = null;
    modelState.selected.clear();
    modelState.detailSelection = null;
    const request = ++modelState.moduleRequest;
    schedulePreview();
    renderModules();
    renderModuleHeader();
    renderView();
    renderDetail();
    renderSelection();
    try {
      const data = await requestJson(`/api/module?id=${encodeURIComponent(id)}`);
      if (request !== modelState.moduleRequest) return;
      modelState.module = data;
      modelState.moduleId = data.id || id;
      modelState.error = null;
      renderAll();
    } catch (error) {
      if (request !== modelState.moduleRequest) return;
      modelState.error = error.message;
      setConnection(false, 'Module load failed');
      renderModuleHeader();
      renderView();
      toast(error.message, true);
    }
  }

  async function pollState() {
    if (modelState.polling) return;
    modelState.polling = true;
    try {
      const data = await requestJson('/api/state');
      modelState.project = data;
      modelState.csrf = typeof data.csrf === 'string' ? data.csrf : null;
      modelState.lastUpdated = data.updated_at || new Date().toISOString();
      modelState.error = null;
      modelState.lastApiError = null;
      setConnection(true, 'Connected');
      renderUsageTop();
      renderModules();
      renderActivity();
      renderUsage();
      renderWorkers();
      renderJobs();
      renderModelAvailability();
      if (modelState.moduleId && modelState.module) {
        const id = modelState.moduleId;
        const generation = modelState.moduleRequest;
        const fresh = await requestJson(`/api/module?id=${encodeURIComponent(id)}`);
        if (generation === modelState.moduleRequest && id === modelState.moduleId) {
          modelState.module = fresh;
          const available = new Set([...safeArray(fresh.parts).map(p => String(p.id)), ...safeArray(fresh.exports).map(e => `export:${e.va}`)]);
          for (const selected of selectedIds()) if (!available.has(selected)) modelState.selected.delete(selected);
          const detail = modelState.detailSelection;
          if (detail?.kind === 'part') {
            const updated = safeArray(fresh.parts).find(p => String(p.id) === detail.id);
            modelState.detailSelection = updated ? { kind: 'part', id: detail.id, data: updated } : null;
          }
          const activeScope = ui.scopeCanvas.contains(document.activeElement) ? document.activeElement.getAttribute('aria-label') : null;
          renderModuleHeader(); renderView(); renderDetail(); renderSelection();
          if (activeScope) {
            const restored = Array.from(ui.scopeCanvas.querySelectorAll('button')).find(button => button.getAttribute('aria-label') === activeScope);
            restored?.focus({ preventScroll: true });
          }
          if (selectedIds().length) schedulePreview();
        }
      } else if (modelState.moduleId) {
        await loadModule(modelState.moduleId);
      } else if (safeArray(data.modules).length) {
        await loadModule(data.modules[0].id || data.modules[0].name);
      }
    } catch (error) {
      modelState.error = error.message;
      setConnection(false, `API unavailable · ${error.message}`);
      ui.updatedAt.textContent = 'Live data unavailable';
      if (modelState.lastApiError !== error.message) toast(error.message, true);
      modelState.lastApiError = error.message;
    } finally {
      modelState.polling = false;
    }
  }

  async function openArtifact(path, label) {
    if (typeof path !== 'string' || !path) return toast('Evidence path was not supplied.', true);
    ui.artifactTitle.textContent = label || path;
    ui.artifactContent.textContent = 'Loading source evidence…';
    if (!ui.artifactDialog.open) ui.artifactDialog.showModal();
    try {
      const data = await requestJson(`/api/artifact?path=${encodeURIComponent(path)}`);
      const value = typeof data.text === 'string' ? data.text : (typeof data.content === 'string' ? data.content : 'No text content was returned.');
      ui.artifactContent.textContent = value;
    } catch (error) {
      ui.artifactContent.textContent = `Unable to load evidence: ${error.message}`;
    }
  }

  function currentRequest() {
    return {
      dll: modelState.moduleId,
      parts: selectedIds(),
      model: ui.modelSelect.value,
      action: ui.actionSelect.value,
      notes: ui.notes.value.trim(),
    };
  }

  function schedulePreview() {
    clearTimeout(modelState.previewTimer);
    modelState.previewRequest += 1;
    modelState.preview = null;
    modelState.previewError = null;
    modelState.previewDirty = false;
    ui.copyPrompt.disabled = true;
    ui.prompt.value = '';
    ui.previewState.textContent = selectedIds().length && modelState.moduleId ? 'Updating preview…' : 'Select a scope to preview';
    ui.formError.textContent = '';
    updateQueueButton();
    modelState.previewTimer = setTimeout(refreshPreview, 300);
  }

  async function refreshPreview() {
    if (!selectedIds().length || !modelState.moduleId) {
      modelState.preview = null;
      modelState.previewDirty = false;
      modelState.previewError = null;
      ui.prompt.value = '';
      ui.previewState.textContent = 'Select a scope to preview';
      ui.copyPrompt.disabled = true;
      updateQueueButton();
      return;
    }
    const requestId = ++modelState.previewRequest;
    ui.previewState.textContent = 'Building preview…';
    ui.formError.textContent = '';
    try {
      const data = await requestJson('/api/preview', { method: 'POST', body: JSON.stringify(currentRequest()) });
      if (requestId !== modelState.previewRequest) return;
      modelState.preview = data;
      modelState.previewError = null;
      modelState.previewDirty = false;
      ui.prompt.value = typeof data.prompt === 'string' ? data.prompt : '';
      ui.previewState.textContent = data.selection_summary || 'Preview ready';
      ui.copyPrompt.disabled = !ui.prompt.value;
      if (data.scope_blocker) ui.formError.textContent = String(data.scope_blocker);
    } catch (error) {
      if (requestId !== modelState.previewRequest) return;
      modelState.preview = null;
      modelState.previewError = error.message;
      modelState.previewDirty = false;
      ui.prompt.value = '';
      ui.previewState.textContent = 'Preview unavailable';
      ui.formError.textContent = error.message;
      ui.copyPrompt.disabled = true;
    }
    updateQueueButton();
  }

  function updateQueueButton() {
    const hasSelection = selectedIds().length > 0;
    const knownModel = MODEL_OPTIONS.some((m) => m.id === ui.modelSelect.value);
    const modelRecord = safeArray(modelState.project?.models).find((item) => item.id === ui.modelSelect.value);
    const unavailable = modelRecord?.available === false;
    const available = knownModel && !unavailable;
    const blocked = Boolean(modelState.preview?.scope_blocker);
    ui.queue.disabled = !hasSelection || !available || !modelState.preview || Boolean(modelState.previewError) || blocked || modelState.previewDirty;
    const messages = [];
    if (unavailable) messages.push('The selected model is reported unavailable. Choose another model to queue this task.');
    if (modelState.preview?.scope_blocker) messages.push(String(modelState.preview.scope_blocker));
    if (messages.length) ui.formError.textContent = messages.join(' ');
  }

  async function queueTask() {
    if (ui.queue.disabled) return;
    ui.queue.disabled = true;
    ui.formError.textContent = '';
    try {
      const data = await requestJson('/api/jobs', { method: 'POST', body: JSON.stringify(currentRequest()) });
      toast('Task queued. The project owns scheduling and execution.', false);
      if (data.job) {
        const jobs = safeArray(modelState.project?.jobs);
        modelState.project.jobs = [data.job, ...jobs.filter((j) => j.id !== data.job.id)];
        renderJobs();
      }
      await pollState();
    } catch (error) {
      ui.formError.textContent = error.message;
      toast(error.message, true);
    } finally {
      updateQueueButton();
    }
  }

  async function changeJob(id, action) {
    if (!id) return;
    try {
      const data = await requestJson(`/api/jobs/${encodeURIComponent(id)}/${action}`, { method: 'POST', body: '{}' });
      if (data.job) {
        modelState.project.jobs = [data.job, ...safeArray(modelState.project.jobs).filter((j) => j.id !== id)];
        renderJobs();
      }
      toast(`Job ${action} request accepted.`);
      await pollState();
    } catch (error) { toast(error.message, true); }
  }

  function toast(message, isError = false, id = '') {
    if (id && $(id)) {
      const item = $(id);
      item.textContent = message;
      return;
    }
    const item = node('div', `toast${isError ? ' toast-error' : ''}`, message);
    ui.toast.append(item);
    setTimeout(() => item.remove(), 4200);
  }

  async function copyPrompt() {
    if (!ui.prompt.value) return;
    try {
      await navigator.clipboard.writeText(ui.prompt.value);
      toast('Prompt copied.');
    } catch (_) {
      ui.prompt.focus();
      ui.prompt.select();
      try { document.execCommand('copy'); toast('Prompt copied.'); }
      catch (error) { toast(`Copy failed: ${error.message || 'clipboard unavailable'}`, true); }
    }
  }

  function bindEvents() {
    ui.moduleSearch.addEventListener('input', () => { modelState.moduleQuery = ui.moduleSearch.value; renderModules(); });
    ui.scopeSearch.addEventListener('input', () => { modelState.scopeQuery = ui.scopeSearch.value; renderView(); });
    document.querySelectorAll('[data-module-filter]').forEach((button) => button.addEventListener('click', () => {
      modelState.moduleFilter = button.dataset.moduleFilter;
      document.querySelectorAll('[data-module-filter]').forEach((item) => item.classList.toggle('active', item === button));
      renderModules();
    }));
    document.querySelectorAll('.view-tab').forEach((button) => button.addEventListener('click', () => {
      modelState.view = button.dataset.view;
      modelState.scopeQuery = '';
      ui.scopeSearch.value = '';
      ui.scopeSearch.placeholder = modelState.view === 'exports' ? 'Search exports' : 'Search scopes';
      renderView();
      renderDetail();
    }));
    ui.clearSelection.addEventListener('click', () => {
      modelState.selected.clear();
      modelState.detailSelection = null;
      renderView(); renderDetail(); renderSelection(); schedulePreview();
    });
    ui.modelSelect.addEventListener('change', schedulePreview);
    ui.actionSelect.addEventListener('change', schedulePreview);
    ui.notes.addEventListener('input', schedulePreview);
    ui.copyPrompt.addEventListener('click', copyPrompt);
    ui.queue.addEventListener('click', queueTask);
    ui.refresh.addEventListener('click', pollState);
    ui.closeArtifact.addEventListener('click', () => ui.artifactDialog.close());
    document.addEventListener('keydown', (event) => {
      if (event.key === '/' && !event.ctrlKey && !event.metaKey && !['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName)) {
        event.preventDefault(); ui.moduleSearch.focus();
      }
      if (event.key === 'Escape' && ui.artifactDialog.open) ui.artifactDialog.close();
    });
  }

  bindEvents();
  pollState();
  setInterval(pollState, POLL_MS);
})();
