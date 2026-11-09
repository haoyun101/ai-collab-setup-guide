#!/usr/bin/env bash
# Optional update. Missing tools or network leave the skill usable.
set -eu
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
repo=haoyun101/ai-collab-setup-guide
version_pattern='^[0-9]{1,6}\.[0-9]{1,6}\.[0-9]{1,6}$'

update() {
    local current latest index
    [[ ! -e "$root/.git" && -f "$root/VERSION" ]] || return 0
    current=$(cat "$root/VERSION")
    [[ $current =~ $version_pattern ]] || return 0
    command -v curl >/dev/null || return 0
    stage="${root}.update-lock"
    mkdir "$stage" || return 0
    trap 'if [[ -d "$stage/previous/skill" && ! -e "$root" ]]; then mv "$stage/previous/skill" "$root" || exit 0; fi; rm -rf -- "$stage"' EXIT
    # Fetch a single snapshot so the payload and VERSION come from the same commit.
    curl -fsSL --max-time 15 "https://codeload.github.com/$repo/tar.gz/refs/heads/main" > "$stage/package.tar.gz" || return 0
    mkdir "$stage/next" || return 0
    tar -xzf "$stage/package.tar.gz" --strip-components=1 -C "$stage/next" || return 0
    [[ -f "$stage/next/SKILL.md" && -f "$stage/next/scripts/check-update.sh" ]] || return 0
    latest=$(cat "$stage/next/VERSION") || return 0
    [[ $latest =~ $version_pattern ]] || return 0
    local IFS=.
    local -a installed=( $current ) available=( $latest )
    for index in 0 1 2; do
        (( 10#${available[index]} < 10#${installed[index]} )) && return 0
        (( 10#${available[index]} > 10#${installed[index]} )) && break
    done
    (( index < 2 || 10#${available[2]} > 10#${installed[2]} )) || return 0
    mkdir "$stage/previous" || return 0
    # The source directory must still be present for this rename to succeed.
    mv "$root" "$stage/previous/skill" || return 0
    if ! mv "$stage/next" "$root"; then
        mv "$stage/previous/skill" "$root" || :
        return 0
    fi
    printf '已更新到 v%s\n' "$latest"
}

# Keep the staging path available to the EXIT trap.
update 2>/dev/null || :
