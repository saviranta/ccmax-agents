// agents-max dashboard — vanilla JS, no frameworks, no imports

// ─── State ───

const state = {
  currentView: 'running',
  currentProject: null,
  data: null,
  lastFetch: null,
  refreshInterval: 5000
};

// ─── Helpers ───

function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function timeAgo(isoStr) {
  if (!isoStr) return '—';
  const diff = Math.floor((Date.now() - new Date(isoStr).getTime()) / 1000);
  if (diff < 0) return 'just now';
  if (diff < 60) return `${diff}s ago`;
  const m = Math.floor(diff / 60);
  const s = diff % 60;
  if (m < 60) return `${m}m ${s}s ago`;
  const h = Math.floor(m / 60);
  const mm = m % 60;
  return `${h}h ${mm}m ago`;
}

function formatTime(isoStr) {
  if (!isoStr) return '—';
  try {
    const d = new Date(isoStr);
    return d.toLocaleTimeString('en-GB', { hour12: false });
  } catch (e) {
    return isoStr;
  }
}

function statusBadge(status) {
  if (!status) return '';
  const s = String(status).toLowerCase().replace(/\s+/g, '_');
  return `<span class="badge-${escapeHtml(s)}">${escapeHtml(status)}</span>`;
}

function progressBar(done, total, colorClass) {
  colorClass = colorClass || 'blue';
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  return `<div class="progress-bar-container">
    <div class="progress-bar-fill ${escapeHtml(colorClass)}" style="width:${pct}%"></div>
  </div>`;
}

function truncate(str, len) {
  if (!str) return '';
  str = String(str);
  return str.length > len ? str.slice(0, len) + '…' : str;
}

// ─── Data fetching ───

async function fetchSnapshot() {
  try {
    const res = await fetch('data/snapshot.json?_=' + Date.now());
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const data = await res.json();
    state.data = data;
    state.lastFetch = Date.now();

    // Update project selector on first load or if projects changed
    const select = document.getElementById('project-select');
    const projectNames = Object.keys(data.projects || {});
    if (select.options.length !== projectNames.length) {
      const prev = state.currentProject;
      select.innerHTML = projectNames
        .map(name => `<option value="${escapeHtml(name)}"${name === prev ? ' selected' : ''}>${escapeHtml(name)}</option>`)
        .join('');
      if (!state.currentProject && projectNames.length > 0) {
        state.currentProject = projectNames[0];
      }
    }

    // Status indicator: green = fetched within last 10s
    const dot = document.getElementById('status-indicator');
    dot.className = 'status-dot connected';

    render();
  } catch (e) {
    const dot = document.getElementById('status-indicator');
    dot.className = 'status-dot stale';
    console.error('Snapshot fetch failed:', e);
  }
}

// ─── Rendering ───

function renderRunningNow(project) {
  const phase = project.phase || 'Prototyping';
  const phaseDot = phase.toLowerCase();

  // Phase badge
  let html = `<div class="phase-header">
    <div class="phase-badge">
      <span class="phase-dot ${escapeHtml(phaseDot)}"></span>
      ${escapeHtml(phase)}
    </div>
  </div>`;

  // Active agents
  html += `<div class="section-title">Active Agents</div>`;
  const activeAgents = (project.state && project.state.active_agents) || {};
  const agentEntries = Object.entries(activeAgents);

  if (agentEntries.length === 0) {
    html += `<div class="no-data">No active agents</div>`;
  } else {
    html += `<div class="agent-grid">`;
    for (const [agentName, info] of agentEntries) {
      const task = info.task || info.task_id || '—';
      const started = info.started_at || info.started || null;
      html += `<div class="agent-card">
        <div class="agent-card-name">${escapeHtml(agentName)}</div>
        <div class="agent-card-task">${escapeHtml(truncate(task, 60))}</div>
        <div class="agent-card-meta">${started ? timeAgo(started) : ''}</div>
      </div>`;
    }
    html += `</div>`;
  }

  // Recent activity (last 15 audit entries)
  html += `<div class="section-title">Recent Activity</div>`;
  const auditLog = project.audit_log || [];
  const recent = auditLog.slice().reverse().slice(0, 15);

  if (recent.length === 0) {
    html += `<div class="no-data">No recent activity</div>`;
  } else {
    html += `<div class="table-container"><table>
      <thead><tr>
        <th>Time</th><th>Agent</th><th>Action</th><th>Task</th><th>Status</th>
      </tr></thead>
      <tbody>`;
    for (const entry of recent) {
      html += `<tr>
        <td>${escapeHtml(formatTime(entry.ts))}</td>
        <td>${escapeHtml(entry.agent || '—')}</td>
        <td>${escapeHtml(entry.action || '—')}</td>
        <td>${escapeHtml(truncate(entry.task || entry.task_id || '—', 40))}</td>
        <td>${statusBadge(entry.status)}</td>
      </tr>`;
    }
    html += `</tbody></table></div>`;
  }

  // Last handoff card
  const handoffs = project.handoffs || {};
  const handoffOrder = ['builder-to-launcher', 'architect-to-builder', 'prototyper-to-architect'];
  let lastHandoff = null;
  let lastHandoffName = null;
  for (const name of handoffOrder) {
    if (handoffs[name] && Object.keys(handoffs[name]).length > 0) {
      lastHandoff = handoffs[name];
      lastHandoffName = name;
      break;
    }
  }

  html += `<div class="section-title">Last Handoff</div>`;
  if (!lastHandoff) {
    html += `<div class="no-data">No handoffs yet</div>`;
  } else {
    const parts = (lastHandoffName || '').split('-to-');
    const from = parts[0] || '?';
    const to = parts[1] || '?';
    const ts = lastHandoff.timestamp || lastHandoff.created_at || null;
    const artifacts = lastHandoff.artifacts || lastHandoff.files || [];
    const artifactCount = Array.isArray(artifacts) ? artifacts.length : Object.keys(artifacts).length;
    html += `<div class="handoff-card">
      <div class="handoff-agents">${escapeHtml(from)} → ${escapeHtml(to)}</div>
      <div class="handoff-meta">
        ${ts ? escapeHtml(timeAgo(ts)) + ' · ' : ''}
        ${artifactCount} artifact${artifactCount !== 1 ? 's' : ''}
      </div>
    </div>`;
  }

  return html;
}

function renderTaskGraph(project) {
  const tg = project.task_graph || {};
  const tasks = tg.tasks || [];

  // Collect milestones
  const milestoneMap = {};
  for (const task of tasks) {
    const ms = task.milestone || task.epic || 'Uncategorized';
    if (!milestoneMap[ms]) milestoneMap[ms] = { done: 0, total: 0 };
    milestoneMap[ms].total++;
    if ((task.status || '').toLowerCase() === 'done') milestoneMap[ms].done++;
  }

  let html = `<div class="section-title">Milestones</div>`;
  const milestoneEntries = Object.entries(milestoneMap);
  if (milestoneEntries.length === 0) {
    html += `<div class="no-data">No milestones in task graph</div>`;
  } else {
    html += `<div class="milestone-list">`;
    for (const [name, counts] of milestoneEntries) {
      const pct = counts.total > 0 ? Math.round((counts.done / counts.total) * 100) : 0;
      html += `<div class="milestone-row">
        <span class="milestone-name">${escapeHtml(name)}</span>
        ${progressBar(counts.done, counts.total, 'green')}
        <span class="milestone-pct">${pct}% (${counts.done}/${counts.total})</span>
      </div>`;
    }
    html += `</div>`;
  }

  // Phases (collapsible)
  html += `<div class="section-title">Phases</div>`;
  const phases = tg.phases || [];
  if (phases.length === 0 && tasks.length === 0) {
    html += `<div class="no-data">No task graph data</div>`;
  } else if (phases.length > 0) {
    for (const phase of phases) {
      const phaseName = phase.name || phase.id || 'Phase';
      const phaseTasks = phase.tasks || tasks.filter(t => t.phase === phase.id || t.phase === phase.name);
      const donePct = phaseTasks.length > 0
        ? Math.round((phaseTasks.filter(t => (t.status || '').toLowerCase() === 'done').length / phaseTasks.length) * 100)
        : 0;
      html += `<details>
        <summary>${escapeHtml(phaseName)} <span class="badge-${donePct === 100 ? 'done' : 'pending'}" style="margin-left:auto;margin-right:0.5rem">${donePct}%</span></summary>
        <div class="table-container"><table>
          <thead><tr><th>ID</th><th>Title</th><th>Assigned To</th><th>Size</th><th>Status</th></tr></thead>
          <tbody>`;
      for (const task of phaseTasks) {
        html += `<tr>
          <td>${escapeHtml(task.id || task.task_id || '—')}</td>
          <td>${escapeHtml(truncate(task.title || task.name || '—', 40))}</td>
          <td>${escapeHtml(task.assigned_to || '—')}</td>
          <td>${escapeHtml(task.size || task.effort || '—')}</td>
          <td>${statusBadge(task.status)}</td>
        </tr>`;
      }
      html += `</tbody></table></div></details>`;
    }
  } else {
    // Flat task list with no phases
    html += `<details open>
      <summary>All Tasks</summary>
      <div class="table-container"><table>
        <thead><tr><th>ID</th><th>Title</th><th>Assigned To</th><th>Size</th><th>Status</th></tr></thead>
        <tbody>`;
    for (const task of tasks) {
      html += `<tr>
        <td>${escapeHtml(task.id || task.task_id || '—')}</td>
        <td>${escapeHtml(truncate(task.title || task.name || '—', 40))}</td>
        <td>${escapeHtml(task.assigned_to || '—')}</td>
        <td>${escapeHtml(task.size || task.effort || '—')}</td>
        <td>${statusBadge(task.status)}</td>
      </tr>`;
    }
    html += `</tbody></table></div></details>`;
  }

  // Checkpoint timeline
  html += `<div class="section-title">Checkpoint Timeline</div>`;
  const checkpoints = (project.state && project.state.checkpoints) || [];
  const recentCheckpoints = checkpoints.slice().reverse().slice(0, 8);
  if (recentCheckpoints.length === 0) {
    html += `<div class="no-data">No checkpoints recorded</div>`;
  } else {
    html += `<div class="checkpoint-list">`;
    for (const cp of recentCheckpoints) {
      const hash = (cp.commit || cp.hash || '').slice(0, 7);
      const taskId = cp.task_id || cp.task || '—';
      const ts = cp.created_at || cp.timestamp || null;
      html += `<div class="checkpoint-item">
        <span class="checkpoint-hash">${escapeHtml(hash) || '——'}</span>
        <span class="checkpoint-task">${escapeHtml(taskId)}</span>
        <span class="checkpoint-time">${ts ? escapeHtml(timeAgo(ts)) : ''}</span>
      </div>`;
    }
    html += `</div>`;
  }

  return html;
}

function renderMetrics(project) {
  const tg = project.task_graph || {};
  const tasks = tg.tasks || [];

  // Counts
  const total = tasks.length;
  const done = tasks.filter(t => (t.status || '').toLowerCase() === 'done').length;
  const failed = tasks.filter(t => (t.status || '').toLowerCase() === 'failed').length;
  const parked = tasks.filter(t => (t.status || '').toLowerCase() === 'parked').length;

  let html = `<div class="section-title">Overview</div>
  <div class="stat-grid">
    <div class="stat-card">
      <div class="stat-number">${total}</div>
      <div class="stat-label">Total Tasks</div>
    </div>
    <div class="stat-card">
      <div class="stat-number" style="color:var(--green)">${done}</div>
      <div class="stat-label">Done</div>
    </div>
    <div class="stat-card">
      <div class="stat-number" style="color:var(--red)">${failed}</div>
      <div class="stat-label">Failed</div>
    </div>
    <div class="stat-card">
      <div class="stat-number" style="color:var(--amber)">${parked}</div>
      <div class="stat-label">Parked</div>
    </div>
  </div>`;

  // Turns by agent
  html += `<div class="section-title">Turns by Agent</div>`;
  const auditLog = project.audit_log || [];
  const turnsByAgent = {};
  for (const entry of auditLog) {
    const agent = entry.agent || 'unknown';
    const turns = Number(entry.turns_used) || 0;
    turnsByAgent[agent] = (turnsByAgent[agent] || 0) + turns;
  }
  const agentTurnEntries = Object.entries(turnsByAgent).sort((a, b) => b[1] - a[1]);
  if (agentTurnEntries.length === 0) {
    html += `<div class="no-data">No turn data in audit log</div>`;
  } else {
    const maxTurns = agentTurnEntries[0][1] || 1;
    html += `<div class="bar-chart">`;
    for (const [agent, turns] of agentTurnEntries) {
      const pct = Math.round((turns / maxTurns) * 100);
      html += `<div class="bar-chart-row">
        <span class="bar-chart-label">${escapeHtml(agent)}</span>
        <div class="bar-chart-bar-bg">
          <div class="bar-chart-bar-fill" style="width:${pct}%"></div>
        </div>
        <span class="bar-chart-value">${turns}</span>
      </div>`;
    }
    html += `</div>`;
  }

  // Status distribution stacked bar
  html += `<div class="section-title">Status Distribution</div>`;
  if (total === 0) {
    html += `<div class="no-data">No tasks in task graph</div>`;
  } else {
    const inProgress = tasks.filter(t => (t.status || '').toLowerCase() === 'in_progress').length;
    const pending = tasks.filter(t => (t.status || '').toLowerCase() === 'pending').length;
    const blocked = tasks.filter(t => (t.status || '').toLowerCase() === 'blocked').length;

    const segments = [
      { label: 'Done', count: done, color: 'var(--green)' },
      { label: 'In Progress', count: inProgress, color: 'var(--blue)' },
      { label: 'Pending', count: pending, color: 'var(--gray)' },
      { label: 'Parked', count: parked, color: 'var(--amber)' },
      { label: 'Failed', count: failed, color: 'var(--red)' },
      { label: 'Blocked', count: blocked, color: 'var(--gray)' },
    ].filter(s => s.count > 0);

    html += `<div style="display:flex;height:20px;border-radius:4px;overflow:hidden;margin-bottom:0.75rem">`;
    for (const seg of segments) {
      const pct = (seg.count / total) * 100;
      html += `<div style="width:${pct}%;background:${seg.color};height:100%" title="${seg.label}: ${seg.count}"></div>`;
    }
    html += `</div>`;

    // Legend
    html += `<div style="display:flex;flex-wrap:wrap;gap:0.75rem;font-size:0.8rem;color:var(--text-muted);margin-bottom:1.5rem">`;
    for (const seg of segments) {
      const pct = Math.round((seg.count / total) * 100);
      html += `<span><span style="display:inline-block;width:10px;height:10px;border-radius:2px;background:${seg.color};margin-right:4px;vertical-align:middle"></span>${escapeHtml(seg.label)}: ${seg.count} (${pct}%)</span>`;
    }
    html += `</div>`;
  }

  // Last 10 completed tasks
  html += `<div class="section-title">Recently Completed Tasks</div>`;
  const doneTasks = tasks
    .filter(t => (t.status || '').toLowerCase() === 'done')
    .slice(-10)
    .reverse();

  if (doneTasks.length === 0) {
    html += `<div class="no-data">No completed tasks yet</div>`;
  } else {
    html += `<div class="table-container"><table>
      <thead><tr><th>Title</th><th>Size</th><th>Assigned To</th><th>Status</th></tr></thead>
      <tbody>`;
    for (const task of doneTasks) {
      html += `<tr>
        <td>${escapeHtml(truncate(task.title || task.name || '—', 60))}</td>
        <td>${escapeHtml(task.size || task.effort || '—')}</td>
        <td>${escapeHtml(task.assigned_to || '—')}</td>
        <td>${statusBadge(task.status)}</td>
      </tr>`;
    }
    html += `</tbody></table></div>`;
  }

  return html;
}

function renderAuditLog(project) {
  const auditLog = project.audit_log || [];

  let html = `<div class="audit-filter-wrap">
    <input type="text" id="audit-filter" placeholder="Filter by agent, action, task...">
  </div>`;

  const entries = auditLog.slice().reverse().slice(0, 100);

  if (entries.length === 0) {
    html += `<div class="no-data">No audit log entries</div>`;
    return html;
  }

  html += `<div class="table-container"><table>
    <thead><tr>
      <th>Time</th><th>Agent</th><th>Action</th><th>Task</th><th>Status</th><th>File</th><th>Turns</th><th></th>
    </tr></thead>
    <tbody id="audit-tbody">`;

  for (let i = 0; i < entries.length; i++) {
    const entry = entries[i];
    const hasDiff = !!(entry.diff);
    const diffId = `diff-${i}`;

    html += `<tr class="audit-row">
      <td>${escapeHtml(formatTime(entry.ts))}</td>
      <td>${escapeHtml(entry.agent || '—')}</td>
      <td>${escapeHtml(entry.action || '—')}</td>
      <td>${escapeHtml(truncate(entry.task || entry.task_id || '—', 30))}</td>
      <td>${statusBadge(entry.status)}</td>
      <td>${escapeHtml(truncate(entry.file || '', 28))}</td>
      <td>${entry.turns_used !== undefined && entry.turns_used !== null ? escapeHtml(String(entry.turns_used)) : '—'}</td>
      <td>${hasDiff ? `<button class="diff-toggle" data-diff="${escapeHtml(diffId)}">▶</button>` : ''}</td>
    </tr>`;

    if (hasDiff) {
      html += `<tr class="diff-row" id="${escapeHtml(diffId)}" style="display:none">
        <td colspan="8"><pre class="diff-block">${escapeHtml(entry.diff)}</pre></td>
      </tr>`;
    }
  }

  html += `</tbody></table></div>`;
  return html;
}

// ─── Main render dispatcher ───

function render() {
  if (!state.data || !state.currentProject) return;
  const project = state.data.projects[state.currentProject];
  if (!project) return;
  const content = document.getElementById('content');
  switch (state.currentView) {
    case 'running': content.innerHTML = renderRunningNow(project); break;
    case 'tasks':   content.innerHTML = renderTaskGraph(project);  break;
    case 'metrics': content.innerHTML = renderMetrics(project);    break;
    case 'audit':   content.innerHTML = renderAuditLog(project);   break;
  }
  setupAuditFilter();
  setupDiffToggles();
}

// ─── Audit filter ───

function setupAuditFilter() {
  const input = document.getElementById('audit-filter');
  if (!input) return;
  input.addEventListener('input', () => {
    const q = input.value.toLowerCase();
    document.querySelectorAll('.audit-row').forEach(row => {
      const matches = row.textContent.toLowerCase().includes(q);
      row.style.display = matches ? '' : 'none';
      // Also hide the diff row below if the audit row is hidden
      const next = row.nextElementSibling;
      if (next && next.classList.contains('diff-row')) {
        if (!matches) next.style.display = 'none';
      }
    });
  });
}

// ─── Diff toggle ───

function setupDiffToggles() {
  document.querySelectorAll('.diff-toggle').forEach(btn => {
    btn.addEventListener('click', () => {
      const diffId = btn.getAttribute('data-diff');
      const diffRow = document.getElementById(diffId);
      if (!diffRow) return;
      const isVisible = diffRow.style.display !== 'none';
      diffRow.style.display = isVisible ? 'none' : '';
      btn.textContent = isVisible ? '▶' : '▼';
    });
  });
}

// ─── Tabs ───

function setupTabs() {
  document.querySelectorAll('.tab').forEach(btn => {
    btn.addEventListener('click', () => {
      state.currentView = btn.getAttribute('data-view');
      document.querySelectorAll('.tab').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      render();
    });
  });
}

// ─── Project selector ───

function setupProjectSelector() {
  const select = document.getElementById('project-select');
  select.addEventListener('change', () => {
    state.currentProject = select.value;
    render();
  });
}

// ─── Clock ───

function updateClock() {
  const clock = document.getElementById('clock');
  if (!clock) return;
  const now = new Date();
  clock.textContent = now.toLocaleTimeString('en-GB', { hour12: false });

  // Mark stale if last fetch > 15 seconds ago
  if (state.lastFetch) {
    const age = Date.now() - state.lastFetch;
    const dot = document.getElementById('status-indicator');
    if (dot) {
      dot.className = age < 15000 ? 'status-dot connected' : 'status-dot stale';
    }
  }
}

// ─── Init ───

function init() {
  setupTabs();
  setupProjectSelector();

  // Initial fetch, then poll
  fetchSnapshot();
  setInterval(fetchSnapshot, state.refreshInterval);

  // Clock tick
  updateClock();
  setInterval(updateClock, 1000);
}

document.addEventListener('DOMContentLoaded', init);
