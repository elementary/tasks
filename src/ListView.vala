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

        var settings_button = new Gtk.ToggleButton ();
        settings_button.valign = Gtk.Align.CENTER;
        settings_button.add (new Gtk.Image.from_icon_name ("view-more-horizontal-symbolic", Gtk.IconSize.MENU));
        settings_button.tooltip_text = _("Edit Name and Appearance");
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var list_settings_popover = new Tasks.ListSettingsPopover (settings_button);

        column_spacing = 12;
        margin = 24;
        margin_top = 0;
        add (label);
        add (settings_button);

        settings_button.toggled.connect (() => {
            if (settings_button.active) {
                list_settings_popover.source = source;
                list_settings_popover.show_all ();
            }
        });

        list_settings_popover.closed.connect (() => {
            settings_button.active = false;
        });

        notify["source"].connect (() => {
            if (source != null) {
                label.label = source.dup_display_name ();
                Tasks.Application.set_task_color (source, label);
            } else {
                label.label = "";
            }

            show_all ();
        });
    }
}
