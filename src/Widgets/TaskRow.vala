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

    private Gtk.DragSource drag_source;

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

    class construct {
        set_css_name ("task-row");
    }

    static construct {
        var style_provider = new Gtk.CssProvider ();
        style_provider.load_from_resource ("io/elementary/tasks/TaskRow.css");
        Gtk.StyleContext.add_provider_for_display (Gdk.Display.get_default (), style_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }

    construct {
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

        icon = new Gtk.Image.from_icon_name ("list-add-symbolic");
        icon.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        check = new Gtk.CheckButton () {
            valign = Gtk.Align.CENTER,
            css_classes = { "task-row-check" }
        };

        state_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        state_stack.add_child (icon);
        state_stack.add_child (check);

        summary_entry = new Gtk.Entry ();
        summary_entry.add_css_class (Granite.STYLE_CLASS_FLAT);

        due_datetime_popover = new Tasks.Widgets.EntryPopover.DateTime ();

        if (is_gtask) {
            due_datetime_popover.hide_timepicker ();
        }

        due_datetime_popover_revealer = new Gtk.Revealer () {
            margin_end = 6,
            reveal_child = false,
            transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT,
            child = due_datetime_popover
        };

        due_datetime_popover.value_format.connect ((value) => {
            due_datetime_popover.remove_css_class ("error");
            if (value == null) {
                return null;
            }
            var today = new GLib.DateTime.now_local ();
            if (today.compare (value) > 0 && !completed) {
                due_datetime_popover.add_css_class ("error");
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
            margin_end = 6,
            reveal_child = false,
            transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT,
            child = location_popover
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
        description_label.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);

        // Should not use a transition that varies the width else label aligning and ellipsizing is incorrect.
        description_label_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.CROSSFADE,
            reveal_child = false,
            child = description_label
        };

<<<<<<< HEAD
        var task_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        task_box.append (due_datetime_popover_revealer);
        task_box.append (location_popover_revealer);
        task_box.append (description_label_revealer);
=======
        var task_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        task_box.add (due_datetime_popover_revealer);
        task_box.add (location_popover_revealer);
        task_box.add (description_label_revealer);
>>>>>>> master

        task_detail_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP,
            child = task_box
        };
<<<<<<< HEAD
=======
        task_detail_revealer.add (task_box);
>>>>>>> master

        var description_textview = new Granite.HyperTextView () {
            //  border_width = 12,
            height_request = 140,
            accepts_tab = false
        };
        description_textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);

        description_textbuffer = new Gtk.TextBuffer (null);
        description_textview.set_buffer (description_textbuffer);

        var description_frame = new Gtk.Frame (null) {
            hexpand = true,
            child = description_textview
        };

        var buttons_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));
        buttons_size_group.add_widget (cancel_button);

        var save_button = new Gtk.Button.with_label (created ? _("Save Changes") : _("Add Task")) {
            css_classes = { Granite.STYLE_CLASS_SUGGESTED_ACTION }
        };
        buttons_size_group.add_widget (save_button);

        var right_buttons_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.END
        };
        right_buttons_box.append (cancel_button);
        right_buttons_box.append (save_button);

        var button_grid = new Gtk.Grid () {
            margin_top = 12,
            column_homogeneous = true,
            css_classes = { "button-box" }
        };
        button_grid.attach (right_buttons_box, 1, 0);

        var form_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_top = 6,
            margin_bottom = 6
        };
<<<<<<< HEAD
        form_box.append (description_frame);
        form_box.append (button_grid);
=======
        form_box.add (description_frame);
        form_box.add (button_box);
>>>>>>> master

        task_form_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN,
            child = form_box
        };
<<<<<<< HEAD
=======
        task_form_revealer.add (form_box);
>>>>>>> master

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
            reveal_child = true,
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP,
            child = grid
        };

<<<<<<< HEAD
        child = revealer;
        margin_start = 12;
        margin_end = 12;
=======
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
>>>>>>> master

        add_css_class (Granite.STYLE_CLASS_ROUNDED);

        if (created) {
            check.show ();
            state_stack.visible_child = check;

            var delete_button = new Gtk.Button.with_label (_("Delete Task")) {
                halign = Gtk.Align.START,
                css_classes = { Granite.STYLE_CLASS_DESTRUCTIVE_ACTION }
            };
            buttons_size_group.add_widget (delete_button);

            button_grid.attach (delete_button, 0, 0);

            delete_button.clicked.connect (() => {
                end_editing ();
                remove_request ();
                task_removed (task);
            });
        }

        build_drag_and_drop ();

        var key_controller = new Gtk.EventControllerKey ();
        add_controller (key_controller);

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

        var summary_entry_focus_controller = new Gtk.EventControllerFocus ();
        summary_entry.add_controller (summary_entry_focus_controller);
        summary_entry_focus_controller.enter.connect (() => {
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
            add_css_class ("collapsed");
            add_css_class (Granite.STYLE_CLASS_CARD);

        } else {
            remove_css_class (Granite.STYLE_CLASS_CARD);
            remove_css_class ("collapsed");
        }
    }

    public void update_request () {
        if (!is_scheduled_view) {
            // FIXME: check.get_first_child () is used because Gtk.StyleContext.add_provider works differently in Gtk4
            // Also, it's deprecated now, so we need to use Gtk.StyleContext.add_provider_for_display
            Tasks.Application.set_task_color (source, check.get_first_child ());
        }

        var default_due_datetime = new DateTime.now_local ().add_hours (1);
        default_due_datetime = default_due_datetime.add_minutes (-default_due_datetime.get_minute ());
        default_due_datetime = default_due_datetime.add_seconds (-default_due_datetime.get_seconds ());

        if (task == null || !created) {
            state_stack.set_visible_child (icon);

            completed = false;
            check.active = completed;
            summary_entry.text = "";
            summary_entry.remove_css_class (Granite.STYLE_CLASS_DIM_LABEL);
            summary_entry.add_css_class ("add-task");
            task_detail_revealer.reveal_child = false;
            task_detail_revealer.remove_css_class (Granite.STYLE_CLASS_DIM_LABEL);

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
            summary_entry.remove_css_class ("add-task");

            if (completed) {
                summary_entry.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.add_css_class (Granite.STYLE_CLASS_DIM_LABEL);
            } else {
                summary_entry.remove_css_class (Granite.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.remove_css_class (Granite.STYLE_CLASS_DIM_LABEL);
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

        drag_source = new Gtk.DragSource ();
        add_controller (drag_source);

        drag_source.prepare.connect (on_drag_prepare);
        drag_source.drag_begin.connect (on_drag_begin);
        drag_source.drag_cancel.connect (on_drag_cancel);
        drag_source.drag_end.connect (on_drag_end);
    }

    private int drag_offset_x;
    private int drag_offset_y;
    private bool had_cards_class;
    private bool is_canceled;

    private Gdk.ContentProvider? on_drag_prepare (double x, double y) {
        drag_offset_x = (int) x;
        drag_offset_y = (int) y;

        return new Gdk.ContentProvider.for_value ("task://%s/%s".printf (source.uid, task.get_uid ()));
    }

    private void on_drag_begin (Gdk.Drag drag) {
        drag_source.set_icon (new Gtk.WidgetPaintable (this), drag_offset_x, drag_offset_y);

        had_cards_class = has_css_class (Granite.STYLE_CLASS_CARD);
        is_canceled = false;

        add_css_class ("drag-active");
        if (had_cards_class) {
            remove_css_class (Granite.STYLE_CLASS_CARD);
        }
    }

    private bool on_drag_cancel (Gdk.Drag drag, Gdk.DragCancelReason reason) {
        is_canceled = true;

        return true;
    }

    private void on_drag_end (Gdk.Drag drag, bool delete_data) {
        if (is_canceled) {
            remove_css_class ("drag-active");
            if (had_cards_class) {
                add_css_class (Granite.STYLE_CLASS_CARD);
            }
        } else {
            ((Gtk.ListBox) parent).remove (this);
            destroy ();
        }
    }
}
