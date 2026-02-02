/**
 * Luma - Command Router
 * 
 * Parses LLM responses into structured actions.
 * Per AGENTS.md: Deterministic action allowlist only.
 */

export interface BrowserAction {
  type: 'new_tab' | 'navigate' | 'close_tab' | 'switch_tab';
  url?: string;
  index?: string;
}

export interface LLMResponse {
  text: string;
  action?: BrowserAction;
}

export class CommandRouter {
  private actionAllowlist = ['new_tab', 'navigate', 'close_tab', 'switch_tab'];

  /**
   * Parse LLM response and extract action if present.
   * Per AGENTS.md: Model output is untrusted. Only execute allowlisted actions.
   */
  parseResponse(response: string): LLMResponse {
    const result: LLMResponse = { text: response };

    // Look for action markers in response
    // Expected format: ACTION: <type> [params]
    const actionMatch = response.match(/ACTION:\s*(\w+)(?:\s+(.+))?/i);
    
    if (actionMatch) {
      const actionType = actionMatch[1].toLowerCase();
      const params = actionMatch[2];

      // Validate against allowlist
      if (this.actionAllowlist.includes(actionType)) {
        const action: BrowserAction = {
          type: actionType as any
        };

        // Parse parameters based on action type
        switch (actionType) {
          case 'new_tab':
          case 'navigate':
            if (params) {
              action.url = this.extractUrl(params);
            }
            break;
          case 'switch_tab':
            if (params) {
              action.index = params.trim();
            }
            break;
        }

        result.action = action;
        
        // Remove action from text
        result.text = response.replace(/ACTION:.*$/i, '').trim();
      }
    }

    return result;
  }

  private extractUrl(text: string): string {
    // Extract URL from text
    const urlMatch = text.match(/https?:\/\/[^\s]+/);
    if (urlMatch) {
      return urlMatch[0];
    }
    
    // If no protocol, assume https
    const domainMatch = text.match(/([a-z0-9-]+\.)+[a-z]{2,}/i);
    if (domainMatch) {
      return 'https://' + domainMatch[0];
    }

    return text.trim();
  }

  /**
   * Validate action before execution.
   * Per AGENTS.md: Fail closed - if ambiguous, ask for clarification.
   */
  validateAction(action: BrowserAction): { valid: boolean; error?: string } {
    if (!this.actionAllowlist.includes(action.type)) {
      return { valid: false, error: 'Action not in allowlist' };
    }

    switch (action.type) {
      case 'new_tab':
      case 'navigate':
        // URL is optional for new_tab, required for navigate
        if (action.type === 'navigate' && !action.url) {
          return { valid: false, error: 'URL required for navigate action' };
        }
        break;
      
      case 'switch_tab':
        if (!action.index) {
          return { valid: false, error: 'Tab index required' };
        }
        break;
    }

    return { valid: true };
  }
}
