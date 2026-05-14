# Wayland Backend Feature Implementation Plan (vs X11 parity)

## Scope
This plan turns the identified feature gaps into an execution roadmap, ordered by user impact and architectural dependencies.

## Milestone 0: Baseline and instrumentation (1 week)

### Goals
- Make regressions visible before feature work starts.

### Tasks
1. Add targeted debug categories for Wayland DnD, IME, pointer buttons, scroll axes, output changes.
2. Add an integration harness script to run basic backend smoke tests under a Wayland compositor (Weston/headless where possible).
3. Capture current behavior snapshots for:
   - local drag/drop
   - external drag/drop
   - IME composition
   - extra mouse buttons
   - touchpad/continuous scroll
   - output hotplug/scale/geometry change

### Exit criteria
- Repro steps and logs are documented for every missing feature bucket.

---

## Milestone 1: Inter-process DnD on Wayland (`wl_data_device`) (2–3 weeks)

### Why first
External DnD is a major UX gap and is already explicitly stubbed in `WaylandDragView`.

### Tasks
1. **Protocol plumbing**
   - Add `wl_data_device_manager`, `wl_data_device`, `wl_data_source`, `wl_data_offer` objects to `WaylandConfig` lifecycle.
   - Bind globals in registry handler, add listeners, and teardown safely.
2. **Outbound drag path**
   - Implement source offers for pasteboard MIME types.
   - Wire drag enter/motion/leave/drop events to existing `GSDragView`/AppKit event flow.
3. **Inbound drag path**
   - Accept offers, map MIME types to pasteboard types, handle selection reads over FDs.
4. **Action negotiation**
   - Map Wayland dnd actions (`copy/move/ask`) to `NSDragOperation` consistently with X11 behavior.
5. **Error handling**
   - Handle canceled drags, destroyed offers, and compositor-denied serials.

### Files primarily touched
- `Source/wayland/WaylandDragView.m`
- `Source/wayland/WaylandServer.m` (registry/globals)
- `Headers/wayland/WaylandServer.h` (config structs)

### Exit criteria
- Drag from GNUstep app to external app and vice versa works for text and URI list payloads.
- `postDragEvent` and `sendExternalEvent` no longer log “not implemented” for inter-process cases.

---

## Milestone 2: IME/preedit/status support parity path (2 weeks)

### Goals
Bring Wayland input method behavior closer to X11 XIM-visible capabilities used by AppKit text input flows.

### Tasks
1. Introduce Wayland text-input integration strategy:
   - Prefer `text-input-v3` (or compositor-supported equivalent) and optional input-method protocols.
2. Implement input method state in `WaylandInputServer`:
   - Preedit string lifecycle
   - Cursor/spot location updates
   - Status/preedit rectangles and setters
3. Feed composed text and commit/cancel events into existing key/text dispatch pipeline.
4. Keep fallback behavior when compositor lacks protocol support.

### Files primarily touched
- `Source/wayland/WaylandInputServer.m`
- `Source/wayland/WaylandServer+Keyboard.m`
- `Headers/wayland/WaylandInputServer.h`

### Exit criteria
- `statusArea/preeditArea/preeditSpot` and setters return meaningful values when protocol is available.
- Basic composition (e.g., dead keys/CJK IME) works in NSText-based controls.

---

## Milestone 3: Pointer button completeness + wheel/scroll semantics (1–2 weeks)

### Goals
Close input parity gaps affecting advanced mice and touchpads.

### Tasks
1. Map BTN_SIDE/BTN_EXTRA/BTN_FORWARD/BTN_BACK to appropriate `NSOtherMouse*` events and button numbers.
2. Implement `pointer_handle_axis_discrete`, `pointer_handle_frame`, and `pointer_handle_axis_stop`:
   - group axis events per frame
   - include discrete step data when available
   - emit momentum/phase semantics where AppKit expects them
3. Normalize button mapping/documentation versus X11 `XGetPointerMapping` assumptions.

### Files primarily touched
- `Source/wayland/WaylandServer+Cursor.m`

### Exit criteria
- Side buttons generate usable app events.
- Touchpad and wheel scrolling feel consistent and no longer rely on TODO placeholders.

---

## Milestone 4: Output change handling and monitor reconfiguration (1–2 weeks)

### Goals
Implement dynamic monitor behavior expected from mature backend operation.

### Tasks
1. Implement output configure callback path currently marked TODO.
2. Add runtime reactions for:
   - output add/remove
   - geometry/scale changes
   - window reposition/reclamp on output change
3. Audit coordinate transforms across output scale and transform states.

### Files primarily touched
- `Source/wayland/WaylandServer+Output.m`
- `Source/wayland/WaylandServer.m`
- `Headers/wayland/WaylandServer.h`

### Exit criteria
- Windows remain usable after output change events (hotplug, scale change).
- Screen geometry reported to AppKit updates correctly.

---

## Milestone 5: Stability and rendering hardening (ongoing, parallel)

### Goals
Address known “incomplete/broken” operational issues and reduce compositor hangs/freeze conditions.

### Tasks
1. Audit buffer lifecycle (attach/damage/commit/release ordering).
2. Add synchronization guards around surface destruction and resize churn.
3. Validate Cairo surface blit ordering to avoid stray backing-surface visibility.
4. Stress-test event loop responsiveness under frequent input and redraw.

### Exit criteria
- No reproducible freeze in sustained interaction test.
- No random backing-surface artifacts in compositor during normal usage.

---

## Cross-cutting requirements

1. **Feature flags**
   - Gate new protocol-dependent behavior by runtime detection and defaults.
2. **Compatibility matrix**
   - Track compositor support (Weston, Mutter, KWin, wlroots-based).
3. **Testing**
   - Add automated tests where feasible; otherwise scripted manual test playbooks.
4. **Documentation**
   - Update `Source/wayland/README.md` milestone-by-milestone with current status.

## Suggested delivery order
1. Milestone 0 baseline
2. Milestone 1 external DnD
3. Milestone 3 pointer/scroll completeness
4. Milestone 2 IME support
5. Milestone 4 output reconfiguration
6. Milestone 5 hardening (continuous)

## Effort estimate summary
- M0: 1 week
- M1: 2–3 weeks
- M2: 2 weeks
- M3: 1–2 weeks
- M4: 1–2 weeks
- M5: ongoing

Total for first parity wave (M0–M4): ~7–10 weeks for one experienced contributor, faster with parallel owners.
