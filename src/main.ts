/**
 * Luma - Main Process
 * 
 * Electron main process entry point.
 * Per AGENTS.md: User-invoked only, no background activity.
 */

import { app, BrowserWindow, ipcMain, globalShortcut, Menu } from 'electron';
import * as path from 'path';
import { TabManager } from './browser/TabManager';
import { KeychainManager } from './auth/KeychainManager';

let mainWindow: BrowserWindow | null = null;
const tabManager = new TabManager();

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 800,
    minHeight: 600,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#1a1a1a',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: false,
      contextIsolation: true,
      webviewTag: true,
      sandbox: true,
      allowRunningInsecureContent: false,
      webSecurity: true
    }
  });

  const mainPath = path.join(__dirname, 'ui/index.html');
  console.log('Loading:', mainPath);
  mainWindow.loadFile(mainPath);

  // Dev tools for debugging
  mainWindow.webContents.openDevTools({ mode: 'detach' });

  // Cmd+E to toggle AI panel
  mainWindow.webContents.on('before-input-event', (event, input) => {
    if (input.meta && input.key.toLowerCase() === 'e' && input.type === 'keyDown') {
      event.preventDefault();
      mainWindow?.webContents.send('toggle-ai-panel');
    }
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

// IPC handlers - Keychain
ipcMain.handle('get-gemini-key', async () => {
  try {
    return await KeychainManager.getGeminiKey();
  } catch (error) {
    console.error('Error getting key:', error);
    return null;
  }
});

ipcMain.handle('set-gemini-key', async (_, key: string) => {
  try {
    return await KeychainManager.setGeminiKey(key);
  } catch (error) {
    console.error('Error setting key:', error);
    return false;
  }
});

ipcMain.handle('delete-gemini-key', async () => {
  try {
    return await KeychainManager.deleteGeminiKey();
  } catch (error) {
    console.error('Error deleting key:', error);
    return false;
  }
});

// IPC handlers - Tabs
ipcMain.handle('tab:new', async (_, url?: string) => {
  const tab = tabManager.createTab(url);
  console.log('New tab:', tab);
  return tab;
});

ipcMain.handle('tab:close', async (_, tabId: string) => {
  tabManager.closeTab(tabId);
});

ipcMain.handle('tab:switch', async (_, tabId: string) => {
  tabManager.setActiveTab(tabId);
});

ipcMain.handle('tab:get-all', async () => {
  const tabs = tabManager.getAllTabs();
  console.log('tab:get-all called, returning:', tabs);
  return tabs;
});

ipcMain.handle('tab:get-active', async () => {
  return tabManager.getActiveTab();
});

ipcMain.handle('tab:update', async (_, tabId: string, updates: any) => {
  tabManager.updateTab(tabId, updates);
});

app.whenReady().then(() => {
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
