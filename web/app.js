// Voice Inbox — web client. Same loop as the iOS app:
// record → transcribe → classify/structure (server) → confirm → card.
// Local-first: everything you save lives in this browser (localStorage).

const $ = (sel) => document.querySelector(sel);
const API = location.origin;
const STORE_KEY = "voice-inbox-web-v1";
const SETTINGS_KEY = "voice-inbox-web-settings";

// ---------- state ----------
const db = load();
const settings = Object.assign({ language: "system", notifications: "unknown" }, JSON.parse(localStorage.getItem(SETTINGS_KEY) || "{}"));
let filter = null;          // null | today | todos | reminders | ideas
let pendingConfirm = null;  // capture being confirmed
let editing = null;         // { kind, id } when editing a saved card
const timers = new Map();   // reminder id → timeout

function load() {
  try { return Object.assign({ captures: [], todos: [], reminders: [], ideas: [] }, JSON.parse(localStorage.getItem(STORE_KEY) || "{}")); }
  catch { return { captures: [], todos: [], reminders: [], ideas: [] }; }
}
function save() { localStorage.setItem(STORE_KEY, JSON.stringify(db)); render(); }
function saveSettings() { localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings)); }
const uid = () => (crypto.randomUUID ? crypto.randomUUID() : String(Date.now() + Math.random()));

// ---------- language ----------
function resolvedLanguage() {
  if (settings.language === "zh") return "zh";
  if (settings.language === "en") return "en";
  return (navigator.language || "en").toLowerCase().startsWith("zh") ? "zh" : "en";
}
const speechLocale = () => (resolvedLanguage() === "zh" ? "zh-CN" : "en-US");

// ---------- server ----------
async function health() {
  const res = await fetch(`${API}/health`, { cache: "no-store" });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}
async function createCapture() {
  const res = await fetch(`${API}/v1/captures`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ mode: "quick" }) });
  if (!res.ok) throw new Error(`Server returned ${res.status}`);
  return res.json();
}
async function uploadAudio(uploadUrl, wavBlob) {
  const res = await fetch(uploadUrl, { method: "PUT", headers: { "content-type": "audio/wav" }, body: wavBlob });
  if (!res.ok) throw new Error(`Upload failed (${res.status})`);
}
async function processCapture(id, { transcript, language } = {}) {
  const body = { timezone: Intl.DateTimeFormat().resolvedOptions().timeZone, localeHint: resolvedLanguage() };
  if (transcript) { body.transcript = transcript; body.language = language || speechLocale(); }
  const res = await fetch(`${API}/v1/captures/${id}/process`, { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`Server returned ${res.status}`);
}
async function pollCapture(id) {
  for (let i = 0; i < 40; i++) {
    await new Promise((r) => setTimeout(r, 1200));
    const res = await fetch(`${API}/v1/captures/${id}`, { cache: "no-store" });
    if (!res.ok) throw new Error(`Server returned ${res.status}`);
    const data = await res.json();
    if (data.status === "done") return data;
    if (data.status === "failed") throw new Error(data.error || "Processing failed");
  }
  throw new Error("Processing timed out. Try again.");
}

// ---------- pipeline ----------
async function runCapture(capture) {
  capture.status = "processing"; capture.error = null; save();
  try {
    const { captureId, uploadUrl } = await createCapture();
    if (capture.transcript) {
      await processCapture(captureId, { transcript: capture.transcript, language: capture.language });
    } else if (capture.wav) {
      await uploadAudio(uploadUrl, capture.wav);
      await processCapture(captureId);
    } else {
      throw new Error("Nothing to process");
    }
    const result = await pollCapture(captureId);
    capture.transcript = result.transcript || capture.transcript;
    capture.intent = result.result?.intent || "unclassified";
    capture.confidence = result.result?.confidence ?? 0;
    capture.payload = result.result?.[capture.intent] || {};
    capture.status = "awaitingConfirm";
    delete capture.wav;
    save();
    openConfirm(capture);
  } catch (err) {
    capture.status = "failed"; capture.error = humanError(err); save();
  }
}
function humanError(err) {
  const m = String(err?.message || err);
  if (/Failed to fetch|NetworkError|Load failed/i.test(m)) return `Can't reach the server at ${API}.`;
  return m;
}
function submitText(text, language) {
  const t = text.trim(); if (!t) return;
  const capture = { id: uid(), createdAt: Date.now(), transcript: t, language: language || speechLocale(), status: "queued" };
  db.captures.unshift(capture); save();
  runCapture(capture);
}

// ---------- recording (Web Speech API, with audio-upload fallback) ----------
const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
let recognition = null, mediaRecorder = null, chunks = [], recording = false, startedAt = 0, timerInterval = null, finalText = "";
const recordBtn = $("#recordBtn"), liveText = $("#liveText"), timer = $("#timer"), hint = $("#hint");

function setRecordingUI(on) {
  recording = on;
  recordBtn.classList.toggle("recording", on);
  recordBtn.setAttribute("aria-label", on ? "Stop recording" : "Record");
  timer.hidden = !on;
  hint.textContent = on ? "Tap again to stop · Space" : "Tap to talk · Space to start and stop";
  if (on) { startedAt = Date.now(); timerInterval = setInterval(() => { const s = Math.floor((Date.now() - startedAt) / 1000); timer.textContent = `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`; }, 250); }
  else { clearInterval(timerInterval); timer.textContent = "0:00"; }
}

async function startRecording() {
  finalText = ""; liveText.textContent = "";
  if (SR) {
    recognition = new SR();
    recognition.lang = speechLocale();
    recognition.interimResults = true;
    recognition.continuous = true;
    recognition.onresult = (e) => {
      let interim = "";
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const r = e.results[i];
        if (r.isFinal) finalText += r[0].transcript; else interim += r[0].transcript;
      }
      liveText.textContent = finalText + interim;
    };
    recognition.onerror = (e) => { if (e.error !== "no-speech" && e.error !== "aborted") liveText.textContent = `Speech error: ${e.error}`; };
    recognition.onend = () => { if (recording) finishRecording(); };
    recognition.start();
    setRecordingUI(true);
    return;
  }
  // Fallback: capture audio, convert to WAV, let the server transcribe.
  const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  chunks = [];
  mediaRecorder = new MediaRecorder(stream);
  mediaRecorder.ondataavailable = (e) => chunks.push(e.data);
  mediaRecorder.onstop = async () => {
    stream.getTracks().forEach((t) => t.stop());
    const blob = new Blob(chunks, { type: mediaRecorder.mimeType });
    const wav = await toWav(blob);
    const capture = { id: uid(), createdAt: Date.now(), status: "queued", wav };
    db.captures.unshift(capture); save();
    runCapture(capture);
  };
  mediaRecorder.start();
  setRecordingUI(true);
}
function finishRecording() {
  if (!recording) return;
  setRecordingUI(false);
  if (recognition) { const r = recognition; recognition = null; r.onend = null; try { r.stop(); } catch {} 
    const text = (finalText + " " + (liveText.textContent.slice(finalText.length) || "")).trim();
    liveText.textContent = "";
    if (text) submitText(text); else liveText.textContent = "Didn't catch that. Try again.";
    return;
  }
  if (mediaRecorder && mediaRecorder.state !== "inactive") mediaRecorder.stop();
}
function toggleRecording() { recording ? finishRecording() : startRecording().catch((e) => { setRecordingUI(false); liveText.textContent = humanError(e); }); }

async function toWav(blob) {
  const ctx = new (window.AudioContext || window.webkitAudioContext)();
  const decoded = await ctx.decodeAudioData(await blob.arrayBuffer());
  const rate = 16000, frames = Math.ceil(decoded.duration * rate);
  const offline = new OfflineAudioContext(1, frames, rate);
  const src = offline.createBufferSource(); src.buffer = decoded; src.connect(offline.destination); src.start();
  const mono = (await offline.startRendering()).getChannelData(0);
  const buf = new ArrayBuffer(44 + mono.length * 2), v = new DataView(buf);
  const w = (o, s) => { for (let i = 0; i < s.length; i++) v.setUint8(o + i, s.charCodeAt(i)); };
  w(0, "RIFF"); v.setUint32(4, 36 + mono.length * 2, true); w(8, "WAVE"); w(12, "fmt "); v.setUint32(16, 16, true); v.setUint16(20, 1, true); v.setUint16(22, 1, true);
  v.setUint32(24, rate, true); v.setUint32(28, rate * 2, true); v.setUint16(32, 2, true); v.setUint16(34, 16, true); w(36, "data"); v.setUint32(40, mono.length * 2, true);
  for (let i = 0; i < mono.length; i++) { const s = Math.max(-1, Math.min(1, mono[i])); v.setInt16(44 + i * 2, s < 0 ? s * 0x8000 : s * 0x7FFF, true); }
  return new Blob([buf], { type: "audio/wav" });
}

recordBtn.addEventListener("click", toggleRecording);
document.addEventListener("keydown", (e) => {
  if (e.code === "Space" && !["INPUT", "TEXTAREA", "SELECT"].includes(document.activeElement?.tagName) && !document.querySelector("dialog[open]")) { e.preventDefault(); toggleRecording(); }
});
$("#typeForm").addEventListener("submit", (e) => { e.preventDefault(); const i = $("#typeInput"); submitText(i.value); i.value = ""; });

// ---------- confirm / edit sheet ----------
const dlg = $("#confirmDialog");
function fillLines(container, values, placeholder) {
  container.innerHTML = "";
  values.forEach((v) => addLine(container, v, placeholder));
}
function addLine(container, value = "", placeholder = "") {
  const input = document.createElement("input"); input.type = "text"; input.value = value; input.placeholder = placeholder; container.appendChild(input); return input;
}
const linesOf = (container) => [...container.querySelectorAll("input")].map((i) => i.value.trim()).filter(Boolean);
function toLocalInput(date) { const d = new Date(date); d.setMinutes(d.getMinutes() - d.getTimezoneOffset()); return d.toISOString().slice(0, 16); }

function showFields() {
  const intent = dlg.querySelector('input[name="intent"]:checked')?.value || "todo";
  $("#todoFields").hidden = intent !== "todo"; $("#reminderFields").hidden = intent !== "reminder"; $("#ideaFields").hidden = intent !== "idea";
}
dlg.querySelectorAll('input[name="intent"]').forEach((r) => r.addEventListener("change", showFields));
$("#addSubtask").addEventListener("click", () => addLine($("#fSubtasks"), "", "Subtask").focus());
$("#addBullet").addEventListener("click", () => addLine($("#fBullets"), "", "Point").focus());

function openConfirm(capture) {
  pendingConfirm = capture; editing = null;
  $("#confirmTitle").textContent = "Confirm";
  $("#confirmDelete").textContent = "Delete this capture"; $("#confirmDelete").hidden = false;
  $("#confirmLater").textContent = "Later";
  const intent = ["todo", "reminder", "idea"].includes(capture.intent) ? capture.intent : "todo";
  dlg.querySelector(`input[name="intent"][value="${intent}"]`).checked = true;
  const p = capture.payload || {};
  $("#confidenceNote").hidden = capture.intent !== "unclassified";
  $("#confidenceNote").textContent = `The AI wasn't confident about the type (${Math.round((capture.confidence || 0) * 100)}%). Pick one.`;
  $("#fTitle").value = p.title || capture.transcript?.split(/[，,。；;.\n]/)[0] || "";
  $("#fDetails").value = p.details || "";
  fillLines($("#fSubtasks"), p.subtasks || [], "Subtask");
  $("#fFireAt").value = toLocalInput(p.fireAt ? new Date(p.fireAt) : new Date(Date.now() + 3600e3));
  fillLines($("#fBullets"), p.bullets || [], "Point");
  $("#transcriptField").hidden = !capture.transcript; $("#fTranscript").textContent = capture.transcript || "";
  showFields(); dlg.showModal();
}
function openEdit(kind, id) {
  const item = db[kind].find((x) => x.id === id); if (!item) return;
  pendingConfirm = null; editing = { kind, id };
  $("#confirmTitle").textContent = "Edit"; $("#confirmLater").textContent = "Cancel";
  $("#confirmDelete").textContent = "Delete"; $("#confirmDelete").hidden = false;
  const intent = kind === "todos" ? "todo" : kind === "reminders" ? "reminder" : "idea";
  dlg.querySelector(`input[name="intent"][value="${intent}"]`).checked = true;
  $("#confidenceNote").hidden = true;
  $("#fTitle").value = item.title; $("#fDetails").value = item.details || "";
  fillLines($("#fSubtasks"), (item.subtasks || []).map((s) => s.text), "Subtask");
  $("#fFireAt").value = toLocalInput(item.fireAt || Date.now() + 3600e3);
  fillLines($("#fBullets"), item.bullets || [], "Point");
  $("#transcriptField").hidden = !item.transcript; $("#fTranscript").textContent = item.transcript || "";
  showFields(); dlg.showModal();
}
$("#confirmLater").addEventListener("click", () => dlg.close("later"));
$("#confirmDelete").addEventListener("click", () => {
  if (pendingConfirm) { if (confirm("Delete this capture? The transcript will be deleted.")) { db.captures = db.captures.filter((c) => c.id !== pendingConfirm.id); save(); dlg.close("deleted"); } }
  else if (editing) { if (confirm("Delete this card?")) { deleteCard(editing.kind, editing.id); dlg.close("deleted"); } }
});
$("#confirmForm").addEventListener("submit", (e) => {
  e.preventDefault();
  const intent = dlg.querySelector('input[name="intent"]:checked').value;
  const title = $("#fTitle").value.trim(); if (!title) return;
  const transcript = pendingConfirm?.transcript ?? db[editing?.kind]?.find((x) => x.id === editing?.id)?.transcript;
  const base = { title, transcript, updatedAt: Date.now() };
  let kind, item;
  if (intent === "todo") { kind = "todos"; const old = editing ? db.todos.find((x) => x.id === editing.id) : null; item = { ...base, details: $("#fDetails").value.trim(), subtasks: linesOf($("#fSubtasks")).map((t) => ({ text: t, done: old?.subtasks?.find((s) => s.text === t)?.done || false })) }; }
  else if (intent === "reminder") { kind = "reminders"; item = { ...base, fireAt: new Date($("#fFireAt").value).getTime(), done: false }; }
  else { kind = "ideas"; item = { ...base, bullets: linesOf($("#fBullets")) }; }
  if (editing) {
    const i = db[editing.kind].findIndex((x) => x.id === editing.id);
    const old = db[editing.kind][i]; db[editing.kind].splice(i, 1);
    item.id = old.id; item.createdAt = old.createdAt; if (kind === "reminders" && editing.kind === "reminders") item.done = old.done;
  } else {
    item.id = uid(); item.createdAt = Date.now();
    db.captures = db.captures.filter((c) => c.id !== pendingConfirm.id);
  }
  db[kind].unshift(item); save();
  if (kind === "reminders") scheduleReminder(item);
  dlg.close("saved");
});

// ---------- cards ----------
function deleteCard(kind, id) { db[kind] = db[kind].filter((x) => x.id !== id); if (timers.has(id)) { clearTimeout(timers.get(id)); timers.delete(id); } save(); }
function toggleSubtask(id, idx) { const t = db.todos.find((x) => x.id === id); t.subtasks[idx].done = !t.subtasks[idx].done; t.completedAt = t.subtasks.length && t.subtasks.every((s) => s.done) ? Date.now() : null; save(); }
function toggleReminder(id) { const r = db.reminders.find((x) => x.id === id); r.done = !r.done; if (r.done && timers.has(id)) { clearTimeout(timers.get(id)); timers.delete(id); } else if (!r.done) scheduleReminder(r); save(); }
function fmtTime(ts) { const d = new Date(ts), now = new Date(); const t = d.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" }); if (d.toDateString() === now.toDateString()) return `Today ${t}`; const tm = new Date(now); tm.setDate(tm.getDate() + 1); if (d.toDateString() === tm.toDateString()) return `Tomorrow ${t}`; return d.toLocaleString([], { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }); }
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const isToday = (ts) => new Date(ts).toDateString() === new Date().toDateString();

function render() {
  const openTodos = db.todos.filter((t) => !t.completedAt).length;
  const openRem = db.reminders.filter((r) => !r.done);
  $("#countToday").textContent = openRem.filter((r) => isToday(r.fireAt) || r.fireAt < Date.now()).length;
  $("#countTodos").textContent = openTodos; $("#countReminders").textContent = openRem.length; $("#countIdeas").textContent = db.ideas.length;
  document.querySelectorAll(".tile").forEach((t) => t.classList.toggle("active", t.dataset.filter === filter));
  $("#clearFilter").hidden = !filter;
  $("#streamTitle").textContent = { today: "Today", todos: "To-dos", reminders: "Reminders", ideas: "Ideas" }[filter] || "Recent";

  const out = [];
  if (!filter) for (const c of db.captures) out.push(captureRow(c));
  const entries = [];
  if (!filter || filter === "todos") entries.push(...db.todos.map((t) => ({ at: t.createdAt, html: todoCard(t) })));
  if (!filter || filter === "reminders") entries.push(...db.reminders.map((r) => ({ at: r.createdAt, html: reminderCard(r) })));
  if (filter === "today") entries.push(...db.reminders.filter((r) => !r.done && (isToday(r.fireAt) || r.fireAt < Date.now())).sort((a, b) => a.fireAt - b.fireAt).map((r) => ({ at: Infinity, html: reminderCard(r) })));
  if (!filter || filter === "ideas") entries.push(...db.ideas.map((i) => ({ at: i.createdAt, html: ideaCard(i) })));
  entries.sort((a, b) => b.at - a.at).forEach((e) => out.push(e.html));
  $("#stream").innerHTML = out.join("");
  $("#emptyState").hidden = out.length > 0;
}
function captureRow(c) {
  const label = { queued: "Queued", processing: "Processing", awaitingConfirm: "To confirm", failed: "Failed" }[c.status] || c.status;
  const sub = c.status === "failed" ? esc(c.error) : c.status === "awaitingConfirm" ? "Tap to confirm" : esc(c.transcript || "Voice note");
  return `<div class="card capture-row" data-capture="${c.id}">${c.status === "processing" ? '<div class="spin"></div>' : ""}<div style="flex:1;min-width:0"><div class="card-title">${esc(c.transcript?.slice(0, 80) || "Voice note")}</div><div class="meta">${sub}</div></div><span class="badge ${c.status === "failed" ? "failed" : ""}">${label}</span>${c.status === "failed" ? `<div class="card-actions"><button data-act="retry" title="Retry">↻</button><button data-act="delcap" title="Delete">✕</button></div>` : ""}</div>`;
}
function todoCard(t) {
  return `<div class="card ${t.completedAt ? "done" : ""}" data-todo="${t.id}"><div class="card-head"><span class="glyph">☑︎</span><span class="card-title">${esc(t.title)}</span><div class="card-actions"><button data-act="edit" data-kind="todos" title="Edit">✎</button><button data-act="del" data-kind="todos" title="Delete">✕</button></div></div>${t.details ? `<p class="details">${esc(t.details)}</p>` : ""}${(t.subtasks || []).map((s, i) => `<div class="row ${s.done ? "done" : ""}" data-sub="${i}"><span class="circle">${s.done ? "✓" : ""}</span><span class="row-text">${esc(s.text)}</span></div>`).join("")}</div>`;
}
function reminderCard(r) {
  const overdue = !r.done && r.fireAt < Date.now();
  return `<div class="card ${r.done ? "done" : ""}" data-reminder="${r.id}"><div class="row" data-toggle><span class="circle ${r.done ? "" : ""}">${r.done ? "✓" : ""}</span><div style="flex:1"><div class="card-title">${esc(r.title)}</div><div class="meta ${overdue ? "overdue" : ""}">${fmtTime(r.fireAt)}</div></div><span class="glyph">🔔</span><div class="card-actions"><button data-act="edit" data-kind="reminders" title="Edit">✎</button><button data-act="del" data-kind="reminders" title="Delete">✕</button></div></div></div>`;
}
function ideaCard(i) {
  return `<div class="card" data-idea="${i.id}"><div class="card-head"><span class="glyph">💡</span><span class="card-title">${esc(i.title)}</span><div class="card-actions"><button data-act="edit" data-kind="ideas" title="Edit">✎</button><button data-act="del" data-kind="ideas" title="Delete">✕</button></div></div>${i.bullets?.length ? `<ul class="bullets">${i.bullets.map((b) => `<li>${esc(b)}</li>`).join("")}</ul>` : ""}</div>`;
}
$("#stream").addEventListener("click", (e) => {
  const btn = e.target.closest("button[data-act]");
  const card = e.target.closest("[data-todo],[data-reminder],[data-idea],[data-capture]");
  if (!card) return;
  const id = card.dataset.todo || card.dataset.reminder || card.dataset.idea || card.dataset.capture;
  if (btn) {
    const act = btn.dataset.act;
    if (act === "edit") return openEdit(btn.dataset.kind, id);
    if (act === "del") { if (confirm("Delete this card?")) deleteCard(btn.dataset.kind, id); return; }
    if (act === "retry") { const c = db.captures.find((x) => x.id === id); if (c) runCapture(c); return; }
    if (act === "delcap") { if (confirm("Delete this capture?")) { db.captures = db.captures.filter((x) => x.id !== id); save(); } return; }
  }
  if (card.dataset.capture) { const c = db.captures.find((x) => x.id === id); if (c?.status === "awaitingConfirm") openConfirm(c); else if (c?.status === "failed") alert(c.error); return; }
  const sub = e.target.closest("[data-sub]"); if (sub && card.dataset.todo) return toggleSubtask(id, Number(sub.dataset.sub));
  if (e.target.closest("[data-toggle]") && card.dataset.reminder) return toggleReminder(id);
});
document.querySelectorAll(".tile").forEach((t) => t.addEventListener("click", () => { filter = filter === t.dataset.filter ? null : t.dataset.filter; render(); }));
$("#clearFilter").addEventListener("click", () => { filter = null; render(); });

// ---------- reminders (browser notifications; fire while this page is open) ----------
function scheduleReminder(r) {
  if (timers.has(r.id)) clearTimeout(timers.get(r.id));
  const delay = r.fireAt - Date.now(); if (r.done || delay < 0 || delay > 2147483647) return;
  timers.set(r.id, setTimeout(() => {
    timers.delete(r.id);
    if (Notification.permission === "granted") new Notification(r.title, { body: "Reminder from Voice Inbox", icon: "/icons/icon-192.png" });
    else alert(`Reminder: ${r.title}`);
    render();
  }, delay));
}
db.reminders.forEach(scheduleReminder);

// ---------- settings ----------
const sdlg = $("#settingsDialog");
$("#settingsBtn").addEventListener("click", () => { $("#serverOrigin").textContent = API; $("#langSelect").value = settings.language; $("#testResult").textContent = ""; notifState(); sdlg.showModal(); });
$("#serverBannerBtn").addEventListener("click", () => $("#settingsBtn").click());
$("#langSelect").addEventListener("change", (e) => { settings.language = e.target.value; saveSettings(); });
$("#testConnection").addEventListener("click", async () => {
  $("#testResult").textContent = "Testing…";
  try { const h = await health(); $("#testResult").textContent = `OK · speech: ${label(h.providers.asr)} · structuring: ${h.providers.structurer === "mock" ? "rules (Claude not configured)" : h.providers.structurer}`; }
  catch (e) { $("#testResult").textContent = humanError(e); }
});
function label(asr) { return asr === "mock" ? "browser (server has no cloud ASR)" : asr === "tencent" ? "Tencent Cloud ASR" : asr; }
function notifState() { const p = ("Notification" in window) ? Notification.permission : "unsupported"; $("#notifState").textContent = { granted: "Allowed — reminders will notify while this page is open.", denied: "Blocked in the browser settings.", default: "Not asked yet.", unsupported: "Not supported in this browser." }[p]; $("#notifBtn").hidden = p !== "default"; }
$("#notifBtn").addEventListener("click", async () => { await Notification.requestPermission(); notifState(); });

// ---------- boot ----------
async function boot() {
  render();
  try { await health(); $("#serverBanner").hidden = true; }
  catch (e) { $("#serverBannerText").textContent = humanError(e); $("#serverBanner").hidden = false; }
  db.captures.filter((c) => c.status === "processing").forEach((c) => { c.status = "failed"; c.error = "Interrupted. Retry."; });
  save();
  if ("serviceWorker" in navigator && (location.protocol === "https:" || location.hostname === "localhost")) navigator.serviceWorker.register("/sw.js").catch(() => {});
}
boot();
