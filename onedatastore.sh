#!/bin/sh
#args: <name> <template> [state] [clusters] [chmod] [user] [group]
set -e

fix_permissions() {
  if [ -n "$chmod" ]; then
    onedatastore chmod "$ID" "$chmod"
  fi

  if [ -n "$user" ]; then
    if OUTPUT="$(onedatastore chown "$ID" "$user")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi

  if [ -n "$group" ]; then
    if OUTPUT="$(onedatastore chgrp "$ID" "$group")"; then
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
    onecluster adddatastore "$CLUSTER" "$ID"
  done
}

. "$1"
CONFIG="$_ansible_tmpdir/datastore.conf"
TMPNAME="$(echo "$_ansible_tmpdir" | awk -F/ '{print $(NF-1)}')"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search datastore
if OUTPUT="$(onedatastore list -lID,USER,NAME --csv -fNAME="$name")"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete datastore
    onedatastore delete "$ID"
    echo '{"changed":true}'
  else
    # Datastore is not exist
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
  # New datastore
  echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
  if OUTPUT="$(onedatastore create "$CONFIG")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  fix_permissions
  onedatastore rename "$ID" "$name"
  add_to_cluster
  echo '{"changed":true}'
else
  # Existing datastore
  BEFORE="$(onedatastore show -x "$ID" | sha256sum )"
  onedatastore update "$ID" "$CONFIG"
  fix_permissions
  add_to_cluster
  AFTER="$(onedatastore show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
