import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
DIST = ROOT / "dist"
OUT = DIST / "umbra.luau"
ENTRY = "Umbra"

PRELUDE = """local __modules = {}
local __cache = {}

local function require(name)
\tlocal cached = __cache[name]
\tif cached ~= nil then
\t\treturn cached
\tend

\tlocal factory = __modules[name]
\tif not factory then
\t\terror("Umbra: unknown module '" .. tostring(name) .. "'", 2)
\tend

\tlocal result = factory()
\tif result == nil then
\t\tresult = true
\tend

\t__cache[name] = result
\treturn result
end

"""


def collect():
    modules = {}
    for path in sorted(SRC.rglob("*.luau")):
        name = path.stem
        if name in modules:
            raise SystemExit(
                f"duplicate module name '{name}':\n  {modules[name]}\n  {path}\n"
                "module names must be unique because the bundle resolves them by name"
            )
        modules[name] = path
    return modules


def luau_compile(target: Path) -> tuple[bool, str]:
    binary = Path(os.path.expanduser("~")) / ".rokit" / "bin" / "luau-compile.exe"
    if not binary.exists():
        return True, "luau-compile not found, parse check skipped"

    result = subprocess.run(
        [str(binary), "--binary", str(target)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    output = (result.stderr or b"").decode("utf-8", errors="replace")
    return result.returncode == 0, output.strip()


def main():
    modules = collect()

    if ENTRY not in modules:
        raise SystemExit(f"entry module '{ENTRY}' not found in {SRC}")

    chunks = [PRELUDE]

    for name in sorted(modules):
        source = modules[name].read_text(encoding="utf-8").rstrip()
        chunks.append(f'__modules["{name}"] = function()\n{source}\nend\n\n')

    chunks.append(f'return require("{ENTRY}")\n')

    DIST.mkdir(parents=True, exist_ok=True)

    staging = DIST / "umbra.staging.luau"
    staging.write_text("".join(chunks), encoding="utf-8")

    ok, output = luau_compile(staging)

    if not ok:
        staging.unlink(missing_ok=True)
        print("BUILD FAILED - bundle does not parse", file=sys.stderr)
        print(output, file=sys.stderr)
        return 1

    staging.replace(OUT)

    size = OUT.stat().st_size
    print(f"bundled {len(modules)} modules -> {OUT}")
    print(f"{size:,} bytes")
    if output:
        print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
