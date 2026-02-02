/**
 * Luma - Keychain Manager
 * 
 * Secure storage for Gemini API key using macOS Keychain.
 * Per SECURITY.md: Never log keys, never expose to renderer.
 */

import * as keytar from 'keytar';

const SERVICE_NAME = 'com.luma.browser';
const GEMINI_KEY_ACCOUNT = 'gemini-api-key';

export class KeychainManager {
  static async getGeminiKey(): Promise<string | null> {
    try {
      return await keytar.getPassword(SERVICE_NAME, GEMINI_KEY_ACCOUNT);
    } catch (error) {
      console.error('Failed to retrieve Gemini key:', error);
      return null;
    }
  }

  static async setGeminiKey(key: string): Promise<boolean> {
    try {
      await keytar.setPassword(SERVICE_NAME, GEMINI_KEY_ACCOUNT, key);
      return true;
    } catch (error) {
      console.error('Failed to store Gemini key:', error);
      return false;
    }
  }

  static async deleteGeminiKey(): Promise<boolean> {
    try {
      return await keytar.deletePassword(SERVICE_NAME, GEMINI_KEY_ACCOUNT);
    } catch (error) {
      console.error('Failed to delete Gemini key:', error);
      return false;
    }
  }
}
