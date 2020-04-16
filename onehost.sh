#!/bin/sh
set -x
#args: <name> <im_mad> <vmm_mad> [template] [state] [cluster]
set -e

add_to_cluster() {
  if [ -n "$cluster" ]; then
    onecluster addhost "$cluster" "$ID"
  fi
}

. "$1"
CONFIG="$_ansible_tmpdir/host.conf"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search host
if OUTPUT="$(onehost list -lID,NAME --csv -fNAME="$name")"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi


if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete host
    onehost delete "$ID"
    echo '{"changed":true}'
  else
    # Host is not exist
    echo '{"changed":false}'
  fi
  exit 0
elif [ -n "$state" ] && [ "$state" != "present" ]; then
  echo '{"changed":false, "failed":true, "msg": "value of state must be one of: present, absent, got: '"$state"'"}'
  exit -1
fi

if [ -z "$im_mad" ]; then
  echo '{"changed":false, "failed":true, "msg": "im_mad is required"}'
  exit -1
fi
if [ -z "$vmm_mad" ]; then
  echo '{"changed":false, "failed":true, "msg": "vmm_mad is required"}'
  exit -1
fi


# Write template
echo "$template" > "$CONFIG"

if [ -z "$ID" ]; then
  # New host
  if OUTPUT="$(onehost create -i "$im_mad" -v "$vmm_mad" "$name")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
    onehost update "$ID" "$CONFIG"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  add_to_cluster
  echo '{"changed":true}'
else
  # Existing host
  BEFORE="$(onehost show -x "$ID" | sha256sum )"
  onehost update "$ID" "$CONFIG"
  add_to_cluster
  AFTER="$(onehost show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
