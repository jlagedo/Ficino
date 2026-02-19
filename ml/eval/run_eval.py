#!/usr/bin/env python3
"""End-to-end eval pipeline: build prompts → run on-device model → LLM judge.

Usage:
    uv run python eval/run_eval.py v19
    uv run python eval/run_eval.py v19 -l 10
    uv run python eval/run_eval.py v19 -l 10 -p 3
    uv run python eval/run_eval.py v19 --prompts data/eval/prompts.jsonl   # skip build
    uv run python eval/run_eval.py v19 --output data/eval/output_v19.jsonl  # skip build+model, just judge
"""

import argparse
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent.parent
EVAL_DIR = ROOT / "eval"
DATA_DIR = ROOT / "data" / "eval"
PROMPTS_DIR = ROOT / "prompts"


def log(msg: str) -> None:
    print(f"\n\033[1;36m▸ {msg}\033[0m")


def run(cmd: list[str], label: str) -> None:
    log(label)
    print(f"  \033[2m$ {' '.join(cmd)}\033[0m")
    result = subprocess.run(cmd)
    if result.returncode != 0:
        print(f"\n\033[1;31m✗ {label} failed (exit {result.returncode})\033[0m")
        sys.exit(result.returncode)


def main():
    parser = argparse.ArgumentParser(
        description="End-to-end eval: build prompts → run model → judge output."
    )
    parser.add_argument("version", help="Version tag (e.g. v19)")
    parser.add_argument("-l", "--limit", type=int, default=None,
                        help="Limit number of prompts/responses")
    parser.add_argument("-p", "--passes", type=int, default=1,
                        help="Number of judge passes (default: 1)")
    parser.add_argument("-t", "--temperature", type=float, default=None,
                        help="Model temperature (forwarded to FMPromptRunner)")
    parser.add_argument("--context", type=Path, default=DATA_DIR / "context_top100.jsonl",
                        help="Context JSONL file (default: data/eval/context_top100.jsonl)")
    parser.add_argument("--prompts", type=Path, default=None,
                        help="Skip build step, use existing prompts file")
    parser.add_argument("--output", type=Path, default=None,
                        help="Skip build+model steps, just judge this output file")
    args = parser.parse_args()

    version = args.version
    instruction = PROMPTS_DIR / f"fm_instruction_{version}.json"
    if not instruction.exists():
        print(f"\033[1;31m✗ Instruction file not found: {instruction}\033[0m")
        sys.exit(1)

    # Step 1: Build prompts (unless --prompts or --output given)
    if args.output:
        prompts_file = None
        output_file = args.output
    elif args.prompts:
        prompts_file = args.prompts
    else:
        prompts_file = DATA_DIR / "prompts_top100.jsonl"
        cmd = [
            sys.executable, str(EVAL_DIR / "build_prompts.py"),
            str(args.context), "-v", version,
            "-o", str(prompts_file),
        ]
        if args.limit:
            cmd += ["-l", str(args.limit)]
        run(cmd, f"Building prompts ({version})")

    # Step 2: Run model (unless --output given)
    if not args.output:
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        output_file = DATA_DIR / f"output_{version}_{timestamp}.jsonl"
        DATA_DIR.mkdir(parents=True, exist_ok=True)

        cmd = [
            str(EVAL_DIR / "run_model.sh"),
            version, str(prompts_file),
        ]
        if args.limit:
            cmd += ["-l", str(args.limit)]
        if args.temperature is not None:
            cmd += ["-t", str(args.temperature)]
        run(cmd, f"Running model ({version})")

        # run_model.sh generates its own timestamped filename, find the latest
        outputs = sorted(DATA_DIR.glob(f"output_{version}_*.jsonl"))
        if not outputs:
            print(f"\033[1;31m✗ No output file found for {version}\033[0m")
            sys.exit(1)
        output_file = outputs[-1]

    # Step 3: Judge
    if not output_file.exists():
        print(f"\033[1;31m✗ Output file not found: {output_file}\033[0m")
        sys.exit(1)

    cmd = [
        sys.executable, str(EVAL_DIR / "judge_output.py"),
        str(output_file),
    ]
    if args.limit:
        cmd += ["-l", str(args.limit)]
    if args.passes > 1:
        cmd += ["-p", str(args.passes)]
    run(cmd, f"Judging output ({version})")

    log("Done")


if __name__ == "__main__":
    main()
