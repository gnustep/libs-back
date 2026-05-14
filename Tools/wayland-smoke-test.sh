#!/usr/bin/env bash
# wayland-smoke-test.sh — Milestone 0 integration harness for the Wayland backend.
#
# Starts the Ambrosia compositor nested inside the current Wayland session,
# then exercises each feature bucket in wayland_feature_implementation_plan.md
# and captures log snapshots.
#
# Usage:
#   ./Tools/wayland-smoke-test.sh [options]
#
# Options:
#   -c PATH   Path to ambrosia-compositor binary (auto-detected if omitted)
#   -o DIR    Directory to write snapshot logs (default: /tmp/wayland-smoke-YYYYMMDD-HHMMSS)
#   -t SECS   Per-test timeout in seconds (default: 10)
#   -v        Verbose: show compositor log in real time
#   -h        Show this help
#
# Exit status: 0 if all smoke tests passed, 1 if any failed or setup failed.
#
# Debug categories enabled during the run (set via NSDebugCategories):
#   WaylandDnD, WaylandIME, WaylandPointer, WaylandScroll, WaylandOutput
#
# Requirements:
#   - A running Wayland session (WAYLAND_DISPLAY must be set or wayland-0 must
#     exist).  The compositor runs nested inside that session.
#   - ambrosia-compositor binary (see -c option or AMBROSIA_ROOT below).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
AMBROSIA_ROOT="/home/james/development/ambrosia-experimental"

COMPOSITOR_BIN=""
OUTPUT_DIR=""
TIMEOUT_SECS=10
VERBOSE=0
PASS=0
FAIL=0
COMPOSITOR_PID=""
CLIENT_WAYLAND_DISPLAY=""

# ── helpers ──────────────────────────────────────────────────────────────────

log()  { echo "[smoke] $*"; }
pass() { echo "[PASS] $*"; (( PASS++ )) || true; }
fail() { echo "[FAIL] $*"; (( FAIL++ )) || true; }

usage() {
    sed -n 's/^# //p' "$0" | head -35
    exit 0
}

# ── cleanup on exit ───────────────────────────────────────────────────────────

cleanup() {
    if [[ -n "${COMPOSITOR_PID}" ]] && kill -0 "${COMPOSITOR_PID}" 2>/dev/null; then
        log "stopping compositor (pid ${COMPOSITOR_PID}) …"
        kill -TERM "${COMPOSITOR_PID}" 2>/dev/null || true
        wait "${COMPOSITOR_PID}" 2>/dev/null || true
        log "compositor stopped"
    fi
}
trap cleanup EXIT

# ── argument parsing ──────────────────────────────────────────────────────────

while getopts "c:o:t:vh" opt; do
    case "${opt}" in
        c) COMPOSITOR_BIN="${OPTARG}" ;;
        o) OUTPUT_DIR="${OPTARG}" ;;
        t) TIMEOUT_SECS="${OPTARG}" ;;
        v) VERBOSE=1 ;;
        h) usage ;;
        *) echo "Unknown option -${OPTARG}" >&2; exit 1 ;;
    esac
done

# ── locate compositor ─────────────────────────────────────────────────────────

if [[ -z "${COMPOSITOR_BIN}" ]]; then
    for candidate in \
            "${AMBROSIA_ROOT}/Compositor/obj/ambrosia-compositor" \
            "${AMBROSIA_ROOT}/Compositor"/obj.*/ambrosia-compositor \
            "$(command -v ambrosia-compositor 2>/dev/null || true)"; do
        if [[ -x "${candidate}" ]]; then
            COMPOSITOR_BIN="${candidate}"
            break
        fi
    done
fi

if [[ -z "${COMPOSITOR_BIN}" || ! -x "${COMPOSITOR_BIN}" ]]; then
    echo "ERROR: cannot find ambrosia-compositor binary." >&2
    echo "       Build it in ${AMBROSIA_ROOT}/Compositor or pass -c <path>." >&2
    exit 1
fi
log "compositor: ${COMPOSITOR_BIN}"

# ── output directory ──────────────────────────────────────────────────────────

if [[ -z "${OUTPUT_DIR}" ]]; then
    OUTPUT_DIR="/tmp/wayland-smoke-$(date +%Y%m%d-%H%M%S)"
fi
mkdir -p "${OUTPUT_DIR}"
log "snapshots: ${OUTPUT_DIR}"

COMPOSITOR_LOG="${OUTPUT_DIR}/compositor.log"

# ── GNUstep environment ───────────────────────────────────────────────────────

if [[ -z "${GNUSTEP_MAKEFILES:-}" ]]; then
    for gnustep_sh in \
            /usr/share/GNUstep/Makefiles/GNUstep.sh \
            /usr/local/share/GNUstep/Makefiles/GNUstep.sh \
            /usr/GNUstep/System/Library/Makefiles/GNUstep.sh; do
        if [[ -f "${gnustep_sh}" ]]; then
            # shellcheck source=/dev/null
            source "${gnustep_sh}"
            break
        fi
    done
fi

# ── find the parent Wayland session ──────────────────────────────────────────
# wlr_backend_autocreate reads WAYLAND_DISPLAY to decide whether to create a
# nested-Wayland backend.  We must point it at the real running session so
# Ambrosia can render into it.

PARENT_DISPLAY="${WAYLAND_DISPLAY:-}"
if [[ -z "${PARENT_DISPLAY}" ]]; then
    # Try well-known sockets under XDG_RUNTIME_DIR
    XDG_RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    for sock in "${XDG_RT}/wayland-0" "${XDG_RT}/wayland-1"; do
        if [[ -S "${sock}" ]]; then
            PARENT_DISPLAY="$(basename "${sock}")"
            break
        fi
    done
fi

if [[ -z "${PARENT_DISPLAY}" ]]; then
    echo "ERROR: no running Wayland session found." >&2
    echo "       Set WAYLAND_DISPLAY or start a Wayland compositor first." >&2
    exit 1
fi
log "parent Wayland session: ${PARENT_DISPLAY}"

# ── start Ambrosia nested in the parent session ───────────────────────────────
# Pass WAYLAND_DISPLAY=<parent> so wlr_backend_autocreate picks the Wayland
# backend.  The compositor calls wl_display_add_socket_auto() to create its
# *own* socket (wayland-N) and logs:
#   "Ambrosia compositor running on WAYLAND_DISPLAY=wayland-N"
# We parse that line to discover the client socket.

log "starting compositor (nested in ${PARENT_DISPLAY}) …"

if [[ "${VERBOSE}" -eq 1 ]]; then
    WAYLAND_DISPLAY="${PARENT_DISPLAY}" "${COMPOSITOR_BIN}" 2>&1 \
        | tee "${COMPOSITOR_LOG}" &
    COMPOSITOR_PID=$!
else
    WAYLAND_DISPLAY="${PARENT_DISPLAY}" "${COMPOSITOR_BIN}" \
        >"${COMPOSITOR_LOG}" 2>&1 &
    COMPOSITOR_PID=$!
fi

# ── wait for the compositor's own socket to be announced ─────────────────────

log "waiting for compositor socket …"
WAIT_MAX=30   # 30 × 0.5 s = 15 s
for (( i=0; i<WAIT_MAX; i++ )); do
    if ! kill -0 "${COMPOSITOR_PID}" 2>/dev/null; then
        log "compositor exited before announcing socket (see ${COMPOSITOR_LOG})"
        tail -5 "${COMPOSITOR_LOG}" | sed 's/^/  /' >&2
        break
    fi

    # Parse the socket name from the compositor log
    CLIENT_WAYLAND_DISPLAY="$(
        grep -m1 'running on WAYLAND_DISPLAY=' "${COMPOSITOR_LOG}" 2>/dev/null \
        | sed 's/.*WAYLAND_DISPLAY=\([^ ]*\).*/\1/'
    )"

    if [[ -n "${CLIENT_WAYLAND_DISPLAY}" ]]; then
        XDG_RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
        if [[ -S "${XDG_RT}/${CLIENT_WAYLAND_DISPLAY}" ]]; then
            log "compositor ready on ${CLIENT_WAYLAND_DISPLAY} (pid ${COMPOSITOR_PID})"
            break
        fi
    fi
    sleep 0.5
done

if [[ -z "${CLIENT_WAYLAND_DISPLAY}" ]]; then
    log "WARNING: could not determine compositor socket — runtime tests will be skipped"
else
    # Export so subsequent client tools connect to the right compositor
    export WAYLAND_DISPLAY="${CLIENT_WAYLAND_DISPLAY}"
fi

# ── helper: run a single smoke probe ─────────────────────────────────────────

run_probe() {
    local name="$1"; shift
    local logfile="$1"; shift

    if timeout "${TIMEOUT_SECS}" "$@" >"${logfile}" 2>&1; then
        pass "${name}"
    else
        local status=$?
        if [[ ${status} -eq 124 ]]; then
            fail "${name} (timeout after ${TIMEOUT_SECS}s)"
        else
            fail "${name} (exit ${status})"
        fi
    fi
}

check_log_contains() {
    local name="$1" logfile="$2" pattern="$3"
    if grep -qE "${pattern}" "${logfile}" 2>/dev/null; then
        pass "${name}: found '${pattern}'"
    else
        fail "${name}: '${pattern}' not found in ${logfile}"
    fi
}

check_log_absent() {
    local name="$1" logfile="$2" pattern="$3"
    if grep -qE "${pattern}" "${logfile}" 2>/dev/null; then
        fail "${name}: unexpected '${pattern}' found in ${logfile}"
    else
        pass "${name}: '${pattern}' absent (expected)"
    fi
}

# ── SMOKE TESTS ───────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════"
echo " Wayland backend smoke tests (Milestone 0)"
echo " Compositor:  ${COMPOSITOR_BIN}"
echo " Parent:      ${PARENT_DISPLAY}"
echo " Client sock: ${CLIENT_WAYLAND_DISPLAY:-unknown}"
echo "═══════════════════════════════════════════════"
echo ""

# ── T1: compositor process is running ────────────────────────────────────────

if kill -0 "${COMPOSITOR_PID}" 2>/dev/null; then
    pass "T1: compositor process running (pid ${COMPOSITOR_PID})"
else
    fail "T1: compositor process not running"
fi

# ── T2: compositor socket exists ─────────────────────────────────────────────

if [[ -n "${CLIENT_WAYLAND_DISPLAY}" ]]; then
    XDG_RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    SOCK_PATH="${XDG_RT}/${CLIENT_WAYLAND_DISPLAY}"
    if [[ -S "${SOCK_PATH}" ]]; then
        pass "T2: compositor socket exists: ${SOCK_PATH}"
    else
        fail "T2: compositor socket missing: ${SOCK_PATH}"
    fi
else
    fail "T2: compositor socket unknown (startup failed)"
fi

# ── T3: protocol globals via wayland-info ────────────────────────────────────

WL_INFO_LOG="${OUTPUT_DIR}/wayland-info.log"
if [[ -n "${CLIENT_WAYLAND_DISPLAY}" ]] && command -v wayland-info &>/dev/null; then
    run_probe "T3: wayland-info connect" "${WL_INFO_LOG}" wayland-info
    check_log_contains "T3: wl_compositor advertised" "${WL_INFO_LOG}" "wl_compositor"
    check_log_contains "T3: xdg_wm_base advertised"   "${WL_INFO_LOG}" "xdg_wm_base"
    check_log_contains "T3: wl_seat advertised"        "${WL_INFO_LOG}" "wl_seat"
else
    log "T3: skipped (no compositor socket or wayland-info not installed)"
fi

# ── T4: capture globals snapshot ─────────────────────────────────────────────

if [[ -n "${CLIENT_WAYLAND_DISPLAY}" ]] && command -v wayland-info &>/dev/null; then
    GLOBALS_SNAPSHOT="${OUTPUT_DIR}/globals-snapshot.txt"
    wayland-info >"${GLOBALS_SNAPSHOT}" 2>&1 || true
    log "T4: globals snapshot → ${GLOBALS_SNAPSHOT}"
    pass "T4: globals snapshot captured"
else
    log "T4: globals snapshot skipped"
fi

# ── T5: backend library loads ────────────────────────────────────────────────

BACK_LIB=""
for lib_candidate in \
        "${REPO_ROOT}/obj/libgnustep-back.so" \
        /usr/lib/GNUstep/Libraries/libgnustep-back.so \
        /usr/local/lib/GNUstep/Libraries/libgnustep-back.so; do
    if [[ -f "${lib_candidate}" ]]; then
        BACK_LIB="${lib_candidate}"
        break
    fi
done

BACK_LIB_LOG="${OUTPUT_DIR}/backend-lib.log"
if [[ -n "${BACK_LIB}" ]]; then
    if python3 -c "import ctypes; ctypes.CDLL('${BACK_LIB}')" \
            >"${BACK_LIB_LOG}" 2>&1; then
        pass "T5: backend library loads: ${BACK_LIB}"
    else
        fail "T5: backend library failed to load: ${BACK_LIB}"
    fi
else
    log "T5: gnustep-back library not found — skipping dlopen check"
fi

# ── T6: compositor log contains startup markers ───────────────────────────────

check_log_contains "T6: compositor initialised" \
    "${COMPOSITOR_LOG}" "Ambrosia: initialising compositor"
check_log_contains "T6: backend created" \
    "${COMPOSITOR_LOG}" "Backend created|Creating wayland backend"
check_log_contains "T6: compositor announced socket" \
    "${COMPOSITOR_LOG}" "running on WAYLAND_DISPLAY="

# ── T7: DnD stub snapshot ────────────────────────────────────────────────────

DND_SOURCE="${REPO_ROOT}/Source/wayland/WaylandDragView.m"
DND_LOG="${OUTPUT_DIR}/dnd-snapshot.txt"
{
    echo "=== DnD debug-category static check ==="
    grep -n "WaylandDnD" "${DND_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== DnD stubs present ==="
    grep -n "not yet\|not implemented\|wl_data_device" "${DND_SOURCE}" 2>/dev/null || true
} >"${DND_LOG}"
check_log_contains "T7: WaylandDnD category in source"   "${DND_LOG}" "WaylandDnD"
check_log_contains "T7: inter-process DnD stub present"  "${DND_LOG}" "wl_data_device"

# ── T8: IME stub snapshot ─────────────────────────────────────────────────────

IME_SOURCE="${REPO_ROOT}/Source/wayland/WaylandInputServer.m"
IME_LOG="${OUTPUT_DIR}/ime-snapshot.txt"
{
    echo "=== IME debug-category static check ==="
    grep -n "WaylandIME" "${IME_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== IME stubs (statusArea/preeditArea return NO) ==="
    grep -n "statusArea\|preeditArea\|preeditSpot" "${IME_SOURCE}" 2>/dev/null || true
} >"${IME_LOG}"
check_log_contains "T8: WaylandIME category in source" "${IME_LOG}" "WaylandIME"
check_log_contains "T8: statusArea stub present"       "${IME_LOG}" "statusArea"

# ── T9: pointer/scroll stub snapshot ─────────────────────────────────────────

CURSOR_SOURCE="${REPO_ROOT}/Source/wayland/WaylandServer+Cursor.m"
PTR_LOG="${OUTPUT_DIR}/pointer-snapshot.txt"
{
    echo "=== WaylandPointer debug-category static check ==="
    grep -n "WaylandPointer" "${CURSOR_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== WaylandScroll debug-category static check ==="
    grep -n "WaylandScroll" "${CURSOR_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== Extra button TODO milestone marker ==="
    grep -n "Milestone 3\|BTN_SIDE\|BTN_EXTRA\|BTN_FORWARD\|BTN_BACK" "${CURSOR_SOURCE}" 2>/dev/null || true
} >"${PTR_LOG}"
check_log_contains "T9: WaylandPointer category in source" "${PTR_LOG}" "WaylandPointer"
check_log_contains "T9: WaylandScroll category in source"  "${PTR_LOG}" "WaylandScroll"
check_log_contains "T9: extra-button Milestone 3 marker"   "${PTR_LOG}" "Milestone 3"

# ── T10: output stub snapshot ─────────────────────────────────────────────────

OUTPUT_SOURCE="${REPO_ROOT}/Source/wayland/WaylandServer+Output.m"
OUT_LOG="${OUTPUT_DIR}/output-snapshot.txt"
{
    echo "=== WaylandOutput debug-category static check ==="
    grep -n "WaylandOutput" "${OUTPUT_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== Output configure TODO ==="
    grep -n "TODO\|configure_handler\|XXX" "${OUTPUT_SOURCE}" 2>/dev/null || true
} >"${OUT_LOG}"
check_log_contains "T10: WaylandOutput category in source" "${OUT_LOG}" "WaylandOutput"

# ── T11: compositor log sanity ────────────────────────────────────────────────

check_log_absent "T11: no crash/abort in compositor log" \
    "${COMPOSITOR_LOG}" "Segmentation fault|Aborted|SIGSEGV|double free"

# ── summary ───────────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════"
echo " Results: ${PASS} passed, ${FAIL} failed"
echo " Snapshots in: ${OUTPUT_DIR}"
echo "═══════════════════════════════════════════════"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
exit 0
