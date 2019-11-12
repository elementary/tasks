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

public class Tasks.TaskRow : Gtk.ListBoxRow {
    public E.Source source { get; construct; }
    public ECal.Component task { get; construct; }

    private static Gtk.CssProvider taskrow_provider;

    public bool completed { get; private set; }

    public TaskRow (E.Source source, ECal.Component task) {
        Object (source: source, task: task);
    }

    static construct {
        taskrow_provider = new Gtk.CssProvider ();
        taskrow_provider.load_from_resource ("io/elementary/tasks/TaskRow.css");
    }

    construct {
        unowned ICal.Component ical_task = task.get_icalcomponent ();
        completed = ical_task.get_status () == ICal.PropertyStatus.COMPLETED;

        var check = new Gtk.CheckButton ();
        check.sensitive = false;
        check.active = completed;
        check.margin_top = 2;
        check.valign = Gtk.Align.START;
        Tasks.Application.set_task_color (source, check);

        var summary_label = new Gtk.Label (ical_task.get_summary ());
        summary_label.justify = Gtk.Justification.LEFT;
        summary_label.wrap = true;
        summary_label.xalign = 0;

        if (completed) {
            summary_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        }

        var description_grid = new Gtk.Grid ();
        description_grid.column_spacing = 6;

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = grid.margin_end = 24;
        grid.column_spacing = 6;
        grid.row_spacing = 3;
        grid.attach (check, 0, 0);
        grid.attach (summary_label, 1, 0);
        grid.attach (description_grid, 1, 1);

        if ( !ical_task.get_due ().is_null_time () ) {
            var due_date_time = Util.ical_to_date_time (ical_task.get_due ());
            var h24_settings = new GLib.Settings ("org.gnome.desktop.interface");
            var format = h24_settings.get_string ("clock-format");

            var due_label = new Gtk.Label (Granite.DateTime.get_relative_datetime (due_date_time));
            due_label.tooltip_text = _("%s at %s").printf (
                due_date_time.format (Granite.DateTime.get_default_date_format (true)),
                due_date_time.format (Granite.DateTime.get_default_time_format (format.contains ("12h")))
            );

            unowned Gtk.StyleContext due_label_context = due_label.get_style_context ();
            due_label_context.add_class ("due-date");
            due_label_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            description_grid.add (due_label);
        }

        if (ical_task.get_description () != null) {
            var description = ical_task.get_description ();
            description = description.replace ("\r", "").strip ();
            string[] lines = description.split ("\n");
            string stripped_description = lines[0].strip ();
            for (int i = 1; i < lines.length; i++) {
                string stripped_line = lines[i].strip ();

                if (stripped_line.length > 0 ) {
                    stripped_description += " " + stripped_line;
                }
            }

            if (stripped_description.length > 0) {
                var description_label = new Gtk.Label (stripped_description);
                description_label.xalign = 0;
                description_label.lines = 1;
                description_label.ellipsize = Pango.EllipsizeMode.END;
                description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

                description_grid.add (description_label);
            }
        }

        var eventbox = new Gtk.EventBox ();
        eventbox.expand = true;
        eventbox.above_child = false;
        eventbox.add (grid);

        eventbox.event.connect ((event) => {
            if (event.type == Gdk.EventType.@2BUTTON_PRESS) {
                var task_popover = new Tasks.TaskSettingsPopover (task);
                task_popover.constrain_to = Gtk.PopoverConstraint.NONE;
                task_popover.position = Gtk.PositionType.LEFT;
                task_popover.set_relative_to (check);
                task_popover.popup ();

            } else if (!is_selected () && event.type == Gdk.EventType.BUTTON_PRESS) {
                activate ();
            }
        });

        add (eventbox);
    }
}
