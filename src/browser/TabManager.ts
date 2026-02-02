/**
 * Luma - Tab Manager
 * 
 * Manages browser tabs state.
 * Per SRS: Standard tab operations (new, close, switch).
 */

import { v4 as uuidv4 } from 'uuid';

export interface Tab {
  id: string;
  url: string;
  title: string;
  favicon?: string;
}

export class TabManager {
  private tabs: Tab[] = [];
  private activeTabId: string | null = null;

  constructor() {
    // Create initial tab
    this.createTab('luma://start');
  }

  createTab(url: string = 'luma://start'): Tab {
    const tab: Tab = {
      id: uuidv4(),
      url,
      title: 'New Tab'
    };
    this.tabs.push(tab);
    this.activeTabId = tab.id;
    return tab;
  }

  closeTab(tabId: string): void {
    const index = this.tabs.findIndex(t => t.id === tabId);
    if (index === -1) return;

    this.tabs.splice(index, 1);

    // If closing active tab, switch to adjacent
    if (this.activeTabId === tabId) {
      if (this.tabs.length > 0) {
        const newIndex = Math.min(index, this.tabs.length - 1);
        this.activeTabId = this.tabs[newIndex].id;
      } else {
        this.activeTabId = null;
      }
    }

    // Always keep at least one tab
    if (this.tabs.length === 0) {
      this.createTab();
    }
  }

  setActiveTab(tabId: string): void {
    const tab = this.tabs.find(t => t.id === tabId);
    if (tab) {
      this.activeTabId = tabId;
    }
  }

  getActiveTab(): Tab | null {
    return this.tabs.find(t => t.id === this.activeTabId) || null;
  }

  getAllTabs(): Tab[] {
    return this.tabs;
  }

  updateTab(tabId: string, updates: Partial<Tab>): void {
    const tab = this.tabs.find(t => t.id === tabId);
    if (tab) {
      Object.assign(tab, updates);
    }
  }
}
