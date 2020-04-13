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

    private Gee.Collection<ECal.ClientView> views;

    /*
     * We need to pass a valid S-expression as query to guarantee the callback events are fired.
     *
     * See `e-cal-backend-sexp.c` of evolution-data-server for available S-expressions:
     * https://gitlab.gnome.org/GNOME/evolution-data-server/-/blob/master/src/calendar/libedata-cal/e-cal-backend-sexp.c
     */

    public void add_view (E.Source task_list, string query) {
        var view = Tasks.Application.model.create_task_list_view (
                        task_list,
                        query,
                        on_tasks_added,
                        on_tasks_modified,
                        on_tasks_removed );
        lock (views) {
            views.add (view);
        }
    }

    private void remove_views () {
        lock (views) {
            foreach (ECal.ClientView view in views) {
                Tasks.Application.model.destroy_task_list_view (view);
            }
            views.clear ();
        }
    }

    private Gtk.Revealer settings_button_revealer;
    private EditableLabel editable_title;
    private Gtk.ListBox task_list;

    construct {
        views = new Gee.ArrayList<ECal.ClientView> ((Gee.EqualDataFunc<ECal.ClientView>?) direct_equal);

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

        settings_button_revealer = new Gtk.Revealer ();
        settings_button_revealer.transition_type = Gtk.RevealerTransitionType.CROSSFADE;
        settings_button_revealer.add (settings_button);

        var placeholder = new Gtk.Label (_("No Tasks"));
        placeholder.show ();

        unowned Gtk.StyleContext placeholder_context = placeholder.get_style_context ();
        placeholder_context.add_class (Gtk.STYLE_CLASS_DIM_LABEL);
        placeholder_context.add_class (Granite.STYLE_CLASS_H2_LABEL);

        task_list = new Gtk.ListBox ();
        task_list.selection_mode = Gtk.SelectionMode.NONE;
        task_list.set_filter_func (filter_function);
        task_list.set_placeholder (placeholder);
        task_list.set_sort_func (sort_function);
        task_list.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);

        var scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.expand = true;
        scrolled_window.add (task_list);

        margin_bottom = 3;
        column_spacing = 12;
        row_spacing = 24;
        attach (editable_title, 0, 0);
        attach (settings_button_revealer, 1, 0);
        attach (scrolled_window, 0, 1, 2);

        Application.settings.changed["show-completed"].connect (() => {
            task_list.invalidate_filter ();
        });

        settings_button.toggled.connect (() => {
            if (settings_button.active) {
                list_settings_popover.source = source;
            }
        });

        task_list.row_activated.connect ((row) => {
            ((Tasks.TaskRow) row).reveal_child_request (true);
        });

        notify["source"].connect (() => {
            remove_views ();

            foreach (unowned Gtk.Widget child in task_list.get_children ()) {
                child.destroy ();
            }

            update_request ();
            show_all ();
        });

        editable_title.changed.connect (() => {
            if (source == null) {
                return;
            }
            source.display_name = editable_title.text;
            source.write.begin (null);
        });

        update_request ();
    }

    public void update_request () {
        if (source == null) {
            editable_title.sensitive = false;
            editable_title.text = _("Scheduled");
            settings_button_revealer.reveal_child = false;

            Tasks.Application.set_task_color_from_string ("#3689e6", editable_title);

            task_list.@foreach ((row) => {
                if (row is Tasks.TaskRow) {
                    (row as Tasks.TaskRow).update_request ();
                }
            });

        } else {
            settings_button_revealer.reveal_child = true;
            editable_title.text = source.dup_display_name ();
            editable_title.sensitive = true;

            Tasks.Application.set_task_color (source, editable_title);

            task_list.@foreach ((row) => {
                if (row is Tasks.TaskRow) {
                    (row as Tasks.TaskRow).update_request ();
                }
            });
        }
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
        var row_a = (Tasks.TaskRow) row1;
        var row_b = (Tasks.TaskRow) row2;

        if (row_a.completed == row_b.completed) {
            unowned ICal.Component comp_a = row_a.task.get_icalcomponent ();
            unowned ICal.Component comp_b = row_b.task.get_icalcomponent ();

            ICal.Time start_a = comp_a.get_dtstart ();
            ICal.Time stamp_a = comp_a.get_dtstamp ();

            ICal.Time start_b = comp_b.get_dtstart ();
            ICal.Time stamp_b = comp_b.get_dtstamp ();

            if ( start_a.is_null_time () && start_b.is_null_time () ) {
                return stamp_b.compare (stamp_a);

            } else if (start_a.is_null_time () && !start_b.is_null_time ()) {
                return 1;

            } else if (start_b.is_null_time () && !start_a.is_null_time ()) {
                return -1;

            } else {
                return start_a.compare (start_b);
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
        task_list.invalidate_sort ();
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

        task_list.invalidate_sort ();
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
