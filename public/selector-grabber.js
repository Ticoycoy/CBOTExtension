/**
 * CB-PHAA Selector Grabber - standalone script injected into page.
 * Runs in MAIN world when popup triggers it via chrome.scripting.executeScript({ files: ['selector-grabber.js'] }).
 * No dependency on content script.
 */
(function() {
  "use strict";
  if (window.__CBPHAA_SELECTOR_GRABBER_ACTIVE__) {
    window.__CBPHAA_SELECTOR_GRABBER_ACTIVE__ = false;
    if (typeof window.__CBPHAA_GRABBER_CLEANUP__ === "function") window.__CBPHAA_GRABBER_CLEANUP__();
    return;
  }
  window.__CBPHAA_SELECTOR_GRABBER_ACTIVE__ = true;

  var overlay = document.createElement("div");
  overlay.id = "cbph-selector-grabber-overlay";
  overlay.style.cssText = "position:fixed;inset:0;z-index:2147483646;pointer-events:auto;cursor:crosshair;background:rgba(0,0,0,0.05);";
  var highlight = document.createElement("div");
  highlight.id = "cbph-selector-grabber-highlight";
  highlight.style.cssText = "position:fixed;pointer-events:none;z-index:2147483645;border:2px solid #56ab2f;background:rgba(86,171,47,0.15);box-sizing:border-box;border-radius:2px;transition:top 0.05s,left 0.05s,width 0.05s,height 0.05s;";
  var tooltip = document.createElement("div");
  tooltip.id = "cbph-selector-grabber-tooltip";
  tooltip.style.cssText = "position:fixed;pointer-events:none;z-index:2147483647;background:#333;color:#fff;font:11px/1.2 sans-serif;padding:4px 8px;border-radius:4px;white-space:nowrap;max-width:320px;overflow:hidden;text-overflow:ellipsis;";
  document.body.appendChild(overlay);
  document.body.appendChild(highlight);
  document.body.appendChild(tooltip);
  highlight.style.display = "none";
  tooltip.style.display = "none";

  function getElementAtPoint(x, y) {
    overlay.style.pointerEvents = "none";
    var el = document.elementFromPoint(x, y);
    overlay.style.pointerEvents = "auto";
    return el && el !== overlay && el !== highlight && el !== tooltip ? el : null;
  }
  function escapeCssId(id) {
    if (!id) return "";
    return String(id).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
  }
  function getSimpleSelector(el) {
    if (!el || el.nodeType !== 1) return "";
    var tag = el.tagName.toLowerCase();
    if (el.id && /^[a-zA-Z][\w-]*$/.test(el.id)) return tag + "#" + escapeCssId(el.id);
    var parts = [tag];
    if (el.className && typeof el.className === "string") {
      var classes = el.className.trim().split(/\s+/).filter(Boolean);
      classes.slice(0, 3).forEach(function(c) { if (/^[\w-]+$/.test(c)) parts.push("." + c); });
    }
    return parts.join("");
  }
  function getSelectorPath(el) {
    if (!el || el.nodeType !== 1) return "";
    var tag = el.tagName.toLowerCase();
    var nth = 1;
    var sib = el.previousElementSibling;
    while (sib) { if (sib.tagName === el.tagName) nth++; sib = sib.previousElementSibling; }
    return tag + ":nth-of-type(" + nth + ")";
  }
  function countMatches(selector) {
    try { return document.querySelectorAll(selector).length; } catch (e) { return 0; }
  }
  function getUniqueSelector(target) {
    if (!target || target.nodeType !== 1) return { selector: "", duplicate: false };
    var simple = getSimpleSelector(target);
    if (countMatches(simple) <= 1) return { selector: simple, duplicate: false };
    var path = [], current = target;
    while (current && current !== document.body) {
      path.unshift(getSelectorPath(current));
      if (countMatches(path.join(" > ")) === 1) return { selector: path.join(" > "), duplicate: true };
      current = current.parentElement;
    }
    return { selector: simple, duplicate: true };
  }
  function getAllAttributes(el) {
    if (!el || el.nodeType !== 1) return {};
    var o = {};
    for (var i = 0; i < el.attributes.length; i++) { var a = el.attributes[i]; o[a.name] = a.value; }
    return o;
  }
  function escapeHtml(s) {
    var d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  }
  function showResultPanel(data) {
    var existingBackdrop = document.getElementById("cbph-selector-grabber-modal-backdrop");
    var existingPanel = document.getElementById("cbph-selector-grabber-result");
    if (existingBackdrop) existingBackdrop.remove();
    if (existingPanel) existingPanel.remove();
    var backdrop = document.createElement("div");
    backdrop.id = "cbph-selector-grabber-modal-backdrop";
    backdrop.style.cssText = "position:fixed;inset:0;z-index:2147483646;background:rgba(0,0,0,0.5);display:flex;align-items:center;justify-content:center;padding:16px;box-sizing:border-box;";
    var panel = document.createElement("div");
    panel.id = "cbph-selector-grabber-result";
    panel.style.cssText = "position:relative;z-index:2147483647;width:100%;max-width:480px;max-height:85vh;overflow:hidden;background:#fff;color:#333;font:12px/1.4 sans-serif;border-radius:12px;box-shadow:0 8px 32px rgba(0,0,0,0.3);display:flex;flex-direction:column;";
    var dupNote = data.duplicate ? "<div style='color:#e65100;font-size:11px;margin-bottom:8px;'>Duplicate elements found – selector uses parent path for uniqueness.</div>" : "";
    var attrRows = Object.keys(data.attributes).map(function(k) {
      var v = String(data.attributes[k]);
      var short = v.length > 60 ? v.substring(0, 60) + "…" : v;
      return "<div style='display:flex;align-items:center;justify-content:space-between;padding:6px 8px;background:#f5f5f5;border-radius:4px;margin-bottom:4px;'>" +
        "<span style='font-weight:600;color:#1565c0;font-size:11px;'>" + escapeHtml(k) + "</span>" +
        "<span style='font-family:monospace;font-size:11px;word-break:break-all;max-width:70%;'>" + escapeHtml(short) + "</span>" +
        "<button type='button' class='cbph-attr-copy' data-value='" + escapeHtml(v).replace(/'/g, "&#39;") + "' style='background:none;border:none;cursor:pointer;padding:2px;margin-left:4px;' title='Copy value'>⎘</button>" +
        "</div>";
    }).join("");
    panel.innerHTML =
      "<div style='display:flex;align-items:center;justify-content:space-between;padding:12px 16px;border-bottom:1px solid #e0e0e0;background:#fafafa;border-radius:12px 12px 0 0;'>" +
      "<span style='font-weight:700;font-size:14px;color:#333;'>Selector - Press ESC to cancel selector grabber</span>" +
      "<button type='button' id='cbph-grabber-close' style='background:none;border:none;cursor:pointer;padding:4px;font-size:18px;line-height:1;color:#666;' title='Close'>×</button>" +
      "</div>" +
      "<div style='padding:16px;overflow:auto;flex:1;'>" +
      "<div style='font-weight:600;font-size:11px;color:#666;margin-bottom:6px;'>CSS Selector</div>" +
      "<div style='display:flex;align-items:center;gap:8px;margin-bottom:12px;'>" +
      "<div style='flex:1;word-break:break-all;background:#f5f5f5;padding:8px 10px;border-radius:6px;font-family:monospace;font-size:12px;'>" + escapeHtml(data.selector) + "</div>" +
      "<button type='button' id='cbph-grabber-copy' style='padding:8px 12px;background:#56ab2f;color:#fff;border:none;border-radius:6px;cursor:pointer;font-size:12px;white-space:nowrap;' title='Copy selector'>Copy</button>" +
      "</div>" + dupNote +
      "<div style='font-weight:600;font-size:11px;color:#666;margin-bottom:6px;'>Tag</div>" +
      "<div style='margin-bottom:12px;font-family:monospace;font-size:12px;'>" + escapeHtml(data.tagName) + "</div>" +
      "<div style='font-weight:600;font-size:11px;color:#666;margin-bottom:6px;'>Attributes</div>" +
      "<div style='max-height:200px;overflow:auto;'>" + (attrRows || "<div style='color:#999;font-size:11px;'>No attributes</div>") + "</div>" +
      "</div>";
    backdrop.appendChild(panel);
    document.body.appendChild(backdrop);
    document.getElementById("cbph-grabber-copy").onclick = function() {
      try {
        navigator.clipboard.writeText(data.selector);
        this.textContent = "Copied!";
        var t = this;
        setTimeout(function() { t.textContent = "Copy"; }, 1500);
      } catch (e) {}
    };
    document.getElementById("cbph-grabber-close").onclick = function() { backdrop.remove(); };
    backdrop.onclick = function(e) { if (e.target === backdrop) backdrop.remove(); };
    panel.onclick = function(e) { e.stopPropagation(); };
    var attrCopyBtns = panel.querySelectorAll(".cbph-attr-copy");
    for (var i = 0; i < attrCopyBtns.length; i++) {
      (function(btn) {
        var val = btn.getAttribute("data-value");
        if (val) btn.onclick = function() {
          try {
            navigator.clipboard.writeText(val);
            btn.textContent = "✓";
            setTimeout(function() { btn.textContent = "⎘"; }, 800);
          } catch (e) {}
        };
      })(attrCopyBtns[i]);
    }
  }
  function onMove(e) {
    var el = getElementAtPoint(e.clientX, e.clientY);
    if (!el) { highlight.style.display = "none"; tooltip.style.display = "none"; return; }
    var r = el.getBoundingClientRect();
    highlight.style.display = "block";
    highlight.style.left = r.left + "px";
    highlight.style.top = r.top + "px";
    highlight.style.width = r.width + "px";
    highlight.style.height = r.height + "px";
    var tag = el.tagName.toLowerCase();
    var id = el.id ? "#" + el.id : "";
    var cls = el.className && typeof el.className === "string" ? "." + el.className.trim().split(/\s+/)[0] : "";
    tooltip.textContent = tag + id + (cls ? cls : "");
    tooltip.style.display = "block";
    tooltip.style.left = (r.left + r.width / 2 - tooltip.offsetWidth / 2) + "px";
    tooltip.style.top = (r.top - tooltip.offsetHeight - 6) + "px";
    if (tooltip.offsetTop < 4) tooltip.style.top = (r.bottom + 6) + "px";
  }
  function onClick(e) {
    e.preventDefault();
    e.stopPropagation();
    var el = getElementAtPoint(e.clientX, e.clientY);
    if (!el) return;
    var result = getUniqueSelector(el);
    var attrs = getAllAttributes(el);
    showResultPanel({ selector: result.selector, duplicate: result.duplicate, tagName: el.tagName.toLowerCase(), attributes: attrs });
  }
  function onKey(e) {
    if (e.key === "Escape") {
      window.__CBPHAA_SELECTOR_GRABBER_ACTIVE__ = false;
      if (window.__CBPHAA_GRABBER_CLEANUP__) window.__CBPHAA_GRABBER_CLEANUP__();
    }
  }
  overlay.addEventListener("mousemove", onMove);
  overlay.addEventListener("click", onClick, true);
  document.addEventListener("keydown", onKey);
  window.__CBPHAA_GRABBER_CLEANUP__ = function() {
    overlay.remove();
    highlight.remove();
    tooltip.remove();
    document.removeEventListener("keydown", onKey);
    var p = document.getElementById("cbph-selector-grabber-result");
    if (p) p.remove();
    var b = document.getElementById("cbph-selector-grabber-modal-backdrop");
    if (b) b.remove();
    window.__CBPHAA_GRABBER_CLEANUP__ = null;
  };
})();
