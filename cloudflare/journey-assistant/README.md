# TitoDex Journey Assistant Worker

Independent Worker source for the Journey blocker helper. The current host APK
keeps three HGSS hints available offline. The reviewed online corpus also
covers selected blockers in DPPt, BW/BW2, XY, ORAS, SM/USUM, SWSH, BDSP,
Legends: Arceus, and Scarlet/Violet.

The request path is deliberately fail-safe:

1. Exact game + local aliases + verified save location are scored first.
2. On a miss, the Worker may read the current versioned TitoDex Dex bundle
   through the read-only `DEX_CONTENT` R2 binding. Exact species encounter,
   held-item, versioned learnset, profile, item, and ability questions are
   validated and answered without a model. Open-ended questions receive only a
   bounded entity evidence object. Cultivation, strategy, route, and
   recommendation questions retrieve fixed sources and Tavily in parallel,
   then use bundle fields to cross-check entities, versions, and numbers before
   Qwen composition and a second verification pass. Evolution conditions and
   standalone move values retain the existing exact-version source path.
3. Only a remaining local miss or tie may use the optional AI Search binding.
4. AI Search returns candidate `hintId` values; its chunk text is never used as
   an answer.
5. Workers AI is the public default and may classify an allowed candidate and
   reorder deterministic answer sections. It cannot add, remove, or rewrite
   facts. A unique local match makes zero model calls.
6. If the audited corpus still has no match and `CURATED_WEB_ENABLED=true`, a
   strict Pokémon-game scope classifier may query only PokéAPI, StrategyWiki,
   and Wikidata. Qwen composes a labelled, cited, unreviewed answer solely from
   the bounded results.
7. Only when those fixed sources cannot support an answer, an explicitly
   enabled Tavily adapter may make one `basic` search over a server-owned
   Pokémon domain allowlist. Its snippets still pass through the same Qwen
   support check and second verifier. No client/model URL or domain is accepted.
8. If the public Tavily + Qwen path still cannot support an answer, an
   explicitly enabled DeepSeek V4 Flash custom provider may try one native
   server-side web search. TitoDex accepts it only when the response contains
   linked search-result blocks on the same domain allowlist and a second Qwen
   check supports the answer from bounded citation text. Any provider, quota,
   shape, or verification failure preserves the deterministic no-match result.

## Key-free curated source fallback

This fallback needs no new binding, account resource, or API key. The App still
calls only `/v1/ask`; all source requests originate in the Worker. The existing
per-device 20 requests/minute limiter remains the public abuse/cost guard, with
no daily five-request cap.

- PokéAPI REST v2 is queried only for a validated resource kind and slug. The
  Worker first resolves Chinese species/move/item/ability/location names from
  the App's existing compact label catalogs, then uses the model value only as
  a fallback. Species evolution links are followed only when they
  remain on the exact `pokeapi.co/api/v2/evolution-chain/<id>` allowlist.
- StrategyWiki uses one search request and one latest-revision request. Its
  revision URL and CC-BY-SA attribution are returned with the answer. This is
  best-effort because StrategyWiki may return 403 to Cloudflare egress; such a
  denial is skipped without weakening the other sources or local fallback.
- Wikidata uses its entity search API and contributes only the returned CC0
  structured label/description.
- Model output cannot provide a hostname, URL, `site:` operator, or Boolean
  search operator. Responses and source text are byte/length bounded, fetched
  with timeouts, and treated as untrusted prompt-injection input.
- 52Poké remains in the manual fact-check/source-lock workflow for future
  reviewed R2 facts. The Worker never directly fetches its page prose and never
  adds it to AI Search; only a transient Tavily citation snippet may reach the
  verifier when that optional route is enabled.

Every live-source answer is visibly labelled `未经 TitoDex 人工审核`. A source
failure, invalid model result, quota exhaustion, or scope rejection returns the
original deterministic `no_match` response. Live answers never write to R2.

## Optional Tavily allowlist search

Tavily is a final retrieval adapter, not an answer provider. It is never called
until local audited hints, exact Dex-bundle encounter facts, AI Search
candidates, and the fixed PokéAPI/StrategyWiki/Wikidata pass have all failed to
answer.

- Install `TAVILY_API_KEY` as a Worker secret; never place it in
  `wrangler.jsonc`, source, an APK, documentation examples, or logs.
- After the secret exists, set `TAVILY_WEB_ENABLED=true` in the private
  deployment configuration. Both conditions are required.
- Each question makes at most one Tavily request with `search_depth=basic`, no
  Tavily-generated answer, no raw page content, four results maximum, a short
  timeout, a bounded response, and no retry.
- The fixed allowlist is Pokémon.com, Bulbapedia, Serebii, StrategyWiki,
  PokéAPI, Pokémon Database, and the 52Poké wiki. Returned URLs are revalidated
  against the same exact hostnames before snippets can reach Qwen.
- Tavily snippets are transient and are never stored, indexed, or packaged.
  52Poké remains excluded from direct page fetching; without separate
  permission its content also remains excluded from R2/AI Search and APK data.

The secret can be installed interactively from the Worker directory:

```bash
npx wrangler secret put TAVILY_API_KEY
```

This command prompts for the value without writing it to the repository. Do
not run it during ordinary source verification, and do not enable the flag
until the intended deployment has the secret.

## Client-visible status and execution trace

`GET /health` returns only sanitized capability flags: Worker reachability,
Workers AI Qwen configuration, Dex-bundle/AI Search/curated-source switches, the three
fixed source provider names, generic `webSearch` plus
`webSearchProviders` containing `tavily` only when its flag and secret are
present, and `deepseek-native` only after its server flag is enabled following
a successful custom-provider smoke test. Explicit `braveSearch: false` remains
for older clients. Health never returns
an Account ID, binding identifier, production origin, model credential, or
secret.

Every `/v1/ask` response also carries a privacy-safe trace:

- `answerMode`: local audited, online audited, AI Search audited, curated
  sources + Qwen, DeepSeek native search, or no match;
- `modelUsed` and `aiSearchUsed`: what this request actually used, not merely
  what the deployment has configured;
- `sourceKinds`: `pokeapi`, `strategywiki`, `wikidata`, `tavily`, or
  `deepseek-native` only when that route actually supports the returned answer.

No prompt, generated query, source excerpt, location ID, or user text is added
to the trace or Worker log.

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
namespace `tito-dex` and enables retrieval only after reviewed documents have
completed indexing. A single-instance
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

Structured entity questions do not need a second copy of the Dex bundle inside
this index. They are answered from `DEX_CONTENT` before web retrieval. A future
fuzzy-entity index may return only a candidate species/item/move/game identity;
the Worker must still rebuild the answer from the current bounded R2 detail
object instead of trusting indexed chunk prose.

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

DeepSeek is not AI Search's generation model and is never an unlimited public
fallback. Qwen remains the public classifier/composer/verifier. The optional
native-search route is tried only after the local/audited/fixed-source and
Tavily + Qwen paths cannot support an answer.

Native V4 Flash setup:

1. In AI Gateway, create a custom provider with slug `deepseek-anthropic` and
   base URL `https://api.deepseek.com`. Calls use the resulting provider name
   `custom-deepseek-anthropic`, fixed endpoint `anthropic/v1/messages`, and
   fixed model `deepseek-v4-flash`.
2. Add the DeepSeek key to that provider through the existing
   `titodex-journey-assistant` Gateway's BYOK Provider Keys screen. Cloudflare
   stores it in Secrets Store; never add it to `wrangler.jsonc`, source, an APK,
   documentation, a committed `.env`, or logs. This deployment selects the
   `TitoDex` alias through `DEEPSEEK_NATIVE_KEY_ALIAS`; keep that variable in
   sync if the Gateway alias changes.
3. Run a private smoke test. It must contain a linked `server_tool_use` and
   allowlisted `web_search_tool_result`, followed by bounded citations; a plain
   model-memory answer does not count as web search.
4. Deploy with `DEEPSEEK_NATIVE_SEARCH_ENABLED=true` only after BYOK is
   present, then require the live smoke below to prove real search before an
   App release. The checked-in configuration remains disabled; every
   provider/search failure still falls through to the deterministic result.

The alias is mandatory. TitoDex does not fall back to a `default` BYOK alias if
`DEEPSEEK_NATIVE_KEY_ALIAS` is missing or renamed. The provider-native Gateway
request also needs encrypted Worker secrets for the account identity and a
minimal Gateway Run token; their values must never enter source, an APK,
documentation examples, or logs.

The native request uses Anthropic Messages with `web_search_20250305`, one use,
the same server-owned Pokémon domain allowlist, ten-second timeout, one attempt,
no cache or prompt logging, and a 128 KiB response cap. TitoDex rejects model
text containing its own URL/domain, exposes only revalidated source URLs, and
asks Workers AI to support-check the draft against bounded citation snippets.
Failure falls back without changing the deterministic result.

The current live smoke showed that this provider response did not reliably
honour its requested domain/use limits and did not return bounded citation text
for the support verifier. TitoDex therefore keeps the DeepSeek native-search
flag off. Tavily + Qwen remains the enabled allowlisted web-search route; the
DeepSeek adapter and encrypted configuration are retained for a later provider
compatibility retest.

The older provider-native JSON generation path remains separately gated by
`AI_EXTERNAL_PROVIDER_ENABLED=true` and `AI_PROVIDER=deepseek`; its example
model is now `deepseek-v4-flash`. It does not provide native web search and is
not required for the native-search route above.

For a self-hosted OpenAI-compatible model, first create an authenticated custom
provider in AI Gateway. Then set `AI_PROVIDER` to `custom-<slug>` and use either
`chat/completions` or `v1/chat/completions`. The code does not accept arbitrary
origin URLs, so a model credential cannot be redirected to another host.

Provider calls use a ten-second timeout, one attempt, no response cache, no AI
Gateway prompt logging, strict JSON parsing, and a 16 KiB response cap. AI
Search receives only the bounded question and derived context; neither API can
accept raw save bytes under the request schema. Worker logs contain only coarse
result metadata and never the question or exact location.

## Worker-only content access

`JOURNEY_CONTENT` is a Worker-side R2 binding to
`titodex-journey-content`. `DEX_CONTENT` binds the existing versioned Dex
bucket for structured entity lookup. Both are used read-only and the App never
receives an R2 URL or credential. The Worker serves only these public paths:

- `/v1/extensions/journey_assistant/catalog`
- `/v1/extensions/journey_assistant/objects/<immutable-name>.apk`

The catalog must contain a same-origin relative `objects/*.apk` path. All other
bucket keys, including AI Search documents and Dex detail objects, remain
unreachable as raw files through the Worker. Dex lookup accepts only the root
manifest and `v<number>/details/<numeric-species-id>.json`, enforces byte caps,
and selects only `obtainLocationsByVersion[request.game]`. Empty or unavailable
R2, Search, Gateway, or model resources fail closed; Journey answers continue
to use the installed deterministic pack. The structured reader permits only the
validated root manifest, numeric species details, and fixed `items.json`,
`moves.json`, or `dex_catalog.json` objects under that manifest prefix. Flavor
prose and held-item rows are not supplied to embeddings or Qwen. Held-item
answers are deterministic and retain the bundle's PokeAPI / 52Poké attribution.

References:

- <https://developers.cloudflare.com/ai-gateway/usage/providers/deepseek/>
- <https://developers.cloudflare.com/ai-gateway/configuration/bring-your-own-keys/>
- <https://developers.cloudflare.com/ai-gateway/configuration/custom-providers/>
- <https://developers.cloudflare.com/ai-gateway/usage/worker-binding-methods/>

Privacy, resource provisioning, deployment gates, and app endpoint wiring are
also documented in [`../../docs/JOURNEY_ASSISTANT.md`](../../docs/JOURNEY_ASSISTANT.md).

Tavily request fields and response bounds follow its official Search endpoint:
<https://docs.tavily.com/documentation/api-reference/endpoint/search>.
