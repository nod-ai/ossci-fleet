#!/usr/bin/env bash

# This will get copied to your PVC home-directory (/home/ossci).
# Then, inside your SSH session on your pod, run:
#
#    ~/xx.sh start
#
# This will create (if not already present) a persistent directory,
#
#    ~/xx
#
# and a local temporary directory,
#
#    /tmp/xx
#
# and will rsync ~/xx into /tmp/xx.
#
# Conversely, the rsync of /tmp/xx back into ~/xx will be:
# 1. Scheduled as a hourly cron-job.
# 2. Added as logout command for bash and zsh shells.
# 3. Triggerable at any time by this command:
#
#    ~/xx.sh save
#
# The indended usage is that performance-sensitive directories will be
# put under /tmp/xx so that they benefit from the local filesystem.
#
# Example usage pattern:
# 1. IREE source tree in /tmp/xx/iree
# 2. IREE build directory in /tmp/xx/iree-build
# 3. Less performance-sensitive files stay under $HOME.
# 4. Files that don't need persistence go under /tmp.
# 5. ccache users: put your ccache under /tmp.  Don't need to put it under
#    /tmp/xx unless you really care about that first incremental build of the day.

set -e

command="$1"
persistent_path="$HOME/xx"
local_path="/tmp/xx"

function show_usage_and_exit() {
  echo "Usage:"
  echo ""
  echo "    $(basename $0) start"
  echo ""
  echo "        rsync ${persistent_path} -> ${local_path}"
  echo "        registers 'save' command at exit and as hourly cron-job."
  echo ""
  echo "    $(basename $0) save"
  echo ""
  echo "        rsync ${local_path} -> ${persistent_path}"
  echo ""
  exit 1
}

if [[ $# != 1 ]]
then
  show_usage_and_exit
fi

if [[ ! -x /usr/bin/rsync ]]
then
  sudo apt install -y -qq rsync
fi

if [[ ! -x /usr/bin/crontab ]]
then
  sudo apt install -y -qq cron
fi

if [[ ! -d "$persistent_path" ]]
then
  echo "Creating persistent directory $persistent_path"
  mkdir -p "$persistent_path"
fi

rsync_progress_flags="--info=progress2 --no-inc-recursive --human-readable"

function append_line_if_not_already_found() {
  file="$1"
  line="$2"
  if ! grep "$line" "$file"
  then
    echo "$line" >> "$file"
    echo "Appended to $file:    $line"
  fi
}

if [[ "$1" == "start" ]]
then
  echo "Syncing ${persistent_path} -> ${local_path} ..."
  # Atomic copy: first copy to a .temp destination, then overwrite.
  local_path_temp="${local_path}.temp"
  rsync -a $rsync_progress_flags "${persistent_path}/" "${local_path_temp}"
  # Now overwrite the destination.
  # The destination path may exist as a symlink to persistent_path, created during
  # startup to avoid glitches with sessions that rely on the local path
  # existing on startup. Now is the time to delete it and create the local
  # directory.
  if [[ -L "$local_path" ]]
  then
    rm "$local_path"
  fi
  mv "${local_path_temp}" "$local_path"

  save_command="rsync -a \"${local_path}/\" \"${persistent_path}\""

  # Append the save_command to Bash and Zsh logout command files.
  append_line_if_not_already_found "$HOME/.bash_logout" "$save_command"
  append_line_if_not_already_found "$HOME/.zlogout" "$save_command"

  # Create the cron-job
  current_minute="$(date +%M)"
  # Schedule first save 30 minutes from now i.e. farthest-away from now to avoid
  # it running immediately.
  schedule_minute="$(( (current_minute + 30) % 60 ))"
  crontab_entry="$schedule_minute * * * * $save_command"
  echo "Setting up crontab:  $crontab_entry"
  crontab_entry_tmpfile="$(mktemp --suffix=crontab_entry_tmpfile)"
  echo "$crontab_entry" > "$crontab_entry_tmpfile"
  crontab "$crontab_entry_tmpfile"
  rm "$crontab_entry_tmpfile"
  sudo service cron restart
elif [[ "$1" == "save" ]]
then
  echo "Syncing ${local_path} -> ${persistent_path} ..."
  rsync -a $rsync_progress_flags "${local_path}/" "${persistent_path}"
else
  show_usage_and_exit
fi
