/**
 * Webview Preload Script
 * 
 * Handles link clicks and other webview-specific interactions.
 * Intercepts link clicks to navigate in the same tab (unless Cmd/Ctrl+Click).
 */

import { ipcRenderer } from 'electron';

// Wait for DOM to be ready
document.addEventListener('DOMContentLoaded', () => {
  // Handle all link clicks
  document.addEventListener('click', (e: any) => {
    const target = (e.target as HTMLElement).closest('a');
    if (!target) return;

    const href = target.getAttribute('href');
    if (!href || href.startsWith('#') || href.startsWith('javascript:')) return;

    // Check if this is a Cmd/Ctrl+Click (open in new tab)
    const isNewTab = e.metaKey || e.ctrlKey || e.button === 1; // Cmd/Ctrl or middle click

    if (isNewTab) {
      // Let the new-window event handle it
      return;
    }

    // For regular clicks, navigate in current tab
    e.preventDefault();
    
    // Convert relative URLs to absolute
    let url = href;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      try {
        url = new URL(href, window.location.href).toString();
      } catch {
        url = href;
      }
    }

    // Load in current webview
    (window as any).location.href = url;
  }, true); // Use capture phase to catch clicks early
});
