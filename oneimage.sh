#!/bin/sh
#args: <name> <datastore> <path> [state] [template] [type] [chmod] [user] [group]
set -e

fix_permissions() {
  if [ -n "$chmod" ]; then
    oneimage chmod "$ID" "$chmod"
  fi

  if [ -n "$user" ]; then
    if OUTPUT="$(oneimage chown "$ID" "$user")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi

  if [ -n "$group" ]; then
    if OUTPUT="$(oneimage chgrp "$ID" "$group")"; then
      true
    else
      RC=$?
      if ! echo "$OUTPUT" | grep -q "already owns"; then
        echo "$OUTPUT"; exit $RC
      fi
    fi
  fi
}

. "$1"
CONFIG="$_ansible_tmpdir/image.conf"
TMPNAME="$(echo "$_ansible_tmpdir" | awk -F/ '{print $(NF-1)}')"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search image
if OUTPUT="$(oneimage list -lID,USER,NAME --csv -fNAME="$name" $user)"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete image
    oneimage delete "$ID"
    echo '{"changed":true}'
  else
    # Image is not exist
    echo '{"changed":false}'
  fi
  exit 0
elif [ -n "$state" ] && [ "$state" != "present" ]; then
  echo '{"changed":false, "failed":true, "msg": "value of state must be one of: present, absent, got: '"$state"'"}'
  exit -1
fi

if [ -z "$datastore" ]; then
  echo '{"changed":false, "failed":true, "msg": "datastore is required"}'
  exit -1
fi
if [ -z "$path" ] && [ -z "$size" ]; then
  echo '{"changed":false, "failed":true, "msg": "path (or size) is required"}'
  exit -1
fi

# Write template
echo "$template" > "$CONFIG"

if [ -z "$ID" ]; then
  # New image
  echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
  if [ -n "$path" ]; then
    echo "PATH=\"$path\"" >> "$CONFIG"
  fi
  if [ -n "$size" ]; then
    echo "SIZE=\"$size\"" >> "$CONFIG"
  fi
  if [ -n "$type" ]; then
    echo "TYPE=\"$type\"" >> "$CONFIG"
  fi
  if OUTPUT="$(oneimage create -d "$datastore" "$CONFIG")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  oneimage unlock "$ID"
  fix_permissions
  oneimage rename "$ID" "$name"
  echo '{"changed":true}'
else
  # Existing image
  OUTPUT="$(oneimage show -x "$ID")"
  if echo "$OUTPUT" | grep -q '<STATE>5</STATE>'; then
    echo '{"changed":false, "failed":true, "msg": "image in error state!"}'
    exit -1
  fi
  BEFORE="$(echo "$OUTPUT" | sha256sum )"
  oneimage update "$ID" "$CONFIG"
  if [ -n "$type" ]; then
    oneimage chtype "$ID" "$type"
  fi
  fix_permissions
  AFTER="$(oneimage show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
