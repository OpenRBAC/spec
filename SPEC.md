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
6. **Push registration (optional, inspired by UMA 2.0 resource registration).**
   Apps that cannot host a file (desktop, mobile, on-prem) MAY push the manifest
   instead: `PUT` the manifest to the IdP's `openrbac_registration_endpoint`,
   authenticated as the OAuth client (client credentials or private_key_jwt).
   The IdP stores it exactly as if fetched. Request: `PUT` with the manifest as
   the body. Response `200`:
   `{ "changed": bool, "added": [ids], "removed": [ids], "role_changes": [ids] }`;
   `400` with `{ "error": "...", "details": [...] }` for an invalid manifest.
7. **Source precedence.** A client has one manifest source at a time: a fetch
   URL or push. A successful push switches the client to push (the IdP stops
   fetching) until an administrator sets a fetch URL again.

### 2.1 IdP metadata

An IdP that supports OpenRBAC SHOULD advertise it in its OpenID Provider /
OAuth Authorization Server metadata:

| Member | Meaning |
|---|---|
| `openrbac_versions_supported` | e.g. `["0.1"]` |
| `openrbac_registration_endpoint` | Push registration endpoint (§2 item 6), if offered |
| `openrbac_evaluation_endpoint` | AuthZEN evaluation endpoint (§5.4), if offered |

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
    "<role id>": { "title": "Human title", "description": "optional", "persona": "operator", "actions": ["<pattern>", "..."] }
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
| `app.resource` | no | RFC 9728 resource identifier (URL). When present, the IdP SHOULD bind the manifest to that audience and use it as the `aud` of tokens carrying `perm` |
| `groups` | yes | Ordered object of groups; at least one |
| `groups.*.actions` | yes | Object of action id → string (title) or action object |
| `roles` | no | Suggested roles (IdPs SHOULD offer them as built-ins); each MAY carry a `persona` (§3.3) |
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

### 3.3 Suggested roles and personas

Each role in `roles` is a recommendation the IdP offers as a ready-made role
for the app. A role MAY declare a `persona`: the kind of team it is meant for.
Personas come from a small shared vocabulary so an organization can map its
groups **once** and have every newly connected app propose matching roles:

| Persona | Typical team |
|---|---|
| `owner` | Account owners, break-glass |
| `admin` | Platform / cloud / server administrators |
| `operator` | Day-to-day operations (e.g. patching, deployments, devices) |
| `security` | Security engineering and incident response (may change security settings) |
| `auditor` | Security audit and compliance (read-only, including logs and evidence) |
| `support` | Helpdesk / customer support |
| `developer` | Engineers integrating with the app |
| `billing` | Finance and billing |
| `viewer` | Everyone else, read-only |

Apps MAY use other values prefixed with `x-` (e.g. `x-patching`); IdPs treat
unknown personas as unmapped. Several roles MAY share a persona. A role without
a persona is offered but never auto-proposed.

IdP behavior (informative): an organization maps groups to personas
(e.g. "Security team" → `auditor`, "Linux ops" → `operator`). When an app's
manifest is registered or changes, the IdP proposes assigning each role to the
groups mapped to its persona; an administrator accepts, adjusts or declines.
Proposals MUST NOT take effect without acceptance unless the organization
opted in to automatic assignment for that persona.

### 3.4 Patterns in roles

Role `actions` entries are exact action ids or patterns:

- `*` — every action
- `prefix*` — every action id starting with `prefix` (e.g. `device.*`, `write:*`)
- `*suffix` — every action id ending with `suffix` (e.g. `*.read`, `*:read`)
- `*infix*` — every action id containing `infix` (e.g. `*:content*`)
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
- Claim `roles`: array of role ids the user holds for this client (informational):
  manifest role ids for suggested roles, IdP-assigned ids for custom roles.
- Claim `openrbac`: the manifest version (or ETag) the grants were computed from.
- The access token issued for the app's audience MUST carry `perm` (an empty
  array when nothing is granted). The ID token and userinfo carry `perm`,
  `roles` and `openrbac` when the client requests scope `openrbac`; IdPs MAY
  include them by default.
- Large grant sets: the IdP MAY omit `perm` and set `perm_uri` to a userinfo-like
  endpoint returning `{ "perm": [...] }`.

### 5.2 SAML 2.0

- Attribute `urn:openrbac:perm` (multi-valued) — granted action ids.
- Attribute `urn:openrbac:roles` (multi-valued) — role ids.

### 5.3 Application enforcement

The application checks for the exact action id in `perm`. It MUST treat a
missing action as denied and MUST ignore unknown ids.

### 5.4 Evaluation API (optional, AuthZEN)

Instead of (or in addition to) carrying `perm` in tokens, an IdP MAY act as an
OpenID AuthZEN Policy Decision Point. The application asks at request time:

```json
POST /access/v1/evaluation
{ "subject":  { "type": "user", "id": "<sub>" },
  "action":   { "name": "content.publish" },
  "resource": { "type": "openrbac_app", "id": "<app.id>" } }
→ { "decision": true }
```

`action.name` is an OpenRBAC action id. This suits large grant sets,
per-resource decisions (e.g. one location or device), and revocation without
waiting for tokens to expire. Applications MAY combine both: `perm` for UI
hints, the evaluation API for sensitive (`dangerous`) actions.

## 6. Change management

When a re-fetched manifest differs:

- **New actions**: not granted to anyone, except through roles that now match
  them by pattern **if** the administrator opted in to auto-expansion for that
  role. Default: show "N new actions" for review.
- **Removed actions**: grants are kept but inactive (not issued); restored if the
  action returns.
- **Changed suggested roles**: IdP shows a diff; built-in role definitions update
  only after admin acceptance.
- **Custom roles** (created by administrators): store the expanded action list
  at save time. New actions never join a custom role automatically; the IdP
  SHOULD list them as "new since this role was saved".
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
- **IdP level 2**: custom roles from the catalog, change review (§6), SAML attributes,
  group-to-persona mapping with role proposals (§3.3).

## 9. Relationship to other work

OpenRBAC deliberately reuses existing building blocks rather than inventing
transport or policy semantics:

- **RFC 9728 (OAuth 2.0 Protected Resource Metadata)**: discovery model and
  resource identity. Its metadata document can point to the manifest
  (`openrbac_uri`), and `app.resource` binds a manifest to that resource.
  RFC 9728 `scopes_supported` lists what a *client* may request; OpenRBAC lists
  what a *user* may do inside the app.
- **UMA 2.0 (User-Managed Access)**: resource servers register resources and
  `resource_scopes` with the authorization server. OpenRBAC keeps that idea of
  app-declared actions, but as a static, cacheable document with optional push
  registration (§2 item 6), without UMA's permission tickets and RPT flow.
- **OpenID AuthZEN**: standard subject/action/resource evaluation API between an
  application (PEP) and a decision point (PDP). OpenRBAC supplies the action
  catalog AuthZEN leaves undefined; §5.4 uses AuthZEN as the runtime check.
- **OpenAPI**: an OpenAPI operation MAY reference required actions with
  `x-openrbac: ["content.publish"]`.
- **Cedar / Zanzibar / OPA**: policy engines decide; an OpenRBAC manifest can
  seed their action catalogs.
- **SCIM**: provisions users and groups; OpenRBAC defines what those groups may do.
