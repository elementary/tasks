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

public class Tasks.TaskSettingsPopover : Gtk.Popover {

    public ECal.Component task { get; construct; }

    public TaskSettingsPopover (ECal.Component task) {
        Object (task: task);
    }

    construct {
        unowned ICal.Component ical_task = task.get_icalcomponent ();

        var summary_entry = new Gtk.Entry ();
        summary_entry.margin = 12;
        summary_entry.margin_top = summary_entry.margin_bottom = 12;

        if (ical_task.get_summary () != null) {
            summary_entry.text = ical_task.get_summary ().strip ();
        }

        summary_entry.changed.connect (() => {
            if (summary_entry.text != null) {
                task.get_icalcomponent ().set_summary (summary_entry.text.strip ());
            } else {
                task.get_icalcomponent ().set_summary ("");
            }
        });

        var due_label = new Gtk.Label (_("Schedule"));
        due_label.hexpand = true;
        due_label.xalign = 0;

        var due_switch = new Gtk.Switch ();
        due_switch.active = !ical_task.get_due ().is_null_time ();

        var due_grid = new Gtk.Grid ();
        due_grid.column_spacing = 6;
        due_grid.add (due_label);
        due_grid.add (due_switch);

        var due_button = new Gtk.ModelButton ();
        due_button.margin_top = due_button.margin_bottom = 3;
        due_button.get_child ().destroy ();
        due_button.add (due_grid);

        var date_picker = new Granite.Widgets.DatePicker ();
        date_picker.hexpand = true;

        var time_picker = new Granite.Widgets.TimePicker ();
        time_picker.hexpand = true;

        var due_datetimepicker = new Gtk.Grid ();
        due_datetimepicker.column_spacing = 6;
        due_datetimepicker.margin_start = due_datetimepicker.margin_end = 12;
        due_datetimepicker.margin_bottom = 12;
        due_datetimepicker.add (date_picker);
        due_datetimepicker.add (time_picker);

        if (!ical_task.get_due ().is_null_time ()) {
            var due_date_time = Util.ical_to_date_time (ical_task.get_due ());
            date_picker.date = time_picker.time = due_date_time;
        }

        date_picker.date_changed.connect (() => {
            ical_task.set_due (Util.date_time_to_ical (date_picker.date, time_picker.time));
        });
        time_picker.time_changed.connect (() => {
            ical_task.set_due (Util.date_time_to_ical (date_picker.date, time_picker.time));
        });

        var description_textview = new Gtk.TextView ();
        description_textview.left_margin = description_textview.right_margin = 12;
        description_textview.top_margin = description_textview.bottom_margin = 12;
        description_textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
        description_textview.accepts_tab = false;

        Gtk.TextBuffer buffer = new Gtk.TextBuffer (null);
        if (ical_task.get_description () != null) {
            buffer.text = ical_task.get_description ().strip ();
        }
        description_textview.set_buffer (buffer);

        description_textview.buffer.changed.connect (() => {
            // First, clear the description
            int count = task.get_icalcomponent ().count_properties (ICal.PropertyKind.DESCRIPTION_PROPERTY);
            for (int i = 0; i < count; i++) {
#if E_CAL_2_0
                ICal.Property remove_prop;
#else
                unowned ICal.Property remove_prop;
#endif
                remove_prop = task.get_icalcomponent ().get_first_property (ICal.PropertyKind.DESCRIPTION_PROPERTY);
                task.get_icalcomponent ().remove_property (remove_prop);
            }

            // Then add the new description - if we have any
            var description = description_textview.get_buffer ().text;
            if (description != null && description.strip ().length > 0) {
                var property = new ICal.Property (ICal.PropertyKind.DESCRIPTION_PROPERTY);
                property.set_description (description.strip ());
                task.get_icalcomponent ().add_property (property);
            }
        });

        var description_scrolled_window = new Gtk.ScrolledWindow (null, null);
        description_scrolled_window.hscrollbar_policy = Gtk.PolicyType.EXTERNAL;
        description_scrolled_window.height_request = 140;
        description_scrolled_window.add (description_textview);

        var description_frame = new Gtk.Frame (null);
        description_frame.margin = 12;
        description_frame.margin_bottom = 0;
        description_frame.add (description_scrolled_window);

        var done_button = new Gtk.Button ();
        done_button.label = _("Done");
        done_button.halign = Gtk.Align.END;
        done_button.margin = 12;

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.margin_top = 3;
        grid.add (summary_entry);
        grid.add (due_button);
        grid.add (due_datetimepicker);
        grid.add (description_frame);
        grid.add (done_button);
        grid.show_all ();

        width_request = 379;
        add (grid);

        if (ical_task.get_due ().is_null_time ()) {
            due_datetimepicker.hide ();
        }

        due_button.button_release_event.connect (() => {
            var previous_active = due_switch.active;
            due_switch.activate ();

            if (previous_active) {
                due_datetimepicker.hide ();
                ical_task.set_due (ICal.Time.null_time ());
            } else {
                ical_task.set_due (Util.date_time_to_ical (date_picker.date, time_picker.time));
                due_datetimepicker.show ();
            }

            return Gdk.EVENT_STOP;
        });

        done_button.button_release_event.connect (() => {
            popdown ();
            return Gdk.EVENT_STOP;
        });
    }
}
