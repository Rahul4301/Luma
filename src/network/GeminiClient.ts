/**
 * Luma - Gemini Client
 * 
 * Google Gemini API integration.
 * Per AGENTS.md: User-invoked only. No background calls.
 * Per SECURITY.md: API key from Keychain only. Never logged.
 */

export interface PageContext {
  title: string;
  url: string;
  excerpt?: string;
}

export class GeminiClient {
  private apiEndpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent';

  /**
   * Send message to Gemini with optional page context.
   * Per AGENTS.md: Context sent only when user requests.
   */
  async sendMessage(
    userMessage: string,
    context: PageContext | null,
    apiKey: string
  ): Promise<string> {
    if (!apiKey) {
      throw new Error('Gemini API key not found');
    }

    // Build prompt with context if provided
    let prompt = userMessage;
    
    if (context) {
      const contextStr = `Page Context:\nTitle: ${context.title}\nURL: ${context.url}\n\n`;
      prompt = contextStr + userMessage;
    }

    // Add system instructions for action format
    const systemInstructions = `
You are Luma, a helpful browser AI assistant.

You can execute browser actions using this format:
- To open a new tab: ACTION: new_tab <url>
- To navigate: ACTION: navigate <url>
- To close tab: ACTION: close_tab
- To switch tabs: ACTION: switch_tab <index>

Only suggest actions when explicitly requested. Otherwise, just answer questions.
Keep responses concise and helpful.
`;

    const requestBody = {
      contents: [
        {
          parts: [
            { text: systemInstructions },
            { text: prompt }
          ]
        }
      ],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 1024,
      }
    };

    try {
      const response = await fetch(`${this.apiEndpoint}?key=${apiKey}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody)
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`Gemini API error: ${response.status} - ${error}`);
      }

      const data = await response.json();
      
      if (!data.candidates || data.candidates.length === 0) {
        throw new Error('No response from Gemini');
      }

      const text = data.candidates[0].content.parts[0].text;
      return text;
    } catch (error: any) {
      console.error('Gemini API error:', error);
      throw new Error(`Failed to get response: ${error.message}`);
    }
  }
}
