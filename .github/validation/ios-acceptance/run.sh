#!/usr/bin/env bash
set -euo pipefail
work="$RUNNER_TEMP/ios-acceptance"
results="$RUNNER_TEMP/ios-acceptance-results"
mkdir -p "$results"
device="$(xcrun simctl list devices available -j | node -e '
  const { devices } = JSON.parse(require("node:fs").readFileSync(0, "utf8"));
  const phone = Object.entries(devices)
    .filter(([runtime]) => runtime.includes("SimRuntime.iOS-"))
    .flatMap(([, entries]) => entries)
    .find(entry => entry.isAvailable && entry.name.startsWith("iPhone"));
  if (!phone) throw new Error("No iPhone simulator found");
  console.log(phone.udid);
')"
fixture_pid=""
cleanup() {
  status=$?
  if [[ -n "$fixture_pid" ]]; then kill "$fixture_pid" 2>/dev/null || true; fi
  if [[ "$status" != 0 ]]; then
    xcrun simctl io "$device" screenshot "$results/failure.png" 2>/dev/null || true
    tail -n 40 "$results/fixture.log" 2>/dev/null || true
  fi
  xcrun simctl shutdown "$device" 2>/dev/null || true
}
trap cleanup EXIT
echo "Booting simulator $device"
xcrun simctl boot "$device"
ditto -x -k "$work/deeptutor-ios-simulator.zip" "$work"

# Give only the disposable simulator trust for the local fixture.
openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days 2 \
  -subj '/CN=DeepTutor Simulator Test CA' \
  -keyout "$work/ca.key" -out "$work/ca.pem"
openssl req -new -newkey rsa:2048 -nodes -sha256 -subj '/CN=localhost' \
  -keyout "$work/server.key" -out "$work/server.csr"
printf '%s\n' 'subjectAltName=DNS:localhost' 'extendedKeyUsage=serverAuth' \
  'keyUsage=digitalSignature,keyEncipherment' >"$work/server-ext.cnf"
openssl x509 -req -in "$work/server.csr" -CA "$work/ca.pem" \
  -CAkey "$work/ca.key" -CAcreateserial -out "$work/server.pem" \
  -days 2 -sha256 -extfile "$work/server-ext.cnf"
node ../../.github/validation/ios-acceptance/fixture.cjs "$work/server.key" "$work/server.pem" \
  >"$results/fixture.log" 2>&1 &
fixture_pid=$!
curl --fail --silent --show-error --retry 10 --retry-connrefused \
  --cacert "$work/ca.pem" https://localhost:18001/api/auth/status
xcrun simctl bootstatus "$device" -b
xcrun simctl keychain "$device" add-root-cert "$work/ca.pem"
xcrun simctl install "$device" "$work/DeepTutorMobile.app"
test_src="$GITHUB_WORKSPACE/.github/validation/ios-acceptance/xctest"
cp -R "$test_src" "$work/xctest"
cd "$work/xctest"
xcodegen generate
xcodebuild -project NativeAcceptance.xcodeproj -scheme NativeAcceptance \
  -destination "id=$device" -parallel-testing-enabled NO \
  -derivedDataPath "$work/derived" -resultBundlePath "$results/Acceptance.xcresult" \
  CODE_SIGNING_ALLOWED=NO test
grep -q 'second turn resumed after sequence 1' "$results/fixture.log"
echo 'iOS native acceptance passed.'
