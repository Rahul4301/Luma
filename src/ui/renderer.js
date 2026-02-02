// Luma - Renderer
console.log('Renderer loaded');

const lumaApi = window.luma;
console.log('lumaApi:', lumaApi);

let tabs = [];
let activeTabId = null;
let aiPanelVisible = false;
let chatHistory = [];

const START_URL = new URL('start.html', window.location.href).toString();

function resolveTabUrl(url) {
  if (!url || url === 'luma://start') return START_URL;
  return url;
}

function isStartUrl(url) {
  return url === 'luma://start' || (url && url.startsWith('file:') && url.includes('start.html'));
}

function isColorLight(colorString) {
  // Parse RGB color string
  const match = colorString.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
  if (!match) return false;
  
  const r = parseInt(match[1]);
  const g = parseInt(match[2]);
  const b = parseInt(match[3]);
  
  // Calculate luminance using standard formula
  const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  
  // Consider colors with luminance > 0.5 as light
  return luminance > 0.5;
}

const colorSampleInFlight = new WeakSet();

function clearSurfaceColors() {
  const activeTabEl = Array.from(tabsContainer.children).find(el =>
    el.classList.contains('tab') && el.classList.contains('active')
  );
  if (activeTabEl) {
    activeTabEl.style.background = 'rgb(13, 13, 13)'; // Start page color
    activeTabEl.classList.remove('light-bg');
  }

  const addressBar = document.getElementById('address-bar');
  if (addressBar) {
    addressBar.style.background = 'rgb(13, 13, 13)'; // Start page color
    addressBar.classList.remove('light-bg');
  }

  if (urlInput) {
    urlInput.style.background = 'rgb(13, 13, 13)'; // Start page color
    urlInput.style.borderColor = 'rgb(13, 13, 13)';
  }
}

function applySurfaceColor(rgbColor) {
  const activeTabEl = Array.from(tabsContainer.children).find(el =>
    el.classList.contains('tab') && el.classList.contains('active')
  );
  if (activeTabEl) {
    activeTabEl.style.background = rgbColor;
  }

  const addressBar = document.getElementById('address-bar');
  if (addressBar && !addressBar.classList.contains('hidden')) {
    addressBar.style.background = rgbColor;
  }

  if (urlInput && !document.getElementById('address-bar')?.classList.contains('hidden')) {
    urlInput.style.background = rgbColor;
    urlInput.style.borderColor = rgbColor;
  }

  const isLight = isColorLight(rgbColor);
  if (activeTabEl) {
    activeTabEl.classList.toggle('light-bg', isLight);
  }
  if (addressBar) {
    addressBar.classList.toggle('light-bg', isLight);
  }
}

function sampleTopRowColor(dataUrl) {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = img.width;
      canvas.height = img.height;
      const ctx = canvas.getContext('2d');
      if (!ctx) {
        resolve('rgb(26, 26, 26)');
        return;
      }
      ctx.drawImage(img, 0, 0);
      const width = img.width;
      const data = ctx.getImageData(0, 0, width, 1).data;
      let r = 0, g = 0, b = 0, count = 0;
      for (let i = 0; i < data.length; i += 4) {
        r += data[i];
        g += data[i + 1];
        b += data[i + 2];
        count++;
      }
      r = Math.round(r / count);
      g = Math.round(g / count);
      b = Math.round(b / count);
      resolve(`rgb(${r}, ${g}, ${b})`);
    };
    img.onerror = () => resolve('rgb(26, 26, 26)');
    img.src = dataUrl;
  });
}

async function extractSurfaceColor(webview) {
  if (!webview || colorSampleInFlight.has(webview)) return;

  try {
    const currentUrl = webview.getURL?.() || '';
    if (isStartUrl(currentUrl)) {
      clearSurfaceColors();
      return;
    }

    colorSampleInFlight.add(webview);
    try {
      const image = await webview.capturePage({ x: 0, y: 0, width: 120, height: 1 });
      const dataUrl = image.toDataURL();
      const color = await sampleTopRowColor(dataUrl);
      applySurfaceColor(color);
    } catch (e) {
      // Ignore capture errors
    } finally {
      colorSampleInFlight.delete(webview);
    }
  } catch (e) {
    // Webview not ready yet, ignore
    colorSampleInFlight.delete(webview);
  }
}

function focusStartPageInput(webview) {
  try {
    const currentUrl = webview.getURL?.() || '';
    if (isStartUrl(currentUrl)) {
      webview.executeJavaScript(`document.getElementById('q')?.focus();`);
    }
  } catch (e) {
    // Webview not ready yet, ignore
  }
}

// DOM
const tabsContainer = document.getElementById('tabs-container');
const webviewsContainer = document.getElementById('webviews-container');
const urlInput = document.getElementById('url-input');
const aiPanel = document.getElementById('ai-panel');
const aiToggleBtn = document.getElementById('ai-toggle-btn');
const aiCloseBtn = document.getElementById('ai-close-btn');
const newTabBtn = document.getElementById('new-tab-btn');

console.log('DOM elements:', {
  tabsContainer: !!tabsContainer,
  webviewsContainer: !!webviewsContainer,
  urlInput: !!urlInput,
  newTabBtn: !!newTabBtn
});
const backBtn = document.getElementById('back-btn');
const forwardBtn = document.getElementById('forward-btn');
const reloadBtn = document.getElementById('reload-btn');
const contextPreview = document.getElementById('context-preview');
const chatHistoryEl = document.getElementById('chat-history');
const aiInput = document.getElementById('ai-input');
const aiSendBtn = document.getElementById('ai-send-btn');
const settingsModal = document.getElementById('settings-modal');
const settingsCloseBtn = document.getElementById('settings-close-btn');
const saveKeyBtn = document.getElementById('save-key-btn');
const deleteKeyBtn = document.getElementById('delete-key-btn');
const geminiKeyInput = document.getElementById('gemini-key-input');

async function init() {
  try {
    console.log('Init start');
    console.log('lumaApi available:', !!lumaApi);
    
    tabs = await lumaApi.tabGetAll();
    console.log('Loaded tabs:', tabs, 'length:', tabs?.length);
    
    // Always ensure at least one tab exists
    if (!tabs || tabs.length === 0) {
      console.log('No tabs found, creating initial tab with luma://start');
      const tab = await lumaApi.tabNew('luma://start');
      console.log('Created tab:', tab);
      tabs = [tab];
    }
    
    activeTabId = tabs[0]?.id;
    console.log('Setting active tab ID:', activeTabId);
    console.log('About to render with tabs:', tabs);
    render();
    console.log('Render complete');
    
    lumaApi.onToggleAIPanel(() => {
      toggleAIPanel();
    });
    
    // Check if API key exists, prompt settings if not
    checkFirstLaunch();
    
    console.log('Init done');
  } catch (e) {
    console.error('Init error:', e);
    console.error('Error stack:', e.stack);
  }
}

function render() {
  // Remove only tab elements, preserve new tab button
  const existingTabs = Array.from(tabsContainer.querySelectorAll('.tab'));
  existingTabs.forEach(tab => tab.remove());
  
  // Get reference to new tab button (should still be in DOM)
  const newTabBtn = document.getElementById('new-tab-btn');
  
  tabs.forEach(tab => {
    const tabEl = document.createElement('div');
    tabEl.className = 'tab' + (tab.id === activeTabId ? ' active' : '');
    
    // Add favicon if available
    if (tab.favicon) {
      const faviconEl = document.createElement('img');
      faviconEl.className = 'tab-favicon';
      faviconEl.src = tab.favicon;
      faviconEl.onerror = () => faviconEl.style.display = 'none';
      tabEl.appendChild(faviconEl);
    }
    
    const titleEl = document.createElement('span');
    titleEl.className = 'tab-title';
    titleEl.textContent = tab.title || '';
    
    const closeBtn = document.createElement('button');
    closeBtn.className = 'tab-close';
    closeBtn.textContent = '×';
    closeBtn.onclick = (e) => {
      e.stopPropagation();
      closeTab(tab.id);
    };
    
    tabEl.appendChild(titleEl);
    tabEl.appendChild(closeBtn);
    
    // Make entire tab clickable
    tabEl.onclick = () => switchTab(tab.id);
    
    // Insert before new tab button
    if (newTabBtn) {
      tabsContainer.insertBefore(tabEl, newTabBtn);
    } else {
      tabsContainer.appendChild(tabEl);
    }
  });

  updateAddressBarVisibility();
  renderWebviews();
}

function updateAddressBarVisibility() {
  const activeTab = tabs.find(t => t.id === activeTabId);
  const addressBar = document.getElementById('address-bar');
  if (activeTab && activeTab.url === 'luma://start') {
    addressBar.classList.add('hidden');
  } else {
    addressBar.classList.remove('hidden');
  }
}

function renderWebviews() {
  // Only create webviews that don't exist yet
  tabs.forEach(tab => {
    if (!document.getElementById(`webview-${tab.id}`)) {
      const webview = document.createElement('webview');
      webview.id = `webview-${tab.id}`;
      webview.src = resolveTabUrl(tab.url);
      webview.preload = 'file://' + window.location.pathname.replace('/ui/index.html', '/webview-preload.js');
      
      webview.addEventListener('did-stop-loading', async () => {
        const url = webview.getURL?.() || '';
        let title = webview.getTitle?.() || 'Page';
        
        // Always use 'New Tab' for start pages
        if (isStartUrl(url)) {
          title = 'New Tab';
        }
        
        // Get favicon
        let favicon = null;
        if (!isStartUrl(url)) {
          try {
            const favicons = await webview.executeJavaScript(`
              Array.from(document.querySelectorAll('link[rel*="icon"]'))
                .map(link => link.href)
                .filter(href => href && href.startsWith('http'))[0] || null
            `);
            favicon = favicons;
          } catch (e) {
            // Ignore errors
          }
        }
        
        updateTabInfo(tab.id, title, url, favicon);

        if (tab.id === activeTabId) {
          urlInput.value = isStartUrl(url) ? '' : url;
          if (aiPanelVisible) {
            updateContextPreview();
          }
        }
      });
      
      webview.addEventListener('did-start-loading', () => {
        if (tab.id === activeTabId) {
          // Could add loading indicator here
        }
      });

      webview.addEventListener('did-commit-navigation', () => {
        if (tab.id === activeTabId) {
          extractSurfaceColor(webview);
        }
      });

      // Extract background color early for instant visual feedback
      webview.addEventListener('dom-ready', () => {
        if (tab.id === activeTabId) {
          extractSurfaceColor(webview);
          focusStartPageInput(webview);
        }
      });

      // Handle link clicks opening in new tabs (Cmd+Click) or same tab
      webview.addEventListener('will-navigate', (e) => {
        // Allow navigation, don't block it
      });

      // Handle new-window event for Ctrl/Cmd+Click on links
      webview.addEventListener('new-window', (e) => {
        e.preventDefault();
        const url = e.url;
        if (url && (url.startsWith('http') || url.startsWith('https'))) {
          newTabWithURL(url);
        }
      });
      
      webviewsContainer.appendChild(webview);
    }
  });
  
  // Remove webviews for closed tabs
  Array.from(webviewsContainer.children).forEach(webview => {
    const tabId = webview.id.replace('webview-', '');
    if (!tabs.find(t => t.id === tabId)) {
      webview.remove();
    }
  });
  
  updateWebviewVisibility();
}

function updateWebviewVisibility() {
  // Show only the active webview
  Array.from(webviewsContainer.children).forEach(webview => {
    const tabId = webview.id.replace('webview-', '');
    if (tabId === activeTabId) {
      webview.classList.add('active');
      // Extract top-row color for active tab styling
      extractSurfaceColor(webview);
      // Focus start page input if applicable
      focusStartPageInput(webview);
    } else {
      webview.classList.remove('active');
    }
  });
}

function updateTabInfo(tabId, title, url, favicon) {
  const tab = tabs.find(t => t.id === tabId);
  if (tab) {
    const wasStartPage = tab.url === 'luma://start';
    tab.title = title;
    tab.url = isStartUrl(url) ? 'luma://start' : url;
    if (favicon) tab.favicon = favicon;
    const isStartPage = tab.url === 'luma://start';
    
    // Re-render to update favicon and title
    const tabIndex = tabs.findIndex(t => t.id === tabId);
    if (tabIndex !== -1) {
      render();
    }
    
    // Update address bar visibility if navigating away from or to start page
    if (tab.id === activeTabId && wasStartPage !== isStartPage) {
      updateAddressBarVisibility();
    }
  }
}

async function newTab() {
  try {
    const tab = await lumaApi.tabNew();
    tabs.push(tab);
    activeTabId = tab.id;
    render();
  } catch (e) {
    console.error('New tab error:', e);
  }
}

async function newTabWithURL(urlString) {
  try {
    const tab = await lumaApi.tabNew();
    tabs.push(tab);
    activeTabId = tab.id;
    render();
    
    // Load URL in the new tab's webview
    setTimeout(() => {
      const webview = document.getElementById(`webview-${tab.id}`);
      if (webview) {
        webview.loadURL(urlString);
      }
    }, 100);
  } catch (e) {
    console.error('New tab with URL error:', e);
  }
}

async function closeTab(tabId) {
  try {
    await lumaApi.tabClose(tabId);
    tabs = tabs.filter(t => t.id !== tabId);
    if (tabs.length === 0) await newTab();
    else if (activeTabId === tabId) activeTabId = tabs[0].id;
    render();
  } catch (e) {
    console.error('Close tab error:', e);
  }
}

async function switchTab(tabId) {
  try {
    await lumaApi.tabSwitch(tabId);
    activeTabId = tabId;
    render();
  } catch (e) {
    console.error('Switch tab error:', e);
  }
}

function toggleAIPanel() {
  aiPanelVisible = !aiPanelVisible;
  aiPanel.classList.toggle('hidden', !aiPanelVisible);
  aiToggleBtn.classList.toggle('active', aiPanelVisible);
  
  if (aiPanelVisible) {
    updateContextPreview();
  }
}

function updateContextPreview() {
  const activeTab = tabs.find(t => t.id === activeTabId);
  if (activeTab) {
    contextPreview.innerHTML = `
      <div><strong>Title:</strong> ${activeTab.title || ''}</div>
      <div><strong>URL:</strong> ${activeTab.url || 'about:blank'}</div>
    `;
  }
}

function sendAIMessage() {
  const message = aiInput.value.trim();
  if (!message) return;
  
  // Add user message to chat
  chatHistory.push({ role: 'user', content: message });
  renderChatHistory();
  
  aiInput.value = '';
  
  // Mock AI response (will be replaced with real Gemini call)
  setTimeout(() => {
    chatHistory.push({ 
      role: 'assistant', 
      content: 'This is a mock response. Gemini integration coming soon!' 
    });
    renderChatHistory();
  }, 500);
}

function renderChatHistory() {
  chatHistoryEl.innerHTML = chatHistory.map(msg => `
    <div class="chat-message ${msg.role}">
      <div class="message-role">${msg.role}</div>
      <div class="message-content">${msg.content}</div>
    </div>
  `).join('');
  chatHistoryEl.scrollTop = chatHistoryEl.scrollHeight;
}

urlInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    let url = urlInput.value.trim();
    if (!url.startsWith('http')) {
      url = url.includes('.') ? 'https://' + url : 'https://google.com/search?q=' + encodeURIComponent(url);
    }
    const webview = document.getElementById(`webview-${activeTabId}`);
    if (webview?.loadURL) webview.loadURL(url);
  }
});

// Drag and drop handlers
function handleDropURL(dataTransfer) {
  // Check for URL in drag data
  let url = null;
  
  if (dataTransfer.types.includes('text/uri-list')) {
    url = dataTransfer.getData('text/uri-list');
  } else if (dataTransfer.types.includes('text/plain')) {
    const text = dataTransfer.getData('text/plain');
    // Check if it looks like a URL
    if (text.startsWith('http://') || text.startsWith('https://')) {
      url = text;
    }
  }
  
  return url;
}

// Handle drag over the main container (allow drop)
document.addEventListener('dragover', (e) => {
  e.preventDefault();
  e.dataTransfer.dropEffect = 'link';
});

// Drop on tab strip - create new tab
document.getElementById('tab-strip').addEventListener('drop', (e) => {
  e.preventDefault();
  const url = handleDropURL(e.dataTransfer);
  if (url) {
    newTabWithURL(url);
  }
});

// Drop on webviews container - navigate current tab
webviewsContainer.addEventListener('drop', (e) => {
  e.preventDefault();
  const url = handleDropURL(e.dataTransfer);
  if (url) {
    const webview = document.getElementById(`webview-${activeTabId}`);
    if (webview?.loadURL) {
      webview.loadURL(url);
    }
  }
});

webviewsContainer.addEventListener('dragover', (e) => {
  e.preventDefault();
  e.dataTransfer.dropEffect = 'link';
});

// Keyboard shortcuts
document.addEventListener('keydown', (e) => {
  if (e.metaKey || e.ctrlKey) {
    // Cmd+T - New Tab
    if (e.key === 't') {
      e.preventDefault();
      newTab();
    }
    // Cmd+W - Close Tab
    else if (e.key === 'w') {
      e.preventDefault();
      if (tabs.length > 1) closeTab(activeTabId);
    }
    // Cmd+L - Focus address bar
    else if (e.key === 'l') {
      e.preventDefault();
      urlInput.focus();
      urlInput.select();
    }
    // Cmd+R - Reload
    else if (e.key === 'r' && !e.shiftKey) {
      e.preventDefault();
      const wv = document.getElementById(`webview-${activeTabId}`);
      if (wv?.reload) wv.reload();
    }
    // Cmd+[ - Previous tab
    else if (e.key === '[') {
      e.preventDefault();
      const currentIdx = tabs.findIndex(t => t.id === activeTabId);
      if (currentIdx > 0) switchTab(tabs[currentIdx - 1].id);
    }
    // Cmd+] - Next tab
    else if (e.key === ']') {
      e.preventDefault();
      const currentIdx = tabs.findIndex(t => t.id === activeTabId);
      if (currentIdx < tabs.length - 1) switchTab(tabs[currentIdx + 1].id);
    }
    // Cmd+1-9 - Switch to tab by index
    else if (e.key >= '1' && e.key <= '9') {
      e.preventDefault();
      const idx = parseInt(e.key) - 1;
      if (idx < tabs.length) switchTab(tabs[idx].id);
    }
    // Cmd+F - Find in page
    else if (e.key === 'f') {
      e.preventDefault();
      const wv = document.getElementById(`webview-${activeTabId}`);
      if (!wv?.findInPage) return;
      const query = window.prompt('Find in page');
      if (query && query.trim()) {
        wv.findInPage(query.trim(), { findNext: false, matchCase: false });
      } else {
        wv.stopFindInPage?.('clearSelection');
      }
    }
    // Cmd+Enter in AI input - Send message
    else if (e.key === 'Enter' && document.activeElement === aiInput) {
      e.preventDefault();
      sendAIMessage();
    }
  }
  // Escape - Close AI panel or blur input
  else if (e.key === 'Escape') {
    if (aiPanelVisible) {
      toggleAIPanel();
    } else if (document.activeElement === urlInput) {
      urlInput.blur();
    }
  }
});

newTabBtn.addEventListener('click', newTab);
aiToggleBtn.addEventListener('click', toggleAIPanel);
aiCloseBtn.addEventListener('click', toggleAIPanel);
if (aiSendBtn) {
  aiSendBtn.addEventListener('click', sendAIMessage);
}

aiInput.addEventListener('keydown', (e) => {
  if ((e.metaKey || e.ctrlKey) && e.key === 'Enter') {
    e.preventDefault();
    sendAIMessage();
  }
});

// Settings modal
async function openSettings() {
  const key = await lumaApi.getGeminiKey();
  if (key) {
    geminiKeyInput.value = '••••••••••••••••';
  }
  settingsModal.classList.remove('hidden');
}

settingsCloseBtn.addEventListener('click', () => {
  settingsModal.classList.add('hidden');
});

saveKeyBtn.addEventListener('click', async () => {
  const key = geminiKeyInput.value.trim();
  if (key && key !== '••••••••••••••••') {
    await lumaApi.setGeminiKey(key);
    alert('API key saved successfully!');
    settingsModal.classList.add('hidden');
  }
});

deleteKeyBtn.addEventListener('click', async () => {
  if (confirm('Are you sure you want to delete your API key?')) {
    await lumaApi.deleteGeminiKey();
    geminiKeyInput.value = '';
    alert('API key deleted');
  }
});

// Model selection toggle
document.querySelectorAll('input[name="model"]').forEach(radio => {
  radio.addEventListener('change', (e) => {
    const ollamaSettings = document.getElementById('ollama-settings');
    if (e.target.value === 'ollama') {
      ollamaSettings.style.display = 'flex';
    } else {
      ollamaSettings.style.display = 'none';
    }
  });
});

// Check for API key on first launch
async function checkFirstLaunch() {
  const key = await lumaApi.getGeminiKey();
  if (!key) {
    setTimeout(() => openSettings(), 500);
  }
}

backBtn.addEventListener('click', () => {
  const wv = document.getElementById(`webview-${activeTabId}`);
  if (wv?.canGoBack?.()) wv.goBack();
});

forwardBtn.addEventListener('click', () => {
  const wv = document.getElementById(`webview-${activeTabId}`);
  if (wv?.canGoForward?.()) wv.goForward();
});

reloadBtn.addEventListener('click', () => {
  const wv = document.getElementById(`webview-${activeTabId}`);
  if (wv?.reload) wv.reload();
});

init();
