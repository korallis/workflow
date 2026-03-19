# Module Specification: {{MODULE_NAME}}

## 1. Purpose

**What is this module?**
{{DESCRIPTION}}

**Who uses it?**
{{USER_ROLES}}

**What problem does it solve?**
{{PROBLEM_STATEMENT}}

**Key goals:**
- {{GOAL_1}}
- {{GOAL_2}}
- {{GOAL_3}}

---

## 2. User Stories

| ID | As a... | I want to... | So that... |
|----|---------|-------------|-----------|
| US-1 | {{ROLE}} | {{ACTION}} | {{BENEFIT}} |
| US-2 | {{ROLE}} | {{ACTION}} | {{BENEFIT}} |
| US-3 | {{ROLE}} | {{ACTION}} | {{BENEFIT}} |
| US-4 | {{ROLE}} | {{ACTION}} | {{BENEFIT}} |
| US-5 | {{ROLE}} | {{ACTION}} | {{BENEFIT}} |

---

## 3. Data Model

### Core Entities

```typescript
/**
 * {{ENTITY_NAME}} — {{ENTITY_DESCRIPTION}}
 */
interface {{ENTITY_NAME}} {
  /** {{FIELD_DESCRIPTION}} */
  id: string;

  /** {{FIELD_DESCRIPTION}} */
  createdAt: Date;

  /** {{FIELD_DESCRIPTION}} */
  updatedAt: Date;

  // Add other fields below
  {{FIELD_NAME}}: {{FIELD_TYPE}}; // {{FIELD_COMMENT}}
  {{FIELD_NAME}}: {{FIELD_TYPE}}; // {{FIELD_COMMENT}}
  {{FIELD_NAME}}: {{FIELD_TYPE}}; // {{FIELD_COMMENT}}
}

/**
 * {{ENTITY_NAME}} — {{ENTITY_DESCRIPTION}}
 */
interface {{ENTITY_NAME}} {
  {{FIELD_NAME}}: {{FIELD_TYPE}}; // {{FIELD_COMMENT}}
  {{FIELD_NAME}}: {{FIELD_TYPE}}; // {{FIELD_COMMENT}}
}
```

### Data Relationships

{{DESCRIBE_RELATIONSHIPS_BETWEEN_ENTITIES}}

### Validation Rules

- {{RULE_1}}
- {{RULE_2}}
- {{RULE_3}}

---

## 4. API / Server Actions

### {{ENDPOINT_NAME}}

**Route:** `{{METHOD}} {{PATH}}`

**Purpose:** {{ENDPOINT_PURPOSE}}

**Authentication:** {{AUTH_REQUIREMENT}}

**Request:**
```json
{
  "{{FIELD}}": "{{EXAMPLE_VALUE}}",
  "{{FIELD}}": "{{EXAMPLE_VALUE}}"
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {
    "{{FIELD}}": "{{EXAMPLE_VALUE}}"
  }
}
```

**Response (400):**
```json
{
  "success": false,
  "error": "{{ERROR_CODE}}",
  "message": "{{ERROR_DESCRIPTION}}"
}
```

**Error Codes:**
- `VALIDATION_ERROR` — {{ERROR_DESCRIPTION}}
- `NOT_FOUND` — {{ERROR_DESCRIPTION}}
- `UNAUTHORIZED` — {{ERROR_DESCRIPTION}}

---

### {{ENDPOINT_NAME}}

**Route:** `{{METHOD}} {{PATH}}`

**Purpose:** {{ENDPOINT_PURPOSE}}

**Authentication:** {{AUTH_REQUIREMENT}}

**Request:**
```json
{
  "{{FIELD}}": "{{EXAMPLE_VALUE}}"
}
```

**Response (200):**
```json
{
  "success": true,
  "data": {}
}
```

---

## 5. UI Screens

### {{SCREEN_NAME}}

**Route:** `{{ROUTE}}`

**Purpose:** {{SCREEN_PURPOSE}}

**Key Components:**
- {{COMPONENT_1}} — {{DESCRIPTION}}
- {{COMPONENT_2}} — {{DESCRIPTION}}
- {{COMPONENT_3}} — {{DESCRIPTION}}

**User Flow:**
1. {{STEP_1}}
2. {{STEP_2}}
3. {{STEP_3}}

**Empty State:**
{{DESCRIBE_EMPTY_STATE}}

**Loading State:**
{{DESCRIBE_LOADING_STATE}}

**Error State:**
{{DESCRIBE_ERROR_STATE}}

---

### {{SCREEN_NAME}}

**Route:** `{{ROUTE}}`

**Purpose:** {{SCREEN_PURPOSE}}

**Key Components:**
- {{COMPONENT_1}} — {{DESCRIPTION}}

**User Flow:**
1. {{STEP}}

---

## 6. Business Logic & Rules

### Validation Rules

- {{RULE}}: {{DESCRIPTION}} {{CONSTRAINT}}
- {{RULE}}: {{DESCRIPTION}} {{CONSTRAINT}}
- {{RULE}}: {{DESCRIPTION}} {{CONSTRAINT}}

### Calculations

- {{CALCULATION}}: {{FORMULA_OR_LOGIC}}
- {{CALCULATION}}: {{FORMULA_OR_LOGIC}}

### State Transitions

{{DESCRIBE_STATE_CHANGES_IF_APPLICABLE}}

### Edge Cases & Constraints

- {{EDGE_CASE}}: {{HANDLING}}
- {{EDGE_CASE}}: {{HANDLING}}
- {{EDGE_CASE}}: {{HANDLING}}

### Permissions & Access Control

- {{PERMISSION}}: {{DESCRIPTION}}
- {{PERMISSION}}: {{DESCRIPTION}}

---

## 7. Integration Points

| Module | How we use it | Direction |
|--------|---------------|-----------|
| {{MODULE_NAME}} | {{USAGE_DESCRIPTION}} | {{DEPENDS_ON / USED_BY / BIDIRECTIONAL}} |
| {{MODULE_NAME}} | {{USAGE_DESCRIPTION}} | {{DEPENDS_ON / USED_BY / BIDIRECTIONAL}} |
| {{MODULE_NAME}} | {{USAGE_DESCRIPTION}} | {{DEPENDS_ON / USED_BY / BIDIRECTIONAL}} |

### Data Flow

{{DESCRIBE_HOW_DATA_FLOWS_BETWEEN_MODULES}}

---

## 8. Acceptance Criteria

- [ ] {{CRITERION_1}}
- [ ] {{CRITERION_2}}
- [ ] {{CRITERION_3}}
- [ ] {{CRITERION_4}}
- [ ] {{CRITERION_5}}
- [ ] All endpoints tested with valid and invalid inputs
- [ ] UI screens tested on desktop and mobile
- [ ] Error states handled gracefully
- [ ] Console shows no errors or warnings
- [ ] Spec and code are in sync

---

## 9. Out of Scope

- {{EXCLUSION_1}}
- {{EXCLUSION_2}}
- {{EXCLUSION_3}}

These may be addressed in future iterations or by other modules.

---

## 10. Open Questions

- [ ] {{QUESTION_1}}
- [ ] {{QUESTION_2}}
- [ ] {{QUESTION_3}}

These should be resolved before or during implementation.

---

## Revision History

| Date | Author | Change |
|------|--------|--------|
| {{DATE}} | {{AUTHOR}} | Initial spec |

