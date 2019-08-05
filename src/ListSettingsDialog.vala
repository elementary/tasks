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

public class Tasks.ListSettingsDialog : Gtk.Dialog {
    public E.Source source { get; construct; }

    public ListSettingsDialog (E.Source source) {
        Object (source: source);
    }

    construct {
        var name_label = new Gtk.Label (_("Name:"));
        name_label.halign = Gtk.Align.END;

        var name_entry = new Gtk.Entry ();
        name_entry.activates_default = true;
        name_entry.text = source.dup_display_name ();
        name_entry.sensitive = source.writable;

        var grid = new Gtk.Grid ();
        grid.column_spacing = 12;
        grid.margin_start = grid.margin_end = 6;
        grid.margin_bottom = 18;
        grid.add (name_label);
        grid.add (name_entry);

        get_content_area ().add (grid);

        border_width = 6;
        deletable = false;
        modal = true;
        resizable = false;
        transient_for = ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();

        var close_button = add_button (_("Close"), Gtk.ResponseType.CLOSE);
        close_button.has_default = true;

        response.connect (() => {
            source.display_name = name_entry.text;
            try {
                source.write.begin (null);
            } catch (Error e) {
                critical (e.message);
            }
            destroy ();
        });
    }
}
