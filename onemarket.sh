#!/bin/sh
#args: <name> [template] [state]
set -e

. "$1"
CONFIG="$_ansible_tmpdir/market.conf"

if [ -z "$name" ]; then
  echo '{"changed":false, "failed":true, "msg": "name is required"}'
  exit -1
fi

# Search market
if OUTPUT="$(onemarket list -lID,NAME --csv -fNAME="$name")"; then
  ID="$(echo "$OUTPUT" | awk -F, 'FNR==2{print $1}')"
else
  RC=$?; echo "$OUTPUT"; exit $RC
fi

if [ "$state" = "absent" ]; then
  if [ -z "$ID" ]; then
    # Delete market
    onemarket delete "$ID"
    echo '{"changed":true}'
  else
    # Market is not exist
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
  # New market
  if OUTPUT="$(onemarket create "$name")"; then
    ID="$(echo "$OUTPUT" | awk '{print $NF}' )"
    onemarket update "$ID" "$CONFIG"
  else
    RC=$?; echo "$OUTPUT"; exit $RC
  fi
  echo '{"changed":true}'
else
  # Existing market
  BEFORE="$(onemarket show -x "$ID" | sha256sum )"
  onemarket update "$ID" "$CONFIG"
  AFTER="$(onemarket show -x "$ID" | sha256sum )"
  if [ "$BEFORE" != "$AFTER" ]; then
    echo '{"changed":true}'
  else
    echo '{"changed":false}'
  fi
fi
