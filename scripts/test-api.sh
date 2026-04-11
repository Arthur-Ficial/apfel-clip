#!/bin/zsh
# test-api.sh — live control API smoke tests
# Starts the app, exercises every control API endpoint, then quits.
# Usage: ./scripts/test-api.sh
set -uo pipefail

PASS=0
FAIL=0
pass() { print "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { print "  [FAIL] $1" >&2; FAIL=$((FAIL + 1)); }

# ── Start app ────────────────────────────────────────────────────────────────
pkill -x apfel-clip 2>/dev/null; sleep 1
open /Applications/apfel-clip.app

PORT=""
for i in {1..24}; do
    for p in 11436 11437 11438 11439; do
        if curl -s --max-time 0.5 "http://127.0.0.1:$p/health" 2>/dev/null | grep -q '"status"'; then
            PORT=$p; break 2
        fi
    done
    sleep 0.5
done

if [[ -z "$PORT" ]]; then
    print "ERROR: app did not start within 12 seconds" >&2; exit 1
fi
print "==> Control API on port $PORT"

api()  { curl -s "http://127.0.0.1:$PORT$1"; }
post() { curl -s -X POST "http://127.0.0.1:$PORT$1" ${2:+-d "$2"}; }

field() {
    local json="$1" key="$2" expected="$3"
    local got
    got=$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get(sys.argv[2],'__MISSING__'))" \
        "$json" "$key" 2>/dev/null)
    if [[ "$got" == "$expected" ]]; then
        return 0
    else
        print "    field '$key': expected '$expected', got '$got'" >&2
        return 1
    fi
}

has_field() {
    local json="$1" key="$2"
    python3 -c "import sys,json; d=json.loads(sys.argv[1]); sys.exit(0 if sys.argv[2] in d else 1)" \
        "$json" "$key" 2>/dev/null
}

# ── Tests ────────────────────────────────────────────────────────────────────

print ""
print "── GET /health ──"
r=$(api /health)
field "$r" status ok && pass "GET /health status=ok" || fail "GET /health status"

print ""
print "── GET /settings ──"
r=$(api /settings)
field "$r" status ok                                              && pass "GET /settings status=ok"                          || fail "GET /settings status"
has_field "$r" auto_copy                                          && pass "GET /settings has auto_copy"                      || fail "GET /settings missing auto_copy"
has_field "$r" launch_at_login                                    && pass "GET /settings has launch_at_login"                || fail "GET /settings missing launch_at_login"
has_field "$r" preferred_panel                                    && pass "GET /settings has preferred_panel"                || fail "GET /settings missing preferred_panel"
has_field "$r" favorite_action_ids                                && pass "GET /settings has favorite_action_ids"            || fail "GET /settings missing favorite_action_ids"
has_field "$r" hidden_action_ids                                  && pass "GET /settings has hidden_action_ids"              || fail "GET /settings missing hidden_action_ids"
has_field "$r" check_for_updates_on_launch                        && pass "GET /settings has check_for_updates_on_launch"    || fail "GET /settings missing check_for_updates_on_launch"

print ""
print "── POST /settings check_for_updates_on_launch ──"
r=$(post /settings '{"check_for_updates_on_launch":false}')
field "$r" check_for_updates_on_launch False && pass "POST /settings sets check_for_updates_on_launch=false" || fail "POST /settings check_for_updates_on_launch=false"
r=$(api /settings)
field "$r" check_for_updates_on_launch False && pass "GET /settings persists false"                          || fail "GET /settings didn't persist false"
r=$(post /settings '{"check_for_updates_on_launch":true}')
field "$r" check_for_updates_on_launch True  && pass "POST /settings re-enables check_for_updates_on_launch" || fail "POST /settings re-enable failed"

print ""
print "── GET /welcome ──"
r=$(api /welcome)
field "$r" status ok            && pass "GET /welcome status=ok"                              || fail "GET /welcome status"
has_field "$r" visible          && pass "GET /welcome has visible"                            || fail "GET /welcome missing visible"
has_field "$r" current_version  && pass "GET /welcome has current_version"                   || fail "GET /welcome missing current_version"
has_field "$r" last_seen_version && pass "GET /welcome has last_seen_version"                || fail "GET /welcome missing last_seen_version"
has_field "$r" check_for_updates_on_launch && pass "GET /welcome has check_for_updates_on_launch" || fail "GET /welcome missing check_for_updates_on_launch"

print ""
print "── POST /debug/reset-first-run ──"
r=$(post /debug/reset-first-run)
field "$r" visible True && pass "/debug/reset-first-run makes welcome visible"             || fail "/debug/reset-first-run visible"
field "$r" last_seen_version "" && pass "/debug/reset-first-run clears last_seen_version" || fail "/debug/reset-first-run last_seen_version"

print ""
print "── POST /welcome/dismiss ──"
r=$(post /welcome/dismiss)
field "$r" visible False && pass "/welcome/dismiss hides overlay"  || fail "/welcome/dismiss visible"
cv=$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('current_version',''))" "$r" 2>/dev/null)
lsv=$(python3 -c "import sys,json; d=json.loads(sys.argv[1]); print(d.get('last_seen_version',''))" "$r" 2>/dev/null)
if [[ "$cv" == "$lsv" && -n "$cv" ]]; then
    pass "/welcome/dismiss saves last_seen_version=$lsv"
else
    fail "/welcome/dismiss last_seen_version mismatch (cv='$cv' lsv='$lsv')"
fi

print ""
print "── POST /welcome/show ──"
r=$(post /welcome/show)
field "$r" visible True && pass "/welcome/show makes overlay visible" || fail "/welcome/show visible"

print ""
print "── GET /update ──"
r=$(api /update)
field "$r" status ok                    && pass "GET /update status=ok"            || fail "GET /update status"
has_field "$r" state                    && pass "GET /update has state"             || fail "GET /update missing state"
has_field "$r" current_version          && pass "GET /update has current_version"   || fail "GET /update missing current_version"
has_field "$r" update_available         && pass "GET /update has update_available"  || fail "GET /update missing update_available"
has_field "$r" install_method           && pass "GET /update has install_method"    || fail "GET /update missing install_method"

print ""
print "── GET /actions ──"
r=$(api /actions)
field "$r" status ok && pass "GET /actions status=ok" || fail "GET /actions status"
has_field "$r" actions && pass "GET /actions has actions" || fail "GET /actions missing actions"
has_field "$r" all_actions && pass "GET /actions has all_actions" || fail "GET /actions missing all_actions"

print ""
print "── POST /ui/show / hide ──"
post /ui/show >/dev/null && pass "POST /ui/show responded" || fail "POST /ui/show failed"
post /ui/hide >/dev/null && pass "POST /ui/hide responded" || fail "POST /ui/hide failed"

# ── Cleanup — leave app in neutral state ─────────────────────────────────────
post /welcome/dismiss >/dev/null 2>&1 || true
post /ui/hide >/dev/null 2>&1 || true

# ── Summary ──────────────────────────────────────────────────────────────────
print ""
print "==> $PASS passed / $FAIL failed"
[[ $FAIL -eq 0 ]] && print "==> All API tests passed." || { print "==> FAILURES: $FAIL" >&2; exit 1; }
