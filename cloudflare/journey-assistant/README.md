# TitoDex Journey Assistant Worker

Independent Worker source for the Journey blocker helper. The current host APK
keeps three HGSS hints available offline. The reviewed online corpus also
covers selected blockers in DPPt, BW/BW2, XY, ORAS, SM/USUM, SWSH, BDSP,
Legends: Arceus, and Scarlet/Violet.

The current source candidate simplifies online research. It has not yet replaced
the recorded production version below.

1. Exact-game local hints and executed Dex-bundle queries answer first. A unique
   local match makes zero model calls. Structured facts retain ownership of
   their entity, version, value and condition fields.
2. Optional AI Search narrows reviewed hint IDs; retrieved chunks cannot supply
   answer facts. The routing model also prepares bilingual search terms.
3. On a remaining miss, the normal Exa path reuses complete Chinese/English
   terms from routing or the name dictionary. Only missing or mixed-language
   terms need one query-preparation call.
4. Exa performs one Chinese and one English `/search` request concurrently,
   with at most six results each. It uses `auto` and retrieved highlights,
   with no domain restriction or generated Exa answer. The normal Exa path
   does not make fixed PokéAPI, StrategyWiki or Wikidata requests.
5. URL deduplication, website diversity and topic/work checks produce at most
   six web excerpts. These join bounded local evidence for composition and
   support verification. Contradictions, wrong versions and invented facts
   retain their existing guards. Citations keep original source URLs.
6. Qwen is the default text model for terms, composition and verification.
   A request-local text fallback can use the existing DeepSeek Gateway/BYOK
   identity after model failure, without search tools or continuations.
   `modelProviders` records successful text-model participation.
7. Tavily and DeepSeek native web search are disabled by default. They require
   explicit opt-in. The key-free fixed-source path remains available when Exa
   is not configured; an active Exa failure preserves deterministic fallback.

Before semantic blocks leave the Worker, `enforceFinalFacts` restores executed
structured query results and keeps their evidence/entity IDs aligned. An
online verification pass does not grant the model ownership of those facts.
See [structured query coverage and limitations](../../docs/ASK_STRUCTURED_DATA.md).
The App no longer advertises the optional Journey pack downloader; compatible
pack loading and reviewed hint delivery remain implemented.

### Conversation and version scope

The App stores at most 20 local conversations, with explicit deletion at capacity.
Creating a conversation is part of the conversation switch sheet.
It sends only the active conversation's newest six Q&A pairs. A page-level
version picker is no longer part of the flow; the global edition supplies the
default scope. A server-owned resolver runs after strict request validation and
before hints, bundle facts, search or model work. It resolves explicit titles
and user follow-ups, keeps same-version save context, and removes save context
when changing to another version or researching several versions.

Unsupported and combined default editions may send the optional plain
`context.referenceGameTitle`. Only canonical game aliases become research
scope; caller text cannot create an exact-game key or supply server scope
metadata. Explicit question titles take precedence. Deploy this compatible
Worker before the new App: the preceding Worker rejects this extra context key.
The canonical wire schema is `data/journey/assistant_api.schema.json`.

### Conversation candidate verification (2026-10-08)

Worker: 496 tests passed / 10 existing skipped; structured configuration:
27 passed / 10 existing skipped; strict schema: 7 passed. Types and dry-run
passed. App: 864 tests passed / 2 existing skipped, full analysis clean,
Android arm64 debug build passed. Real widget screenshots cover the page,
conversation drawer and small-screen/large-text status layouts. Production
rollout, signed release and physical-device acceptance remain pending.

### General basics candidate (2026-10-09)

Unscoped general mechanics questions first answer the useful supported basics,
without requiring a game choice. Empty introductions and version prompts cannot
count as an answer. Capture/obtain questions retain their location intent and may
show up to two sourced examples explicitly labelled with the game. Optional
`outlineMode: basic_web_outline` identifies this presentation while preserving
the existing answer-mode contract. Basic verification uses fixed claim keys and
numeric source references, mapped by the server to original IDs; each retained
claim still needs an exact source quote. Original bundle fields continue to guard
web claims, and contradictions cannot be revived by fallback.

Web rejection can fall back to readable local evolution, type or weakness
projections with upstream links and explicit cached-evidence labels. These links
do not claim a live API read. A conservative capture projection accepts explicit
edition/location rows, retains stated conditions and original source URLs, and
keeps unknown boundaries or qualifiers out of the answer. It does not infer
location fields from flattened cards or add missing capture steps.

App: 864 passed / 2 existing skipped; full analysis clean and Android arm64 debug
build passed. Real-response widget captures passed 14 tests. Worker: 566 passed /
10 existing skipped; structured configuration: 27 passed / 10 existing skipped;
typecheck and dry-run passed. Real 0%-traffic candidate requests answered general
Eevee/Riolu evolution and Pikachu weakness questions. Two consecutive normal
Riolu capture requests returned version-labelled answers and public citations.
A normal request on the final candidate also returned a deterministic projection
of explicit edition/location rows with its original public source link.
These responses establish API behavior, not a blanket independent fact audit.
A simulated failure of the entire composition path still returns no_match when
location cards have no safely parseable edition/location boundaries. Temporary
format and failure hooks were removed. Ordinary production traffic was restored
to the recorded baseline; no App release or production rollout occurred.

### Candidate verification (2026-10-08)

- Worker: 410 tests passed / 10 existing skipped; independent structured
  configuration: 27 passed / 10 existing skipped.
- Typecheck and Worker dry-run passed.
- App: 87 relevant tests passed, targeted analysis clean and Android arm64
  debug build passed. Sources use theme-coloured Custom Tabs, with external
  browser fallback; history preserves model participation and original URLs.
- This earlier local snapshot had no real-provider acceptance evidence. See the
  latest general-basics candidate checks above. Signed release and physical-device
  browser acceptance remain pending.

## Key-free curated source fallback

This fallback needs no new binding, account resource, or API key. The App still
calls only `/v1/ask`; all source requests originate in the Worker. The existing
edge-derived identity limiter and global question budget remain the public abuse/cost guards, with
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
  adds it to AI Search; only a transient enabled-provider citation snippet may reach the
  verifier when that optional route is enabled.

Every live-source answer is visibly labelled `未经 TitoDex 人工审核`. A source
failure, invalid model result, quota exhaustion, or scope rejection returns the
original deterministic `no_match` response. Live answers never write to R2.

## Bilingual Exa search and optional fallback

The normal source configuration uses `EXA_WEB_ENABLED=true`,
`WEB_SEARCH_PRIMARY=exa`, `TAVILY_WEB_ENABLED=false`,
`DEEPSEEK_NATIVE_SEARCH_ENABLED=false` and
`DEEPSEEK_TEXT_FALLBACK_ENABLED=true`.

- `EXA_API_KEY` and optional `TAVILY_API_KEY` stay in Worker secrets. Provider
  flags and `CURATED_WEB_ENABLED=true` also gate retrieval. Health checks key
  shape and flags; it does not inspect account credit.
- Chinese and English Exa requests run in parallel, once per language. Each
  has a five-second limit, six results and a bounded 64 KiB response. The
  shared retrieval deadline is ten seconds. A failed language does not discard
  evidence returned by the other language.
- Exa searches the public web without `includeDomains`. Accepted URLs must
  use public HTTPS, have no credentials or unusual port, and pass topic/work
  checks. The Worker uses provider excerpts and does not fetch arbitrary URLs.
- When explicitly enabled, Tavily can fail over per pool. Account, shape,
  network, rate-limit and quota failures skip subsequent calls to that provider
  during the same question. An already-started language request can finish.
  The next question starts with fresh provider availability.
- DeepSeek text fallback reuses `CF_ACCOUNT_ID`, `CF_AIG_TOKEN` and the existing
  explicit BYOK alias. It sends no web tools, has a six-second timeout and
  bounded output. It is reported separately from web search in health/trace.
- Logs contain provider, phase, status and count, never keys, query text,
  excerpts or upstream error bodies. Evidence is not stored or indexed.
  A duplicate URL counts once; provider names do not establish independence.

Local development can use a git-ignored `.dev.vars` file in this directory with
`EXA_API_KEY=<your key>`; keep the value out of chat, command arguments and logs.
For production, install the key interactively, then enable Exa only after a
successful live check:

```bash
npx wrangler secret put EXA_API_KEY
```

The failover reacts to API status; it does not distinguish free credits from
paid balance. Free-only usage must be enforced by the account's spending cap
and disabled automatic recharge. The user created the account and installed the secret. Validation uses a
candidate before the approved production rollout recorded below. No payment settings were changed.

Official API references: [Exa Search](https://exa.ai/docs/reference/search),
[Exa error codes](https://exa.ai/docs/admin/error-codes),
[Tavily Search](https://docs.tavily.com/documentation/api-reference/endpoint/search).

## Validation on 2026-10-08

The candidate is based on current `origin/main` (`4d204de`), preserving the
production Worker source (`49a04e6`) and its security/grounding checks. The older
local checkout was not used for deployment.

- Worker: 372 tests passed, 10 existing artifact tests skipped; the separate
  structured-data checks passed 27 tests (10 existing skips).
- Flutter: 27 assistant tests passed, targeted analysis clean, zh/en Exa labels
  preserved alongside the current split Ask components.
- Real Exa adapter calls using the encrypted Worker secret: 52Poké returned six
  accepted snippets in 2.534 seconds; fallback returned three accepted snippets
  from Game8/Pokémon Database in 2.541 seconds, both HTTP 200.
- Live validation uses `redirect=manual` and rejects 3xx responses. This avoids
  the immediate runtime failure observed with `redirect=error` while preventing
  credential forwarding. Private probe code/credentials were removed locally;
  probe versions are outside the active deployment.
- End-to-end Lucario cultivation query returned a medium-confidence answer
  with `sourceKinds=[exa]` and two citations in 12.9 seconds. A broader starter
  recommendation returned `no_match` in 8.3 seconds when support was insufficient.
- Initial candidate `17f7ddc9-5ea5-4fe3-9957-6d9257ef5d3c` verified Exa/Tavily
  failover. The current candidate disables Tavily by default at the user's request;
  version `337a442a-3a13-49c0-bdbb-80c54f7666fe` now serves 100% of production
  traffic from source `7b30345`. Health reports Exa and DeepSeek; Tavily is absent.
  The former production `0ab85fe8-9d78-4c0b-a925-24377f5c6f1c` remains the
  rollback version. A normal production request returned HTTP 200, an Exa
  citation and a low-confidence answer in 11.6 seconds. The private probe path
  returns 404.

Successful retrieval does not establish that every generated answer is correct;
version, source and claim checks remain required.

## Client-visible status and execution trace

`GET /health` returns only sanitized capability flags: Worker reachability,
Workers AI Qwen configuration, Dex-bundle/AI Search/curated-source switches, the three
fixed source provider names, generic `webSearch` plus
`webSearchProviders` containing `exa` and/or `tavily` in configured order
only when their flags and secrets are present, and `deepseek-native` only after its server flag is enabled following
a successful custom-provider smoke test. Explicit `braveSearch: false` remains
for older clients. Health never returns
an Account ID, binding identifier, production origin, model credential, or
secret.

The App presents the encyclopedia/guide allowlist as one connection capability
instead of counting every source as a separate service. The complete possible
source list and rights notes live in Settings Credits; every answer still shows
only the sources actually used.

Every `/v1/ask` response also carries a privacy-safe trace:

- `answerMode`: local audited, online audited, AI Search audited, curated
  sources + Qwen, DeepSeek native search, Qwen × DeepSeek corroborated, or no
  match;
- `modelUsed` and `aiSearchUsed`: what this request actually used, not merely
  what the deployment has configured;
- `sourceKinds`: `pokeapi`, `strategywiki`, `wikidata`, `exa`, `tavily`, or
  `deepseek-native` only when that route actually supports the returned answer.

Clients may opt into progressive rendering with
`Accept: application/x-ndjson`. The Worker emits a retrieval progress event,
then waits for the same deterministic/model/source verification used by the
JSON route. Only after that check completes does it emit a bounded semantic
plan and verified answer blocks, followed by the authoritative `result` event.
It never exposes raw, unverified provider tokens. Clients that omit the header
continue to receive the single JSON response.

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

## Optional legacy DeepSeek native search / custom provider setup

Native search is disabled in the current source candidate. The text fallback
uses the same Gateway identity with no tools. The following instructions cover
explicitly enabling the legacy native-search path.

DeepSeek is not AI Search's generation model and is never an unlimited public
fallback. Qwen remains the public classifier/composer/verifier. After the
local/audited/Dex-bundle route misses, the optional native-search request runs
concurrently with fixed-source/Tavily + Qwen research so one slow provider does
not consume the App's whole timeout; the verified Qwen route wins when both
succeed.

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
   present, then require a live smoke to prove real search before an App
   release. The v0.8.16 trial configuration enables it alongside Tavily; every
   provider/search failure still falls through to the deterministic result.

The alias is mandatory. TitoDex does not fall back to a `default` BYOK alias if
`DEEPSEEK_NATIVE_KEY_ALIAS` is missing or renamed. The provider-native Gateway
request also needs encrypted Worker secrets for the account identity and a
minimal Gateway Run token; their values must never enter source, an APK,
documentation examples, or logs.

The native request uses Anthropic Messages with `web_search_20250305`, one
search use, the same server-owned Pokémon domain allowlist, up to four bounded
pause-turn continuations, an 18-second per-request timeout and a 26-second
whole-chain deadline, no cache or prompt logging, and a 128 KiB response cap. TitoDex rejects model
text containing its own URL/domain, exposes only revalidated source URLs, and
asks Workers AI to support-check the draft against bounded citation snippets.
Failure falls back without changing the deterministic result.

The provider has executed the requested search in a live smoke, but its current
response shape does not always include bounded `cited_text` for the Qwen
support verifier. TitoDex therefore revalidates every returned source URL
against its server-owned allowlist. When citation text exists, Qwen verifies
the draft; when it does not, the explicit
`EXPERIMENTAL_BROAD_ANSWERS=true` trial may return the sourced result at low
confidence with an in-App warning. Disabling that flag restores the strict
evidence gate without changing deterministic fallback.

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


### 问答滥用控制

`/v1/ask` 按 Cloudflare 覆写的 `CF-Connecting-IP` 限流（20 次/60 秒）；
设备键和 `X-Forwarded-For` 不参与额度身份。缺失边缘地址共享保守桶。
该信任边界要求请求经过 Cloudflare 公网边缘；不要通过不可信 Worker
子请求转发任意 `CF-Connecting-IP`，也不要开放绕过边缘的入口。

`QUESTION_BUDGET` 使用单个 SQLite Durable Object 持久化、原子预留整个问答
流程的额度：全服务 60 次/分钟、1000 次/UTC 日，失败不退款。额度在任何
问答 R2、检索、搜索及模型调用前扣减，绑定缺失或控制失败返回 503，额度
耗尽返回 429。发布时必须包含 `question-budget-v1` 的 Durable Object 迁移。
这些是保守的初始请求阈值；每次请求仍受现有调用数量、Token 与超时限制。
这不是精确费用计量或独立提供商熔断；部署前应按实际容量调整阈值，并结合
提供商费用上限。Cloudflare 原生 IP 限流是边缘近似控制，全服务预算由
Durable Object 跨边缘协调。
