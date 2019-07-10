#!/bin/sh
#args: <name> <template> [state] [clusters] [chmod] [user] [group]
set -e

fix_permissions() {
  if [ -n "$chmod" ]; then
    onevnet chmod "$ID" "$chmod"
  fi

  if [ -n "$user" ]; then
    if OUTPUT="$(onevnet chown "$ID" "$user")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi

  if [ -n "$group" ]; then
    if OUTPUT="$(onevnet chgrp "$ID" "$group")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi
}
add_to_cluster() {
  for CLUSTER in $clusters; do
    onecluster addvnet "$CLUSTER" "$ID"
  done
}

. "$1"
CONFIG="$_ansible_tmpdir/vnet.conf"
TMPNAME="$(echo "$_ansible_tmpdir" | awk -F/ '{print $(NF-1)}')"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search vnet
if OUTPUT="$(onevnet list -lID,USER,NAME --csv -fNAME="$name" $user)"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete vnet
    onevnet delete "$ID"
    echo '{"changed":true}'
  else
    # Vnet is not exist
    echo '{"changed":false}'
  fi
  exit 0
elif [ -n "$state" ] && [ "$state" != "present" ]; then
  echo '{"changed":false, "failed":true, "msg": "value of state must be one of: present, absent, got: '"$state"'"}'
  exit -1
fi

if [ -z "$template" ]; then
  echo '{"changed":false, "failed":true, "msg": "template is required"}'
  exit -1
fi

# Write template
echo "$template" > "$CONFIG"

if [ -z "$ID" ]; then
  # New vnet
  echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
  if OUTPUT="$(onevnet create "$CONFIG")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  fix_permissions
  onevnet rename "$ID" "$name"
  add_to_cluster
  echo '{"changed":true}'
else
  # Existing vnet
  BEFORE="$(onevnet show -x "$ID" | sha256sum )"
  onevnet update "$ID" "$CONFIG"
  fix_permissions
  add_to_cluster
  AFTER="$(onevnet show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
