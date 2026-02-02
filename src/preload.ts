/**
 * Luma - Preload Script
 * 
 * Exposes secure IPC bridge to renderer.
 * Per SECURITY.md: No direct node integration in renderer.
 */

import { contextBridge, ipcRenderer } from 'electron';

contextBridge.exposeInMainWorld('luma', {
  // Keychain
  getGeminiKey: () => ipcRenderer.invoke('get-gemini-key'),
  setGeminiKey: (key: string) => ipcRenderer.invoke('set-gemini-key', key),
  deleteGeminiKey: () => ipcRenderer.invoke('delete-gemini-key'),

  // Tab management
  tabNew: (url?: string) => ipcRenderer.invoke('tab:new', url),
  tabClose: (tabId: string) => ipcRenderer.invoke('tab:close', tabId),
  tabSwitch: (tabId: string) => ipcRenderer.invoke('tab:switch', tabId),
  tabGetAll: () => ipcRenderer.invoke('tab:get-all'),

  // AI panel toggle
  onToggleAIPanel: (callback: () => void) => {
    ipcRenderer.on('toggle-ai-panel', callback);
  }
});
