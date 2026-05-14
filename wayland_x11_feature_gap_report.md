# Wayland vs X11 backend feature-gap report

This report lists features available in the X11 backend that are currently missing or only stubbed/partial in the Wayland backend.

## 1) Inter-process drag-and-drop (external DnD) is missing on Wayland

- Wayland explicitly says inter-process drag via `wl_data_device` is not implemented and only logs for external events.
- X11 implements external DnD message flow (`XdndStatus`, `XdndFinished`, `XdndEnter`, `XdndPosition`, `XdndDrop`, `XdndLeave`) via `xdnd_*` calls.

Evidence:
- Wayland: `Source/wayland/WaylandDragView.m` (`postDragEvent`, `sendExternalEvent`).
- X11: `Source/x11/XGDragView.m` (`postDragEvent`, `sendExternalEvent`).

## 2) Input method (IME/XIM-style preedit/status positioning) support is missing on Wayland

- Wayland input method style returns `nil` and all preedit/status geometry accessors return `NO`.
- X11 has a dedicated XIM input server with style negotiation and IC lifecycle management.

Evidence:
- Wayland: `Source/wayland/WaylandInputServer.m` (`inputMethodStyle`, `statusArea`, `preeditArea`, `preeditSpot`, `setStatusArea`, `setPreeditArea`, `setPreeditSpot`).
- X11: `Source/x11/XIMInputServer.m` (`ximInit`, `ximStyleInit`, `ximCreateIC` flow).

## 3) Extended mouse button mapping is incomplete on Wayland

- Wayland currently maps left/right/middle only and leaves BTN_SIDE/BTN_EXTRA/BTN_FORWARD/BTN_BACK as TODO.
- X11 backend has explicit pointer-mapping commentary/handling path and broader mature event translation.

Evidence:
- Wayland: `Source/wayland/WaylandServer+Cursor.m` TODO in button switch.
- X11 reference behavior mentioned in same file comments and implemented in mature X11 event code.

## 4) Advanced scroll semantics are partial on Wayland

- Wayland pointer callbacks for `frame`, `axis_stop`, and `axis_discrete` are currently empty.
- Comments note missing momentum/trackpad behavior.

Evidence:
- Wayland: `Source/wayland/WaylandServer+Cursor.m` (`pointer_handle_frame`, `pointer_handle_axis_stop`, `pointer_handle_axis_discrete`, momentum TODO comments).

## 5) Output reconfiguration callback path is unimplemented on Wayland

- Wayland output mode handler includes explicit “Should we implement this?” for output configure callback behavior.
- X11 has established monitor/screen management infrastructure (monitor list + RANDR-related members in server).

Evidence:
- Wayland: `Source/wayland/WaylandServer+Output.m` (`handle_mode` TODO block).
- X11: `Headers/x11/XGServer.h` monitor/randr fields.

## 6) Overall backend completeness/stability is explicitly below X11

- Wayland backend README still declares it "incomplete and broken" and lists unresolved rendering/freezing issues.
- X11 backend is long-standing and feature-complete enough to include broad subsystems (XIM, XDND, RANDR integration points, GLX path, etc.).

Evidence:
- Wayland: `Source/wayland/README.md`.
- X11: breadth of subsystem files in `Source/x11/` and `Headers/x11/`.
