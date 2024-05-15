/*
 * Copyright 2019-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Tasks.Widgets.TaskRow : Gtk.ListBoxRow {

    public signal void task_completed (ECal.Component task);
    public signal void task_changed (ECal.Component task);
    public signal void task_removed (ECal.Component task);
    public signal void unselect (Gtk.ListBoxRow row);

    public bool completed { get; private set; }
    public E.Source source { get; construct; }
    public ECal.Component task { get; construct set; }
    public bool is_scheduled_view { get; construct; }

    private bool created;

    private Tasks.Widgets.EntryPopover.DateTime due_datetime_popover;
    private Gtk.Revealer due_datetime_popover_revealer;

    private Tasks.Widgets.EntryPopover.Location location_popover;
    private Gtk.Revealer location_popover_revealer;

    private Gtk.EventBox event_box;
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

    private Gtk.EventControllerKey key_controller;

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

        summary_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        due_datetime_popover = new Tasks.Widgets.EntryPopover.DateTime ();

        if (is_gtask) {
            due_datetime_popover.hide_timepicker ();
        }

        due_datetime_popover_revealer = new Gtk.Revealer () {
            child = due_datetime_popover,
            margin_end = 6,
            reveal_child = false,
            transition_type = SLIDE_RIGHT
        };

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

        location_popover = new Tasks.Widgets.EntryPopover.Location ();

        location_popover_revealer = new Gtk.Revealer () {
            child = location_popover,
            margin_end = 6,
            reveal_child = false,
            transition_type = SLIDE_RIGHT
        };

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

        // Should not use a transition that varies the width else label aligning and ellipsizing is incorrect.
        description_label_revealer = new Gtk.Revealer () {
            child = description_label,
            transition_type = CROSSFADE,
            reveal_child = false
        };

        var task_box = new Gtk.Box (HORIZONTAL, 0);
        task_box.add (due_datetime_popover_revealer);
        task_box.add (location_popover_revealer);
        task_box.add (description_label_revealer);

        task_detail_revealer = new Gtk.Revealer () {
            child = task_box,
            transition_type = SLIDE_UP
        };

        var description_textview = new Granite.HyperTextView () {
            top_margin = 12,
            right_margin = 12,
            bottom_margin = 12,
            left_margin = 12,
            height_request = 140,
            accepts_tab = false
        };
        description_textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);

        description_textbuffer = new Gtk.TextBuffer (null);
        description_textview.set_buffer (description_textbuffer);

        var description_frame = new Gtk.Frame (null) {
            child = description_textview,
            hexpand = true
        };

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));

        var save_button = new Gtk.Button.with_label (created ? _("Save Changes") : _("Add Task"));
        save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var right_buttons_box = new Gtk.Box (HORIZONTAL, 6) {
            hexpand = true,
            halign = END,
            homogeneous = true
        };
        right_buttons_box.add (cancel_button);
        right_buttons_box.add (save_button);

        var button_box = new Gtk.Box (HORIZONTAL, 6) {
            margin_top = 12
        };
        button_box.get_style_context ().add_class ("button-box");
        button_box.pack_end (right_buttons_box);

        var form_box = new Gtk.Box (VERTICAL, 12) {
            margin_top = 6,
            margin_bottom = 6
        };
        form_box.add (description_frame);
        form_box.add (button_box);

        task_form_revealer = new Gtk.Revealer () {
            child = form_box,
            transition_type = SLIDE_DOWN
        };

        var grid = new Gtk.Grid () {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 12,
            margin_end = 12,
            column_spacing = 6,
            row_spacing = 3
        };
        grid.attach (state_stack, 0, 0);
        grid.attach (summary_entry, 1, 0);
        grid.attach (task_detail_revealer, 1, 1);
        grid.attach (task_form_revealer, 1, 2);

        revealer = new Gtk.Revealer () {
            child = grid,
            reveal_child = true,
            transition_type = SLIDE_UP
        };

        event_box = new Gtk.EventBox () {
            hexpand = true,
            vexpand = true,
            above_child = false
        };
        event_box.add_events (
            Gdk.EventMask.BUTTON_PRESS_MASK |
            Gdk.EventMask.BUTTON_RELEASE_MASK
        );
        event_box.add (revealer);

        child = event_box;
        margin_start = 12;
        margin_end = 12;

        get_style_context ().add_class ("task");
        get_style_context ().add_class (Granite.STYLE_CLASS_ROUNDED);

        if (created) {
            check.show ();
            state_stack.visible_child = check;

            var delete_button = new Gtk.Button.with_label (_("Delete Task")) {
                halign = START
            };
            delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

            button_box.pack_start (delete_button);

            delete_button.clicked.connect (() => {
                end_editing ();
                remove_request ();
                task_removed (task);
            });
        }

        build_drag_and_drop ();

        key_controller = new Gtk.EventControllerKey (this);

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
            end_editing ();
        });

        summary_entry.grab_focus.connect (() => {
            activate ();
        });

        cancel_button.clicked.connect (() => {
            reset_form ();
            end_editing ();
        });

        key_controller.key_released.connect ((keyval, keycode, state) => {
            if (keyval == Gdk.Key.Escape) {
                reset_form ();
                end_editing ();
            }
        });

        save_button.clicked.connect (() => {
            save_task (task);
            end_editing ();
        });

        notify["task"].connect (() => {
            update_request ();
        });
        update_request ();
    }

    private void end_editing () {
        unselect (this);
        reveal_child_request (false);

        if (!created) {
            reset_form ();
        }
    }

    private void reset_form () {
        if (!created) {
            var empty_task = new ECal.Component ();
            empty_task.set_new_vtype (ECal.ComponentVType.TODO);
            task = empty_task;
        }

        var icalcomponent = task.get_icalcomponent ();
        summary_entry.text = icalcomponent.get_summary () == null ? "" : icalcomponent.get_summary ();  // vala-lint=line-length
        description_textbuffer.text = icalcomponent.get_description () == null ? "" : icalcomponent.get_description ();  // vala-lint=line-length
        due_datetime_popover.value = icalcomponent.get_due ().is_null_time () ? null : Util.ical_to_date_time_local (icalcomponent.get_due ());  // vala-lint=line-length
        location_popover.value = Util.get_ecalcomponent_location (task);
    }

    private void save_task (ECal.Component task) {
        unowned ICal.Component ical_task = task.get_icalcomponent ();

        ICal.Time new_icaltime;
        if (due_datetime_popover.value == null) {
            new_icaltime = new ICal.Time.null_time ();
        } else {
            var task_tz = ical_task.get_due ().get_timezone ();
            if (task_tz != null) {
                // If the task has a timezone, must convert from displayed local time
                new_icaltime = Util.datetimes_to_icaltime (due_datetime_popover.value, due_datetime_popover.value, ECal.util_get_system_timezone ());
                new_icaltime.convert_to_zone_inplace (task_tz);
            } else {
                // Use floating timezone if no timezone already exists
                new_icaltime = Util.datetimes_to_icaltime (due_datetime_popover.value, due_datetime_popover.value, null);
            }
        }

        ical_task.set_due (new_icaltime);
        ical_task.set_dtstart (new_icaltime);

        Util.set_ecalcomponent_location (task, location_popover.value);

        ical_task.set_summary (summary_entry.text);
        ical_task.set_description (description_textbuffer.text);

        task_changed (task);
    }

    public void reveal_child_request (bool value) {
        task_form_revealer.reveal_child = value;
        task_details_reveal_request (!value);

        if (value) {
            get_style_context ().add_class ("collapsed");
            get_style_context ().add_class (Granite.STYLE_CLASS_CARD);

        } else {
            get_style_context ().remove_class (Granite.STYLE_CLASS_CARD);
            get_style_context ().remove_class ("collapsed");
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
                var due_datetime = Util.ical_to_date_time_local (ical_task.get_due ());
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
                description_label.label = "";
                description_label_revealer.reveal_child = false;

            } else {
                var description = Tasks.Util.line_break_to_space (ical_task.get_description ());

                if (description != null && description.length > 0) {
                    description_label.label = description;
                    description_label_revealer.reveal_child = true;
                } else {
                    description_label.label = "";
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
        if (!created || is_scheduled_view) {
            return;
        }
        Gtk.drag_source_set (event_box, Gdk.ModifierType.BUTTON1_MASK, Application.DRAG_AND_DROP_TASK_DATA, Gdk.DragAction.MOVE);

        event_box.drag_begin.connect (on_drag_begin);
        event_box.drag_data_get.connect (on_drag_data_get);
        event_box.drag_data_delete.connect (on_drag_data_delete);
    }

    private void on_drag_begin (Gdk.DragContext context) {
        Gtk.Allocation alloc;
        get_allocation (out alloc);

        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
        var cairo_context = new Cairo.Context (surface);

        var had_cards_class = get_style_context ().has_class (Granite.STYLE_CLASS_CARD);

        get_style_context ().add_class ("drag-active");
        if (had_cards_class) {
            get_style_context ().remove_class (Granite.STYLE_CLASS_CARD);
        }
        draw_to_cairo_context (cairo_context);
        if (had_cards_class) {
            get_style_context ().add_class (Granite.STYLE_CLASS_CARD);
        }
        get_style_context ().remove_class ("drag-active");

        int drag_icon_x, drag_icon_y;
        translate_coordinates (this, 0, 0, out drag_icon_x, out drag_icon_y);
        surface.set_device_offset (-drag_icon_x, -drag_icon_y);

        Gtk.drag_set_icon_surface (context, surface);
    }

    private void on_drag_data_get (Gtk.Widget widget, Gdk.DragContext context, Gtk.SelectionData selection_data, uint target_type, uint time) {
        var task_uri = "task://%s/%s".printf (source.uid, task.get_uid ());
        selection_data.set_uris ({ task_uri });
    }

    private void on_drag_data_delete (Gdk.DragContext context) {
        destroy ();
    }
}
