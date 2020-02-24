#!/bin/sh
#args: <name> <template> [state] [clusters] [chmod] [user] [group]
set -e

. "$1"
CONFIG="$_ansible_tmpdir/group.conf"
TMPNAME="$(echo "$_ansible_tmpdir" | awk -F/ '{print $(NF-1)}')"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search group
if OUTPUT="$(onegroup list -lID,NAME --csv -fNAME="$name")"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete group
    onegroup delete "$ID"
    echo '{"changed":true}'
  else
    # Froup is not exist
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
  # New group
  echo "NAME=\"$TMPNAME\"" >> "$CONFIG"
  if OUTPUT="$(onegroup create "$CONFIG")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  onegroup rename "$ID" "$name"
  echo '{"changed":true}'
else
  # Existing group
  BEFORE="$(onegroup show -x "$ID" | sha256sum )"
  onegroup update "$ID" "$CONFIG"
  AFTER="$(onegroup show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
