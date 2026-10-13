# step: print a command, run it, remember failures. finish: list them, exit 1 so
# chezmoi retries the script on the next apply.
failed=""
step() { echo "==> $*"; "$@" || failed="$failed
  $*"; }
finish() { [ -z "$failed" ] || { printf 'failed:%s\n' "$failed"; exit 1; }; }
