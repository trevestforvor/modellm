# Feature Research

**Domain:** On-device iOS LLM runner with Hugging Face integration
**Researched:** 2026-04-08
**Confidence:** HIGH (multiple verified sources: PocketPal AI, LLMFarm, LM Studio, Enclave AI, direct App Store analysis)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Browse/search Hugging Face models | Every comparable app does this; HF is the de facto registry | MEDIUM | HF Hub API is public; filter by task=text-generation and file format |
| Download model with progress indicator | Long downloads (1-8GB) require visible progress or users assume it's broken | LOW | Background download session; show MB/s, ETA, and cancellation |
| Chat interface | Primary way users validate a model works; bare minimum is single-turn | MEDIUM | Streaming output (token-by-token) is expected, not optional |
| Model library (list, delete, switch) | Storage is scarce on iPhone; users need control over what's installed | LOW | File size, quant level, and last-used date should be visible |
| Offline operation after download | The entire point; apps that silently require network are penalized in reviews | LOW | All inference must work in airplane mode |
| Streaming token output | Waiting for full response before display feels broken compared to cloud apps | MEDIUM | llama.cpp Swift bindings support streaming via callbacks |
| Basic inference parameters | Temperature, system prompt at minimum; power users expect these | LOW | Keep advanced params (top-p, repeat penalty) behind an "advanced" section |
| Storage usage display | Users need to know how much space models are using before and after download | LOW | Use FileManager to report sizes; show available device storage too |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Device-aware compatibility tiers (hard + soft) | Core value prop. No other iOS app does pre-download compatibility screening. PocketPal/LLMFarm let you download anything — you find out it fails at runtime | HIGH | Requires device spec detection (chip, RAM), GGUF metadata parsing (param count, quant), and a compatibility ruleset. This is the moat. |
| Hard limit: block incompatible models | Prevents "why won't this load" frustration that dominates 1-star reviews | MEDIUM | Filter models > 90% of available RAM; block unsupported quant types for chip gen |
| Soft warning: "Will run slowly" tier | Lets power users make informed tradeoffs; trust-building | MEDIUM | Token/s estimates based on chip + model size benchmarks; show expected speed band |
| Real-time tokens/sec display | Surfaces the cost of model choice; helps users compare | LOW | llama.cpp reports this natively; PocketPal AI already does this |
| Chip-specific model recommendations | "Best models for your iPhone 15 Pro" surfaces curated subset | MEDIUM | Requires a compatibility ruleset + HF tag/metadata querying |
| Storage-aware download warnings | "This model will use 87% of your free storage" before confirming download | LOW | High value, low cost; no other app does this well |
| Quantization explanation in plain language | Q4_K_M, Q8_0 etc. are opaque to non-technical users; translate to "balanced", "high quality", "fast/small" | LOW | Static mapping; reduces support burden and builds trust |
| Chat history persistence | Users expect to return to prior conversations; most iOS LLM apps don't persist well | MEDIUM | CoreData or SQLite; scoped per model |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| RAG / document upload | Seen in LM Studio and Off Grid; users want to chat with PDFs | Massive scope expansion on top of an unvalidated core; RAG needs chunking, embedding models (separate pipeline), and vector search — this is a v2+ project on its own | Perfect the base chat loop first; RAG is a natural v2 upsell |
| Model fine-tuning | LLMFarm supports it; power users ask for it | Fine-tuning on-device at scale is impractical; even LLMFarm's LoRA FineTune is limited; creates runaway complexity and crashes | Out of scope for v1; document why |
| OpenAI-compatible local API server | LM Studio's killer desktop feature; developers want to point apps at localhost | iOS sandboxing makes running a socket server for other apps non-trivial; Apple kills background processes aggressively | Not applicable to mobile; skip entirely |
| Multi-model simultaneous inference | Users want to compare models side-by-side | Two loaded models = 2x RAM pressure; iOS will kill the app; the UX complexity is high | Let users switch models; keep one loaded at a time |
| Cloud inference fallback | Users suggest it for slow devices | Completely contradicts the privacy and offline value proposition; adds a server, auth, and cost | Lean into the "fully offline" story as a feature, not a limitation |
| Push notification when download completes | Seems convenient | iOS background download sessions can complete this natively without custom notification logic; and users don't expect LLM apps to send push notifications | Use URLSession background download with in-app badge update |
| Social / sharing features | Share your chat, share a model | Leaks private conversations; users are explicitly choosing local-first for privacy | Keep everything local; maybe export to clipboard only |

## Feature Dependencies

```
Device spec detection (chip, RAM, storage)
    └──required by──> Compatibility tier calculation
                          └──required by──> Hard limit filtering (browse view)
                          └──required by──> Soft warning display (model detail)
                          └──required by──> Storage-aware download warning

HF Hub API integration (browse + search)
    └──required by──> Model detail view (metadata: params, quant, size)
                          └──required by──> Compatibility tier calculation
                          └──required by──> Quantization plain-language labels

Model download (URLSession background)
    └──required by──> Model library (list/delete/switch)
                          └──required by──> Model loading (inference engine)
                                                └──required by──> Chat UI

Chat UI
    └──enhanced by──> Streaming token output
    └──enhanced by──> Tokens/sec display
    └──enhanced by──> Chat history persistence
    └──enhanced by──> Inference parameters (temp, system prompt)
```

### Dependency Notes

- **Compatibility tier requires device spec detection:** You cannot compute a compatibility rating without knowing chip generation and available RAM. Device detection must be Phase 1.
- **Hard filtering requires model metadata from HF API:** GGUF file size, quantization type, and param count come from HF metadata. Browsing and filtering are coupled.
- **Inference requires model library:** A model must be downloaded and tracked before it can be loaded. Download + library management is a prerequisite to any chat.
- **Streaming enhances but doesn't block chat:** A non-streaming chat UI can ship; streaming is a fast follow that dramatically improves the feel.

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept.

- [ ] Device spec detection (chip family, RAM, available storage) — foundation for the entire value proposition
- [ ] HF Hub browse + search (GGUF/LLM models only) — primary discovery surface
- [ ] Hard compatibility filtering (block models that cannot run) — the core differentiator; prevents bad downloads
- [ ] Soft compatibility tiers with plain-language labels — "Fast", "Slow", "Won't run"; builds trust
- [ ] Model detail view with size, quant plain-language label, compatibility verdict — pre-download decision context
- [ ] Storage-aware download warning — "Uses 4.2 GB, you have 6.1 GB free"
- [ ] Background download with progress — UX requirement for 2-8 GB files
- [ ] Model library with delete — storage management is critical on mobile
- [ ] Model loading + streaming chat UI — validate the full pipeline end-to-end
- [ ] Tokens/sec display in chat — shows users their device capability

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Chat history persistence — when users return to the app and want prior context
- [ ] Inference parameter controls (temperature, system prompt) — power users will ask immediately
- [ ] Model search filters (size range, quant type, param count) — once catalog feels large
- [ ] Chip-specific recommendations ("Best for A17 Pro") — if user acquisition data shows value

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] RAG / document upload — massive scope; only after core chat loop is proven
- [ ] Image/multimodal model support — PROJECT.md explicitly defers this
- [ ] Speech-to-text — PROJECT.md explicitly defers this
- [ ] iPad layout — iPhone first per PROJECT.md
- [ ] LoRA adapter management — niche power-user feature; defer

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Device spec detection | HIGH | LOW | P1 |
| HF Hub browse + search | HIGH | MEDIUM | P1 |
| Hard compatibility filtering | HIGH | MEDIUM | P1 |
| Soft compatibility tiers | HIGH | MEDIUM | P1 |
| Background download + progress | HIGH | MEDIUM | P1 |
| Model library (list/delete/switch) | HIGH | LOW | P1 |
| Streaming chat UI | HIGH | MEDIUM | P1 |
| Storage-aware download warning | HIGH | LOW | P1 |
| Quantization plain-language labels | MEDIUM | LOW | P1 |
| Tokens/sec display | MEDIUM | LOW | P1 |
| Chat history persistence | MEDIUM | MEDIUM | P2 |
| Inference parameter controls | MEDIUM | LOW | P2 |
| Model search filters | MEDIUM | MEDIUM | P2 |
| Chip-specific recommendations | MEDIUM | HIGH | P2 |
| RAG / document upload | HIGH (perceived) | HIGH | P3 |
| LoRA adapter management | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | LM Studio (desktop) | PocketPal AI (iOS) | LLMFarm (iOS) | Our Approach |
|---------|---------------------|---------------------|----------------|--------------|
| HF Hub browsing | Yes, polished | Yes, basic | No (manual import) | Yes, filtered by compatibility |
| Pre-download compatibility check | No | No | No | Yes — core differentiator |
| Hard limit filtering | No | No | No | Yes — block downloads that won't run |
| Soft compatibility tiers | No | No | No | Yes — "Fast / Slow / Won't run" |
| Storage warning before download | No | No | No | Yes — show % of free storage used |
| Streaming chat | Yes | Yes | Yes | Yes |
| Tokens/sec display | Yes | Yes | Yes | Yes |
| Model library management | Yes | Yes | Yes | Yes |
| Plain-language quant labels | No | No | No | Yes |
| RAG | Yes (v0.3+) | Yes (Off Grid does) | No | v2+ |
| OpenAI API server | Yes | No | No | No (iOS sandbox incompatible) |

## Sources

- [PocketPal AI GitHub](https://github.com/a-ghorbani/pocketpal-ai) — feature list, HF integration details
- [LLMFarm GitHub](https://github.com/guinmoon/LLMFarm) — iOS LLM runner feature set
- [LM Studio Review 2026](https://elephas.app/blog/lm-studio-review) — desktop feature baseline
- [Are Local LLMs on Mobile a Gimmick? (Callstack, 2025)](https://www.callstack.com/blog/local-llms-on-mobile-are-a-gimmick) — real pain points: storage, OS kills, RAM
- [Enclave AI GGUF Quantization Guide](https://enclaveai.app/blog/2026/03/15/llm-quantization-explained-gguf-guide/) — quant types and device RAM requirements
- [How to Run LLMs Locally on iPhone 2026 (DEV Community)](https://dev.to/alichherawalla/how-to-run-llms-locally-on-your-iphone-in-2026-completely-offline-no-subscription-4b3a) — current iOS LLM landscape
- [Unsloth: Deploy LLMs on Phone](https://unsloth.ai/docs/basics/inference-and-deployment/deploy-llms-phone) — performance benchmarks by chip/model size

---
*Feature research for: On-device iOS LLM runner (ModelRunner)*
*Researched: 2026-04-08*
