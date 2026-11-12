# OpenRBAC

**Apps publish the permissions they understand. Identity providers read them.**

OpenRBAC is a tiny, open format for an application to describe its actions,
groups and suggested roles in one JSON file — the way OpenAPI describes
endpoints. An identity provider (IdP) fetches the file when the app is
connected over OIDC or SAML, shows admins real checkboxes instead of free-text
scopes, and puts exactly the granted actions in the token.

```json
{
  "openrbac": "0.1",
  "app": { "id": "signage-player", "name": "Signage Player" },
  "groups": {
    "device": {
      "title": "Devices",
      "actions": {
        "device.register": "Pair a new screen",
        "device.reset": "Factory-reset a screen",
        "device.volume": "Change volume"
      }
    },
    "content": {
      "title": "Content",
      "actions": {
        "content.read": "View content",
        "content.publish": "Publish to screens"
      }
    }
  },
  "roles": {
    "operator": { "title": "Device operator", "actions": ["device.*", "content.read"] },
    "viewer":   { "title": "Viewer", "actions": ["*.read"] }
  }
}
```

Serve it at `https://your-app.example/.well-known/openrbac.json`. That's it.

## Why

- **Apps** stop hard-coding role names into IdP configs by hand.
- **IdPs** get a machine-readable catalog: real names, descriptions, groups,
  safe defaults, change detection.
- **Admins** assign meaningful permissions per app instead of guessing scope strings.
- **Any naming style works:** `device.reset`, `write:content`, `Content.Publish` —
  action ids are opaque strings.

## Adopt in 5 minutes

1. Write `openrbac.json` (see [examples/](examples/)); validate it against
   [schema/openrbac-0.1.schema.json](schema/openrbac-0.1.schema.json).
2. Serve it at `/.well-known/openrbac.json` on your app's origin.
3. Read granted actions from the token's `perm` claim (OIDC) or the `perm`
   attribute (SAML), and check them in your code.

Full spec: [SPEC.md](SPEC.md). Status: **draft 0.1** — feedback welcome.

## License

Apache-2.0 (spec text, schema and examples), like OpenAPI.
