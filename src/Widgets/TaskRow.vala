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
    private EditableLabel editable_summary;

    private Tasks.TaskDetailRevealer task_detail_revealer;

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

        editable_summary = new EditableLabel ();
        task_detail_revealer = new Tasks.TaskDetailRevealer (task);

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = grid.margin_end = 24;
        grid.column_spacing = 6;
        grid.row_spacing = 3;
        grid.attach (check, 0, 0);
        grid.attach (editable_summary, 1, 0);
        grid.attach (task_detail_revealer, 1, 1);

        var eventbox = new Gtk.EventBox ();
        eventbox.expand = true;
        eventbox.above_child = false;
        eventbox.add (grid);

        add (eventbox);
        get_style_context ().add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        eventbox.button_press_event.connect ((event) => {
            if (event.type == Gdk.EventType.@2BUTTON_PRESS) {
                show_popover ();

            } else if (!is_selected () ) {
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
            switch (event.keyval) {
                case Gdk.Key.space:
                    if (has_focus) {
                        check.active = !check.active;
                    }
                    break;

                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    if (has_focus) {
                        show_popover ();
                    } else {
                        grab_focus ();
                    }
                    break;

                case Gdk.Key.Escape:
                    grab_focus ();
                    break;
            }
        });

        editable_summary.changed.connect (() => {
            if (task == null) {
                return;
            }
            task.get_icalcomponent ().set_summary (editable_summary.text);
            task_changed (task);
        });

        editable_summary.button_press_event.connect ((event) => {
            if (event.type != Gdk.EventType.@2BUTTON_PRESS) {
                if (!is_selected ()) {
                   activate ();
                }
                editable_summary.grab_focus ();
                return Gdk.EVENT_STOP;
            }
        });

        notify["task"].connect (() => {
            task_detail_revealer.task = task;
            update_request ();
        });
        update_request ();
    }

    private void update_request () {
        if (task == null) {
            completed = false;
            check.active = completed;
            editable_summary.text = null;
            editable_summary.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);

        } else {
            unowned ICal.Component ical_task = task.get_icalcomponent ();
            completed = ical_task.get_status () == ICal.PropertyStatus.COMPLETED;
            check.active = completed;

            editable_summary.text = ical_task.get_summary ();

            if (completed) {
                editable_summary.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            } else {
                editable_summary.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            }
        }
    }

    private void show_popover () {
        var task_popover = new Tasks.TaskSettingsPopover (task);
        task_popover.constrain_to = Gtk.PopoverConstraint.NONE;
        task_popover.position = Gtk.PositionType.LEFT;
        task_popover.set_relative_to (check);

        task_popover.closed.connect (() => {
            task_changed (task);
        });

        task_popover.popup ();
    }
}
