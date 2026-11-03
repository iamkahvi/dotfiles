---
name: textarea-decode
description: Decodes textarea.quick.shopify.io URLs by extracting and decompressing the content from the URL hash fragment. Use when a user shares a textarea.quick.shopify.io link.
---

# Textarea Decode

Decodes paste content from `textarea.quick.shopify.io` URLs. The content is stored as raw-deflate-compressed, URL-safe base64 in the URL hash fragment, so no authentication is needed.

## Usage

```bash
./decode.sh "<textarea_url_or_hash>"
```

Accepts either a full URL or just the hash fragment.

## Examples

```bash
# Full URL
./decode.sh "https://textarea.quick.shopify.io/#XdBNTwIx..."

# Just the hash
./decode.sh "XdBNTwIx..."
```
