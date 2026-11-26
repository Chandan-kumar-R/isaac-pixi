#!/usr/bin/env bash
# Sourced by pixi on `pixi run` and `pixi shell`, for every environment.

if [[ -n "${CONDA_PREFIX:-}" && -d "$CONDA_PREFIX/lib" ]]; then
    case ":${LD_LIBRARY_PATH:-}:" in
        *":$CONDA_PREFIX/lib:"*) ;;
        *) export LD_LIBRARY_PATH="$CONDA_PREFIX/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ;;
    esac
fi

# Isaac Sim renders through Vulkan. With several ICDs installed (Intel,
# lavapipe, ...) the loader may pick an integrated or software driver, which
# breaks camera rendering and video recording. Pin it to NVIDIA when present.
for _icd in /usr/share/vulkan/icd.d/nvidia_icd.json \
            /usr/local/share/vulkan/icd.d/nvidia_icd.json \
            /etc/vulkan/icd.d/nvidia_icd.json
do
    if [[ -f "$_icd" ]]; then
        export VK_DRIVER_FILES="$_icd"   # current name
        export VK_ICD_FILENAMES="$_icd"  # legacy name, for older loaders
        break
    fi
done
unset _icd
