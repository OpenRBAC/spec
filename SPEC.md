# OpenRBAC 0.1 (draft)

The key words MUST, SHOULD and MAY are used as in RFC 2119.

## 1. Purpose

An **application** (relying party, resource server) publishes a **manifest**
listing the actions it can authorize, how they group, and roles it suggests.
An **identity provider** (IdP) or access-management system fetches the manifest,
lets administrators grant actions to users (directly or through roles), and
delivers the granted actions to the application in tokens or assertions.

OpenRBAC does not decide *how* an application enforces actions, and it does not
replace OAuth scopes or policy engines. It is a catalog plus a delivery
convention.

## 2. Discovery

1. The manifest MUST be served over HTTPS as `application/json`.
2. Default location: `https://<app origin>/.well-known/openrbac.json`.
3. An application MAY publish elsewhere and point to it from:
   - OAuth Protected Resource Metadata (RFC 9728): member `openrbac_uri`;
   - the IdP's client registration (admin enters the URL, or dynamic
     registration includes `openrbac_uri`).
4. The IdP MUST only fetch a manifest whose origin matches one of the
   application's registered redirect URI origins, or one an administrator
   explicitly confirmed.
5. The IdP SHOULD re-fetch periodically and honor `ETag` / `Cache-Control`.
   It MUST NOT silently grant actions that appear in a new manifest version
   (see §6).

## 3. Manifest

```json
{
  "openrbac": "0.1",
  "app": { "id": "gimbal-dashboard", "name": "Gimbal", "version": "2026.11.12" },
  "groups": {
    "<group id>": {
      "title": "Human title",
      "description": "optional",
      "actions": {
        "<action id>": "Short description",
        "<action id>": { "title": "Short description", "dangerous": true, "deprecated": false }
      }
    }
  },
  "roles": {
    "<role id>": { "title": "Human title", "description": "optional", "actions": ["<pattern>", "..."] }
  },
  "default_role": "<role id>"
}
```

| Member | Required | Meaning |
|---|---|---|
| `openrbac` | yes | Spec version, `"0.1"` |
| `app.id` | yes | Stable identifier, `[a-z0-9][a-z0-9._-]{0,63}` |
| `app.name` | yes | Display name |
| `app.version` | no | Manifest/app version, informational |
| `groups` | yes | Ordered object of groups; at least one |
| `groups.*.actions` | yes | Object of action id → string (title) or action object |
| `roles` | no | Suggested roles (IdPs SHOULD offer them as built-ins) |
| `default_role` | no | Role for members with no explicit assignment; omit = no access |

### 3.1 Action ids

- Opaque strings, case-sensitive, 1–128 chars from `A-Za-z0-9._:-/` .
  Any convention works: `device.reset`, `write:content`, `Devices/Reset`.
- MUST be unique across the whole manifest (not just within a group).
- An action id MUST NOT be reused for a different meaning; deprecate and add a new id.

### 3.2 Action object

| Member | Meaning |
|---|---|
| `title` | Short description (required in object form) |
| `description` | Longer help text |
| `dangerous` | `true` = destructive or security-sensitive; IdPs SHOULD require explicit confirmation to grant |
| `deprecated` | `true` = still honored, hide from new grants |

### 3.3 Patterns in roles

Role `actions` entries are exact action ids or patterns:

- `*` — every action
- `prefix*` — every action id starting with `prefix` (e.g. `device.*`, `write:*`)
- `*suffix` — every action id ending with `suffix` (e.g. `*.read`, `*:read`)
- `@group` — every action in a group

Patterns are expanded by the IdP against the current manifest. Tokens MUST
carry expanded action ids, never patterns (§5).

## 4. Grants (IdP side, informative)

An IdP SHOULD let administrators, per application and per organization/tenant:

- assign the manifest's suggested roles;
- create custom roles from the catalog (checkboxes by group);
- grant actions directly to a user or group (optional).

Grants are evaluated per application: actions of one app never appear in
another app's tokens.

## 5. Delivery

### 5.1 OIDC / OAuth

- Claim `perm`: array of granted action ids for **this** client (audience).
- Claim `roles`: array of role ids the user holds for this client (informational).
- Claim `openrbac`: the manifest version (or ETag) the grants were computed from.
- Included in the ID token and/or access token and userinfo when the client
  requests scope `openrbac` (IdPs MAY include them by default).
- Large grant sets: the IdP MAY omit `perm` and set `perm_uri` to a userinfo-like
  endpoint returning `{ "perm": [...] }`.

### 5.2 SAML 2.0

- Attribute `urn:openrbac:perm` (multi-valued) — granted action ids.
- Attribute `urn:openrbac:roles` (multi-valued) — role ids.

### 5.3 Application enforcement

The application checks for the exact action id in `perm`. It MUST treat a
missing action as denied and MUST ignore unknown ids.

## 6. Change management

When a re-fetched manifest differs:

- **New actions**: not granted to anyone, except through roles that now match
  them by pattern **if** the administrator opted in to auto-expansion for that
  role. Default: show "N new actions" for review.
- **Removed actions**: grants are kept but inactive (not issued); restored if the
  action returns.
- **Changed suggested roles**: IdP shows a diff; built-in role definitions update
  only after admin acceptance.
- **Unreachable manifest**: keep the last good copy; never drop grants because a
  fetch failed.

## 7. Security

- HTTPS only; no redirects to other origins.
- Manifests are public metadata. They MUST NOT contain secrets or tenant data.
- An IdP MUST cap manifest size (recommended 256 KiB) and action count
  (recommended 2,000).
- Optional integrity: the application MAY publish a detached JWS
  (`openrbac.json.jws`) signed with a key from its JWKS; IdPs MAY require it.

## 8. Conformance

- **App level 1**: serves a valid manifest; enforces `perm`.
- **IdP level 1**: fetches and validates manifests; grants suggested roles;
  issues `perm` for the audience.
- **IdP level 2**: custom roles from the catalog, change review (§6), SAML attributes.

## 9. Relationship to other work

- **OAuth scopes / RFC 9728**: scopes describe what a *client* may request;
  OpenRBAC describes what a *user* may do inside the app. RFC 9728 metadata can
  point to the manifest (`openrbac_uri`).
- **OpenAPI**: an OpenAPI operation MAY reference required actions with
  `x-openrbac: ["content.publish"]`.
- **Cedar / Zanzibar / OPA**: policy engines decide; an OpenRBAC manifest can
  seed their action catalogs.
- **SCIM**: provisions users and groups; OpenRBAC defines what those groups may do.
