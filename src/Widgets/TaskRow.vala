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
    private Gtk.CheckButton check;
    private Gtk.Label summary_label;

    private Gtk.Label due_label;
    private Gtk.Revealer due_label_revealer;
    private Gtk.Label description_label;
    private Gtk.Revealer description_label_revealer;
    private Gtk.Grid description_grid;
    private Gtk.Revealer description_grid_revealer;

    public E.Source source { get; construct; }
    public ECal.Component task { get; construct set; }
    public signal void task_changed (ECal.Component task);

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
        check = new Gtk.CheckButton ();
        check.margin_top = 2;
        check.valign = Gtk.Align.START;
        Tasks.Application.set_task_color (source, check);

        summary_label = new Gtk.Label (null);
        summary_label.justify = Gtk.Justification.LEFT;
        summary_label.wrap = true;
        summary_label.xalign = 0;

        description_grid = new Gtk.Grid ();
        description_grid.column_spacing = 6;

        description_grid_revealer = new Gtk.Revealer ();
        description_grid_revealer.reveal_child = false;
        description_grid_revealer.add (description_grid);

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = grid.margin_end = 24;
        grid.column_spacing = 6;
        grid.row_spacing = 3;
        grid.attach (check, 0, 0);
        grid.attach (summary_label, 1, 0);
        grid.attach (description_grid_revealer, 1, 1);

        due_label = new Gtk.Label (null);
        unowned Gtk.StyleContext due_label_context = due_label.get_style_context ();
        due_label_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        due_label_context.add_class ("due-date");

        due_label_revealer = new Gtk.Revealer ();
        due_label_revealer.reveal_child = false;
        due_label_revealer.add (due_label);

        description_label = new Gtk.Label (null);
        description_label.xalign = 0;
        description_label.lines = 1;
        description_label.ellipsize = Pango.EllipsizeMode.END;
        description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        description_label_revealer = new Gtk.Revealer ();
        description_label_revealer.reveal_child = false;
        description_label_revealer.add (description_label);

        description_grid.add (due_label_revealer);
        description_grid.add (description_label_revealer);

        var eventbox = new Gtk.EventBox ();
        eventbox.expand = true;
        eventbox.above_child = false;
        eventbox.add (grid);

        add (eventbox);

        eventbox.event.connect ((event) => {
            if (event.type == Gdk.EventType.@2BUTTON_PRESS) {
                var task_popover = new Tasks.TaskSettingsPopover (task);
                task_popover.constrain_to = Gtk.PopoverConstraint.NONE;
                task_popover.position = Gtk.PositionType.LEFT;
                task_popover.set_relative_to (check);

                task_popover.closed.connect (() => {
                    task_changed (task);
                });

                task_popover.popup ();

            } else if (!is_selected () && event.type == Gdk.EventType.BUTTON_PRESS) {
                activate ();
            }
        });

        check.toggled.connect (() => {
            if (task == null) {
                return;
            }
            task.get_icalcomponent ().set_status (check.active ? ICal.PropertyStatus.COMPLETED : ICal.PropertyStatus.NONE);
            task_changed (task);
        });

        key_release_event.connect ((event) => {
            if (event.keyval == Gdk.Key.space) {
                check.active = !check.active;
            }
        });

        notify["task"].connect (update_request);
        update_request ();
    }

    private void update_request () {
        if (task == null) {
            completed = false;
            check.active = completed;
            summary_label.label = null;
            summary_label.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            description_grid.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            description_grid_revealer.reveal_child = false;
            due_label_revealer.reveal_child = false;
            description_label_revealer.reveal_child = false;

        } else {
            unowned ICal.Component ical_task = task.get_icalcomponent ();
            completed = ical_task.get_status () == ICal.PropertyStatus.COMPLETED;
            check.active = completed;

            summary_label.label = ical_task.get_summary ();

            if (completed) {
                summary_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                description_grid.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            } else {
                summary_label.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
                description_grid.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            }

            if ( ical_task.get_due ().is_null_time () ) {
                due_label_revealer.reveal_child = false;
                GLib.Timeout.add (due_label_revealer.transition_duration, () => {
                    due_label_revealer.visible = false;
                    return GLib.Source.REMOVE;
                });

            } else {
                var due_date_time = Util.ical_to_date_time (ical_task.get_due ());
                var h24_settings = new GLib.Settings ("org.gnome.desktop.interface");
                var format = h24_settings.get_string ("clock-format");

                due_label.label = Granite.DateTime.get_relative_datetime (due_date_time);
                due_label.tooltip_text = _("%s at %s").printf (
                    due_date_time.format (Granite.DateTime.get_default_date_format (true)),
                    due_date_time.format (Granite.DateTime.get_default_time_format (format.contains ("12h")))
                );
                due_label_revealer.visible = true;
                due_label_revealer.reveal_child = true;
            }

            if (ical_task.get_description () == null) {
                description_label_revealer.reveal_child = false;

            } else {
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
                    description_label.label = stripped_description;
                    description_label_revealer.reveal_child = true;
                } else {
                    description_label_revealer.reveal_child = false;
                }
            }

            if (due_label_revealer.reveal_child || description_label_revealer.reveal_child) {
                description_grid_revealer.reveal_child = true;
            } else {
                description_grid_revealer.reveal_child = false;
            }
        }
    }
}
