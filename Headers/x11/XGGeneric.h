/* Generic header info common to X backends for GNUstep

   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: Mar 2000
   
   This file is part of the GNUstep project

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */

#ifndef	INCLUDED_XGGENERIC_H
#define	INCLUDED_XGGENERIC_H

/*
 * Flags to indicate which protocols the WindowManager follows
 */
typedef	enum {
  XGWM_UNKNOWN = 0,
  XGWM_WINDOWMAKER = 1,
  XGWM_GNOME = 2,
  XGWM_KDE = 4,
  XGWM_EWMH = 8
} XGWMProtocols;

typedef struct {
  Atom win_type_atom;
  Atom win_desktop_atom;
  Atom win_normal_atom;
  Atom win_floating_atom;
  Atom win_menu_atom;
  Atom win_dock_atom;
  Atom win_modal_atom;
} XGWMWinTypes;

/*
 * Structure containing ivars that are common to all X backend contexts.
 */
struct XGGeneric {
  int   		wm;
  struct {
    unsigned	useWindowMakerIcons:1;
    unsigned    appOwnsMiniwindow:1;
    unsigned    doubleParentWindow:1;
  } flags;
  Time			lastTime;
  Time			lastClick;
  Window		lastClickWindow;
  int			lastClickX;
  int			lastClickY;
  Time			lastMotion;
  Atom			protocols_atom;
  Atom			delete_win_atom;
  Atom			take_focus_atom;
  Atom			miniaturize_atom;
  Atom			win_decor_atom;
  Atom			titlebar_state_atom;
  char			*rootName;
  long			currentFocusWindow;
  long			desiredFocusWindow;
  long			focusRequestNumber;
  unsigned char		lMouse;
  unsigned char		mMouse;
  unsigned char		rMouse;
  unsigned char		upMouse;
  unsigned char		downMouse;
  int			lMouseMask;
  int			mMouseMask;
  int			rMouseMask;
  Window		appRootWindow;
  void			*cachedWindow;	// last gswindow_device_t used.
  XPoint                parent_offset;  // WM defined parent info
  XGWMWinTypes          wintypes;
};

/* GNOME Window layers */
#define WIN_LAYER_DESKTOP                0
#define WIN_LAYER_BELOW                  2
#define WIN_LAYER_NORMAL                 4
#define WIN_LAYER_ONTOP                  6
#define WIN_LAYER_DOCK                   8
#define WIN_LAYER_ABOVE_DOCK             10
#define WIN_LAYER_MENU                   12

#endif

