# TitoDex Journey Assistant Worker

Independent Worker source for the Journey blocker helper. v0.8.13 publishes
the optional content APK and enables the reviewed BGE-M3 index. The current
audited corpus still contains only three HGSS hints.

The request path is deliberately fail-safe:

1. Exact game + local aliases + verified save location are scored first.
2. Only a local miss or tie may use the optional AI Search binding.
3. AI Search returns candidate `hintId` values; its chunk text is never used as
   an answer.
4. Workers AI is the public default and may classify an allowed candidate and
   reorder deterministic answer sections. It cannot add, remove, or rewrite
   facts. A unique local match makes zero model calls.
5. DeepSeek (or an authenticated custom provider) is an explicitly gated,
   non-public option. Search/provider/quota failures fall back through Workers
   AI and finally to the deterministic answer/no-match/clarification response.

## Local verification

```bash
npm ci
npm run types
npm run check
npm test
npm run dry-run
```

Do not deploy from ordinary feature work.

## Optional AI Search setup

The checked-in configuration binds `JOURNEY_SEARCH_NAMESPACE` to the AI Search
namespace `tito-dex` and enables retrieval after the six reviewed v1 documents
have completed indexing. A single-instance
`ai_search` binding cannot address non-default namespaces, so the Worker calls
`JOURNEY_SEARCH_NAMESPACE.get("titodex-journey-search")` only after retrieval
is enabled. Before enabling retrieval, confirm that instance has:

- embedding model: `@cf/baai/bge-m3`
- vector + keyword indexes enabled (hybrid retrieval)
- these five custom metadata fields:
  - `hint_id` (`text`)
  - `audited` (`boolean`)
  - `game` (`text`)
  - `generation` (`number`)
  - `location_id` (`text`)

Every indexed document must use a `hint_id` already present in the reviewed
TitoDex progression-hint bundle. The Worker additionally checks the metadata
against the request and local allowlist. It ignores all returned chunk text.

Build the audited documents and R2 custom-metadata upload plan from the
canonical dataset (do not hand-author a second index corpus):

```bash
python3 ../../tools/build_journey_search_documents.py /tmp/titodex-journey-search
```

The confirmed bucket layout is:

```text
titodex-journey-content
├── journey-search/v<datasetVersion>/<hintId>--<game>--<locationId>.md
└── extensions/journey-assistant/
    ├── extension-catalog.json
    └── objects/<immutable-digest-name>.apk
```

Upload the generated search files only after reviewing
`search-upload-plan.json`, preserving exactly the five custom metadata values.
Scope the AI Search R2 source to `journey-search/` so `extensions/` is never
indexed.

AI Search's embedding model is fixed when the instance is created. To change
from BGE-M3 later, create a new instance instead of silently changing vector
dimensions.

References:

- <https://developers.cloudflare.com/ai-search/api/search/workers-binding/>
- <https://developers.cloudflare.com/ai-search/configuration/retrieval/filtering/>
- <https://developers.cloudflare.com/ai-search/configuration/models/supported-models/>

## Optional DeepSeek / custom provider setup

DeepSeek is not used as AI Search's built-in generation model. The Worker first
resolves the fixed instance from `JOURNEY_SEARCH_NAMESPACE` and calls
`search()`, then calls a model through the Workers AI binding and AI Gateway
`titodex-journey-assistant`.

Recommended DeepSeek configuration:

1. Add the user's DeepSeek key to the `titodex-journey-assistant` AI Gateway as
   a BYOK provider key. Cloudflare stores it in Secrets Store; never add it to
   `wrangler.jsonc`, source, an APK, or a committed `.env` file.
2. Set both `AI_EXTERNAL_PROVIDER_ENABLED=true` and `AI_PROVIDER=deepseek` in
   private deployment configuration. The checked-in public defaults remain
   `false` and `workers-ai`.
3. Keep `AI_PROVIDER_ENDPOINT` as `chat/completions` and choose the desired
   `AI_PROVIDER_MODEL` (the example is `deepseek-chat`).
4. Run `npm run types` after changing Wrangler vars.

For a self-hosted OpenAI-compatible model, first create an authenticated custom
provider in AI Gateway. Then set `AI_PROVIDER` to `custom-<slug>` and use either
`chat/completions` or `v1/chat/completions`. The code does not accept arbitrary
origin URLs, so a model credential cannot be redirected to another host.

Provider calls use a five-second timeout, one attempt, no response cache, no AI
Gateway prompt logging, strict JSON parsing, and a 16 KiB response cap. AI
Search receives only the bounded question and derived context; neither API can
accept raw save bytes under the request schema. Worker logs contain only coarse
result metadata and never the question or exact location.

## Worker-only content access

`JOURNEY_CONTENT` is a Worker-side R2 binding to
`titodex-journey-content`. The App never receives an R2 URL or credential. The
Worker serves only these read-only paths:

- `/v1/extensions/journey_assistant/catalog`
- `/v1/extensions/journey_assistant/objects/<immutable-name>.apk`

The catalog must contain a same-origin relative `objects/*.apk` path. All other
bucket keys, including AI Search documents, remain unreachable through the
Worker. Empty or unavailable R2, Search, Gateway, or model resources fail
closed; Journey answers continue to use the installed deterministic pack.

References:

- <https://developers.cloudflare.com/ai-gateway/usage/providers/deepseek/>
- <https://developers.cloudflare.com/ai-gateway/configuration/bring-your-own-keys/>
- <https://developers.cloudflare.com/ai-gateway/configuration/custom-providers/>
- <https://developers.cloudflare.com/ai-gateway/usage/worker-binding-methods/>

Privacy, resource provisioning, deployment gates, and app endpoint wiring are
also documented in [`../../docs/JOURNEY_ASSISTANT.md`](../../docs/JOURNEY_ASSISTANT.md).
