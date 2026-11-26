#!/bin/sh
cd "$(dirname "$0")" || exit 1

export LD_LIBRARY_PATH="$PWD/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export HOME="${HOME:-/mnt/SDCARD}"
exec ./DinguxCommander --config-prelude ./trimui.cfg

