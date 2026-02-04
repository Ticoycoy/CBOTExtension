# Automation Files Directory

This directory contains JSON files that define automation steps for different domains and paths.

## File Naming Convention

- **Domain-specific**: `{domain}.json` (e.g., `example.com.json`)
- **Path-specific**: `{domain}_{path}.json` (e.g., `example.com_contact.json`)

## File Structure Example

```json
[
  {
    "action": "click",
    "selector": "#submit-button",
    "description": "Click submit button"
  },
  {
    "action": "fill",
    "selector": "input[name='email']",
    "value": "test@example.com",
    "description": "Fill email field"
  }
]
```

## Where to Place Your Files

1. **Domain automation**: Place `{domain}.json` files here for general domain automation
2. **Path-specific automation**: Place `{domain}_{path}.json` files here for specific page automation

## Examples

- `google.com.json` - General Google automation
- `facebook.com_login.json` - Facebook login page automation
- `amazon.com_product.json` - Amazon product page automation

The content script will automatically load the appropriate file based on the current domain and path. 