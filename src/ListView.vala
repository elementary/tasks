/*
* Copyright 2019 elementary, Inc. (https://elementary.io)
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

public class Reminders.ListView : Gtk.Grid {
    public E.Source? source { get; set; }

    private ulong? source_handler;
    private Gtk.Label label;

    construct {
        label = new Gtk.Label ("");

        unowned Gtk.StyleContext label_style_context = label.get_style_context ();
        label_style_context.add_class (Granite.STYLE_CLASS_H1_LABEL);
        label_style_context.add_class (Granite.STYLE_CLASS_ACCENT);

        add (label);

        notify["source"].connect (() => {
            if (source_handler != null) {
                source_handler = null;
            }
            update_source ();

            source_handler = source.changed.connect (() => update_source);

            show_all ();
        });
    }

    private void update_source () {
        label.label = source.display_name;
        Reminders.Application.set_task_color (source, label);
    }
}
