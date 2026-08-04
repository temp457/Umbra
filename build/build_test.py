import subprocess
import sys
from pathlib import Path

import build as builder

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "dist"
OUT = DIST / "umbra-test.luau"
EXAMPLE = ROOT / "Example.luau"


def example_body() -> str:
    lines = EXAMPLE.read_text(encoding="utf-8").splitlines()
    kept = []
    for line in lines:
        if "loadstring(game:HttpGet" in line:
            continue
        kept.append(line)
    return "\n".join(kept).strip()


def main():
    modules = builder.collect()

    if builder.ENTRY not in modules:
        raise SystemExit(f"entry module '{builder.ENTRY}' not found")

    chunks = [builder.PRELUDE]

    for name in sorted(modules):
        source = modules[name].read_text(encoding="utf-8").rstrip()
        chunks.append(f'__modules["{name}"] = function()\n{source}\nend\n\n')

    chunks.append(f'local Umbra = require("{builder.ENTRY}")\n\n')
    chunks.append(example_body())
    chunks.append("\n")

    DIST.mkdir(parents=True, exist_ok=True)

    staging = DIST / "umbra-test.staging.luau"
    staging.write_text("".join(chunks), encoding="utf-8")

    ok, output = builder.luau_compile(staging)

    if not ok:
        staging.unlink(missing_ok=True)
        print("TEST BUILD FAILED - does not parse", file=sys.stderr)
        print(output, file=sys.stderr)
        return 1

    staging.replace(OUT)

    print(f"test build -> {OUT}")
    print(f"{OUT.stat().st_size:,} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
