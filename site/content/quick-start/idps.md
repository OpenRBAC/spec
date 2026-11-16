---
title: "Quick start for identity providers"
description: "Fetch and validate manifests, turn them into roles admins can grant, and deliver the granted actions to each app."
toc: true
---

This page walks through **IdP level 1** conformance: fetch and validate manifests, offer the suggested roles, and issue `perm` for the app's audience. Level 2 features (custom roles from the catalog, change review, SAML, personas) are noted at the end. The [spec](/spec/) is normative; this is the practical path.

## 1. Advertise support

Add these members to your OpenID Provider / OAuth Authorization Server metadata:

```json
{
  "openrbac_versions_supported": ["0.1"],
  "openrbac_registration_endpoint": "https://idp.example/openrbac/register",
  "openrbac_evaluation_endpoint": "https://idp.example/access/v1/evaluation"
}
```

The last two are optional: only list endpoints you implement.

## 2. Find and fetch the manifest

For each connected client (application):

1. Use the URL an administrator entered, the `openrbac_uri` from the app's RFC 9728 protected resource metadata or dynamic registration, or default to `https://<app origin>/.well-known/openrbac.json`.
2. **Only fetch from an origin that matches one of the client's registered redirect URI origins**, or one an administrator explicitly confirmed. This stops a client from pointing you at someone else's manifest.
3. HTTPS only, no redirects to other origins, a timeout of a few seconds.
4. Cache with `ETag` / `Cache-Control` and re-fetch periodically.
5. If a fetch fails, **keep the last good copy**. Never drop grants because an app was briefly unreachable.

## 3. Validate

- Validate against the [JSON Schema](/schema/openrbac-0.1.schema.json).
- Enforce size limits: we recommend at most **256 KiB** and **2,000 actions**.
- Check that action ids are unique across the whole manifest, not just within a group.
- Treat the content as untrusted display text: escape titles and descriptions everywhere you render them.

## 4. Turn it into something admins can grant

- Store the manifest per client, versioned (keep the ETag or a hash).
- Show each **suggested role** as a built-in role for that app, with its title, description and expanded actions.
- Expand role patterns against the current manifest:

| Pattern | Expands to |
|---|---|
| `*` | every action |
| `prefix*` | actions starting with `prefix` |
| `*suffix` | actions ending with `suffix` |
| `*infix*` | actions containing `infix` |
| `@group` | every action in the group |

- Ask for explicit confirmation before granting any action marked `dangerous`.
- Hide `deprecated` actions from new grants but keep honoring existing ones.
- Grants are per application: actions of one app never appear in another app's tokens.

## 5. Deliver the granted actions

In the **access token** issued for the app's audience, include:

| Claim | Contents |
|---|---|
| `perm` | Array of granted action ids for this audience, fully expanded. Empty array when nothing is granted. Required. |
| `roles` | Role ids the user holds for this app (informational). |
| `openrbac` | Manifest version or ETag the grants were computed from. |

Include the same claims in the ID token and userinfo when the client requests the `openrbac` scope. For SAML, use the multi-valued attributes `urn:openrbac:perm` and `urn:openrbac:roles`.

For very large grant sets you may omit `perm` and set `perm_uri` to an endpoint that returns `{ "perm": [...] }`.

## 6. Handle manifest changes

When a re-fetched manifest differs:

- **New actions** are not granted to anyone, unless an administrator opted a role into auto-expansion. Show "N new actions" for review.
- **Removed actions** keep their grants but stop issuing them; restore them if the action returns.
- **Changed suggested roles** update only after an administrator accepts the diff.
- **Custom roles** created by administrators store their expanded action list; new actions never join them automatically.

## Going further (level 2)

- **Custom roles**: let admins build roles from the catalog with checkboxes per group.
- **Personas**: let an organization map its groups to personas once (`Linux ops` → `operator`, `Security team` → `auditor`). When a new app connects, propose its persona roles to those groups, effective only after acceptance.
- **Push registration**: accept `PUT` of a manifest at your registration endpoint, authenticated as the client; respond with what changed.
- **AuthZEN evaluation**: answer `POST /access/v1/evaluation` with `action.name` set to an OpenRBAC action id, for per-resource or real-time checks.
