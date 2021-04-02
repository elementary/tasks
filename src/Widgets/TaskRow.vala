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

    public signal void task_completed (ECal.Component task);
    public signal void task_changed (ECal.Component task);
    public signal void task_removed (ECal.Component task);
    public signal void unselect ();

    public bool completed { get; private set; }
    public E.Source source { get; construct; }
    public ECal.Component task { get; construct set; }
    public bool is_scheduled_view { get; construct; }

    private const Gtk.TargetEntry[] TARGET_ENTRIES = {
        { "GTK_LIST_BOX_ROW", Gtk.TargetFlags.SAME_APP, 0 }
    };

    private bool created;

    private Tasks.DateTimePopover due_datetime_popover;
    private Gtk.Revealer due_datetime_popover_revealer;

    private Tasks.LocationPopover location_popover;
    private Gtk.Revealer location_popover_revealer;

    private Gtk.Stack state_stack;
    private Gtk.Image icon;
    private Gtk.CheckButton check;
    private Gtk.Entry summary_entry;
    private Gtk.Label description_label;
    private Gtk.Revealer revealer;
    private Gtk.Revealer description_label_revealer;
    private Gtk.Revealer task_detail_revealer;
    private Gtk.Revealer task_form_revealer;
    private Gtk.TextBuffer description_textbuffer;
    private unowned Gtk.StyleContext style_context;

    private static Gtk.CssProvider taskrow_provider;

    private TaskRow (ECal.Component task, E.Source source) {
        Object (task: task, source: source);
    }

    public TaskRow.for_source (E.Source source) {
        var task = new ECal.Component ();
        task.set_new_vtype (ECal.ComponentVType.TODO);

        Object (task: task, source: source);
    }

    public TaskRow.for_component (ECal.Component task, E.Source source, bool is_scheduled_view = false) {
        Object (source: source, task: task, is_scheduled_view: is_scheduled_view);
    }

    static construct {
        taskrow_provider = new Gtk.CssProvider ();
        taskrow_provider.load_from_resource ("io/elementary/tasks/TaskRow.css");
    }

    construct {
        can_focus = false;
        created = calcomponent_created (task);

        // GTasks tasks only have date on due time, so only show the date
        bool is_gtask = false;
        E.SourceRegistry? registry = null;
        try {
            registry = Application.model.get_registry_sync ();
            is_gtask = Application.model.get_collection_backend_name (source, registry) == "google";
        } catch (Error e) {
            warning ("unable to get the registry, assuming task is not from gtask");
        }

        icon = new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.MENU);
        icon.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        check = new Gtk.CheckButton () {
            valign = Gtk.Align.CENTER
        };

        state_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        state_stack.add (icon);
        state_stack.add (check);

        summary_entry = new Gtk.Entry ();

        unowned Gtk.StyleContext summary_entry_context = summary_entry.get_style_context ();
        summary_entry_context.add_class (Gtk.STYLE_CLASS_FLAT);
        summary_entry_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        due_datetime_popover = new Tasks.DateTimePopover ();

        if (is_gtask) {
            due_datetime_popover.hide_timepicker ();
        }

        due_datetime_popover_revealer = new Gtk.Revealer () {
            margin_end = 6,
            reveal_child = false,
            transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT
        };
        due_datetime_popover_revealer.add (due_datetime_popover);

        due_datetime_popover.value_format.connect ((value) => {
            due_datetime_popover.get_style_context ().remove_class ("error");
            if (value == null) {
                return null;
            }
            var today = new GLib.DateTime.now_local ();
            if (today.compare (value) > 0 && !completed) {
                due_datetime_popover.get_style_context ().add_class ("error");
            }

            if (is_gtask) {
                if (is_scheduled_view) {
                    return null;
                } else {
                    return _("%s").printf (Tasks.Util.get_relative_date (value));
                }
            } else {
                var h24_settings = new GLib.Settings ("org.gnome.desktop.interface");
                var format = h24_settings.get_string ("clock-format");

                if (is_scheduled_view) {
                    return _("%s").printf (
                        value.format (Granite.DateTime.get_default_time_format (format.contains ("12h")))
                    );
                } else {
                    ///TRANSLATORS: Represents due date and time of a task, e.g. "Tomorrow at 9:00 AM"
                    return _("%s at %s").printf (
                        Tasks.Util.get_relative_date (value),
                        value.format (Granite.DateTime.get_default_time_format (format.contains ("12h")))
                    );
                }
            }
        });

        due_datetime_popover.value_changed.connect ((value) => {
            if (!task_form_revealer.reveal_child) {
                if (value == null) {
                    due_datetime_popover_revealer.reveal_child = false;
                }
                save_task (task);
            }
        });

        location_popover = new Tasks.LocationPopover ();

        location_popover_revealer = new Gtk.Revealer () {
            margin_end = 6,
            reveal_child = false,
            transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT
        };
        location_popover_revealer.add (location_popover);

        location_popover.value_format.connect ((value) => {
            if (value == null) {
                return null;
            }
            var location = (value.display_name == null ? value.postal_address : value.display_name);

            switch (value.proximity) {
                case Tasks.LocationProximity.ARRIVE:
                    return _("Arriving: %s").printf (location);

                case Tasks.LocationProximity.DEPART:
                    return _("Leaving: %s").printf (location);

                default:
                    return location;
            }
        });

        location_popover.value_changed.connect ((value) => {
            if (!task_form_revealer.reveal_child) {
                if (value == null) {
                    location_popover_revealer.reveal_child = false;
                }
                save_task (task);
            }
        });

        description_label = new Gtk.Label (null) {
            xalign = 0,
            lines = 1,
            ellipsize = Pango.EllipsizeMode.END
        };
        description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        description_label_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT,
            reveal_child = false
        };
        description_label_revealer.add (description_label);

        var task_grid = new Gtk.Grid ();
        task_grid.add (due_datetime_popover_revealer);
        task_grid.add (location_popover_revealer);
        task_grid.add (description_label_revealer);

        task_detail_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP
        };
        task_detail_revealer.add (task_grid);

        var description_textview = new Gtk.TextView () {
            border_width = 12,
            height_request = 140,
            accepts_tab = false
        };
        description_textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);

        description_textbuffer = new Gtk.TextBuffer (null);
        description_textview.set_buffer (description_textbuffer);

        var description_frame = new Gtk.Frame (null) {
            hexpand = true
        };
        description_frame.add (description_textview);

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));

        var save_button = new Gtk.Button.with_label (created ? _("Save Changes") : _("Add Task"));
        save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL) {
            baseline_position = Gtk.BaselinePosition.CENTER,
            margin_top = 12,
            spacing = 6
        };
        button_box.set_layout (Gtk.ButtonBoxStyle.END);
        button_box.add (cancel_button);
        button_box.add (save_button);

        var form_grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 12,
            margin_top = margin_bottom = 6
        };
        form_grid.attach (description_frame, 0, 0);
        form_grid.attach (button_box, 0, 1);

        task_form_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN
        };
        task_form_revealer.add (form_grid);

        var grid = new Gtk.Grid () {
            margin = 6,
            margin_start = margin_end = 12,
            column_spacing = 6,
            row_spacing = 3
        };
        grid.attach (state_stack, 0, 0);
        grid.attach (summary_entry, 1, 0);
        grid.attach (task_detail_revealer, 1, 1);
        grid.attach (task_form_revealer, 1, 2);

        revealer = new Gtk.Revealer () {
            reveal_child = true
        };
        revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        revealer.add (grid);

        var handle = new Gtk.EventBox () {
            expand = true,
            above_child = false
        };
        handle.add_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
        handle.add (revealer);

        add (handle);
        margin_start = margin_end = 12;

        style_context = get_style_context ();
        style_context.add_class (Granite.STYLE_CLASS_ROUNDED);
        style_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (created) {
            check.show ();
            state_stack.visible_child = check;

            var delete_button = new Gtk.Button.with_label (_("Delete Task"));
            delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            button_box.add (delete_button);
            button_box.set_child_secondary (delete_button, true);

            delete_button.clicked.connect (() => {
                cancel_edit ();
                remove_request ();
                task_removed (task);
            });
        }

        check.toggled.connect (() => {
            if (task == null) {
                return;
            }
            task_completed (task);
        });

        summary_entry.activate.connect (() => {
            if (created || (summary_entry.text != null && summary_entry.text.strip ().length > 0)) {
                save_task (task);
            }
            cancel_edit ();
        });

        summary_entry.grab_focus.connect (() => {
            reveal_child_request (true);
        });

        description_textview.button_press_event.connect ((sender, event) => {
            if (event.type == Gdk.EventType.BUTTON_PRESS && !description_textview.has_focus) {
                description_textview.grab_focus ();
                return Gdk.EVENT_STOP;
            }
            return Gdk.EVENT_PROPAGATE;
        });

        cancel_button.clicked.connect (() => {
            cancel_edit ();
        });

        key_release_event.connect ((event) => {
            if (event.keyval == Gdk.Key.Escape) {
                cancel_edit ();
            }
        });

        save_button.clicked.connect (() => {
            save_task (task);
            cancel_edit ();
        });

        notify["task"].connect (() => {
            update_request ();
        });

        build_drag_and_drop ();
        update_request ();
    }

    private void reset_create () {
        var empty_task = new ECal.Component ();
        empty_task.set_new_vtype (ECal.ComponentVType.TODO);
        task = empty_task;
    }

    private void cancel_edit () {
        if (created) {
            unselect ();
        } else {
            unselect ();
            reset_create ();
        }
        var icalcomponent = task.get_icalcomponent ();
        summary_entry.text = icalcomponent.get_summary () == null ? "" : icalcomponent.get_summary ();  // vala-lint=line-length
        due_datetime_popover.value = icalcomponent.get_due ().is_null_time () ? null : Util.ical_to_date_time (icalcomponent.get_due ());
        location_popover.value = Util.get_ecalcomponent_location (task);
        reveal_child_request (false);
    }

    private void save_task (ECal.Component task) {
        unowned ICal.Component ical_task = task.get_icalcomponent ();

        if (due_datetime_popover.value != null) {
            var due_icaltime = Util.date_time_to_ical (due_datetime_popover.value, due_datetime_popover.value);
            ical_task.set_due (due_icaltime);
            ical_task.set_dtstart (due_icaltime);
        } else {
            var null_icaltime = new ICal.Time.null_time ();

            ical_task.set_due (null_icaltime);
            ical_task.set_dtstart (null_icaltime);
        }

        Util.set_ecalcomponent_location (task, location_popover.value);

        // Clear the old description
        int count = ical_task.count_properties (ICal.PropertyKind.DESCRIPTION_PROPERTY);
        for (int i = 0; i < count; i++) {
            ICal.Property remove_prop;
            remove_prop = ical_task.get_first_property (ICal.PropertyKind.DESCRIPTION_PROPERTY);
            ical_task.remove_property (remove_prop);
        }

        // Add the new description - if we have any
        var description = description_textbuffer.text;
        if (description != null && description.strip ().length > 0) {
            var property = new ICal.Property (ICal.PropertyKind.DESCRIPTION_PROPERTY);
            property.set_description (description.strip ());
            ical_task.add_property (property);
        }

        task.get_icalcomponent ().set_summary (summary_entry.text);
        task_changed (task);
    }

    public void reveal_child_request (bool value) {
        task_form_revealer.reveal_child = value;
        task_details_reveal_request (!value);

        if (value) {
            style_context.add_class ("collapsed");
            style_context.add_class (Granite.STYLE_CLASS_CARD);

        } else {
            style_context.remove_class (Granite.STYLE_CLASS_CARD);
            style_context.remove_class ("collapsed");
        }
    }

    public void update_request () {
        if (!is_scheduled_view) {
            Tasks.Application.set_task_color (source, check);
        }

        var default_due_datetime = new DateTime.now_local ().add_hours (1);
        default_due_datetime = default_due_datetime.add_minutes (-default_due_datetime.get_minute ());
        default_due_datetime = default_due_datetime.add_seconds (-default_due_datetime.get_seconds ());

        if (task == null || !created) {
            state_stack.set_visible_child (icon);

            completed = false;
            check.active = completed;
            summary_entry.text = "";
            summary_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            summary_entry.get_style_context ().add_class ("add-task");
            task_detail_revealer.reveal_child = false;
            task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);

            due_datetime_popover_revealer.reveal_child = false;
            location_popover_revealer.reveal_child = false;

            description_label_revealer.reveal_child = false;
            description_textbuffer.text = "";

        } else if (created) {
            state_stack.set_visible_child (check);

            unowned ICal.Component ical_task = task.get_icalcomponent ();
            completed = ical_task.get_status () == ICal.PropertyStatus.COMPLETED;
            check.active = completed;

            if (ical_task.get_description () != null) {
                description_textbuffer.text = ical_task.get_description ();
            } else {
                description_textbuffer.text = "";
            }

            summary_entry.text = ical_task.get_summary () == null ? "" : ical_task.get_summary ();
            summary_entry.get_style_context ().remove_class ("add-task");

            if (completed) {
                summary_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            } else {
                summary_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            }

            if (ical_task.get_due ().is_null_time ()) {
                due_datetime_popover_revealer.reveal_child = false;
            } else {
                var due_datetime = Util.ical_to_date_time (ical_task.get_due ());
                due_datetime_popover.value = due_datetime;
                due_datetime_popover_revealer.reveal_child = true;
            }

            var location = Util.get_ecalcomponent_location (task);
            if (location == null) {
                location_popover_revealer.reveal_child = false;
            } else {
                location_popover.value = location;
                location_popover_revealer.reveal_child = true;
            }

            if (ical_task.get_description () == null) {
                description_label_revealer.reveal_child = false;

            } else {
                var description = Tasks.Util.line_break_to_space (ical_task.get_description ());

                if (description != null && description.length > 0) {
                    description_label.label = description;
                    description_label_revealer.reveal_child = true;
                } else {
                    description_label_revealer.reveal_child = false;
                }
            }

            task_details_reveal_request (true);
        }
    }

    private void task_details_reveal_request (bool value) {
        description_label_revealer.reveal_child = value && description_label.label != null && description_label.label.strip ().length > 0;
        due_datetime_popover_revealer.reveal_child = !value || due_datetime_popover.value != null;
        location_popover_revealer.reveal_child = !value || location_popover.value != null;

        task_detail_revealer.reveal_child = description_label_revealer.reveal_child ||
            due_datetime_popover_revealer.reveal_child ||
            location_popover_revealer.reveal_child;
    }

    private void remove_request () {
        revealer.reveal_child = false;
        GLib.Timeout.add (revealer.transition_duration, () => {
            destroy ();
            return GLib.Source.REMOVE;
        });
    }

    /*
     * Returns whether or not a ECal.Component was created in the backend EDS.
     */
    private bool calcomponent_created (ECal.Component comp) {
        if (comp == null) {
            return false;
        }

        ICal.Time? created = comp.get_created ();
        if (created == null) {
            return false;
        }

        return created.is_valid_time ();
    }

    private void build_drag_and_drop () {
        Gtk.drag_source_set (this, Gdk.ModifierType.BUTTON1_MASK, TARGET_ENTRIES, Gdk.DragAction.MOVE);
        Gtk.drag_dest_set (this, Gtk.DestDefaults.ALL, TARGET_ENTRIES, Gdk.DragAction.MOVE);

        drag_data_get.connect (on_drag_data_get);
        drag_data_received.connect (on_drag_data_received);

        drag_begin.connect (on_drag_begin);
    }

    private void on_drag_data_get (Gtk.Widget widget, Gdk.DragContext context,
        Gtk.SelectionData selection_data, uint target_type, uint time) {

        uchar[] data = new uchar[(sizeof (Gtk.ListBoxRow))];
        ((Gtk.Widget[])data)[0] = widget;

        selection_data.set (
            Gdk.Atom.intern_static_string ("GTK_LIST_BOX_ROW"), 32, data
        );
    }

    private void on_drag_data_received (Gdk.DragContext context, int x, int y,
        Gtk.SelectionData selection_data, uint target_type, uint time) {

        var data = ((Gtk.Widget[]) selection_data.get_data ())[0];
        var source_row = (Gtk.ListBoxRow) data;
        var target_row = this;

        if (source_row == target_row) {
            return;
        }

        var source_list = (Gtk.ListBox) source_row.parent;
        var target_list = (Gtk.ListBox) target_row.parent;
        var target_list_position = target_row.get_index ();

        source_list.remove (source_row);
        target_list.insert (source_row, target_list_position);
    }

    private void on_drag_begin (Gtk.Widget widget, Gdk.DragContext drag_context) {
        var row = widget.get_ancestor (typeof (Gtk.ListBoxRow));

        Gtk.Allocation row_alloc;
        row.get_allocation (out row_alloc);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, row_alloc.width, row_alloc.height);
        var cairo_context = new Cairo.Context (surface);

        var style_context = row.get_style_context ();
        style_context.add_class ("during-dnd");
        row.draw_to_cairo_context (cairo_context);
        style_context.remove_class ("during-dnd");

        int drag_icon_x, drag_icon_y;
        widget.translate_coordinates (row, 0, 0, out drag_icon_x, out drag_icon_y);
        surface.set_device_offset (-drag_icon_x, -drag_icon_y);

        Gtk.drag_set_icon_surface (drag_context, surface);
    }
}
