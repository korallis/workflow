# Implementation Guide: {{MODULE_NAME}}

This document contains patterns, conventions, and guidelines specific to implementing the {{MODULE_NAME}} module. Use this alongside the SPEC.md to understand not just *what* to build, but *how* to build it consistently with the rest of the system.

---

## Patterns to Follow

### API Endpoint Pattern

All endpoints follow this pattern:

```typescript
export async function {{ACTION_NAME}}(request: {{RequestType}}): Promise<{{ResponseType}}> {
  // 1. Validate input
  if (!request.{{field}}) {
    throw new Error('VALIDATION_ERROR: {{field}} is required');
  }

  // 2. Check permissions
  const user = await auth.getCurrentUser();
  if (!user) {
    throw new Error('UNAUTHORIZED');
  }

  // 3. Fetch/process data
  const data = await db.{{collection}}.findById(request.id);
  if (!data) {
    throw new Error('NOT_FOUND');
  }

  // 4. Apply business logic
  const result = applyBusinessLogic(data);

  // 5. Return structured response
  return { success: true, data: result };
}
```

### React Component Pattern

All UI components follow this structure:

```typescript
import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { {{DependencyComponent}} } from '@/modules/{{module}}/components/{{Component}}';

export function {{ComponentName}}(props: {{PropsType}}) {
  const [state, setState] = useState<{{StateType}}>({
    loading: false,
    error: null,
    data: null,
  });

  useEffect(() => {
    loadData();
  }, []);

  async function loadData() {
    setState((s) => ({ ...s, loading: true }));
    try {
      const result = await fetch{{DataName}}();
      setState((s) => ({ ...s, data: result, error: null }));
    } catch (error) {
      setState((s) => ({
        ...s,
        error: error instanceof Error ? error.message : 'Unknown error',
      }));
    } finally {
      setState((s) => ({ ...s, loading: true }));
    }
  }

  if (state.loading) return <div>Loading...</div>;
  if (state.error) return <div className="text-red-600">Error: {state.error}</div>;
  if (!state.data) return <div>No data</div>;

  return (
    <div>
      {/* Component content */}
    </div>
  );
}
```

### Form Validation Pattern

Use this pattern for all forms:

```typescript
interface FormErrors {
  [key: string]: string | undefined;
}

function validateForm(formData: {{FormType}}): FormErrors {
  const errors: FormErrors = {};

  if (!formData.{{field}}) {
    errors.{{field}} = '{{field}} is required';
  } else if (formData.{{field}}.length < 3) {
    errors.{{field}} = '{{field}} must be at least 3 characters';
  }

  if (!formData.{{field}}) {
    errors.{{field}} = '{{field}} is required';
  }

  return errors;
}
```

### Data Fetching Pattern

```typescript
async function fetch{{DataName}}(id: string) {
  const response = await fetch(`/api/{{endpoint}}/${id}`);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`);
  }
  return response.json();
}
```

---

## Conventions in This Module

### File Structure

```
src/modules/{{MODULE_NAME}}/
├── actions/           # Server-side actions and API handlers
│   ├── {{action}}.ts
│   └── index.ts
├── components/        # React components
│   ├── {{ComponentName}}.tsx
│   └── index.ts
├── hooks/             # Custom React hooks
│   ├── use{{Hook}}.ts
│   └── index.ts
├── lib/               # Utilities and helpers
│   ├── {{helper}}.ts
│   └── validation.ts
├── types/             # TypeScript interfaces
│   ├── index.ts
│   └── {{types}}.ts
├── (routes)/          # Next.js route groups
│   ├── page.tsx
│   └── [id]/
│       └── page.tsx
├── schema.ts          # Zod or validation schema
└── index.ts           # Public exports
```

### State Management

Use {{STATE_LIBRARY}} for state management. Store state at the component level unless shared across multiple modules. For global state, use a dedicated store file in `src/stores/`.

Example:
```typescript
// src/stores/{{moduleName}}.ts
import { create } from '{{state-library}}';

interface {{ModuleState}} {
  data: {{Type}> | null;
  loading: boolean;
  error: string | null;
  load: () => Promise<void>;
}

export const use{{Module}}Store = create<{{ModuleState}}>((set) => ({
  data: null,
  loading: false,
  error: null,
  load: async () => {
    // Load logic
  },
}));
```

### Data Fetching

Use {{FETCH_LIBRARY}} for all data fetching. In server components, fetch directly. In client components, use the custom hooks in the `hooks/` directory.

**Server Component (app/page.tsx):**
```typescript
export default async function Page() {
  const data = await fetch('...').then(r => r.json());
  return <ClientComponent data={data} />;
}
```

**Client Component Hook (hooks/useFetch{{Name}}.ts):**
```typescript
export function use{{Name}}() {
  const [state, setState] = useState({ data: null, loading: false, error: null });

  useEffect(() => {
    // Fetch logic
  }, []);

  return state;
}
```

### Error Handling

All errors must follow this format:

```typescript
interface ApiError {
  code: string;        // e.g., "VALIDATION_ERROR", "NOT_FOUND"
  message: string;     // Human-readable message
  details?: object;    // Additional context if needed
}
```

Always catch errors in try-catch blocks and log them for debugging:

```typescript
try {
  await someAction();
} catch (error) {
  console.error('[{{MODULE_NAME}}] Error in {{action}}:', error);
  // Transform and re-throw with ApiError structure
  throw { code: 'INTERNAL_ERROR', message: 'Something went wrong' };
}
```

---

## Module Boundaries

### This Module Owns

- {{RESPONSIBILITY_1}}
- {{RESPONSIBILITY_2}}
- {{RESPONSIBILITY_3}}

### This Module Reads From

- {{MODULE}}: {{WHAT_WE_READ}}
- {{MODULE}}: {{WHAT_WE_READ}}

### This Module MUST NOT

- {{FORBIDDEN_ACTION_1}} (because {{REASON}})
- {{FORBIDDEN_ACTION_2}} (because {{REASON}})
- {{FORBIDDEN_ACTION_3}} (because {{REASON}})

---

## Known Gotchas

### {{GOTCHA_1}}

**Problem:** {{DESCRIPTION}}

**Solution:** {{SOLUTION}}

**Example:**
```typescript
// ❌ Don't do this
const result = await action();

// ✅ Do this instead
const result = await action();
console.log('Action result:', result);
```

### {{GOTCHA_2}}

**Problem:** {{DESCRIPTION}}

**Solution:** {{SOLUTION}}

---

## Test Patterns

### Unit Test Pattern

Use {{TEST_FRAMEWORK}} for all tests. Each function should have at least one happy path and one error case.

```typescript
import { describe, it, expect } from '@jest/globals';
import { {{function}} } from './{{file}}';

describe('{{FunctionName}}', () => {
  it('should {{behavior}} when {{condition}}', () => {
    // Arrange
    const input = { {{field}}: '{{value}}' };

    // Act
    const result = {{function}}(input);

    // Assert
    expect(result).toEqual({ success: true });
  });

  it('should {{behavior}} when {{condition}}', () => {
    // Arrange
    const input = { {{field}}: null };

    // Act & Assert
    expect(() => {{function}}(input)).toThrow('VALIDATION_ERROR');
  });
});
```

### Integration Test Pattern (API)

Test endpoints with both valid and invalid inputs:

```typescript
describe('POST /api/{{endpoint}}', () => {
  it('should {{behavior}} when {{condition}}', async () => {
    const response = await fetch('/api/{{endpoint}}', {
      method: 'POST',
      body: JSON.stringify({ {{field}}: '{{value}}' }),
    });

    expect(response.status).toBe(200);
    expect(response.json()).toEqual({ success: true, data: {} });
  });

  it('should return 400 when input is invalid', async () => {
    const response = await fetch('/api/{{endpoint}}', {
      method: 'POST',
      body: JSON.stringify({ {{field}}: null }),
    });

    expect(response.status).toBe(400);
    expect(response.json()).toHaveProperty('error');
  });
});
```

### UI Component Test Pattern

Test rendering, interactions, and state changes:

```typescript
import { render, screen, fireEvent } from '@testing-library/react';
import { {{Component}} } from './{{Component}}';

describe('{{Component}}', () => {
  it('should render the component with initial state', () => {
    render(<{{Component}} />);
    expect(screen.getByText('{{EXPECTED_TEXT}}')).toBeInTheDocument();
  });

  it('should {{behavior}} when {{action}} is clicked', async () => {
    render(<{{Component}} />);
    const button = screen.getByRole('button', { name: /{{LABEL}}/i });
    fireEvent.click(button);
    expect(screen.getByText('{{EXPECTED_RESULT}}')).toBeInTheDocument();
  });
});
```

---

## Performance Considerations

- {{CONSIDERATION_1}}: {{DESCRIPTION}}
- {{CONSIDERATION_2}}: {{DESCRIPTION}}

---

## Security Considerations

- {{SECURITY_RULE_1}}: {{DESCRIPTION}}
- {{SECURITY_RULE_2}}: {{DESCRIPTION}}

---

## Debugging Tips

1. {{TIP_1}}
2. {{TIP_2}}
3. {{TIP_3}}

---

## References

- **SPEC.md** — What to build
- **LEARNINGS.md** — Patterns that work across the project
- **CLAUDE.md** — Root-level architecture and conventions
- **Related Modules:** {{MODULE_1}}, {{MODULE_2}}

