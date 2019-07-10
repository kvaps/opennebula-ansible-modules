#!/bin/sh
#args: <name> [template] [state]
set -e

. "$1"
CONFIG="$_ansible_tmpdir/cluster.conf"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search cluster
if OUTPUT="$(onecluster list -lID,NAME --csv -fNAME="$name")"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete cluster
    onecluster delete "$ID"
    echo '{"changed":true}'
  else
    # Cluster is not exist
    echo '{"changed":false}'
  fi
  exit 0
elif [ -n "$state" ] && [ "$state" != "present" ]; then
  echo '{"changed":false, "failed":true, "msg": "value of state must be one of: present, absent, got: '"$state"'"}'
  exit -1
fi

# Write template
echo "$template" > "$CONFIG"

if [ -z "$ID" ]; then
  # New cluster
  if OUTPUT="$(onecluster create "$name")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
    onecluster update "$ID" "$CONFIG"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  echo '{"changed":true}'
else
  # Existing cluster
  BEFORE="$(onecluster show -x "$ID" | sha256sum )"
  onecluster update "$ID" "$CONFIG"
  AFTER="$(onecluster show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
