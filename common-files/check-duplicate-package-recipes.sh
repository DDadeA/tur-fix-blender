#!/bin/bash
set -euo pipefail

cd "$(realpath "$(dirname "$0")/..")"

declare -a tur_repo_paths=()
declare -a upstream_repo_paths=()

while IFS= read -r repo_path; do
	if [[ "$repo_path" == tur* ]]; then
		tur_repo_paths+=("$repo_path")
	else
		upstream_repo_paths+=("$repo_path")
	fi
done < <(jq --raw-output 'del(.pkg_format) | keys | .[]' repo.json)

if [[ "${#tur_repo_paths[@]}" -eq 0 || "${#upstream_repo_paths[@]}" -eq 0 ]]; then
	exit 0
fi

declare -a duplicates=()

for tur_repo_path in "${tur_repo_paths[@]}"; do
	if [[ ! -d "$tur_repo_path" ]]; then
		continue
	fi

	while IFS= read -r pkg; do
		for upstream_repo_path in "${upstream_repo_paths[@]}"; do
			if [[ -d "${upstream_repo_path}/${pkg}" ]]; then
				duplicates+=("${pkg} (${tur_repo_path} vs ${upstream_repo_path})")
			fi
		done
	done < <(find "$tur_repo_path" -mindepth 1 -maxdepth 1 -type d -exec test -f "{}/build.sh" \; -printf "%f\n" | sort -u)
done

if [[ "${#duplicates[@]}" -gt 0 ]]; then
	printf "::error ::Detected duplicate package recipes between TUR and upstream repositories.%0A"
	printf "Add matching upstream recipe paths to common-files/override-packages.txt.%0A"
	printf "Duplicates:%0A"
	printf '%s%0A' "${duplicates[@]}" | sort -u
	exit 1
fi

