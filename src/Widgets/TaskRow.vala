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
    private Gtk.Entry summary_entry;

    private Tasks.TaskDetailRevealer task_detail_revealer;
    private Tasks.TaskFormRevealer task_form_revealer;

    public E.Source source { get; construct; }
    public ECal.Component task { get; construct set; }

    public signal void task_save (ECal.Component task);
    public signal void task_delete (ECal.Component task);

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
        check.valign = Gtk.Align.CENTER;
        Tasks.Application.set_task_color (source, check);

        summary_entry = new Gtk.Entry ();

        unowned Gtk.StyleContext summary_entry_context = summary_entry.get_style_context ();
        summary_entry_context.add_class (Gtk.STYLE_CLASS_FLAT);
        summary_entry_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        task_detail_revealer = new Tasks.TaskDetailRevealer (task);
        task_detail_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;

        task_form_revealer = new Tasks.TaskFormRevealer (task);
        task_form_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = grid.margin_end = 12;
        grid.column_spacing = 6;
        grid.row_spacing = 3;
        grid.attach (check, 0, 0);
        grid.attach (summary_entry, 1, 0);
        grid.attach (task_detail_revealer, 1, 1);
        grid.attach (task_form_revealer, 1, 2);

        add (grid);
        margin_start = margin_end = 12;
        get_style_context ().add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        check.toggled.connect (() => {
            if (task == null) {
                return;
            }
            task.get_icalcomponent ().set_status (check.active ? ICal.PropertyStatus.COMPLETED : ICal.PropertyStatus.NONE);
            task_save (task);
        });

        summary_entry.activate.connect (() => {
            move_focus (Gtk.DirectionType.TAB_BACKWARD);
            save_task ();
        });

        task_form_revealer.cancel_clicked.connect (() => {
            cancel_edit ();
        });

        task_form_revealer.save_clicked.connect (() => {
            save_task ();
        });

        task_form_revealer.delete_clicked.connect ((task) => {
            task_delete (task);
        });

        key_release_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                cancel_edit ();
            }
        });

        summary_entry.grab_focus.connect (() => {
            reveal_child_request (true);
        });

        notify["task"].connect (() => {
            task_detail_revealer.task = task;
            task_form_revealer.task = task;
            update_request ();
        });
        update_request ();
    }

    private void cancel_edit () {
        move_focus (Gtk.DirectionType.TAB_BACKWARD);
        summary_entry.text = task.get_icalcomponent ().get_summary ();
        reveal_child_request (false);
    }

    private void save_task () {
        task.get_icalcomponent ().set_summary (summary_entry.text);
        reveal_child_request (false);
        task_save (task);
    }

    public void reveal_child_request (bool value) {
        task_form_revealer.reveal_child = value;
        task_detail_revealer.reveal_child_request (!value);

        unowned Gtk.StyleContext style_context = get_style_context ();

        if (value) {
            style_context.add_class (Granite.STYLE_CLASS_CARD);
            style_context.add_class ("collapsed");
        } else {
            style_context.remove_class (Granite.STYLE_CLASS_CARD);
            style_context.remove_class ("collapsed");
        }
    }

    private void update_request () {
        if (task == null) {
            completed = false;
            check.active = completed;
            summary_entry.text = null;
            summary_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);

        } else {
            unowned ICal.Component ical_task = task.get_icalcomponent ();
            completed = ical_task.get_status () == ICal.PropertyStatus.COMPLETED;
            check.active = completed;

            summary_entry.text = ical_task.get_summary ();

            if (completed) {
                summary_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            } else {
                summary_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            }
        }
    }
}
