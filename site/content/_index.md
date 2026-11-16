---
title: "OpenRBAC"
---

<section class="section">
<div class="wrap">
<h2>The problem</h2>
<p class="intro">Every application has its own idea of what users can do. Identity providers only see a handful of free-text scopes or group names. So admins guess, apps hard-code role names, and "who can reset a device?" has no answer you can audit.</p>
<div class="grid">
<div class="card"><h3>Admins guess</h3><p>IdP consoles show groups and scopes, not what each app can actually do. Granting the right access means reading docs or asking the developer.</p></div>
<div class="card"><h3>Apps hard-code roles</h3><p>"admin", "editor", "viewer" mean different things in every app, and changing them means a release.</p></div>
<div class="card"><h3>Nobody can audit it</h3><p>There is no single place that lists which person can perform which action in which app.</p></div>
</div>
</div>
</section>

<section class="section">
<div class="wrap">
<h2>How it works</h2>
<p class="intro">One static JSON file, served by the app. No new protocol: discovery and delivery reuse OAuth, OIDC and SAML.</p>
<div class="grid">
<div class="card"><span class="n">1</span><h3>The app publishes</h3><p>Serve <code>/.well-known/openrbac.json</code> listing your actions, how they group, and the roles you suggest.</p></div>
<div class="card"><span class="n">2</span><h3>The IdP reads it</h3><p>When the app is connected, the IdP fetches the manifest and shows admins real checkboxes and ready-made roles.</p></div>
<div class="card"><span class="n">3</span><h3>Tokens carry actions</h3><p>The access token for the app carries a <code>perm</code> claim with exactly the granted action ids. The app checks for them.</p></div>
</div>
</div>
</section>

<section class="section">
<div class="wrap split">
<div>
<h2>A complete manifest</h2>
<p class="intro">Actions are opaque ids you already use. Groups organize them for humans. Roles are suggestions, written with simple patterns like <code>device.*</code>, <code>*.read</code> or <code>@content</code>, and can say which kind of team they are for.</p>
<p><a class="btn" href="/examples/">More examples</a> <a class="btn ghost" href="/schema/openrbac-0.1.schema.json">JSON Schema</a></p>
</div>
<div class="prose">

```json
{
  "openrbac": "0.1",
  "app": { "id": "signage-player", "name": "Signage Player" },
  "groups": {
    "device": {
      "title": "Devices",
      "actions": {
        "device.register": "Pair a new screen",
        "device.reset": { "title": "Factory-reset a screen", "dangerous": true },
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
    "operator": { "title": "Device operator", "persona": "operator",
                  "actions": ["device.*", "content.read"] },
    "viewer":   { "title": "Viewer", "persona": "viewer", "actions": ["*.read"] }
  }
}
```

</div>
</div>
</section>

<section class="section">
<div class="wrap">
<h2>Designed to be easy to adopt</h2>
<div class="grid">
<div class="card"><h3>Small</h3><p>One file, a few required fields. An app can adopt it in an afternoon; an IdP can support the basics without a policy engine.</p></div>
<div class="card"><h3>Static and cacheable</h3><p>A plain HTTPS document with ETags. Apps that cannot host a file can push the manifest to the IdP instead.</p></div>
<div class="card"><h3>Safe to change</h3><p>New actions are never granted silently. Changed suggested roles are shown as a diff for an admin to accept.</p></div>
<div class="card"><h3>Builds on standards</h3><p>Discovery follows RFC 9728 protected resource metadata. Runtime checks can use OpenID AuthZEN. The catalog idea comes from UMA 2.0.</p></div>
<div class="card"><h3>Personas</h3><p>Suggested roles name the team they are for (operator, security, auditor…). Map your groups once; new apps propose matching roles.</p></div>
<div class="card"><h3>Open</h3><p>Apache 2.0. The spec, schema and examples live on GitHub, and changes happen in the open.</p></div>
</div>
</div>
</section>

<section class="section">
<div class="wrap split">
<div class="card"><h3>For application developers</h3><p>Write the manifest, serve it, and check the <code>perm</code> claim. Ten minutes for a first version.</p><p style="margin-top:12px"><a class="btn primary" href="/quick-start/apps/">App quick start</a></p></div>
<div class="card"><h3>For identity provider developers</h3><p>Fetch and validate manifests, offer suggested roles, and issue <code>perm</code> for the app's audience.</p><p style="margin-top:12px"><a class="btn primary" href="/quick-start/idps/">IdP quick start</a></p></div>
</div>
</section>

<section class="section">
<div class="wrap">
<h2>Status</h2>
<p class="intro">Version 0.1 is a draft and is being implemented end to end: <a href="https://gimbal-hq.com">Gimbal</a> publishes a manifest as an application, and Gimbal ID implements the identity provider side. Feedback and implementation reports are welcome on <a href="https://github.com/OpenRBAC/spec/issues">GitHub</a>.</p>
</div>
</section>
