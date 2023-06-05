/*
* Copyright 2023 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/

class Tasks.Widgets.PopoverButton : Gtk.Box {
    public signal void clicked ();

    construct {
        orientation = Gtk.Orientation.HORIZONTAL;
        spacing = 0;
        css_classes = { Granite.STYLE_CLASS_MENUITEM };

        var gesture_click = new Gtk.GestureClick ();
        add_controller (gesture_click);

        gesture_click.released.connect (() => clicked ());
    }
}