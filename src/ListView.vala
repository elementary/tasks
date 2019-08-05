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

public class Tasks.ListView : Gtk.Grid {
    public E.Source? source { get; set; }

    construct {
        var label = new Gtk.Label ("");
        label.halign = Gtk.Align.START;
        label.hexpand = true;

        unowned Gtk.StyleContext label_style_context = label.get_style_context ();
        label_style_context.add_class (Granite.STYLE_CLASS_H1_LABEL);
        label_style_context.add_class (Granite.STYLE_CLASS_ACCENT);

        var settings_button = new Gtk.Button.from_icon_name ("view-more-horizontal-symbolic", Gtk.IconSize.MENU);
        settings_button.tooltip_text = _("Edit Name and Appearance");
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        column_spacing = 12;
        margin = 24;
        margin_top = 0;
        add (label);
        add (settings_button);

        settings_button.clicked.connect (() => {
            var name_entry = new Gtk.Entry ();
            name_entry.text = source.dup_display_name ();
            name_entry.sensitive = source.writable;

            var settings_dialog = new Gtk.Dialog ();
            settings_dialog.modal = true;
            settings_dialog.transient_for = ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();

            settings_dialog.get_content_area ().add (name_entry);

            settings_dialog.show_all ();

            settings_dialog.response.connect (() => {
                source.display_name = name_entry.text;
                try {
                    source.write (null);
                } catch (Error e) {
                    critical (e.message);
                }
            });
        });

        notify["source"].connect (() => {
            label.label = source.dup_display_name ();
            Tasks.Application.set_task_color (source, label);

            show_all ();
        });
    }
}
