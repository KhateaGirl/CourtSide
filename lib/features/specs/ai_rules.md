# AI Coding Rules

These rules guide the AI assistant when modifying the codebase.

## General Rules

Do not rewrite the entire project.

Always inspect existing code before making changes.

Prefer refactoring over replacing files.

Avoid breaking existing functionality.

---

## Architecture Rules

Business logic must live in services or repositories.

UI widgets should remain thin and only handle presentation.

Database queries must be handled in repository layers.

Avoid putting business logic inside UI files.

---

## Code Style

Prefer clear, readable functions.

Avoid extremely large classes.

Extract reusable logic into helper services.

Avoid duplicate logic across files.

---

## Database Safety

Never delete existing tables or columns unless explicitly requested.

Avoid destructive migrations.

Ensure queries respect role permissions.

---

## Testing Mindset

Changes should maintain compatibility with existing functionality.

All booking validation must be enforced at backend level.

Client validation alone is not sufficient.

---

## Cursor Behavior

When uncertain:

Ask for clarification before making large architectural changes.
