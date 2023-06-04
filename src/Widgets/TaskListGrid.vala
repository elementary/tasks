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

public class Tasks.Widgets.TaskListGrid : Gtk.Grid {
    public E.Source source { get; construct; }
    private ECal.ClientView? view = null;

    private EditableLabel editable_title;
    private Gtk.ListBox add_task_list;
    private Gtk.ListBox task_list;
    private bool is_gtasks;

    public TaskListGrid (E.Source source) {
        Object (source: source);
    }

    construct {
        try {
            E.SourceRegistry registry;
            registry = Application.model.get_registry_sync ();
            is_gtasks = Application.model.get_collection_backend_name (source, registry) == "google";
        } catch (Error e) {
            warning ("unable to get the registry, assuming task list is not from gtasks");
        }

        editable_title = new EditableLabel () {
            margin_start = 24,
            hexpand = true
        };
        editable_title.add_css_class (Granite.STYLE_CLASS_H1_LABEL);
        editable_title.add_css_class (Granite.STYLE_CLASS_ACCENT);

        var list_settings_popover = new Tasks.Widgets.ListSettingsPopover ();

        var settings_button = new Gtk.MenuButton () {
            margin_end = 24,
            valign = Gtk.Align.CENTER,
            hexpand = false,
            tooltip_text = _("Edit Name and Appearance"),
            popover = list_settings_popover,
            icon_name = "view-more-symbolic"
        };
        settings_button.add_css_class (Granite.STYLE_CLASS_FLAT);
        settings_button.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        var placeholder = new Gtk.Label (_("No Tasks"));
        placeholder.show ();

        placeholder.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
        placeholder.add_css_class (Granite.STYLE_CLASS_H2_LABEL);

        add_task_list = new Gtk.ListBox () {
            margin_top = 24,
            selection_mode = Gtk.SelectionMode.SINGLE,
            activate_on_single_click = true
        };
        add_task_list.add_css_class (Granite.STYLE_CLASS_BACKGROUND);

        var add_task_row = new Tasks.Widgets.TaskRow.for_source (source);
        add_task_row.unselect.connect (on_row_unselect);

        add_task_row.task_changed.connect ((task) => {
            Tasks.Application.model.add_task.begin (source, task, (obj, res) => {
                try {
                    Tasks.Application.model.add_task.end (res);
                } catch (Error e) {
                    var error_dialog = new Granite.MessageDialog (
                        _("Adding task failed"),
                        _("The task list registry may be unavailable or unable to be written to."),
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
        add_task_list.append (add_task_row);

        task_list = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.MULTIPLE,
            activate_on_single_click = true
        };
        task_list.add_css_class (Granite.STYLE_CLASS_BACKGROUND);
        task_list.set_placeholder (placeholder);
        task_list.set_sort_func (sort_function);

        var scrolled_window = new Gtk.ScrolledWindow () {
            hexpand = true,
            vexpand = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            child = task_list
        };

        column_spacing = 12;
        attach (editable_title, 0, 0);
        attach (settings_button, 1, 0);
        attach (add_task_list, 0, 1, 2);
        attach (scrolled_window, 0, 2, 2);

        Application.settings.changed["show-completed"].connect (() => {
            on_show_completed_changed (Application.settings.get_boolean ("show-completed"));
        });
        on_show_completed_changed (Application.settings.get_boolean ("show-completed"));

        settings_button.activate.connect (() => {
            unowned var main_window = (MainWindow) get_root ();

            // TODO:
            //  error: `Gtk.MenuButton.get_active' is not available in gtk4 4.6.6. Use gtk4 >= 4.10
            //  if (settings_button.active) {
            if (false) {
                list_settings_popover.source = source;

                if (main_window != null) {
                    ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_DELETE_SELECTED_LIST)).set_enabled (true);
                }

            } else if (main_window != null) {
                /*
                * We can't immediate disable the action once the popover is closed,
                * because this would lead to the action not being executed in case
                * the popover was closed because the user clicked on the action.
                * Therefore we wait a tiny bit using GLib.Idle to allow the action to
                * be executed if needed.
                */
                GLib.Idle.add (() => {
                    ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_DELETE_SELECTED_LIST)).set_enabled (
                        add_task_list.get_selected_rows ().length () == 0 &&
                        task_list.get_selected_rows ().length () == 0
                    );
                    return GLib.Source.REMOVE;
                });
            }
        });

        add_task_list.row_activated.connect (on_row_activated);
        task_list.row_activated.connect (on_row_activated);

        editable_title.notify["editing"].connect (() => {
            unowned var main_window = (MainWindow) get_root ();
            if (main_window != null) {
                ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_DELETE_SELECTED_LIST)).set_enabled (!editable_title.editing);
            }
        });

        editable_title.changed.connect (() => {
            Application.model.update_task_list_display_name.begin (source, editable_title.text, (obj, res) => {
                try {
                    Application.model.update_task_list_display_name.end (res);
                } catch (Error e) {
                    editable_title.text = source.display_name;

                    var error_dialog = new Granite.MessageDialog (
                        _("Renaming task list failed"),
                        _("The task list registry may be unavailable or unable to be written to."),
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
    }

    private void on_show_completed_changed (bool show_completed) {
        if (show_completed) {
            set_view_for_query ("(contains? 'any' '')");
        } else {
            set_view_for_query ("NOT is-completed?");
        }
    }

    private void set_view_for_query (string query) {
        unowned var child = task_list.get_first_child ();
        while (child != null) {
            task_list.remove (child);

            child = child.get_next_sibling ();
        }

        if (view != null) {
            Application.model.destroy_task_list_view (view);
        }

        try {
            view = Tasks.Application.model.create_task_list_view (
                source,
                query,
                on_tasks_added,
                on_tasks_modified,
                on_tasks_removed );
        } catch (Error e) {
            critical ("Error creating view with query for source %s[%s]: %s", source.display_name, query, e.message);
        }
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

        if (add_task_list.get_selected_rows ().length () == 0 && task_list.get_selected_rows ().length () == 0) {
            unowned var main_window = (MainWindow) get_root ();
            if (main_window != null) {
                ((SimpleAction) main_window.lookup_action (MainWindow.ACTION_DELETE_SELECTED_LIST)).set_enabled (true);
            }
        }
    }

    public void update_request () {
        editable_title.text = source.dup_display_name ();

        Tasks.Application.set_task_color (source, editable_title);

        unowned var child = task_list.get_first_child ();
        while (child != null) {
            if (child is Tasks.Widgets.TaskRow) {
                unowned var task_row = (child as Tasks.Widgets.TaskRow);
                task_row.update_request ();
            }

            child = child.get_next_sibling ();
        }
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var row_a = (Tasks.Widgets.TaskRow) row1;
        var row_b = (Tasks.Widgets.TaskRow) row2;

        if (row_a.completed == row_b.completed) {
            if (is_gtasks) {
                var gtask_position_a = Util.get_gtasks_position_property_value (row_a.task);
                var gtask_position_b = Util.get_gtasks_position_property_value (row_b.task);

                if (gtask_position_a == gtask_position_b) {
                    return row_b.task.get_last_modified ().compare (row_a.task.get_last_modified ());
                }

                return gtask_position_a.collate (gtask_position_b);
            } else {
                var apple_sortorder_a = Util.get_apple_sortorder_property_value (row_a.task);
                if (apple_sortorder_a == null) {
                    apple_sortorder_a = Util.get_apple_sortorder_default_value (row_a.task).as_int ().to_string ();
                }

                var apple_sortorder_b = Util.get_apple_sortorder_property_value (row_b.task);
                if (apple_sortorder_b == null) {
                    apple_sortorder_b = Util.get_apple_sortorder_default_value (row_b.task).as_int ().to_string ();
                }

                return apple_sortorder_a.collate (apple_sortorder_b);
            }
        } else if (row_a.completed && !row_b.completed) {
            return 1;

        } else if (row_b.completed && !row_a.completed) {
            return -1;
        }

        return 0;
    }

    private void on_tasks_added (Gee.Collection<ECal.Component> tasks, E.Source source) {
        tasks.foreach ((task) => {
            var task_row = new Tasks.Widgets.TaskRow.for_component (task, source, false);
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
