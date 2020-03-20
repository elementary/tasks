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

public class Tasks.ListView : Gtk.Grid {
    public E.Source? source { get; set; }

    private ECal.ClientView view;
    private EditableLabel editable_title;

    private Gtk.ListBox add_task_list;
    private Gtk.ListBox task_list;

    private static Gtk.CssProvider tasklist_provider;

    static construct {
        tasklist_provider = new Gtk.CssProvider ();
        tasklist_provider.load_from_resource ("io/elementary/tasks/TaskList.css");
    }

    construct {
        editable_title = new EditableLabel ();
        editable_title.margin_start = 24;

        unowned Gtk.StyleContext title_context = editable_title.get_style_context ();
        title_context.add_class (Granite.STYLE_CLASS_H1_LABEL);
        title_context.add_class (Granite.STYLE_CLASS_ACCENT);

        var list_settings_popover = new Tasks.ListSettingsPopover ();

        var settings_button = new Gtk.MenuButton ();
        settings_button.margin_end = 24;
        settings_button.valign = Gtk.Align.CENTER;
        settings_button.tooltip_text = _("Edit Name and Appearance");
        settings_button.popover = list_settings_popover;
        settings_button.image = new Gtk.Image.from_icon_name ("view-more-symbolic", Gtk.IconSize.MENU);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        settings_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        var placeholder = new Gtk.Label (_("No Tasks"));
        placeholder.show ();

        unowned Gtk.StyleContext placeholder_context = placeholder.get_style_context ();
        placeholder_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        placeholder_context.add_class (Granite.STYLE_CLASS_H2_LABEL);

        add_task_list = new Gtk.ListBox ();
        add_task_list.selection_mode = Gtk.SelectionMode.NONE;
        add_task_list.margin_top = 24;

        task_list = new Gtk.ListBox ();
        task_list.selection_mode = Gtk.SelectionMode.NONE;
        task_list.set_filter_func (filter_function);
        task_list.set_placeholder (placeholder);
        task_list.set_sort_func (sort_function);

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.expand = true;
        scrolled_window.add (task_list);

        margin_bottom = 3;
        column_spacing = 12;
        attach (editable_title, 0, 0);
        attach (settings_button, 1, 0);
        attach (add_task_list, 0, 1, 2);
        attach (scrolled_window, 0, 2, 2);

        scrolled_window.get_style_context ().add_provider (tasklist_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        get_style_context ().add_class ("task-list");
        get_style_context ().add_provider (tasklist_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        Application.settings.changed["show-completed"].connect (() => {
            task_list.invalidate_filter ();
        });

        settings_button.toggled.connect (() => {
            if (settings_button.active) {
                list_settings_popover.source = source;
            }
        });

        add_task_list.row_activated.connect ((row) => {
            ((Tasks.TaskRow) row).reveal_child_request (true);
        });

        task_list.row_activated.connect ((row) => {
            ((Tasks.TaskRow) row).reveal_child_request (true);
        });

        notify["source"].connect (() => {
            if (view != null) {
                Tasks.Application.model.destroy_task_list_view (view);
            }

            foreach (unowned Gtk.Widget child in add_task_list.get_children ()) {
                child.destroy ();
            }

            if (source != null) {
                update_request ();

                try {
                    view = Tasks.Application.model.create_task_list_view (
                        source,
                        "(contains? 'any' '')",
                        on_tasks_added,
                        on_tasks_modified,
                        on_tasks_removed );

                } catch (Error e) {
                    critical (e.message);
                }

            } else {
                editable_title.text = "";
            }

            show_all ();
        });

        editable_title.changed.connect (() => {
            source.display_name = editable_title.text;
            source.write.begin (null);
        });
    }

    public void update_request () {
        editable_title.text = source.dup_display_name ();
        Tasks.Application.set_task_color (source, editable_title);

        task_list.@foreach ((row) => {
            if (row is Tasks.TaskRow) {
                (row as Tasks.TaskRow).update_request ();
            }
        });
    }

    [CCode (instance_pos = -1)]
    private bool filter_function (Gtk.ListBoxRow row) {
        if (
            Application.settings.get_boolean ("show-completed") == false &&
            ((TaskRow) row).completed
        ) {
            return false;
        }

        return true;
    }

    [CCode (instance_pos = -1)]
    private int sort_function (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var row1_completed = ((Tasks.TaskRow) row1).completed;
        var row2_completed = ((Tasks.TaskRow) row2).completed;

        if (row1_completed && !row2_completed) {
            return 1;
        } else if (row2_completed && !row1_completed) {
            return -1;
        }

        return 0;
    }

    private void on_tasks_added (Gee.Collection<ECal.Component> tasks) {
        tasks.foreach ((task) => {
            var task_row = new Tasks.TaskRow.for_component (task, source);
            task_row.task_completed.connect ((task) => {
                Tasks.Application.model.complete_task (source, task);
            });
            task_row.task_changed.connect ((task) => {
                Tasks.Application.model.update_task (source, task, ECal.ObjModType.THIS_AND_FUTURE);
            });
            task_row.task_removed.connect ((task) => {
                Tasks.Application.model.remove_task (source, task, ECal.ObjModType.ALL);
            });
            task_list.add (task_row);
            return true;
        });
        task_list.show_all ();
    }

    private void on_tasks_modified (Gee.Collection<ECal.Component> tasks) {
        Tasks.TaskRow task_row = null;
        var row_index = 0;

        do {
            task_row = (Tasks.TaskRow) task_list.get_row_at_index (row_index);

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
    }

    private void on_tasks_removed (SList<ECal.ComponentId?> cids) {
        unowned Tasks.TaskRow? task_row = null;
        var row_index = 0;
        do {
            task_row = (Tasks.TaskRow) task_list.get_row_at_index (row_index);

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
    }
}
