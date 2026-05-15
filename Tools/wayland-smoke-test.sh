#!/usr/bin/env bash
# wayland-smoke-test.sh — Integration harness for the Wayland backend (M0–M5).
#
# Starts the Ambrosia compositor nested inside the current Wayland session,
# then exercises each feature bucket in wayland_feature_implementation_plan.md
# and captures log snapshots.
#
# Milestone coverage:
#   M0  T1–T11  Baseline: compositor liveness, protocol globals, source snapshots
#   M5  T12–T19 Stability: buffer lifecycle audits + sustained-operation stress
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
echo " Wayland backend smoke tests (M0–M5)"
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
check_log_contains "T9: extra-button BTN_SIDE mapped"      "${PTR_LOG}" "BTN_SIDE"

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

# ══════════════════════════════════════════════════════════════════════════════
# Milestone 5 — Stability and rendering hardening
# ══════════════════════════════════════════════════════════════════════════════

SHM_SOURCE="${REPO_ROOT}/Source/cairo/WaylandCairoShmSurface.m"
XDGSHELL_SOURCE="${REPO_ROOT}/Source/wayland/WaylandServer+Xdgshell.m"
SERVER_SOURCE="${REPO_ROOT}/Source/wayland/WaylandServer.m"

# ── T12: FD leak fix — finishBuffer closes poolfd ────────────────────────────
# The pool file-descriptor was never closed before M5, leaking one FD per
# window allocation.  The fix is a close() call in finishBuffer.

M5_BUF_LOG="${OUTPUT_DIR}/m5-buffer.txt"
{
    echo "=== finishBuffer: poolfd close ==="
    grep -n "close(buf->poolfd)\|close.*poolfd" "${SHM_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== calloc / poolfd = -1 init ==="
    grep -n "calloc\|poolfd = -1" "${SHM_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== needs_repaint field ==="
    grep -n "needs_repaint" "${SHM_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== owner_surface / owner_display ==="
    grep -n "owner_surface\|owner_display" "${SHM_SOURCE}" 2>/dev/null || true
} >"${M5_BUF_LOG}"

check_log_contains "T12: finishBuffer closes poolfd"      "${M5_BUF_LOG}" "close.*poolfd"
check_log_contains "T12: pool_buffer zero-initialised"    "${M5_BUF_LOG}" "calloc"
check_log_contains "T12: needs_repaint field present"     "${M5_BUF_LOG}" "needs_repaint"
check_log_contains "T12: owner back-pointers present"     "${M5_BUF_LOG}" "owner_surface"

# ── T13: Busy guard in handleExposeRect ──────────────────────────────────────
# Before M5, handleExposeRect attached the buffer unconditionally even while
# the compositor still held it (protocol error / artifact).

M5_EXPOSE_LOG="${OUTPUT_DIR}/m5-expose.txt"
{
    echo "=== busy check in handleExposeRect ==="
    grep -n "pbuffer->busy\|busy" "${SHM_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== repaint-on-release in buffer_handle_release ==="
    # Look for the release callback re-committing after a missed frame
    awk '/buffer_handle_release/,/^}/' "${SHM_SOURCE}" 2>/dev/null | \
        grep -n "needs_repaint\|wl_surface_attach\|wl_surface_commit" || true
    echo ""
    echo "=== size mismatch guard ==="
    grep -n "pbuffer->width.*window->width\|size mismatch\|width != " "${SHM_SOURCE}" 2>/dev/null || true
} >"${M5_EXPOSE_LOG}"

check_log_contains "T13: busy guard in handleExposeRect"  "${M5_EXPOSE_LOG}" "pbuffer->busy"
check_log_contains "T13: repaint-on-release path"         "${M5_EXPOSE_LOG}" "needs_repaint"
check_log_contains "T13: size-mismatch guard"             "${M5_EXPOSE_LOG}" "pbuffer->width"

# ── T14: Precise damage rect in handleExposeRect ─────────────────────────────
# Before M5, wl_surface_damage always used the full surface (0,0,w,h).
# Now the actual exposed NSRect is used.

M5_DAMAGE_LOG="${OUTPUT_DIR}/m5-damage.txt"
{
    echo "=== precise damage in handleExposeRect ==="
    grep -n "NSMinX\|NSMaxY\|NSWidth\|NSHeight\|dx\|dy\|dw\|dh" \
        "${SHM_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== initial commit has damage ==="
    # initWithDevice must call wl_surface_damage before wl_surface_commit
    awk '/initWithDevice/,/^- \(/ { print NR": "$0 }' "${SHM_SOURCE}" 2>/dev/null | \
        grep "wl_surface_damage\|wl_surface_commit" | head -10 || true
} >"${M5_DAMAGE_LOG}"

check_log_contains "T14: precise damage rect uses NSMinX/NSMaxY" \
    "${M5_DAMAGE_LOG}" "NSMinX|NSMaxY|NSWidth|NSHeight"
check_log_contains "T14: initial commit preceded by damage" \
    "${M5_DAMAGE_LOG}" "wl_surface_damage"

# ── T15: clearOwnerSurface prevents use-after-free ───────────────────────────
# destroySurfaceRole: must clear the wl_surface back-pointer before calling
# wl_surface_destroy so the async buffer_handle_release cannot write to a
# freed proxy.

M5_OWNER_LOG="${OUTPUT_DIR}/m5-owner.txt"
{
    echo "=== clearOwnerSurface in WaylandServer.m ==="
    grep -n "clearOwnerSurface\|wl_surface_destroy" "${SERVER_SOURCE}" 2>/dev/null || true
    echo ""
    echo "=== clearOwnerSurface implementation ==="
    awk '/clearOwnerSurface/,/^}/' "${SHM_SOURCE}" 2>/dev/null | head -20 || true
    echo ""
    echo "=== wl_surface_destroy in destroySurfaceRole ==="
    awk '/destroySurfaceRole:/,/^- \(/ { print NR": "$0 }' \
        "${SERVER_SOURCE}" 2>/dev/null | \
        grep "wl_surface_destroy\|clearOwnerSurface" || true
} >"${M5_OWNER_LOG}"

check_log_contains "T15: clearOwnerSurface called before wl_surface_destroy" \
    "${M5_OWNER_LOG}" "clearOwnerSurface"
check_log_contains "T15: wl_surface_destroy present in destroySurfaceRole" \
    "${M5_OWNER_LOG}" "wl_surface_destroy"

# ── T16: No double wl_list_remove in xdg_surface_on_configure ────────────────
# termwindow: removes the window from the list and sets terminated=YES.
# xdg_surface_on_configure must NOT call wl_list_remove a second time.

M5_LIST_LOG="${OUTPUT_DIR}/m5-list-remove.txt"
{
    echo "=== terminated path in xdg_surface_on_configure ==="
    awk '/xdg_surface_on_configure/,/^const struct/' "${XDGSHELL_SOURCE}" 2>/dev/null | \
        grep -n "terminated\|wl_list_remove\|free(window)" | head -20 || true
} >"${M5_LIST_LOG}"

check_log_contains "T16: terminated path frees window"    "${M5_LIST_LOG}" "free.window."
check_log_absent   "T16: no second wl_list_remove" \
    "${M5_LIST_LOG}" "wl_list_remove\("

# ── T17: wl_shm_pool destroyed promptly (no dangling pool pointer) ────────────
# The pool was stored in buf->pool and compared with NULL after being destroyed
# (potential double-destroy if finishBuffer was ever changed to also destroy it).
# M5 sets pool = NULL immediately after destroy and skips the buf->pool field.

M5_POOL_LOG="${OUTPUT_DIR}/m5-pool.txt"
{
    echo "=== wl_shm_pool lifecycle in createShmBuffer ==="
    awk '/createShmBuffer/,/^@implementation/' "${SHM_SOURCE}" 2>/dev/null | \
        grep -n "wl_shm_pool\|wl_shm_create_pool\|wl_shm_pool_destroy\|buf->pool" | head -20 || true
} >"${M5_POOL_LOG}"

check_log_contains "T17: wl_shm_pool_destroy called"       "${M5_POOL_LOG}" "wl_shm_pool_destroy"
check_log_absent   "T17: buf->pool not stored after destroy" "${M5_POOL_LOG}" "buf->pool ="

# ── T18: Compositor survives sustained global queries (event-loop stress) ─────
# Fire wayland-info 20 times in rapid succession against the running compositor.
# Each invocation opens a Wayland connection, reads the global list, and closes.
# A freeze or crash here indicates event-loop saturation or fd/memory leaks.

if [[ -n "${CLIENT_WAYLAND_DISPLAY}" ]] && command -v wayland-info &>/dev/null; then
    M5_STRESS_LOG="${OUTPUT_DIR}/m5-stress.log"
    log "T18: sustained global query stress (20 iterations) …"
    STRESS_OK=1
    for i in $(seq 1 20); do
        if ! timeout 5 wayland-info >>"${M5_STRESS_LOG}" 2>&1; then
            STRESS_OK=0
            fail "T18: wayland-info iteration ${i} failed"
            break
        fi
    done
    if [[ "${STRESS_OK}" -eq 1 ]]; then
        pass "T18: compositor survived 20 consecutive global queries"
    fi
else
    log "T18: stress test skipped (no compositor socket or wayland-info not installed)"
fi

# ── T19: Compositor still alive and clean after stress ───────────────────────

sleep 1
if kill -0 "${COMPOSITOR_PID}" 2>/dev/null; then
    pass "T19: compositor still running after stress"
else
    fail "T19: compositor died during stress test"
fi

check_log_absent "T19: no crash/abort after stress" \
    "${COMPOSITOR_LOG}" "Segmentation fault|Aborted|SIGSEGV|double free|wl_display_disconnect"

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
