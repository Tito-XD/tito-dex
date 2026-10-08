# TitoDex Journey Assistant Worker

Independent Worker source for the Journey blocker helper. The current host APK
keeps three HGSS hints available offline. The reviewed online corpus also
covers selected blockers in DPPt, BW/BW2, XY, ORAS, SM/USUM, SWSH, BDSP,
Legends: Arceus, and Scarlet/Violet.

The request path is deliberately fail-safe:

1. Exact game + local aliases + verified save location are scored first.
2. On a miss, the Worker may read the current versioned TitoDex Dex bundle
   through the read-only `DEX_CONTENT` R2 binding. Exact species encounter,
   held-item, versioned learnset, evolution, profile, item, ability, catalog
   and reverse move/ability intersection questions are
   validated and answered without a model. Open-ended questions receive only a
   bounded entity evidence object. Cultivation, strategy, route, and
   recommendation questions try a bounded Chinese 52Poké result pool first;
   if it cannot support the answer, they retrieve fixed sources plus bounded
   English and Chinese fallback pools over the remaining domains, then use bundle fields to
   cross-check entities, versions, and numbers before Qwen composition and a
   second verification pass. Strict mode requires two independent evidence
   groups whenever available; the explicit v0.8.16 trial may return one
   allowlisted evidence group at low confidence. Evolution conditions and
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
7. For Chinese questions, enabled retrieval providers first search within a boundary whose request
   and accepted-result boundary is only `wiki.52poke.com`. If that evidence is
   empty or fails Qwen support verification, broad advice opens independent
   English/Chinese searches over the remaining server-owned allowlist; narrow
   questions open one mixed fallback search. Snippets still pass through Qwen
   composition and verification, and final answers remain Simplified Chinese.
8. DeepSeek V4 Flash native search runs concurrently with that curated route.
   TitoDex requires linked search-result blocks, revalidates every URL against
   the same allowlist, and uses citation text for a Qwen support pass when the
   provider supplies it. In explicit trial mode a linked, allowlisted result
   without citation text can be returned at low confidence with a warning.
   Any provider, quota, shape, or scope failure preserves deterministic fallback.

Before semantic blocks leave the Worker, `enforceFinalFacts` restores executed
structured query results and keeps their evidence/entity IDs aligned. An
online verification pass does not grant the model ownership of those facts.
See [structured query coverage and limitations](../../docs/ASK_STRUCTURED_DATA.md).
The App no longer advertises the optional Journey pack downloader; compatible
pack loading and reviewed hint delivery remain implemented.

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
  adds it to AI Search; only a transient enabled-provider citation snippet may reach the
  verifier when that optional route is enabled.

Every live-source answer is visibly labelled `未经 TitoDex 人工审核`. A source
failure, invalid model result, quota exhaustion, or scope rejection returns the
original deterministic `no_match` response. Live answers never write to R2.

## Optional Exa primary / Tavily fallback search

Exa is the default retrieval provider. Tavily is disabled by default; it only
participates as a backup after an explicit `TAVILY_WEB_ENABLED=true` setting.
With Tavily disabled, Exa failure continues through the existing fixed-source,
DeepSeek and deterministic fallback paths.

Both services retrieve evidence; the existing composer and verifier decide
whether it supports an answer. Neither is called when a local audited hint or
exact Dex-bundle fact already answers the question.

- `WEB_SEARCH_PRIMARY=exa` selects Exa first. `tavily` explicitly reverses the
  order. A missing/disabled provider is skipped. Exa is enabled in the validated candidate after its Worker secret and live
  retrieval passed. Production traffic is still on the previous version until
  rollout is approved.
- Store `EXA_API_KEY` and `TAVILY_API_KEY` only as Worker secrets. Each also
  needs its corresponding `EXA_WEB_ENABLED` / `TAVILY_WEB_ENABLED` flag and
  `CURATED_WEB_ENABLED=true`. Health requires a valid key shape plus these
  flags; it does not probe the account balance.
- In each language/domain pool, the primary is tried first. Empty or rejected
  results, timeout, malformed data, account errors, rate limiting and quota
  exhaustion fall through to the other provider. Non-empty retrieved evidence
  still needs the existing support checks. If the 52Poké evidence cannot
  support an answer, research proceeds to the remaining domains; it does not
  rerun the same 52Poké pool in the backup solely because composition failed.
- Exa uses `/search`, `type=auto`, six results and bounded `highlights` only.
  It ignores generated summaries, answer output and page text. Tavily retains
  basic retrieval, or advanced retrieval for strategy questions, with no
  generated answer or raw page text. Each call has a five-second maximum,
  a 64 KiB response limit and no retry. Search across both stages shares a
  ten-second wall-clock deadline, including any rejected preferred-source pass.
- Chinese retrieval first isolates `wiki.52poke.com`. A missing or unsupported
  answer opens the remaining allowlisted domains: one mixed query for narrow
  questions, concurrent English/Chinese pools for broad advice. Returned URLs
  must use HTTPS and exactly match the server-owned domain list.
- Exa HTTP 402 and Tavily HTTP 432/433 indicate credit/budget exhaustion;
  HTTP 429 is rate limiting. These and other provider failures skip further
  calls to that provider during the same user question. Already-started language
  requests can still finish. The next question tries the configured primary
  again, allowing a replenished quota to recover without a shared counter.
- Logs contain provider/stage/status/count only, never keys, queries, snippets
  or upstream error bodies. Retrieved evidence is not stored, indexed or
  packaged. A URL returned by both engines counts once; independent evidence
  groups are based on websites, not search-engine names.

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
zero-traffic candidate; ordinary production requests remain on the previous
version. No payment settings were changed.

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
  candidate `337a442a-3a13-49c0-bdbb-80c54f7666fe` is at 0% traffic and
  health reports only Exa and DeepSeek as enabled search routes.
  Production `0ab85fe8-9d78-4c0b-a925-24377f5c6f1c` remains at 100%.

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

## Optional DeepSeek / custom provider setup

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
