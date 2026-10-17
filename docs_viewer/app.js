/**
 * Flutter Competition Toolkit - Modern Local Documentation Viewer App
 */

// State
let currentDocId = null;
let currentSidebarTab = 'all'; // 'all', 'primary', 'modules'
let currentFontSizeIndex = 1;
const FONT_SIZES = ['14px', '16px', '18px', '20px'];
let searchDebounceTimeout = null;

// Icons mapping (clean inline SVGs for zero network dependency)
const ICONS = {
  // Core guide icons
  'book-open': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></svg>',
  'zap': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/></svg>',
  'trophy': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/></svg>',
  'layers': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 2 7 12 12 22 7 12 2"/><polyline points="2 17 12 22 22 17"/><polyline points="2 12 12 17 22 12"/></svg>',
  'compass': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><polygon points="16.24 7.76 14.12 14.12 7.76 16.24 9.88 9.88 16.24 7.76"/></svg>',
  'message-circle': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m3 21 1.9-5.7a8.5 8.5 0 1 1 3.8 3.8z"/></svg>',
  'clipboard-list': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="8" height="4" x="8" y="2" rx="1" ry="1"/><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><path d="M12 11h4"/><path d="M12 16h4"/><circle cx="8" cy="11" r="1"/><circle cx="8" cy="16" r="1"/></svg>',
  'check-circle': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>',
  
  // Lib module icons
  'palette': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="13.5" cy="6.5" r=".5" fill="currentColor"/><circle cx="17.5" cy="10.5" r=".5" fill="currentColor"/><circle cx="8.5" cy="7.5" r=".5" fill="currentColor"/><circle cx="6.5" cy="12.5" r=".5" fill="currentColor"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z"/></svg>',
  'layout': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><line x1="3" x2="21" y1="9" y2="9"/><line x1="9" x2="9" y1="21" y2="9"/></svg>',
  'bell': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>',
  'message-square': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>',
  'check-square': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>',
  'smartphone': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="14" height="20" x="5" y="2" rx="2" ry="2"/><line x1="12" x2="12.01" y1="18" y2="18"/></svg>',
  'navigation': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="3 11 22 2 13 21 11 13 3 11"/></svg>',
  'cpu': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="16" height="16" x="4" y="4" rx="2"/><rect width="6" height="6" x="9" y="9"/><path d="M9 1v3"/><path d="M15 1v3"/><path d="M9 20v3"/><path d="M15 20v3"/><path d="M20 9h3"/><path d="M20 14h3"/><path d="M1 9h3"/><path d="M1 14h3"/></svg>',
  'database': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>',
  'server': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="20" height="8" x="2" y="2" rx="2" ry="2"/><rect width="20" height="8" x="2" y="14" rx="2" ry="2"/><line x1="6" x2="6.01" y1="6" y2="6"/><line x1="6" x2="6.01" y1="18" y2="18"/></svg>',
  'tool': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>',
  'star': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>',
  'sparkles': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z"/></svg>',
  'bot': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="18" height="14" x="3" y="6" rx="2"/><path d="M12 2v4"/><circle cx="9" cy="13" r="1"/><circle cx="15" cy="13" r="1"/><path d="M8 17h8"/></svg>',
  'monitor': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="20" height="14" x="2" y="3" rx="2"/><line x1="8" x2="16" y1="21" y2="21"/><line x1="12" x2="12" y1="17" y2="21"/></svg>',
  'file-text': '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z"/><polyline points="14 2 14 8 20 8"/><line x1="16" x2="8" y1="13" y2="13"/><line x1="16" x2="8" y1="17" y2="17"/><line x1="10" x2="8" y1="9" y2="9"/></svg>',
  'search': '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/></svg>',
  'copy': '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>',
  'check': '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>',
  'arrow-up': '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="18 15 12 9 6 15"/></svg>',
  'external-link': '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" x2="21" y1="14" y2="3"/></svg>'
};

// Initialize Application
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  configureMarked();
  renderSidebar();
  setupEventListeners();
  
  // Handle initial route
  handleHashChange();
  window.addEventListener('hashchange', handleHashChange);
});

// Configure Marked Parser
function configureMarked() {
  if (typeof marked === 'undefined') {
    console.error('marked library not loaded');
    return;
  }
  marked.setOptions({
    gfm: true,
    breaks: false
  });
}

// Render Sidebar Navigation
function renderSidebar() {
  const primaryList = document.getElementById('primaryNavList');
  const moduleList = document.getElementById('moduleNavList');
  const showcaseList = document.getElementById('showcaseNavList');
  
  if (!window.DOCS_METADATA) {
    primaryList.innerHTML = `<div style="padding:15px;color:var(--text-muted);">No documentation data found.</div>`;
    return;
  }
  
  primaryList.innerHTML = '';
  moduleList.innerHTML = '';
  if (showcaseList) showcaseList.innerHTML = '';
  
  window.DOCS_METADATA.forEach(doc => {
    const iconSvg = ICONS[doc.icon] || ICONS['file-text'];
    
    // Create navigation card element
    const itemEl = document.createElement('a');
    itemEl.className = 'nav-item';
    itemEl.id = `nav-${cleanId(doc.id)}`;
    itemEl.href = `#${doc.id}`;
    
    let leftVisual = `<span class="nav-item-icon">${iconSvg}</span>`;
    if (doc.moduleNum && doc.moduleNum !== 'Demo') {
      leftVisual = `<span class="mod-num-chip">${doc.moduleNum}</span>`;
    }
    
    itemEl.innerHTML = `
      ${leftVisual}
      <div class="nav-item-info">
        <div class="nav-item-title">
          <span>${escapeHtml(doc.title)}</span>
          <span class="nav-badge">${escapeHtml(doc.badge)}</span>
        </div>
        <div class="nav-item-desc">${escapeHtml(doc.desc)}</div>
      </div>
    `;
    
    if (doc.isPrimary) {
      primaryList.appendChild(itemEl);
    } else if (doc.isModule) {
      moduleList.appendChild(itemEl);
    } else if (showcaseList) {
      showcaseList.appendChild(itemEl);
    }
  });

  applySidebarTabFilter();
}

// Filter Sidebar based on Tab Selection ('all', 'primary', 'modules')
function setSidebarTab(tab) {
  currentSidebarTab = tab;
  
  // Update tab buttons
  document.querySelectorAll('.sidebar-tab').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.tab === tab);
  });
  
  applySidebarTabFilter();
}

function applySidebarTabFilter() {
  const secCore = document.getElementById('sectionCoreDocs');
  const secLib = document.getElementById('sectionLibModules');
  const secShowcase = document.getElementById('sectionShowcase');
  
  if (!secCore || !secLib) return;
  
  if (currentSidebarTab === 'primary') {
    secCore.style.display = 'block';
    secLib.style.display = 'none';
    if (secShowcase) secShowcase.style.display = 'none';
  } else if (currentSidebarTab === 'modules') {
    secCore.style.display = 'none';
    secLib.style.display = 'block';
    if (secShowcase) secShowcase.style.display = 'block';
  } else { // 'all'
    secCore.style.display = 'block';
    secLib.style.display = 'block';
    if (secShowcase) secShowcase.style.display = 'block';
  }
}

// Handle Routing via URL Hash
function handleHashChange() {
  const hash = window.location.hash.slice(1);
  if (!hash) {
    const defaultDoc = window.DOCS_METADATA ? window.DOCS_METADATA[0].id : 'README.md';
    loadDoc(defaultDoc);
    return;
  }
  
  let docId = hash;
  let targetAnchor = null;
  
  if (hash.includes('#')) {
    const parts = hash.split('#');
    docId = parts[0];
    targetAnchor = parts[1];
  }
  
  loadDoc(docId, targetAnchor);
}

// Load and Render Document
function loadDoc(docId, targetAnchor = null) {
  if (!window.DOCS_METADATA || !window.DOCS_CONTENT) {
    showToast('Documentation content not available');
    return;
  }
  
  // Clean docId and match
  let cleanDocId = docId.replace(/\\/g, '/');
  if (cleanDocId.startsWith('./')) cleanDocId = cleanDocId.substring(2);
  
  const docMeta = window.DOCS_METADATA.find(d => 
    d.id === cleanDocId || 
    d.filename === cleanDocId ||
    d.relPath === cleanDocId ||
    d.id.endsWith(cleanDocId) ||
    cleanDocId.endsWith(d.id)
  );
  
  if (!docMeta) {
    console.warn('Doc not found:', docId);
    return;
  }
  
  currentDocId = docMeta.id;
  
  // Auto switch sidebar tab if current item is hidden
  if (docMeta.isPrimary && currentSidebarTab === 'modules') {
    setSidebarTab('all');
  } else if (docMeta.isModule && currentSidebarTab === 'primary') {
    setSidebarTab('modules');
  }
  
  // Update sidebar active states
  document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
  const activeNav = document.getElementById(`nav-${cleanId(docMeta.id)}`);
  if (activeNav) {
    activeNav.classList.add('active');
    activeNav.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }
  
  // Update Breadcrumbs
  document.getElementById('crumbDocCategory').textContent = docMeta.category;
  document.getElementById('crumbDocTitle').textContent = docMeta.title;
  
  // Update Document Header Banner
  document.getElementById('docHeaderTitle').textContent = docMeta.title;
  document.getElementById('docHeaderDesc').textContent = docMeta.desc;
  document.getElementById('docHeaderBadge').textContent = docMeta.badge;
  document.getElementById('docHeaderCategory').textContent = docMeta.category;
  document.getElementById('docHeaderReadTime').textContent = docMeta.readTime;
  document.getElementById('docHeaderWords').textContent = `${docMeta.words.toLocaleString()} words`;
  document.getElementById('docHeaderFile').textContent = docMeta.relPath;

  // Retrieve Raw Markdown Content
  const rawMarkdown = window.DOCS_CONTENT[docMeta.id] || window.DOCS_CONTENT[docMeta.relPath] || '';
  
  // Render Markdown to HTML
  const markdownContainer = document.getElementById('markdownContent');
  let renderedHtml = marked.parse(rawMarkdown);
  
  markdownContainer.innerHTML = renderedHtml;
  
  // Post-process the rendered HTML
  postProcessContent(markdownContainer, docMeta);
  
  // Build Table of Contents
  buildTableOfContents(markdownContainer);
  
  // Scroll to target anchor or top
  if (targetAnchor) {
    setTimeout(() => {
      const anchorEl = document.getElementById(targetAnchor) || 
                       markdownContainer.querySelector(`a[name="${targetAnchor}"]`) ||
                       markdownContainer.querySelector(`a[id="${targetAnchor}"]`) ||
                       document.getElementById(targetAnchor.toLowerCase());
      if (anchorEl) {
        anchorEl.scrollIntoView({ behavior: 'smooth', block: 'start' });
      } else {
        document.getElementById('articleContainer').scrollTop = 0;
      }
    }, 120);
  } else {
    document.getElementById('articleContainer').scrollTop = 0;
  }
  
  updateReadingProgress();
}

// Post-Process Content
function postProcessContent(container, docMeta) {
  // 1. Wrap tables in responsive container
  container.querySelectorAll('table').forEach(tbl => {
    if (!tbl.parentElement.classList.contains('table-wrapper')) {
      const wrapper = document.createElement('div');
      wrapper.className = 'table-wrapper';
      tbl.parentNode.insertBefore(wrapper, tbl);
      wrapper.appendChild(tbl);
    }
  });

  // 2. Setup Headings with Clean IDs & Classes
  container.querySelectorAll('h1, h2, h3, h4, h5, h6').forEach(heading => {
    const level = heading.tagName.substring(1);
    heading.classList.add('doc-heading', `doc-heading-${level}`);
    
    if (!heading.id) {
      const slug = heading.textContent
        .toLowerCase()
        .replace(/<[^>]+>/g, '')
        .replace(/[^\w\s-]/g, '')
        .trim()
        .replace(/\s+/g, '-');
      heading.id = slug;
    }
  });

  // 3. Syntax Highlighting and Code Blocks
  container.querySelectorAll('pre code').forEach((codeBlock) => {
    const codeText = codeBlock.textContent;
    const isAsciiBox = /[┌┬┐└┴┘│─├┼┤]/.test(codeText);
    const pre = codeBlock.parentElement;
    
    if (isAsciiBox) {
      pre.classList.add('ascii-diagram');
      const wrapper = document.createElement('div');
      wrapper.className = 'ascii-diagram-wrapper';
      pre.parentNode.insertBefore(wrapper, pre);
      wrapper.appendChild(pre);
      return;
    }
    
    // Standard code block
    const wrapper = document.createElement('div');
    wrapper.className = 'code-block-wrapper';
    
    let lang = 'code';
    codeBlock.classList.forEach(cls => {
      if (cls.startsWith('language-')) {
        lang = cls.replace('language-', '');
      }
    });
    
    const header = document.createElement('div');
    header.className = 'code-block-header';
    header.innerHTML = `
      <span class="code-lang-label">${lang}</span>
      <button class="copy-code-btn" title="Copy code">
        ${ICONS['copy']} <span>Copy</span>
      </button>
    `;
    
    const copyBtn = header.querySelector('.copy-code-btn');
    copyBtn.addEventListener('click', () => {
      navigator.clipboard.writeText(codeText).then(() => {
        copyBtn.innerHTML = `${ICONS['check']} <span>Copied!</span>`;
        setTimeout(() => {
          copyBtn.innerHTML = `${ICONS['copy']} <span>Copy</span>`;
        }, 2000);
      });
    });
    
    pre.parentNode.insertBefore(wrapper, pre);
    wrapper.appendChild(header);
    wrapper.appendChild(pre);
    
    if (typeof hljs !== 'undefined') {
      try {
        hljs.highlightElement(codeBlock);
      } catch (e) {
        // fallback
      }
    }
  });
  
  // 4. Intercept Internal Markdown Links & Cross References
  container.querySelectorAll('a').forEach(link => {
    let href = link.getAttribute('href');
    if (!href) return;
    
    // Normalize slashes
    href = href.replace(/\\/g, '/');
    
    if (href.endsWith('.md') || href.includes('.md#') || href.startsWith('lib/') || href.includes('/README.md')) {
      link.classList.add('doc-link');
      link.addEventListener('click', (e) => {
        e.preventDefault();
        
        let targetDoc = href;
        let targetAnchor = null;
        
        if (href.includes('#')) {
          const parts = href.split('#');
          targetDoc = parts[0];
          targetAnchor = parts[1];
        }
        
        if (targetDoc.startsWith('./')) targetDoc = targetDoc.substring(2);
        
        // Find matching doc
        const match = window.DOCS_METADATA.find(d => 
          d.id === targetDoc || 
          d.filename === targetDoc || 
          d.relPath === targetDoc || 
          d.relPath.endsWith(targetDoc) ||
          targetDoc.endsWith(d.relPath)
        );
        
        if (match) {
          window.location.hash = targetAnchor ? `${match.id}#${targetAnchor}` : match.id;
        } else if (targetDoc.startsWith('lib/') && !targetDoc.endsWith('.md')) {
          // If links to folder like lib/01_design_system/app_tokens.dart, check if folder has README
          const folder = targetDoc.split('/')[1];
          const modDoc = window.DOCS_METADATA.find(d => d.relPath.includes(`lib/${folder}/README.md`));
          if (modDoc) {
            window.location.hash = modDoc.id;
          }
        } else if (targetAnchor) {
          const el = document.getElementById(targetAnchor);
          if (el) el.scrollIntoView({ behavior: 'smooth' });
        }
      });
    } else if (href.startsWith('#')) {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const targetId = href.substring(1);
        const el = document.getElementById(targetId) || 
                   container.querySelector(`a[name="${targetId}"]`) ||
                   container.querySelector(`a[id="${targetId}"]`);
        if (el) {
          el.scrollIntoView({ behavior: 'smooth' });
          history.replaceState(null, null, `#${currentDocId}#${targetId}`);
        }
      });
    } else if (href.startsWith('http://') || href.startsWith('https://')) {
      link.setAttribute('target', '_blank');
      link.setAttribute('rel', 'noopener noreferrer');
      link.innerHTML += ` ${ICONS['external-link']}`;
    }
  });
  
  // 5. Format Badges & Tags ([Official], [Toolkit], [Preference], etc.)
  container.querySelectorAll('p, li, td').forEach(el => {
    let html = el.innerHTML;
    let modified = false;
    
    if (html.includes('[Official]')) {
      html = html.replace(/\[Official\]/g, '<span class="pill-badge pill-official">Official</span>');
      modified = true;
    }
    if (html.includes('[Toolkit]')) {
      html = html.replace(/\[Toolkit\]/g, '<span class="pill-badge pill-toolkit">Toolkit</span>');
      modified = true;
    }
    if (html.includes('[Preference]')) {
      html = html.replace(/\[Preference\]/g, '<span class="pill-badge pill-preference">Preference</span>');
      modified = true;
    }
    if (html.includes('Risk: High')) {
      html = html.replace(/Risk:\s*High/g, '<span class="pill-badge pill-risk-high">Risk: High</span>');
      modified = true;
    }
    
    if (modified) el.innerHTML = html;
  });

  // 6. Style Task Lists / Checkboxes
  container.querySelectorAll('li').forEach(li => {
    const text = li.innerHTML.trim();
    if (text.startsWith('[ ] ')) {
      li.classList.add('task-list-item');
      li.innerHTML = `<input type="checkbox" disabled> ` + text.slice(4);
    } else if (text.startsWith('[x] ') || text.startsWith('[X] ')) {
      li.classList.add('task-list-item');
      li.innerHTML = `<input type="checkbox" checked disabled> ` + text.slice(4);
    }
  });
}

// Build Table of Contents
function buildTableOfContents(container) {
  const tocList = document.getElementById('tocList');
  tocList.innerHTML = '';
  
  const headings = container.querySelectorAll('h1, h2, h3');
  if (headings.length === 0) {
    tocList.innerHTML = '<li style="color:var(--text-muted);font-size:12px;padding:8px;">No sections found</li>';
    return;
  }
  
  headings.forEach(heading => {
    const level = parseInt(heading.tagName[1]);
    const id = heading.id || cleanId(heading.textContent);
    heading.id = id;
    
    const li = document.createElement('li');
    li.className = `toc-item toc-level-${level}`;
    li.dataset.headingId = id;
    
    const a = document.createElement('a');
    a.href = `#${currentDocId}#${id}`;
    a.textContent = heading.textContent.replace(/<[^>]+>/g, '').trim();
    a.title = a.textContent;
    
    a.addEventListener('click', (e) => {
      e.preventDefault();
      heading.scrollIntoView({ behavior: 'smooth', block: 'start' });
      history.replaceState(null, null, `#${currentDocId}#${id}`);
      
      document.querySelectorAll('.toc-item').forEach(el => el.classList.remove('active'));
      li.classList.add('active');
    });
    
    li.appendChild(a);
    tocList.appendChild(li);
  });
  
  const filterInput = document.getElementById('tocFilterInput');
  if (filterInput) filterInput.value = '';
}

// Setup Event Listeners
function setupEventListeners() {
  const articleContainer = document.getElementById('articleContainer');
  
  // Scrollspy & Reading Progress
  articleContainer.addEventListener('scroll', () => {
    updateReadingProgress();
    updateScrollspy();
  });
  
  // Sidebar Tab Switcher Buttons
  document.querySelectorAll('.sidebar-tab').forEach(tabBtn => {
    tabBtn.addEventListener('click', () => {
      setSidebarTab(tabBtn.dataset.tab);
    });
  });
  
  // Theme Toggle
  document.getElementById('themeToggleBtn').addEventListener('click', toggleTheme);
  
  // Font Size Adjusters
  document.getElementById('fontSmallerBtn').addEventListener('click', () => changeFontSize(-1));
  document.getElementById('fontBiggerBtn').addEventListener('click', () => changeFontSize(1));
  
  // Copy Raw Markdown Button
  document.getElementById('copyRawDocBtn').addEventListener('click', () => {
    if (currentDocId && window.DOCS_CONTENT && (window.DOCS_CONTENT[currentDocId] || window.DOCS_CONTENT[currentDocId.replace(/\\/g, '/')])) {
      const content = window.DOCS_CONTENT[currentDocId] || window.DOCS_CONTENT[currentDocId.replace(/\\/g, '/')];
      navigator.clipboard.writeText(content).then(() => {
        showToast('Document markdown copied to clipboard!');
      });
    }
  });
  
  // Print Button
  document.getElementById('printDocBtn').addEventListener('click', () => {
    window.print();
  });
  
  // TOC Sidebar Toggle
  document.getElementById('tocToggleBtn').addEventListener('click', () => {
    const tocSidebar = document.getElementById('tocSidebar');
    tocSidebar.style.display = tocSidebar.style.display === 'none' ? 'flex' : 'none';
  });
  
  // Mobile Sidebar Toggle
  document.getElementById('sidebarToggleBtn').addEventListener('click', () => {
    document.getElementById('sidebar').classList.toggle('open');
  });
  
  // TOC Filter Input
  document.getElementById('tocFilterInput').addEventListener('input', (e) => {
    const query = e.target.value.toLowerCase().trim();
    document.querySelectorAll('.toc-item').forEach(item => {
      const text = item.textContent.toLowerCase();
      item.style.display = text.includes(query) ? 'block' : 'none';
    });
  });
  
  // Search Modal Trigger
  document.getElementById('searchModalBtn').addEventListener('click', openSearchModal);
  document.getElementById('globalSearchTrigger').addEventListener('click', openSearchModal);
  
  // Keyboard Shortcut: Ctrl+K or Cmd+K
  document.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
      e.preventDefault();
      openSearchModal();
    } else if (e.key === 'Escape') {
      closeSearchModal();
    }
  });
  
  // Close Search Modal
  document.getElementById('searchModalBackdrop').addEventListener('click', (e) => {
    if (e.target.id === 'searchModalBackdrop') {
      closeSearchModal();
    }
  });
  
  // Search Input Query Handler
  document.getElementById('globalSearchInput').addEventListener('input', (e) => {
    clearTimeout(searchDebounceTimeout);
    searchDebounceTimeout = setTimeout(() => {
      performSearch(e.target.value);
    }, 150);
  });
}

// Update Reading Progress Bar
function updateReadingProgress() {
  const container = document.getElementById('articleContainer');
  const scrollTotal = container.scrollHeight - container.clientHeight;
  const progress = scrollTotal > 0 ? (container.scrollTop / scrollTotal) * 100 : 0;
  document.getElementById('readingProgressBar').style.width = `${Math.min(100, Math.max(0, progress))}%`;
}

// Update Scrollspy for Table of Contents
function updateScrollspy() {
  const container = document.getElementById('articleContainer');
  const headings = container.querySelectorAll('.doc-heading');
  if (headings.length === 0) return;
  
  let currentActiveId = null;
  const scrollY = container.scrollTop + 100;
  
  headings.forEach(heading => {
    if (heading.offsetTop <= scrollY) {
      currentActiveId = heading.id;
    }
  });
  
  if (currentActiveId) {
    document.querySelectorAll('.toc-item').forEach(item => {
      if (item.dataset.headingId === currentActiveId) {
        item.classList.add('active');
        item.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
      } else {
        item.classList.remove('active');
      }
    });
  }
}

// Theme Handlers
function initTheme() {
  const savedTheme = localStorage.getItem('competition_docs_theme') || 'dark';
  applyTheme(savedTheme);
}

function toggleTheme() {
  const current = document.documentElement.getAttribute('data-theme');
  const next = current === 'dark' ? 'light' : 'dark';
  applyTheme(next);
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('competition_docs_theme', theme);
  
  const btn = document.getElementById('themeToggleBtn');
  if (theme === 'dark') {
    btn.innerHTML = '☀️';
    btn.title = 'Switch to light mode';
  } else {
    btn.innerHTML = '🌙';
    btn.title = 'Switch to dark mode';
  }
  
  const hlLink = document.getElementById('highlightThemeLink');
  if (hlLink) {
    hlLink.href = theme === 'dark' ? 'assets/github-dark.min.css' : 'assets/github.min.css';
  }
}

// Font Size Adjustment
function changeFontSize(delta) {
  currentFontSizeIndex = Math.max(0, Math.min(FONT_SIZES.length - 1, currentFontSizeIndex + delta));
  const newSize = FONT_SIZES[currentFontSizeIndex];
  document.getElementById('markdownContent').style.fontSize = newSize;
  showToast(`Text size: ${newSize}`);
}

// Search Modal
function openSearchModal() {
  const modal = document.getElementById('searchModalBackdrop');
  modal.classList.add('open');
  const input = document.getElementById('globalSearchInput');
  input.value = '';
  input.focus();
  performSearch('');
}

function closeSearchModal() {
  document.getElementById('searchModalBackdrop').classList.remove('open');
}

// Search Engine Across All Documents
function performSearch(query) {
  const resultsContainer = document.getElementById('searchResults');
  const trimmed = query.trim().toLowerCase();
  
  if (!trimmed) {
    resultsContainer.innerHTML = `
      <div style="padding:20px;text-align:center;color:var(--text-muted);font-size:13px;">
        Type to search across all 8 competition guides and 14 lib modules...
      </div>
    `;
    return;
  }
  
  const results = [];
  
  window.DOCS_METADATA.forEach(doc => {
    const rawContent = window.DOCS_CONTENT[doc.id] || window.DOCS_CONTENT[doc.relPath] || '';
    const contentLower = rawContent.toLowerCase();
    
    const titleMatch = doc.title.toLowerCase().includes(trimmed);
    
    let index = contentLower.indexOf(trimmed);
    let matchCount = 0;
    let snippet = '';
    
    if (index !== -1) {
      matchCount++;
      const start = Math.max(0, index - 50);
      const end = Math.min(rawContent.length, index + trimmed.length + 80);
      snippet = rawContent.substring(start, end).replace(/\n/g, ' ');
    }
    
    if (titleMatch || matchCount > 0) {
      results.push({
        doc: doc,
        titleMatch: titleMatch,
        snippet: snippet,
        score: (titleMatch ? 10 : 0) + matchCount
      });
    }
  });
  
  results.sort((a, b) => b.score - a.score);
  
  if (results.length === 0) {
    resultsContainer.innerHTML = `
      <div style="padding:24px;text-align:center;color:var(--text-muted);font-size:13px;">
        No results found for "<b>${escapeHtml(query)}</b>"
      </div>
    `;
    return;
  }
  
  resultsContainer.innerHTML = '';
  results.slice(0, 20).forEach(res => {
    const item = document.createElement('div');
    item.className = 'search-result-item';
    
    const regex = new RegExp(`(${escapeRegExp(query)})`, 'gi');
    const highlightedTitle = res.doc.title.replace(regex, '<span class="search-highlight">$1</span>');
    let highlightedSnippet = res.snippet ? res.snippet.replace(regex, '<span class="search-highlight">$1</span>') : res.doc.desc;
    
    item.innerHTML = `
      <div class="search-result-header">
        <span class="search-result-doc">${escapeHtml(res.doc.filename)}</span>
        <span style="font-size:10px;color:var(--text-muted);">${res.doc.category}</span>
      </div>
      <div class="search-result-title">${highlightedTitle}</div>
      <div class="search-result-snippet">...${highlightedSnippet}...</div>
    `;
    
    item.addEventListener('click', () => {
      closeSearchModal();
      window.location.hash = res.doc.id;
    });
    
    resultsContainer.appendChild(item);
  });
}

// Toast Helper
function showToast(message) {
  let toast = document.getElementById('toastNotice');
  if (!toast) {
    toast = document.createElement('div');
    toast.id = 'toastNotice';
    toast.className = 'toast-notice';
    document.body.appendChild(toast);
  }
  toast.textContent = message;
  toast.classList.add('show');
  setTimeout(() => {
    toast.classList.remove('show');
  }, 2400);
}

// Utilities
function cleanId(str) {
  return String(str).toLowerCase().replace(/[^\w-]/g, '-');
}

function escapeHtml(str) {
  if (!str) return '';
  return str.replace(/[&<>'"]/g, 
    tag => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[tag] || tag));
}

function escapeRegExp(string) {
  return string.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
