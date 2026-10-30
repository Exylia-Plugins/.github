#!/usr/bin/env bash
# Publishes one built jar to BuiltByBit as a new version of a resource.
#
#   BUILTBYBIT_TOKEN=... BBB_RESOURCE=<id> [POST_UPDATE=true] \
#     ./publish-builtbybit.sh <name> <version> <jar> [changes-file]
#
# Called by .github/workflows/builtbybit.yml after a plugin's GitHub release, and
# runnable by hand against a jar downloaded from that release. Same v2 Creator
# API call as exylia-release-tools' uploadToBuiltByBit: one request creates the
# version and, with POST_UPDATE=true, the public update post. The changes file
# holds one change per line and becomes that post's list.
set -euo pipefail

name="${1:?name}"
version="${2:?version}"
version="${version#v}"
jar="${3:?jar}"
changes_file="${4:-}"
post_update="${POST_UPDATE:-true}"

: "${BUILTBYBIT_TOKEN:?BUILTBYBIT_TOKEN is not set}"
: "${BBB_RESOURCE:?BBB_RESOURCE is not set}"

test -f "$jar"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# One API call. BuiltByBit says how long to wait in the message itself ("retry
# after 716 milliseconds"; write bursts can ask for ~40 s), so that is what is
# waited instead of a fixed backoff. Prints the response body, returns nothing.
call() {
  local method="$1" path="$2" body="${3:-}" attempt wait
  for attempt in 1 2 3 4 5; do
    if [[ -n "$body" ]]; then
      curl -sS -X "$method" "https://api.builtbybit.com${path}" \
        -H "Authorization: Private ${BUILTBYBIT_TOKEN}" \
        -H "Content-Type: application/json" \
        --max-time 120 --data-binary "@${body}" > "$work/response.json"
    else
      curl -sS -X "$method" "https://api.builtbybit.com${path}" \
        -H "Authorization: Private ${BUILTBYBIT_TOKEN}" \
        --max-time 30 > "$work/response.json"
    fi
    if ! jq -e '.error.code == "RateLimitExceededError"' "$work/response.json" >/dev/null 2>&1; then
      cat "$work/response.json"
      return
    fi
    wait="$(jq -r '.error.message' "$work/response.json" | grep -oE '[0-9]+ millisecond' | grep -oE '[0-9]+' || echo 2000)"
    sleep "$(( wait / 1000 + 1 ))"
  done
  cat "$work/response.json"
}

# BuiltByBit takes the same version name twice, which is what a re-run of the
# release job would do, so the latest version is a gate: not being able to read
# it stops the upload. Hand uploads named it "v1.2.0", the tooling "1.2.0".
# The listing first: /versions/latest kept answering the old version after
# uploads through this API, and let a re-run publish a duplicate. A resource
# still pending approval refuses the listing (ContentViewRestrictedError) but
# answers /versions/latest, and there nothing has been uploaded through here.
recent="$(call GET "/v1/resources/${BBB_RESOURCE}/versions?count=20&order=desc")"
if ! jq -e '.result == "success"' >/dev/null <<< "$recent"; then
  recent="$(call GET "/v1/resources/${BBB_RESOURCE}/versions/latest" | jq -c '.data |= [.]')"
fi
if ! jq -e '.result == "success"' >/dev/null <<< "$recent"; then
  echo "Could not read the versions of resource ${BBB_RESOURCE}:" >&2
  echo "$recent" >&2
  exit 1
fi
if jq -e --arg v "$version" 'any(.data[]; (.name | ltrimstr("v")) == $v)' >/dev/null <<< "$recent"; then
  echo "BuiltByBit already has ${version}; nothing to do."
  exit 0
fi

# The request body is capped at 100 MB, about 67 MB of jar once base64-encoded.
if (( $(stat -c %s "$jar") > 67 * 1024 * 1024 )); then
  echo "${jar} is over BuiltByBit's ~67 MB upload limit." >&2
  exit 1
fi
base64 -w0 "$jar" > "$work/jar.b64"

message=""
if [[ -n "$changes_file" && -s "$changes_file" ]]; then
  message="$(printf '[LIST]\n'; sed 's/^/[*]/' "$changes_file"; printf '[/LIST]\n')"
fi
message+="ExyliaLib announces this update in game: run /exylialib plugins to install it, then restart."

# Written to a file: the base64 jar is far past the argument length limit.
jq -n \
  --argjson resource "$BBB_RESOURCE" \
  --arg version "$version" \
  --arg file "${name}-${version}.jar" \
  --rawfile data "$work/jar.b64" \
  --argjson post "$post_update" \
  --arg title "${name} v${version}" \
  --arg message "$message" \
  '{
     resource_id: $resource,
     version_name: $version,
     file: { name: $file, data: $data }
   } + (if $post then { update: { post: true, title: $title, message: $message } } else {} end)' \
  > "$work/payload.json"

response="$(call POST /v2/resources/creator/update "$work/payload.json")"
if ! jq -e '.result == "success"' >/dev/null <<< "$response"; then
  echo "BuiltByBit refused the upload:" >&2
  echo "$response" >&2
  exit 1
fi

echo "Published ${version} to BuiltByBit resource ${BBB_RESOURCE} (version $(jq -r '.data.version_id // "?"' <<< "$response"))."
