
#!/bin/bash
set -e

# ========================
# BASIC CONFIG
# ========================
REPO_DIR="/home/elk-sync/elk/"
BRANCH="elksync"
LOG_FILE="/home/elk-sync/elk-gitsync.log"
HOST="kvlh3"
LOCK="/tmp/elk-sync-vlh3.lock"
EXCLUDE_FILE="/home/elk-sync/rsync-excludes.txt"

exec >>"$LOG_FILE" 2>&1

# ========================
# PREVENT CONCURRENT RUNS
# ========================
exec 9>"$LOCK" || exit 1
flock -n 9 || exit 0

echo "===== $(date): Sync started on $HOST ====="

cd "$REPO_DIR"

# ========================
# AUTO-STASH LOCAL CHANGES
# ========================
STASHED=0
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "$(date): Local changes detected, stashing"
  git stash push -u -m "auto-stash before sync"
  STASHED=1
fi

# ========================
# PULL LATEST CHANGES
# ========================
git pull --rebase origin "$BRANCH"

# ========================
# RSYNC CONFIGS ONLY
# ========================

# ---- LOGSTASH ----
rsync -a --delete \
  --exclude-from="$EXCLUDE_FILE" \
  /etc/logstash/ \
  "$REPO_DIR/vlh3/logstash/"

# ---- KIBANA ----
rsync -a --delete \
  --exclude-from="$EXCLUDE_FILE" \
  /etc/kibana/ \
  "$REPO_DIR/vlh3/kibana/"

# ---- ELASTICSEARCH ----
rsync -a --delete \
  --exclude-from="$EXCLUDE_FILE" \
  /etc/elasticsearch/ \
  "$REPO_DIR/vlh3/elasticsearch/"

# ========================
# RESTORE STASH IF USED
# ========================
#if [ "$STASHED" -eq 1 ]; then
#  echo "$(date): Restoring stashed changes"
#  git stash pop
#fi

# ========================
# COMMIT & PUSH IF CHANGED
# ========================
git add .gitignore vlh3/

if ! git diff --cached --quiet; then
  git commit -m "vlh3 config sync: $(date '+%Y-%m-%d %H:%M:%S')"
  git push origin "$BRANCH"
  echo "$(date): PUSHED"
else
  echo "$(date): NO CHANGES"
fi

echo "===== $(date): Sync completed ====="

