# CLAUDE.md

macOS menu bar app that delivers Apple Intelligence commentary on the music you're listening to. Uses Apple's on-device 3B Foundation Model, fine-tuned with a LoRA adapter trained on music metadata.

## Repository Structure

```
app/          Swift/Xcode — macOS menu bar app (Apple Intelligence, on-device)
ml/           Python — prompt engineering, evaluation, LoRA training for the 3B model
docs/         Shared reference material (Apple FM specs, prompt guides, training notes)
.claude/      Skills and local settings
```

`app/` and `ml/` are fully independent workspaces — each has its own `CLAUDE.md` with detailed guidance. They connect through the model: `ml/` iterates on prompts and fine-tuning, `app/` ships the results on-device via `FoundationModels` framework.

## Build (from repo root)

```sh
xcodebuild -project app/Ficino.xcodeproj -scheme Ficino -derivedDataPath ./build build
```

## Key Constraints

- **macOS 26+ only.** Verify API availability on macOS — do not assume iOS availability.
- **Never modify `.pbxproj`** — Xcode 16+ synchronized folders auto-detect file changes on disk.
- **Swift 6.2** with strict concurrency. All services use actor isolation.
- **App sandbox enabled** with `com.apple.security.network.client` for MusicKit catalog access.

## Reference Docs (`docs/`)

- `apple_fm_specs.md` — Apple Intelligence Foundation Models specification
- `3b_all.md` — Full 3B model documentation
- `3b_prompt_guide.md` — Prompt engineering guide for the 3B model
- `3b_lora_training.mb` — LoRA training notes
- `apple_adapter_toolkit.md` — Apple adapter/LoRA toolkit guide

## Skills

- **`iterate-prompt`** — Workflow for tuning FM instruction prompts and evaluating results. Invoke with `/iterate-prompt`.
