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

public class Tasks.ListSettingsPopover : Gtk.Popover {
    public E.Source source { get; set; }

    private E.SourceTaskList task_list;

    construct {
        var css_provider = new Gtk.CssProvider ();
        css_provider.load_from_resource ("/io/elementary/tasks/ColorButton.css");

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

        var color_grid = new Gtk.Grid ();
        color_grid.column_spacing = 6;
        color_grid.margin = 12;
        color_grid.add (color_button_red);
        color_grid.add (color_button_orange);
        color_grid.add (color_button_yellow);
        color_grid.add (color_button_green);
        color_grid.add (color_button_blue);
        color_grid.add (color_button_purple);
        color_grid.add (color_button_brown);
        color_grid.add (color_button_slate);

        var show_completed_label = new Gtk.Label (_("Show Completed"));
        show_completed_label.hexpand = true;
        show_completed_label.xalign = 0;

        var show_completed_switch = new Gtk.Switch ();

        var show_completed_grid = new Gtk.Grid ();
        show_completed_grid.column_spacing = 6;
        show_completed_grid.add (show_completed_label);
        show_completed_grid.add (show_completed_switch);

        var show_completed_button = new Gtk.ModelButton ();
        show_completed_button.margin_top = 3;
        show_completed_button.get_child ().destroy ();
        show_completed_button.add (show_completed_grid);

        var delete_button = new Gtk.ModelButton ();
        delete_button.action_name = MainWindow.ACTION_PREFIX + MainWindow.ACTION_DELETE_SELECTED_LIST;
        delete_button.text = _("Delete List");
        delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.margin_top = grid.margin_bottom = 3;
        grid.add (color_grid);
        grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.add (show_completed_button);
        grid.add (delete_button);
        grid.show_all ();

        add (grid);

        color_button_red.toggled.connect (() => {
            task_list.color = "#c6262e";
            source.write.begin (null);
        });

        color_button_orange.toggled.connect (() => {
            task_list.color = "#f37329";
            source.write.begin (null);
        });

        color_button_yellow.toggled.connect (() => {
            task_list.color = "#e6a92a";
            source.write.begin (null);
        });

        color_button_green.toggled.connect (() => {
            task_list.color = "#68b723";
            source.write.begin (null);
        });

        color_button_blue.toggled.connect (() => {
            task_list.color = "#3689e6";
            source.write.begin (null);
        });

        color_button_purple.toggled.connect (() => {
            task_list.color = "#a56de2";
            source.write.begin (null);
        });

        color_button_brown.toggled.connect (() => {
            task_list.color = "#8a715e";
            source.write.begin (null);
        });

        color_button_slate.toggled.connect (() => {
            task_list.color = "#667885";
            source.write.begin (null);
        });

        notify["source"].connect (() => {
            task_list = ((E.SourceTaskList?) source.get_extension (E.SOURCE_EXTENSION_TASK_LIST));
            switch (task_list.dup_color ()) {
                case "#c6262e":
                    color_button_red.active = true;
                    break;
                case "#f37329":
                    color_button_orange.active = true;
                    break;
                case "#e6a92a":
                    color_button_yellow.active = true;
                    break;
                case "#68b723":
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
        });

        show_completed_button.button_release_event.connect (() => {
            show_completed_switch.activate ();
            return Gdk.EVENT_STOP;
        });

        Application.settings.bind ("show-completed", show_completed_switch, "active", GLib.SettingsBindFlags.DEFAULT);
    }
}
