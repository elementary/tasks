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

    public bool completed { get; private set; }
    public E.Source source { get; construct; }
    public ECal.Component task { get; construct set; }

    private bool created;

    private Granite.Widgets.DatePicker due_datepicker;
    private Granite.Widgets.TimePicker due_timepicker;

    private Gtk.Stack state_stack;
    private Gtk.Image icon;
    private Gtk.CheckButton check;
    private Gtk.Entry summary_entry;
    private Gtk.Label description_label;
    private Gtk.Label due_label;
    private Gtk.Revealer revealer;
    private Gtk.Revealer description_label_revealer;
    private Gtk.Revealer due_label_revealer;
    private Gtk.Revealer task_detail_revealer;
    private Gtk.Revealer task_form_revealer;
    private Gtk.Switch due_switch;
    private Gtk.TextBuffer description_textbuffer;

    private static Gtk.CssProvider taskrow_provider;

    private TaskRow (ECal.Component task, E.Source source) {
        Object (task: task, source: source);
    }

    public TaskRow.for_source (E.Source source) {
        var task = new ECal.Component ();
        task.set_new_vtype (ECal.ComponentVType.TODO);

        Object (task: task, source: source);
    }

    public TaskRow.for_component (ECal.Component task, E.Source source) {
        Object (source: source, task: task);
    }

    static construct {
        taskrow_provider = new Gtk.CssProvider ();
        taskrow_provider.load_from_resource ("io/elementary/tasks/TaskRow.css");
    }

    construct {
        created = calcomponent_created (task);

        icon = new Gtk.Image.from_icon_name ("list-add-symbolic", Gtk.IconSize.MENU);
        icon.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        check = new Gtk.CheckButton ();
        check.valign = Gtk.Align.CENTER;

        state_stack = new Gtk.Stack ();
        state_stack.valign = Gtk.Align.START;
        state_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
        state_stack.get_style_context ().add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        state_stack.add (icon);
        state_stack.add (check);

        summary_entry = new Gtk.Entry ();
        summary_entry.placeholder_text = _("Add task to list, press Enter to save…");

        unowned Gtk.StyleContext summary_entry_context = summary_entry.get_style_context ();
        summary_entry_context.add_class (Gtk.STYLE_CLASS_FLAT);
        summary_entry_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var due_image = new Gtk.Image.from_icon_name ("office-calendar-symbolic", Gtk.IconSize.BUTTON);

        due_label = new Gtk.Label (null);
        due_label.margin_start = 3;

        var due_grid = new Gtk.Grid ();
        due_grid.margin_end = 6;
        due_grid.add (due_image);
        due_grid.add (due_label);

        unowned Gtk.StyleContext due_grid_context = due_grid.get_style_context ();
        due_grid_context.add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        due_grid_context.add_class ("due-date");

        due_label_revealer = new Gtk.Revealer ();
        due_label_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
        due_label_revealer.add (due_grid);

        description_label = new Gtk.Label (null);
        description_label.xalign = 0;
        description_label.lines = 1;
        description_label.ellipsize = Pango.EllipsizeMode.END;
        description_label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);

        description_label_revealer = new Gtk.Revealer ();
        description_label_revealer.reveal_child = false;
        description_label_revealer.add (description_label);

        var task_grid = new Gtk.Grid ();
        task_grid.add (due_label_revealer);
        task_grid.add (description_label_revealer);

        task_detail_revealer = new Gtk.Revealer ();
        task_detail_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        task_detail_revealer.add (task_grid);

        due_switch = new Gtk.Switch ();
        due_switch.valign = Gtk.Align.CENTER;

        var due_label = new Gtk.Label (_("Schedule:"));

        due_datepicker = new Granite.Widgets.DatePicker ();
        due_datepicker.hexpand = true;

        due_timepicker = new Granite.Widgets.TimePicker ();
        due_timepicker.hexpand = true;

        var description_textview = new Gtk.TextView ();
        description_textview.border_width = 12;
        description_textview.height_request = 140;
        description_textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
        description_textview.accepts_tab = false;

        description_textbuffer = new Gtk.TextBuffer (null);
        description_textview.set_buffer (description_textbuffer);

        var description_frame = new Gtk.Frame (null);
        description_frame.add (description_textview);

        var cancel_button = new Gtk.Button ();
        cancel_button.label = _("Cancel");

        var save_button = new Gtk.Button ();
        save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        save_button.label = created ? _("Save Changes") : _("Add Task");

        var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        button_box.baseline_position = Gtk.BaselinePosition.CENTER;
        button_box.margin_top = 12;
        button_box.spacing = 6;
        button_box.set_layout (Gtk.ButtonBoxStyle.END);
        button_box.add (cancel_button);
        button_box.add (save_button);

        var form_grid = new Gtk.Grid ();
        form_grid.column_spacing = 12;
        form_grid.row_spacing = 12;
        form_grid.margin_bottom = 6;
        form_grid.attach (due_label, 0, 0);
        form_grid.attach (due_switch, 1, 0);
        form_grid.attach (due_datepicker, 2, 0);
        form_grid.attach (due_timepicker, 3, 0);
        form_grid.attach (description_frame, 0, 1, 4);
        form_grid.attach (button_box, 0, 2, 4);

        task_form_revealer = new Gtk.Revealer ();
        task_form_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
        task_form_revealer.add (form_grid);

        var grid = new Gtk.Grid ();
        grid.margin = 6;
        grid.margin_start = grid.margin_end = 24;
        grid.column_spacing = 6;
        grid.row_spacing = 3;
        grid.attach (state_stack, 0, 0);
        grid.attach (summary_entry, 1, 0);
        grid.attach (task_detail_revealer, 1, 1);
        grid.attach (task_form_revealer, 1, 2);

        revealer = new Gtk.Revealer ();
        revealer.reveal_child = true;
        revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_UP;
        revealer.add (grid);

        add (revealer);
        get_style_context ().add_provider (taskrow_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        if (created) {
            check.show ();
            state_stack.visible_child = check;

            var delete_button = new Gtk.Button ();
            delete_button.label = _("Delete Task");
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
            activate ();
        });

        description_textview.button_press_event.connect (() => {
            description_textview.grab_focus ();
            return Gdk.EVENT_STOP;
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
        update_request ();

        due_switch.bind_property ("active", due_datepicker, "sensitive", GLib.BindingFlags.SYNC_CREATE);
        due_switch.bind_property ("active", due_timepicker, "sensitive", GLib.BindingFlags.SYNC_CREATE);
    }

    private void reset_create () {
        var empty_task = new ECal.Component ();
        empty_task.set_new_vtype (ECal.ComponentVType.TODO);
        task = empty_task;
    }

    private void cancel_edit () {
        if (created) {
            move_focus (Gtk.DirectionType.TAB_BACKWARD);
        } else {
            move_focus (Gtk.DirectionType.TAB_FORWARD);
            reset_create ();
        }
        summary_entry.text = task.get_icalcomponent ().get_summary () == null ? "" : task.get_icalcomponent ().get_summary ();  // vala-lint=line-length
        reveal_child_request (false);
    }

    private void save_task (ECal.Component task) {
        unowned ICal.Component ical_task = task.get_icalcomponent ();

        if (due_switch.active) {
            ical_task.set_due (Util.date_time_to_ical (due_datepicker.date, due_timepicker.time));
            ical_task.set_due (Util.date_time_to_ical (due_datepicker.date, due_timepicker.time));
        } else {
#if E_CAL_2_0
            ical_task.set_due (new ICal.Time.null_time ());
#else
            ical_task.set_due (ICal.Time.null_time ());
#endif
        }

        // Clear the old description
        int count = ical_task.count_properties (ICal.PropertyKind.DESCRIPTION_PROPERTY);
        for (int i = 0; i < count; i++) {
#if E_CAL_2_0
            ICal.Property remove_prop;
#else
            unowned ICal.Property remove_prop;
#endif
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

        unowned Gtk.StyleContext style_context = get_style_context ();

        if (value) {
            style_context.add_class ("collapsed");
            style_context.add_class (Granite.STYLE_CLASS_CARD);
            style_context.add_class (Gtk.STYLE_CLASS_BACKGROUND);

        } else {
            style_context.remove_class (Gtk.STYLE_CLASS_BACKGROUND);
            style_context.remove_class (Granite.STYLE_CLASS_CARD);
            style_context.remove_class ("collapsed");
        }
    }

    public void update_request () {
        Tasks.Application.set_task_color (source, check);

        if (task == null || !created) {
            get_style_context ().add_class ("add-task");
            state_stack.set_visible_child (icon);

            completed = false;
            check.active = completed;
            summary_entry.text = "";
            summary_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            task_detail_revealer.reveal_child = false;
            task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);

            due_label_revealer.reveal_child = false;
            due_switch.active = false;
            due_datepicker.date = due_timepicker.time = new DateTime.now_local ();

            description_label_revealer.reveal_child = false;
            description_textbuffer.text = "";

        } else if (created) {
            get_style_context ().remove_class ("add-task");
            state_stack.set_visible_child (check);

            unowned ICal.Component ical_task = task.get_icalcomponent ();
            completed = ical_task.get_status () == ICal.PropertyStatus.COMPLETED;
            check.active = completed;

            if (ical_task.get_due ().is_null_time ()) {
                due_switch.active = false;
                due_datepicker.date = due_timepicker.time = new DateTime.now_local ();
            } else {
                var due_date_time = Util.ical_to_date_time (ical_task.get_due ());
                due_datepicker.date = due_timepicker.time = due_date_time;

                due_switch.active = true;
            }

            if (ical_task.get_description () != null) {
                description_textbuffer.text = ical_task.get_description ();
            } else {
                description_textbuffer.text = "";
            }

            summary_entry.text = ical_task.get_summary () == null ? "" : ical_task.get_summary ();

            if (completed) {
                summary_entry.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            } else {
                summary_entry.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
                task_detail_revealer.get_style_context ().remove_class (Gtk.STYLE_CLASS_DIM_LABEL);
            }


            if (ical_task.get_due ().is_null_time () ) {
                due_label_revealer.reveal_child = false;
            } else {
                var due_date_time = Util.ical_to_date_time (ical_task.get_due ());
                var h24_settings = new GLib.Settings ("org.gnome.desktop.interface");
                var format = h24_settings.get_string ("clock-format");

                due_label.label = Granite.DateTime.get_relative_datetime (due_date_time);
                due_label.tooltip_text = _("%s at %s").printf (
                    due_date_time.format (Granite.DateTime.get_default_date_format (true)),
                    due_date_time.format (Granite.DateTime.get_default_time_format (format.contains ("12h")))
                );

                var today = new GLib.DateTime.now_local ();
                if (today.compare (due_date_time) > 0 && !completed) {
                    get_style_context ().add_class ("past-due");
                } else {
                    get_style_context ().remove_class ("past-due");
                }

                due_label_revealer.reveal_child = true;
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
        if (value && (due_label_revealer.reveal_child || description_label_revealer.reveal_child)) {
            task_detail_revealer.reveal_child = true;
        } else {
            task_detail_revealer.reveal_child = false;
        }
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
#if E_CAL_2_0
        var created = comp.get_created ();
#else
        ICal.Time created;
        comp.get_created (out created);
#endif
        return !created.is_null_time ();
    }
}
