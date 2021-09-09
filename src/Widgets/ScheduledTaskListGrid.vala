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

public class Tasks.Widgets.ScheduledTaskListGrid : Gtk.Grid {
    private Gee.Collection<ECal.ClientView> views;
    private string h24_clock_format;

    /*
     * We need to pass a valid S-expression as query to guarantee the callback events are fired.
     *
     * See `e-cal-backend-sexp.c` of evolution-data-server for available S-expressions:
     * https://gitlab.gnome.org/GNOME/evolution-data-server/-/blob/master/src/calendar/libedata-cal/e-cal-backend-sexp.c
     */

    public void add_view (E.Source task_list, string query) {
        try {
            var view = Tasks.Application.model.create_task_list_view (
                task_list,
                query,
                on_tasks_added,
                on_tasks_modified,
                on_tasks_removed );

            lock (views) {
                views.add (view);
            }

        } catch (Error e) {
            critical (e.message);
        }
    }

    public void remove_views () {
        foreach (unowned Gtk.Widget child in task_list.get_children ()) {
            child.destroy ();
        }

        lock (views) {
            foreach (ECal.ClientView view in views) {
                Tasks.Application.model.destroy_task_list_view (view);
            }
            views.clear ();
        }
    }

    private Gtk.Label scheduled_title;
    private Gtk.ListBox task_list;

    construct {
        views = new Gee.ArrayList<ECal.ClientView> ((Gee.EqualDataFunc<ECal.ClientView>?) direct_equal);

        h24_clock_format = Application.h24_settings.get_string ("clock-format");

        scheduled_title = new Gtk.Label (_("Scheduled")) {
            ellipsize = Pango.EllipsizeMode.END,
            margin_start = 24,
            margin_bottom = 24,
            xalign = 0
        };

        unowned Gtk.StyleContext scheduled_title_context = scheduled_title.get_style_context ();
        scheduled_title_context.add_class (Granite.STYLE_CLASS_H1_LABEL);
        scheduled_title_context.add_class (Granite.STYLE_CLASS_ACCENT);

        var placeholder = new Gtk.Label (_("No Tasks"));
        placeholder.show ();

        unowned Gtk.StyleContext placeholder_context = placeholder.get_style_context ();
        placeholder_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        placeholder_context.add_class (Granite.STYLE_CLASS_H2_LABEL);

        task_list = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.MULTIPLE,
            activate_on_single_click = true
        };
        task_list.set_placeholder (placeholder);
        task_list.set_sort_func (sort_function);
        task_list.set_header_func (header_function);
        task_list.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);

        var scrolled_window = new Gtk.ScrolledWindow (null, null) {
            expand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };
        scrolled_window.add (task_list);

        column_spacing = 12;
        attach (scheduled_title, 0, 0);
        attach (scrolled_window, 0, 1);

        task_list.row_activated.connect (on_row_activated);

        show_all ();
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        var task_row = (Tasks.Widgets.TaskRow) row;
        task_row.reveal_child_request (true);

        unowned GLib.ActionMap win_action_map = (GLib.ActionMap) get_action_group (MainWindow.ACTION_GROUP_PREFIX);
        if (win_action_map != null) {
            ((SimpleAction) win_action_map.lookup_action (MainWindow.ACTION_DELETE_SELECTED_LIST)).set_enabled (false);
        }
    }

    private void on_row_unselect (Gtk.ListBoxRow row) {
        if (row.parent is Gtk.ListBox) {
            ((Gtk.ListBox) row.parent).unselect_row (row);
        }
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var row_a = (Tasks.Widgets.TaskRow) row1;
        var row_b = (Tasks.Widgets.TaskRow) row2;

        return row_a.task.get_due ().get_value ().compare (row_b.task.get_due ().get_value ());
    }

    private void header_function (Gtk.ListBoxRow lbrow, Gtk.ListBoxRow? lbbefore) {
        if (!(lbrow is Tasks.Widgets.TaskRow)) {
            return;
        }
        var row = (Tasks.Widgets.TaskRow) lbrow;
        unowned ICal.Component comp = row.task.get_icalcomponent ();

        if (comp.get_due ().is_null_time ()) {
            return;
        }

        if (lbbefore != null) {
            var before = (Tasks.Widgets.TaskRow) lbbefore;
            unowned ICal.Component comp_before = before.task.get_icalcomponent ();

            if (comp_before.get_due ().compare_date_only (comp.get_due ()) == 0) {
                return;
            }
        }

        var due_date_time = Util.ical_to_date_time (comp.get_due ());
        var header_label = new Granite.HeaderLabel (Tasks.Util.get_relative_date (due_date_time));
        header_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
        header_label.margin_start = 6;

        row.set_header (header_label);
    }

    private void on_tasks_added (Gee.Collection<ECal.Component> tasks, E.Source source) {
        tasks.foreach ((task) => {
            var task_row = new Tasks.Widgets.TaskRow.for_component (task, source, h24_clock_format, true);
            task_row.unselect.connect (on_row_unselect);

            task_row.task_completed.connect ((task) => {
                Tasks.Application.model.complete_task.begin (source, task, (obj, res) => {
                    GLib.Idle.add (() => {
                        try {
                            Tasks.Application.model.complete_task.end (res);
                        } catch (Error e) {
                            var error_dialog = new Granite.MessageDialog (
                                _("Completing task failed"),
                                _("The task registry may be unavailable or unable to be written to."),
                                new ThemedIcon ("dialog-error"),
                                Gtk.ButtonsType.CLOSE
                            );
                            error_dialog.show_error_details (e.message);
                            error_dialog.run ();
                            error_dialog.destroy ();
                        }

                        return GLib.Source.REMOVE;
                    });
                });
            });

            task_row.task_changed.connect ((task) => {
                Tasks.Application.model.update_task.begin (source, task, ECal.ObjModType.THIS_AND_FUTURE, (obj, res) => {
                    GLib.Idle.add (() => {
                        try {
                            Tasks.Application.model.update_task.end (res);
                        } catch (Error e) {
                            var error_dialog = new Granite.MessageDialog (
                                _("Updating task failed"),
                                _("The task registry may be unavailable or unable to be written to."),
                                new ThemedIcon ("dialog-error"),
                                Gtk.ButtonsType.CLOSE
                            );
                            error_dialog.show_error_details (e.message);
                            error_dialog.run ();
                            error_dialog.destroy ();
                        }

                        return GLib.Source.REMOVE;
                    });
                });
            });

            task_row.task_removed.connect ((task) => {
                Tasks.Application.model.remove_task.begin (source, task, ECal.ObjModType.ALL, (obj, res) => {
                    GLib.Idle.add (() => {
                        try {
                            Tasks.Application.model.remove_task.end (res);
                        } catch (Error e) {
                            var error_dialog = new Granite.MessageDialog (
                                _("Removing task failed"),
                                _("The task registry may be unavailable or unable to be written to."),
                                new ThemedIcon ("dialog-error"),
                                Gtk.ButtonsType.CLOSE
                            );
                            error_dialog.show_error_details (e.message);
                            error_dialog.run ();
                            error_dialog.destroy ();
                        }

                        return GLib.Source.REMOVE;
                    });
                });
            });
            task_list.add (task_row);

            return true;
        });

        Idle.add (() => {
            task_list.invalidate_sort ();
            task_list.show_all ();

            return Source.REMOVE;
        });
    }

    private void on_tasks_modified (Gee.Collection<ECal.Component> tasks) {
        Tasks.Widgets.TaskRow task_row = null;
        var row_index = 0;

        do {
            task_row = (Tasks.Widgets.TaskRow) task_list.get_row_at_index (row_index);

            if (task_row != null) {
                foreach (ECal.Component task in tasks) {
                    if (Util.calcomponent_equal_func (task_row.task, task)) {
                        task_row.task = task;
                        break;
                    }
                }
            }
            row_index++;
        } while (task_row != null);

        Idle.add (() => {
            task_list.invalidate_sort ();

            return Source.REMOVE;
        });
    }

    private void on_tasks_removed (SList<ECal.ComponentId?> cids) {
        unowned Tasks.Widgets.TaskRow? task_row = null;
        var row_index = 0;
        do {
            task_row = (Tasks.Widgets.TaskRow) task_list.get_row_at_index (row_index);

            if (task_row != null) {
                foreach (unowned ECal.ComponentId cid in cids) {
                    if (cid == null) {
                        continue;
                    } else if (cid.get_uid () == task_row.task.get_icalcomponent ().get_uid ()) {
                        task_list.remove (task_row);
                        break;
                    }
                }
            }
            row_index++;
        } while (task_row != null);

        Idle.add (() => {
            task_list.invalidate_sort ();

            return Source.REMOVE;
        });
    }
}
