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

        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/tasks/ColorButton.css");

        var color_label = new Gtk.Label (_("Color:"));
        color_label.xalign = 1;

        var color_button_red = new Gtk.RadioButton (null);

        unowned Gtk.StyleContext color_button_red_context = color_button_red.get_style_context ();
        color_button_red_context.add_class ("color-button");
        color_button_red_context.add_class ("red");
        color_button_red_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var color_button_orange = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_orange_context = color_button_orange.get_style_context ();
        color_button_orange_context.add_class ("color-button");
        color_button_orange_context.add_class ("orange");
        color_button_orange_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var color_button_yellow = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_yellow_context = color_button_yellow.get_style_context ();
        color_button_yellow_context.add_class ("color-button");
        color_button_yellow_context.add_class ("yellow");
        color_button_yellow_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var color_button_green = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_green_context = color_button_green.get_style_context ();
        color_button_green_context.add_class ("color-button");
        color_button_green_context.add_class ("green");
        color_button_green_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var color_button_blue = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_blue_context = color_button_blue.get_style_context ();
        color_button_blue_context.add_class ("color-button");
        color_button_blue_context.add_class ("blue");
        color_button_blue_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var color_button_purple = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_purple_context = color_button_purple.get_style_context ();
        color_button_purple_context.add_class ("color-button");
        color_button_purple_context.add_class ("purple");
        color_button_purple_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var color_button_brown = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_brown_context = color_button_brown.get_style_context ();
        color_button_brown_context.add_class ("color-button");
        color_button_brown_context.add_class ("brown");
        color_button_brown_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var color_button_slate = new Gtk.RadioButton.from_widget (color_button_red);

        unowned Gtk.StyleContext color_button_slate_context = color_button_slate.get_style_context ();
        color_button_slate_context.add_class ("color-button");
        color_button_slate_context.add_class ("slate");
        color_button_slate_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var color_button_none = new Gtk.RadioButton.from_widget (color_button_red);

        var task_list = ((E.SourceTaskList?) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST));
        switch (task_list.dup_color ()) {
            case "#da3d41":
                color_button_red.active = true;
                break;
            case "#f37329":
                color_button_orange.active = true;
                break;
            case "#e6a92a":
                color_button_yellow.active = true;
                break;
            case "#81c837":
                color_button_green.active = true;
                break;
            case "#3689e6":
                color_button_blue.active = true;
                break;
            case "#a56de2":
                color_button_purple.active = true;
                break;
            case "#8a715e":
                color_button_brown.active = true;
                break;
            case "#667885":
                color_button_slate.active = true;
                break;
            default:
                color_button_none.active = true;
                break;
        }

        var color_grid = new Gtk.Grid ();
        color_grid.column_spacing = 6;
        color_grid.add (color_button_red);
        color_grid.add (color_button_orange);
        color_grid.add (color_button_yellow);
        color_grid.add (color_button_green);
        color_grid.add (color_button_blue);
        color_grid.add (color_button_purple);
        color_grid.add (color_button_brown);
        color_grid.add (color_button_slate);

        var grid = new Gtk.Grid ();
        grid.column_spacing =  grid.row_spacing = 12;
        grid.margin_start = grid.margin_end = 6;
        grid.margin_bottom = 18;
        grid.attach (name_label, 0, 0);
        grid.attach (name_entry, 1, 0);
        grid.attach (color_label, 0, 1);
        grid.attach (color_grid, 1, 1);

        get_content_area ().add (grid);

        border_width = 6;
        deletable = false;
        modal = true;
        resizable = false;
        transient_for = ((Gtk.Application) GLib.Application.get_default ()).get_active_window ();

        var close_button = add_button (_("Close"), Gtk.ResponseType.CLOSE);
        close_button.has_default = true;

        color_button_red.toggled.connect (() => {
            task_list.color = "#da3d41";
        });

        color_button_orange.toggled.connect (() => {
            task_list.color = "#f37329";
        });

        color_button_yellow.toggled.connect (() => {
            task_list.color = "#e6a92a";
        });

        color_button_green.toggled.connect (() => {
            task_list.color = "#81c837";
        });

        color_button_blue.toggled.connect (() => {
            task_list.color = "#3689e6";
        });

        color_button_purple.toggled.connect (() => {
            task_list.color = "#a56de2";
        });

        color_button_brown.toggled.connect (() => {
            task_list.color = "#8a715e";
        });

        color_button_slate.toggled.connect (() => {
            task_list.color = "#667885";
        });

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
