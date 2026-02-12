# Fase 3 — LoRA Adapter Training for Music Insights

## The Thesis

The on-device Foundation Model (~3B params) has zero world knowledge. Fase 2 solved the data problem with a Fetch→Normalize→Score→Select→Compact→Prompt pipeline that feeds curated facts into a 4,096-token window. The model's only job is rephrasing.

But rephrasing is a skill. The base model treats all facts equally, writes generically, and has no concept of what makes music writing compelling. LoRA doesn't teach the model *what* Steely Dan is — it teaches the model *how to talk about music* when given facts.

LoRA excels at: style, tone, task structure, domain vocabulary, output consistency.
LoRA cannot do: inject factual knowledge, expand context window, bypass guardrails.

Nobody trains music-domain adapters for Apple's on-device model because the intersection of "music nerd" and "ML practitioner with Apple entitlements" is vanishingly small. That's the gap.

---

## What the Adapter Teaches

### 1. Music Storytelling Voice
**Before adapter (base model):**
> "This song was sampled by another artist. It reached number 3 on the charts."

**After adapter (trained):**
> "That bass line you're hearing? It got lifted wholesale into a 2004 hip-hop hit. The track peaked at #3 — not bad for a seven-minute jazz odyssey."

### 2. Fact Hierarchy Intuition
The model internalizes from training data that:
- Sampling chains > chart positions (more surprising)
- "Written by someone unexpected" > generic credits
- Grammy wins need context ("...in a category dominated by pop acts")
- Sparse data requires graceful handling, not padding

### 3. Domain Register
Natural use of: hook, bridge, B-side, pressing, remaster, session musician, chart entry, deep cut, liner notes, production credit, interpolation vs sample.

### 4. Structured Output Reliability
The base model already excels at JSON/structured extraction. Training with `@Generable`-shaped outputs reinforces the pattern for `MusicInsights` specifically.

### 5. Edge Case Handling
Trained examples with sparse inputs (unknown artist, no Wikipedia, just MusicBrainz basics) teach the model to work with what it has rather than hallucinate or repeat itself.

---

## Training Data Strategy

### Format
Apple's toolkit expects JSONL. Each line is a conversation turn:

```jsonl
[{"role": "user", "content": "PROMPT"}, {"role": "assistant", "content": "RESPONSE"}]
```

The `Schema.md` inside the toolkit covers guided generation fields and safety metadata. The response for `@Generable` output likely needs to match the JSON schema the framework injects at inference time — this requires experimentation with the toolkit.

### Prompt Shape (must match Fase 2 `buildPrompt()` output exactly)

```
Now playing: "Aja" by Steely Dan from "Aja".

Known facts:
- Chart: Billboard #3 in 1977
- Awards: Grammy for Best Engineered Recording 1978
- Producers: Gary Katz
- Session musicians: Wayne Shorter (sax), Steve Gadd (drums)
- Genre: Jazz rock
- Written by: Donald Fagen, Walter Becker

Using ONLY the facts listed above, write 3 short fun facts.
```

### Response Shape (must match `@Generable MusicInsights`)

```json
{
  "trackFact": "That sax solo? Wayne Shorter of Weather Report fame, in what Fagen called a single perfect take.",
  "artistFact": "Steely Dan were studio perfectionists — Aja used 40+ session musicians handpicked from jazz and rock royalty.",
  "albumFact": "Hit #3 on Billboard and won the Grammy for Best Engineered Recording — recognized not for the songs, but for how impossibly good they sounded."
}
```

**Critical:** The exact JSON key names and structure must align with whatever schema the Foundation Models framework injects for `MusicInsights`. This needs to be reverse-engineered from the toolkit's `Schema.md` or by inspecting what the framework sends to the model at runtime.

### Volume Target
Apple's guidance: 100–1,000 samples for basic tasks.

Target: **750 training / 150 eval / 100 test = 1,000 total examples**

### Diversity Matrix

Cover all axes systematically:

| Dimension | Variants |
|-----------|----------|
| **Genre** | Rock, pop, hip-hop, jazz, electronic, classical, R&B, country, metal, Latin, African, K-pop |
| **Era** | Pre-1960, 60s, 70s, 80s, 90s, 2000s, 2010s, 2020s |
| **Data density** | Rich (8+ facts), medium (4-6 facts), sparse (2-3 facts) |
| **Fact types dominant** | Samples-heavy, awards-heavy, credits-heavy, chart-heavy, history-heavy |
| **Artist fame** | Iconic, well-known, niche, obscure, debut |
| **Languages** | English primary, but include multilingual artist names and album titles |
| **Edge cases** | Instrumental tracks, compilations, live albums, singles without album, featuring artists |

Minimum 3 examples per cell in the matrix to avoid overfitting to any single pattern.

---

## Synthetic Data Generation Pipeline

Use Claude (or GPT-4) to generate training data. This is exactly how Apple builds their own adapter datasets — synthetic data from larger models, filtered for quality.

### Step 1: Harvest Real API Data
Pull data from the 4 APIs (MusicBrainz, Wikipedia, Wikidata, Last.fm) for ~500 diverse tracks. Store raw responses.

### Step 2: Run Through Fase 2 Pipeline
Process each track through `scoreFacts()` and `selectFacts()` to produce the exact prompt format the on-device model will see. This ensures training data matches inference-time input shape.

### Step 3: Generate Gold Responses with Claude
For each curated prompt, send to Claude with detailed style instructions:

```
You are a music journalist writing fun facts for a listener discovery app.

Rules:
- ONLY use the facts provided. Never add external knowledge.
- Write in a conversational, enthusiastic tone — like a knowledgeable friend.
- Lead with the most surprising fact.
- Use music terminology naturally (don't explain jargon).
- Each fact should be 1-2 sentences, punchy, no filler.
- When data is sparse, be honest and brief. Don't pad.
- Output valid JSON matching this schema: {"trackFact": "...", "artistFact": "...", "albumFact": "..."}

Input:
{fase2_prompt_output}
```

### Step 4: Quality Filter (Rejection Sampling)
Generate 3 variants per track. Score each on:
- **Faithfulness**: Does it ONLY use provided facts? (discard if it hallucinates)
- **Voice**: Does it sound like a music-savvy friend? (discard if generic/robotic)
- **Density**: Is every sentence earning its tokens? (discard if padded)
- **Structure**: Valid JSON matching schema? (discard if malformed)

Keep the best variant. Target ~70% keep rate.

### Step 5: Human Review Pass
Review 100 random samples manually. Check for:
- Subtle hallucinations (facts that sound plausible but aren't in the input)
- Tone drift (too academic, too casual, inconsistent)
- Repetitive patterns across examples

### Step 6: Format as JSONL
```python
import json

def format_example(prompt: str, response: dict) -> str:
    return json.dumps([
        {"role": "user", "content": prompt},
        {"role": "assistant", "content": json.dumps(response)}
    ])
```

Split: 75% train, 15% eval, 10% test.

---

## Training Procedure

### Prerequisites
- Apple Developer Program membership
- Foundation Models Framework Adapter Entitlement (request from Account Holder)
- Download adapter training toolkit from Apple (entitlement-gated)
- Mac with Apple Silicon, 32GB+ RAM — or Linux with GPU
- Python 3.11 (recommended by Apple)

### Environment Setup
```bash
conda create -n adapter-training python=3.11
conda activate adapter-training
cd /path/to/toolkit
pip install -r requirements.txt
```

### Verify Base Model
```bash
python -m examples.generate --prompt "Test prompt here"
```

Note: Toolkit model weights are optimized for training, not inference. Behavior may differ from on-device Foundation Models framework.

### Train
```bash
python -m examples.train_adapter \
  --train-data /path/to/train.jsonl \
  --eval-data /path/to/valid.jsonl \
  --epochs 5 \
  --learning-rate 1e-3 \
  --batch-size 4 \
  --checkpoint-dir /path/to/checkpoints/
```

Apple's defaults are a starting point. Hyperparameter tuning:

| Parameter | Start | Notes |
|-----------|-------|-------|
| `epochs` | 5 | Watch for overfitting on eval loss after epoch 3 |
| `learning-rate` | 1e-3 | Apple's default. Try 1e-4 if loss is unstable |
| `batch-size` | 4 | Reduce to 2 if OOM on 32GB machine |

### Optional: Train Draft Model
The draft model (~48M params) enables speculative decoding for faster inference. Training one alongside the main adapter is recommended for production.

### Export
```bash
python -m export.export_fmadapter \
  --output-dir ./output \
  --adapter-name MusicInsights \
  --checkpoint adapter-final.pt \
  --author "YourName"
```

**Do not modify export code.** The export logic must match exactly for compatibility with the system model.

Output: `MusicInsights.fmadapter` (~160MB)

---

## Deployment

### Loading in Swift
```swift
// Requires Foundation Models Framework Adapter Entitlement
let adapter = try await LanguageModelAdapter(named: "MusicInsights")
let model = SystemLanguageModel(adapter: adapter)
let session = LanguageModelSession(model: model)

let insights = try await session.respond(
    to: prompt,
    generating: MusicInsights.self
)
```

### Distribution via Background Assets
The adapter is NOT bundled in the app binary. It's downloaded separately via the Background Assets framework, which ensures only the adapter matching the user's OS model version is fetched.

Options:
- Host on your own server
- Use Apple's servers

Each user downloads one adapter (~160MB), matched to their device's base model version.

### Version Management
Every OS update that ships a new base model requires:
1. Download new toolkit version
2. Retrain adapter with same dataset (data pipeline unchanged)
3. Export new `.fmadapter`
4. Deploy via Background Assets

The training data and pipeline are reusable. Only the training step reruns.

---

## Open Questions (Requires Experimentation)

### 1. Guided Generation + Adapter Compatibility
Developer forums show this is unclear. Key question: does the training response need to follow the exact internal JSON schema that `@Generable` produces, or can you train on natural language and let constrained decoding handle structure at inference?

**Test plan:** Train two small adapters (50 examples each):
- Variant A: Response is raw JSON matching `MusicInsights` schema
- Variant B: Response is natural language, rely on `@Generable` at inference
- Compare output quality

### 2. Guardrail Sensitivity
Content filtering has been reported as aggressive. Song titles, artist names, or lyric references might trigger blocks.

**Test plan:** Build a test set of 50 tracks with potentially edgy names/content. Run through the adapter to identify false positive rates. If problematic, the Fase 2 `buildPrompt()` may need a sanitization step.

### 3. Sparse Data Graceful Degradation
When only 2-3 facts are available, does the adapter produce better output than the base model with good prompting?

**Test plan:** Create a sparse-only eval set (20 examples with ≤3 facts). Compare base model + prompt vs adapter output quality.

### 4. Optimal Training Data Volume
Apple says 100-1,000. For a style-focused task like this, where is the sweet spot?

**Test plan:** Train adapters at 200, 500, and 1,000 examples. Measure eval loss convergence and qualitative output. Expect diminishing returns after ~500 for a single-task adapter.

---

## Cost/Benefit Analysis

### Costs
- Entitlement approval process (unknown timeline)
- ~40 hours to build synthetic training pipeline + curate 1,000 examples
- ~2-4 hours training per adapter (on 32GB Mac)
- Retrain on every OS model update (same data, ~2-4 hours each time)
- ~160MB per adapter download per user
- Background Assets integration code

### Benefits
- Distinctive voice that prompt engineering alone can't reliably achieve on a 3B model
- Better structured output quality for `@Generable MusicInsights`
- Graceful handling of sparse/edge-case data
- Competitive moat: nobody else is doing music-domain adapters for on-device Apple models
- Deep learning about LoRA, adapter training, synthetic data generation

### Decision
Ship Fase 2 (prompt-only) as v1. Build the synthetic data pipeline in parallel. Train adapter when entitlement is approved. A/B test adapter vs prompt-only on real output quality. Deploy adapter if the quality delta justifies the operational overhead.

---

## Appendix: Example Training Pairs

### Rich Data (8 facts)
```jsonl
[{"role": "user", "content": "Now playing: \"Smells Like Teen Spirit\" by Nirvana from \"Nevermind\".\n\nKnown facts:\n- Sampled by: Destiny's Child \"Bootylicious\" (interpolation)\n- Chart: Billboard #6, UK #7\n- Producers: Butch Vig\n- Written by: Kurt Cobain, Krist Novoselic, Dave Grohl\n- Genre: Grunge, alternative rock\n- Release: 1991, DGC Records\n- Awards: MTV VMA for Best New Artist 1992\n- Influence: Widely credited with bringing alternative rock to mainstream\n\nUsing ONLY the facts listed above, write 3 short fun facts."}, {"role": "assistant", "content": "{\"trackFact\": \"Destiny's Child interpolated this track for 'Bootylicious' — grunge and R&B colliding in ways Cobain probably never imagined.\", \"artistFact\": \"All three band members share the writing credit — Cobain, Novoselic, and Grohl built that riff together before anyone knew their names.\", \"albumFact\": \"Nevermind on DGC Records didn't just chart at #6 — it's widely credited with dragging alternative rock out of the underground and into the mainstream overnight.\"}"}]
```

### Sparse Data (2 facts)
```jsonl
[{"role": "user", "content": "Now playing: \"Ouro\" by Mabe Fratti from \"Sentir Que No Sabes\".\n\nKnown facts:\n- Genre: Experimental, art pop\n- Active since: 2017\n\nUsing ONLY the facts listed above, write 3 short fun facts."}, {"role": "assistant", "content": "{\"trackFact\": \"This one sits at the intersection of experimental and art pop — genre labels that barely contain what's actually happening in the music.\", \"artistFact\": \"Mabe Fratti has been active since 2017, building a catalog that resists easy categorization.\", \"albumFact\": \"Sentir Que No Sabes — the title roughly translates to 'feeling like you don't know,' which feels fitting for music this deliberately unclassifiable.\"}"}]
```

### Chart-Heavy Data
```jsonl
[{"role": "user", "content": "Now playing: \"Blinding Lights\" by The Weeknd from \"After Hours\".\n\nKnown facts:\n- Chart: Billboard #1 for 4 weeks, Billboard Hot 100 Year-End #1 2020\n- Chart: UK #1, topped charts in 30+ countries\n- Producers: Max Martin, Oscar Holter, The Weeknd\n- Genre: Synthwave, electropop\n- Grammy snub: Zero nominations despite record-breaking chart run\n\nUsing ONLY the facts listed above, write 3 short fun facts."}, {"role": "assistant", "content": "{\"trackFact\": \"Year-end #1 on Billboard for 2020 and topped charts in over 30 countries — then got zero Grammy nominations. The snub that changed how the Grammys work.\", \"artistFact\": \"The Weeknd co-produced this himself alongside Max Martin — the same hitmaker behind half the pop canon.\", \"albumFact\": \"After Hours leaned hard into synthwave and electropop, a sharp left turn that became the most commercially dominant sound of 2020.\"}"}]
```