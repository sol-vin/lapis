#!/usr/bin/env bash
# Wrapper around cc for linking Crystal shared libraries (.so) on Linux.
#
# Problem:
# Crystal emits method symbols with '@' in their mangled names (e.g. *StaticArray(...)@StaticArray...).
# When linking a shared library (-shared), ELF linkers (GNU ld and LLD) interpret '@' as an ELF
# symbol version tag. Because no version node is defined for these names, GNU ld fails with
# "version node not found for symbol" and LLD fails with "symbol ... has undefined version".
#
# Solution:
# 1. For non-shared builds (executables), invoke cc directly.
# 2. For shared builds (-shared):
#    a) Combine all input object files (.o) into a single relocatable object using `ld -r`.
#    b) Localize all symbols except `crystal_godot_init` using `objcopy --keep-global-symbol`.
#       This turns all internal Crystal symbols into STB_LOCAL symbols.
#    c) Local symbols are never exported to .dynsym and never checked for ELF version nodes.
#    d) Link the localized object file with the remaining flags (excluding -rdynamic).

is_shared=0
for arg in "$@"; do
    if [ "$arg" = "-shared" ]; then
        is_shared=1
        break
    fi
done

target_cc="${REAL_CC:-cc}"

if [ "$is_shared" -eq 0 ]; then
    exec "$target_cc" "$@"
fi

# We are building a shared library
objs=()
flags=()

for arg in "$@"; do
    if [ "$arg" = "-rdynamic" ]; then
        continue
    elif [ -f "$arg" ] && [[ "$arg" == *.o || "$arg" == *.o.* || "$arg" == *.obj ]]; then
        objs+=("$arg")
    else
        flags+=("$arg")
    fi
done

if [ ${#objs[@]} -eq 0 ]; then
    exec "$target_cc" "$@"
fi

tmp_dir="${TMPDIR:-/tmp}"
combined="$tmp_dir/crystal_comb_$$.o"
localized="$tmp_dir/crystal_loc_$$.o"

cleanup() {
    rm -f "$combined" "$localized"
}
trap cleanup EXIT INT TERM

# 1. Merge all input objects into a single relocatable object
ld -r "${objs[@]}" -o "$combined"
ret=$?
if [ $ret -ne 0 ]; then
    exit $ret
fi

# 2. Localize all defined symbols except crystal_godot_init
objcopy --keep-global-symbol=crystal_godot_init "$combined" "$localized"
ret=$?
if [ $ret -ne 0 ]; then
    exit $ret
fi

# 3. Link the shared library with localized object
"$target_cc" "$localized" -Wl,-Bsymbolic -Wl,-Bsymbolic-functions "${flags[@]}"
exit $?
