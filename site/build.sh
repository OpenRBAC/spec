#!/usr/bin/env sh
# Generates the spec, examples and schema pages from the repository root, so the
# site always publishes the same commit's SPEC.md, schema and examples.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
mkdir -p "$here/static/schema" "$here/static/examples" "$here/content"
cp "$root"/schema/*.json "$here/static/schema/"
cp "$root"/examples/*.json "$here/static/examples/"
{
  printf -- '---\ntitle: "OpenRBAC 0.1 specification"\ndescription: "Draft. The normative definition of the manifest format, discovery, delivery and change management."\ntoc: true\n---\n\n'
  printf '<div class="note">Draft. Source: <a href="https://github.com/OpenRBAC/spec/blob/main/SPEC.md">SPEC.md on GitHub</a>. Machine-readable schema: <a href="/schema/openrbac-0.1.schema.json">openrbac-0.1.schema.json</a>.</div>\n\n'
  sed '1{/^# /d}' "$root/SPEC.md"
} > "$here/content/spec.md"
{
  printf -- '---\ntitle: "Examples"\ndescription: "Complete manifests you can copy. Each one validates against the 0.1 schema."\ntoc: true\n---\n\n'
  for f in "$root"/examples/*.json; do
    n=$(basename "$f")
    printf '## %s\n\n[Download](/examples/%s)\n\n```json\n' "$n" "$n"
    cat "$f"
    printf '\n```\n\n'
  done
} > "$here/content/examples.md"
