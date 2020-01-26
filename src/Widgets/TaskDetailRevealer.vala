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

public class Tasks.TaskDetailRevealer : Gtk.Revealer {

    private Gtk.Label due_label;
    private Gtk.Revealer due_label_revealer;
    private Gtk.Label description_label;
    private Gtk.Revealer description_label_revealer;
    private Gtk.Grid grid;

    public ECal.Component task { get; construct set; }

    private static Gtk.CssProvider taskrow_provider;

    public TaskDetailRevealer (ECal.Component task) {
        Object (task: task);
    }

    static construct {
        taskrow_provider = new Gtk.CssProvider ();
        taskrow_provider.load_from_resource ("io/elementary/tasks/TaskRow.css");
    }

    construct {
        due_label = new Gtk.Label (null);
        due_label.margin_end = 6;

        unowned Gtk.StyleContext due_label_context = due_label.get_style_context ();
        due_label_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        due_label_context.add_class ("due-date");

        due_label_revealer = new Gtk.Revealer ();
        due_label_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        due_label_revealer.add (due_label);

        description_label = new Gtk.Label (null);
        description_label.xalign = 0;
        description_label.lines = 1;
        description_label.ellipsize = Pango.EllipsizeMode.END;
        description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        description_label_revealer = new Gtk.Revealer ();
        description_label_revealer.reveal_child = false;
        description_label_revealer.add (description_label);

        grid = new Gtk.Grid ();
        grid.add (due_label_revealer);
        grid.add (description_label_revealer);

        reveal_child = false;
        add (grid);

        notify["task"].connect (update_request);
        update_request ();
    }

    private void update_request () {
        if (task == null) {
            reveal_child = false;
            due_label_revealer.reveal_child = false;
            description_label_revealer.reveal_child = false;

        } else {
            unowned ICal.Component ical_task = task.get_icalcomponent ();
            var completed = ical_task.get_status () == ICal.PropertyStatus.COMPLETED;

            if ( ical_task.get_due ().is_null_time () ) {
                due_label_revealer.reveal_child = false;
            } else {
                var due_date_time = Util.ical_to_date_time (ical_task.get_due ());
                var h24_settings = new GLib.Settings ("org.gnome.desktop.interface");
                var format = h24_settings.get_string ("clock-format");

                due_label.label = Granite.DateTime.get_relative_datetime (due_date_time);
                due_label.tooltip_text = _("%s at %s").printf (
                    due_date_time.format (Granite.DateTime.get_default_date_format (true)),
                    due_date_time.format (Granite.DateTime.get_default_time_format (format.contains ("12h")))
                );

                var today = new GLib.DateTime.now_local ();
                if (today.compare (due_date_time) > 0 && !completed) {
                    get_style_context ().add_class ("past-due");
                } else {
                    get_style_context ().remove_class ("past-due");
                }

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

            expand_request ();
        }
    }

    public void collapse_request () {
        reveal_child = false;
    }

    public void expand_request () {
        if (due_label_revealer.reveal_child || description_label_revealer.reveal_child) {
            reveal_child = true;
        } else {
            reveal_child = false;
        }
    }
}
