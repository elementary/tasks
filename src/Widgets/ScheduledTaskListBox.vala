/*
 * Copyright 2019-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Tasks.Widgets.ScheduledTaskListBox : Gtk.Box {
    private Gee.Map<E.Source, ECal.ClientView> views;
    private const string QUERY = "AND (NOT is-completed?) (has-start?)";

    /*
     * We need to pass a valid S-expression as query to guarantee the callback events are fired.
     *
     * See `e-cal-backend-sexp.c` of evolution-data-server for available S-expressions:
     * https://gitlab.gnome.org/GNOME/evolution-data-server/-/blob/master/src/calendar/libedata-cal/e-cal-backend-sexp.c
     */

    private void add_view (E.Source source, string query) {
        try {
            var view = model.create_task_list_view (
                source,
                query,
                on_tasks_added,
                on_tasks_modified,
                on_tasks_removed );

            lock (views) {
                views.set (source, view);
            }

        } catch (Error e) {
            critical (e.message);
        }
    }

    private void remove_view (E.Source source) {
        Gtk.Widget[] children_for_removal = {};
        unowned var child = get_first_child ();
        while (child != null) {
            if (child is Tasks.Widgets.TaskRow && ((Tasks.Widgets.TaskRow) child).source == source) {
                children_for_removal += child;
            }

            child = child.get_next_sibling ();
        }

        for (int i = 0; i < children_for_removal.length; i++) {
            remove (children_for_removal[i]);
            children_for_removal[i].destroy ();
        }

        lock (views) {
            ECal.ClientView view;
            if (views.unset (source, out view)) {
                model.destroy_task_list_view (view);
            }
        }
    }

    public Tasks.TaskModel model { get; construct; }
    private Gtk.Label scheduled_title;
    private Gtk.ListBox task_list;

    public ScheduledTaskListBox (Tasks.TaskModel model) {
        Object (model: model);
    }

    construct {
        views = new Gee.HashMap<E.Source, ECal.ClientView> ();

        scheduled_title = new Gtk.Label (_("Scheduled")) {
            ellipsize = Pango.EllipsizeMode.END,
            margin_start = 24,
            margin_bottom = 24,
            xalign = 0
        };

        scheduled_title.add_css_class (Granite.STYLE_CLASS_H1_LABEL);
        scheduled_title.add_css_class (Granite.STYLE_CLASS_ACCENT);

        var placeholder = new Gtk.Label (_("No Tasks"));
        placeholder.show ();

        placeholder.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
        placeholder.add_css_class (Granite.STYLE_CLASS_H2_LABEL);

        task_list = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.MULTIPLE,
            activate_on_single_click = true
        };
        task_list.set_placeholder (placeholder);
        task_list.set_sort_func (sort_function);
        task_list.set_header_func (header_function);
        task_list.add_css_class (Granite.STYLE_CLASS_BACKGROUND);

        var scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            child = task_list
        };

        orientation = Gtk.Orientation.VERTICAL;
        append (scheduled_title);
        append (scrolled_window);

        task_list.row_activated.connect (on_row_activated);

        model.task_list_added.connect (add_task_list);
        model.task_list_modified.connect (modify_task_list);
        model.task_list_removed.connect (remove_task_list);

        model.get_registry.begin ((obj, res) => {
            E.SourceRegistry registry;
            try {
                registry = model.get_registry.end (res);
            } catch (Error e) {
                critical (e.message);
                return;
            }

            var sources = registry.list_sources (E.SOURCE_EXTENSION_TASK_LIST);
            sources.foreach ((source) => {
                add_task_list (source);
            });
        });
    }

    private void add_task_list (E.Source task_list) {
        if (!task_list.has_extension (E.SOURCE_EXTENSION_TASK_LIST)) {
            return;
        }
        E.SourceTaskList list = (E.SourceTaskList) task_list.get_extension (E.SOURCE_EXTENSION_TASK_LIST);

        if (list.selected == true && task_list.enabled == true && !task_list.has_extension (E.SOURCE_EXTENSION_COLLECTION)) {
            add_view (task_list, QUERY);
        }
    }

    private void modify_task_list (E.Source task_list) {
        remove_task_list (task_list);
        add_task_list (task_list);
    }

    private void remove_task_list (E.Source task_list) {
        remove_view (task_list);
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        var task_row = (Tasks.Widgets.TaskRow) row;
        task_row.reveal_child_request (true);

        unowned var main_window = (MainWindow) get_root ();
        if (main_window != null) {
            ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_DELETE_SELECTED_LIST)).set_enabled (false);
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

        var due_date_time = Tasks.Util.ical_to_date_time_local (comp.get_due ());
        var header_label = new Granite.HeaderLabel (Tasks.Util.get_relative_date (due_date_time)) {
            margin_start = 6
            //  ellipsize = Pango.EllipsizeMode.MIDDLE
        };

        row.set_header (header_label);
    }

    private void on_tasks_added (Gee.Collection<ECal.Component> tasks, E.Source source) {
        tasks.foreach ((task) => {
            var task_row = new Tasks.Widgets.TaskRow.for_component (task, source, true);
            task_row.unselect.connect (on_row_unselect);

            task_row.task_completed.connect ((task) => {
                Tasks.Application.model.complete_task.begin (source, task, (obj, res) => {
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
                        error_dialog.present ();
                        error_dialog.response.connect (() => {
                            error_dialog.destroy ();
                        });
                    }
                });
            });

            task_row.task_changed.connect ((task) => {
                Tasks.Application.model.update_task.begin (source, task, ECal.ObjModType.THIS_AND_FUTURE, (obj, res) => {
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
                        error_dialog.present ();
                        error_dialog.response.connect (() => {
                            error_dialog.destroy ();
                        });
                    }
                });
            });

            task_row.task_removed.connect ((task) => {
                Tasks.Application.model.remove_task.begin (source, task, ECal.ObjModType.ALL, (obj, res) => {
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
                        error_dialog.present ();
                        error_dialog.response.connect (() => {
                            error_dialog.destroy ();
                        });
                    }
                });
            });
            task_list.append (task_row);

            return true;
        });

        Idle.add (() => {
            task_list.invalidate_sort ();

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
