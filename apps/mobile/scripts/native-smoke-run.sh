set -euo pipefail
cd apps/mobile
export EXPO_OFFLINE=1 CI=1
node scripts/native-smoke-fixture.cjs >"$RUNNER_TEMP/native-fixture.log" 2>&1 &
fixture=$!
node node_modules/expo/bin/cli start --dev-client --localhost --port 8081 --max-workers 2 >"$RUNNER_TEMP/native-metro.log" 2>&1 &
metro=$!
cleanup() {
  status=$?
  kill "$fixture" "$metro" 2>/dev/null || true
  if [[ "$status" != 0 ]]; then
    tail -n 30 "$RUNNER_TEMP/native-fixture.log" "$RUNNER_TEMP/native-metro.log"
  fi
}
trap cleanup EXIT
curl --fail --silent --show-error --retry 20 --retry-connrefused --retry-delay 1 http://127.0.0.1:8081/status
curl --fail --silent --show-error --retry 5 --retry-connrefused --retry-delay 1 http://127.0.0.1:18001/api/auth/status
adb install "$RUNNER_TEMP/deeptutor-apk/app-debug.apk"
maestro test scripts/native-smoke.yml
grep -q 'second turn resumed after sequence 1' "$RUNNER_TEMP/native-fixture.log"
echo 'Android native acceptance passed.'
