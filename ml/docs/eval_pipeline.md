# Eval Pipeline

Run all commands from the `ml/` directory.

## Quick run (steps 3→4→5 in one command)

```sh
# full pipeline: build prompts → run model → judge
uv run python eval/run_eval.py v19

# limit to 10, 3-pass judging
uv run python eval/run_eval.py v19 -l 10 -p 3

# skip prompt build, use existing prompts
uv run python eval/run_eval.py v19 --prompts data/eval/prompts_top100.jsonl

# just judge an existing output file
uv run python eval/run_eval.py v19 --output data/eval/output_v19_20260219.jsonl
```

Requires context already fetched (steps 1-2) and FMPromptRunner built in Xcode.

---

## Step 1 — Get a track list

Scrape a chart or playlist to build a CSV eval set.

```sh
eval/scrape_context.sh -p mk --charts --limit 100 > data/eval/mk_top100.csv
# or from a named playlist:
eval/scrape_context.sh -p mk --playlist "Top 100: Global" > data/eval/mk_top100.csv
```

Output: `data/eval/mk_top100.csv` — CSV with `artist,track,album` columns.

## Step 2 — Fetch context

Fetch MusicKit + Genius metadata for each track, mirroring what Ficino does at runtime.

```sh
eval/scrape_context.sh -ce data/eval/mk_top100.csv > data/eval/context_top100.jsonl
# resume from track N if interrupted:
eval/scrape_context.sh -ce data/eval/mk_top100.csv --skip 50 >> data/eval/context_top100.jsonl
```

Output: `data/eval/context_top100.jsonl` — one JSON object per track with raw metadata.

## Step 3 — Build prompts

Clean the raw context and assemble structured prompts. Filters out thin-context tracks (no wiki summary), strips HTML/URLs/CTAs.

```sh
# all tracks, no instruction template
uv run python eval/build_prompts.py data/eval/context_top100.jsonl -o data/eval/prompts_top100.jsonl

# with a versioned instruction template appended
uv run python eval/build_prompts.py data/eval/context_top100.jsonl -v v17 -o data/eval/prompts_top100.jsonl

# limit output count
uv run python eval/build_prompts.py data/eval/context_top100.jsonl -v v17 -l 50 -o data/eval/prompts_top100.jsonl
```

Output: `data/eval/prompts_top100.jsonl` — `{"id", "prompt"}` per line, ready for FMPromptRunner.

> **Note:** Use `-o data/eval/prompts_top100.jsonl` to match the path `run_model.sh` expects. Without `-o`, the default output name would be `context_top100_prompts.jsonl`.

## Step 4 — Run the on-device model

Run FMPromptRunner against a versioned instruction file. Requires the `FMPromptRunner` scheme built in Xcode first.

```sh
# basic run
eval/run_model.sh v19

# custom prompts file, limit to 10, custom temperature
eval/run_model.sh v19 data/eval/my_prompts.jsonl -l 10 -t 0.8
```

What it does:
1. Resolves the instruction file at `prompts/fm_instruction_v19.json`
2. Feeds it the fixed eval set at `data/eval/prompts_top100.jsonl`
3. Writes output to `data/eval/output_v19_<timestamp>.jsonl`

## Step 5 — Score with LLM judge

Score each response using Claude Sonnet via the Anthropic API. Requires `ANTHROPIC_API_KEY` in the environment.

```sh
# score all responses
uv run python eval/judge_output.py data/eval/output_v19_*.jsonl

# limit to 10 responses
uv run python eval/judge_output.py -l 10 data/eval/output_v19_*.jsonl

# 3-pass judging for more stable scores
uv run python eval/judge_output.py -p 3 data/eval/output_v19_*.jsonl
```

Scores on 5 dimensions (0-3 each, 15 max):
- **faith** — faithfulness to provided context
- **ground** — every claim traceable to context
- **tone** — natural, descriptive prose
- **conc** — conciseness (2-3 sentences, no meta-framing)
- **acc** — factual accuracy vs context

Flags failure patterns: **P**reamble, **H**allucination, **E**cho, **C**TA-parrot, **M**isattribution.

Output:
- `data/eval/version_rank.md` — summary table across versions
- `data/eval/vrank/<version>_details.md` — per-response breakdown with prompts, responses, scores, and notes
