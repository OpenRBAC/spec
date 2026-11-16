---
title: "Quick start for applications"
description: "Publish a manifest, connect your app to an IdP that supports OpenRBAC, and enforce the actions in the token."
toc: true
---

## 1. List your actions

Start from the checks your code already makes. Every place you ask "may this user do X?" is an action. Give each one a stable id. Any convention works (`device.reset`, `write:content`, `Devices/Reset`), but pick one and keep it: an id must never be reused for a different meaning.

Group the actions the way an administrator would think about them, and mark anything destructive or security-sensitive as `dangerous` so IdPs ask for confirmation before granting it.

```json
{
  "openrbac": "0.1",
  "app": { "id": "acme-billing", "name": "Acme Billing" },
  "groups": {
    "invoices": {
      "title": "Invoices",
      "actions": {
        "invoices.read": "View invoices",
        "invoices.create": "Create and edit draft invoices",
        "invoices.send": "Send invoices to customers",
        "invoices.void": { "title": "Void a sent invoice", "dangerous": true }
      }
    },
    "settings": {
      "title": "Settings",
      "actions": {
        "settings.read": "View billing settings",
        "settings.payment_methods": { "title": "Change payout bank accounts", "dangerous": true }
      }
    }
  }
}
```

## 2. Suggest roles

Roles are recommendations. IdPs offer them as ready-made roles, and administrators can still build their own from the catalog. Use patterns so roles keep working as you add actions:

| Pattern | Matches |
|---|---|
| `*` | every action |
| `invoices.*` | every action starting with `invoices.` |
| `*.read` | every action ending with `.read` |
| `@settings` | every action in the `settings` group |

Add a `persona` to say which kind of team a role is for. IdPs use it to propose the role to the right groups automatically (always with admin approval).

```json
"roles": {
  "clerk":   { "title": "Billing clerk", "persona": "operator", "actions": ["invoices.read", "invoices.create", "invoices.send"] },
  "auditor": { "title": "Auditor", "persona": "auditor", "actions": ["*.read"] },
  "admin":   { "title": "Billing admin", "persona": "admin", "actions": ["*"] }
},
"default_role": "auditor"
```

Personas: `owner`, `admin`, `operator`, `security`, `auditor`, `support`, `developer`, `billing`, `viewer`, or your own prefixed with `x-`.

## 3. Validate and serve it

Validate the file against the [JSON Schema](/schema/openrbac-0.1.schema.json), for example with `ajv`:

```bash
curl -sO https://openrbac.com/schema/openrbac-0.1.schema.json
npx ajv-cli validate --spec=draft2020 -c ajv-formats \
  -s openrbac-0.1.schema.json -d openrbac.json
```

Serve it over HTTPS as `application/json` at:

```text
https://your-app.example/.well-known/openrbac.json
```

Send an `ETag` so IdPs can re-fetch cheaply. The manifest is public metadata: never put secrets, customer data or tenant names in it.

Can't host a file (desktop, mobile or on-premises apps)? Push the manifest to the IdP's `openrbac_registration_endpoint` instead, authenticated as your OAuth client. See [§2 of the spec](/spec/#2-discovery).

## 4. Enforce `perm`

When a user signs in, the access token for your app carries a `perm` claim with the granted action ids, already expanded from roles and patterns:

```json
{
  "sub": "248289761001",
  "aud": "https://billing.acme.example",
  "perm": ["invoices.read", "invoices.create", "invoices.send", "settings.read"],
  "roles": ["clerk"],
  "openrbac": "W/\"5f1c\""
}
```

Check for the exact action id. Treat anything missing as denied, and ignore ids you do not recognize:

```go
func allowed(claims Claims, action string) bool {
    return slices.Contains(claims.Perm, action)
}

if !allowed(claims, "invoices.void") {
    http.Error(w, "forbidden", http.StatusForbidden)
    return
}
```

Never interpret patterns or role names in your app. The IdP expands them; your app only sees concrete action ids.

## 5. Evolve safely

- **Adding actions** is safe: IdPs never grant new actions silently. Admins see "N new actions" and decide.
- **Removing actions** keeps existing grants inactive, so they come back if you restore the action.
- **Renaming** is not a thing: deprecate the old id (`"deprecated": true`) and add a new one.
- **Changing suggested roles** shows admins a diff to accept.

## Checklist

- [ ] Every authorization check in the app maps to one action id.
- [ ] Destructive and security-sensitive actions are marked `dangerous`.
- [ ] The manifest validates against the schema and is served at `/.well-known/openrbac.json` with an `ETag`.
- [ ] The app denies anything not in `perm` and never expands patterns itself.
