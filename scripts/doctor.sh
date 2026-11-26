#!/usr/bin/env bash
# Check GPU, driver, system libraries and the installed packages.
#
#   pixi run doctor            # default environment
#   pixi run -e lab doctor     # also checks Isaac Lab
#
# Exits non-zero if any check FAILs. WARNs are worth reading but not fatal.
set -uo pipefail

FAILED=0
ok()   { printf '  OK    %s\n' "$*"; }
warn() { printf '  WARN  %s\n' "$*"; }
fail() { printf '  FAIL  %s\n' "$*"; FAILED=1; }
section() { printf '%s\n' "$*"; }

section "GPU / driver"
if command -v nvidia-smi >/dev/null 2>&1 \
    && gpu="$(nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null)" \
    && [[ -n "$gpu" ]]; then
    while IFS= read -r line; do ok "$line"; done <<< "$gpu"
else
    fail "nvidia-smi not found or no NVIDIA GPU visible"
fi

section "System libraries"
glibc="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
if [[ -z "$glibc" ]]; then
    fail "could not determine glibc version"
elif [[ "$(printf '%s\n' 2.35 "$glibc" | sort -V | head -n1)" == "2.35" ]]; then
    ok "glibc $glibc (wheels require >= 2.35)"
else
    fail "glibc $glibc (wheels require >= 2.35)"
fi

# Capture first: `ldconfig | grep -q` under pipefail fails on SIGPIPE.
ldcache="$(ldconfig -p 2>/dev/null)"
if grep -q 'libvulkan\.so\.1 ' <<< "$ldcache"; then
    ok "Vulkan loader present"
else
    fail "Vulkan loader (libvulkan.so.1) missing - sudo apt install libvulkan1"
fi

# Same search list as scripts/activate.sh.
nvidia_icd=""
for _icd in /usr/share/vulkan/icd.d/nvidia_icd.json \
            /usr/local/share/vulkan/icd.d/nvidia_icd.json \
            /etc/vulkan/icd.d/nvidia_icd.json
do
    if [[ -f "$_icd" ]]; then nvidia_icd="$_icd"; break; fi
done
if [[ -n "$nvidia_icd" ]]; then
    ok "NVIDIA Vulkan ICD present"
else
    fail "NVIDIA Vulkan ICD (nvidia_icd.json) not found"
fi

section "Python environment"
if [[ -z "${CONDA_PREFIX:-}" ]]; then
    fail "not inside a pixi environment - run: pixi run doctor"
    exit 1
fi

if [[ -n "$nvidia_icd" && "${VK_DRIVER_FILES:-}" != "$nvidia_icd" ]]; then
    warn "VK_DRIVER_FILES is not pinned to $nvidia_icd - scripts/activate.sh did not run"
fi

libstdcxx="$CONDA_PREFIX/lib/libstdc++.so.6"
if [[ -f "$libstdcxx" ]] && grep -aq 'CXXABI_1\.3\.15' "$libstdcxx"; then
    ok "libstdc++ from the environment provides CXXABI_1.3.15"
else
    warn "no libstdc++ with CXXABI_1.3.15 in $CONDA_PREFIX/lib - Kit may segfault at startup"
fi

python - <<'EOF' || FAILED=1
import sys
from importlib import metadata

failed = False

def ok(msg):   print(f"  OK    {msg}")
def fail(msg):
    global failed
    print(f"  FAIL  {msg}")
    failed = True

try:
    import torch
    ok(f"torch {torch.__version__}")
    if torch.cuda.is_available():
        ok(f"CUDA available: {torch.cuda.get_device_name(0)}")
    else:
        fail("torch cannot see a CUDA device")
except Exception as exc:  # noqa: BLE001
    fail(f"torch import failed: {exc}")

# Read the version from metadata; importing isaacsim would start Kit's bootstrap.
try:
    ok(f"isaacsim {metadata.version('isaacsim')}")
except metadata.PackageNotFoundError:
    fail("isaacsim is not installed")

# Only the `lab` environment has Isaac Lab; report it when present.
try:
    ok(f"isaaclab {metadata.version('isaaclab')}")
except metadata.PackageNotFoundError:
    pass

sys.exit(1 if failed else 0)
EOF

exit "$FAILED"
