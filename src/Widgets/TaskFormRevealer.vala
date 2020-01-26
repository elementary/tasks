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
* You should have recei ved a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/

public class Tasks.TaskFormRevealer : Gtk.Revealer {

    public ECal.Component task { get; construct set; }

    private Gtk.Switch due_switch;
    private Gtk.TextBuffer description_textbuffer;
    private Granite.Widgets.DatePicker due_datepicker;
    private Granite.Widgets.TimePicker due_timepicker;

    public signal void cancel_clicked ();
    public signal void save_clicked (ECal.Component task);
    public signal void delete_clicked (ECal.Component task);

    public TaskFormRevealer (ECal.Component task) {
        Object (task: task);
    }

    construct {
        due_switch = new Gtk.Switch ();
        due_switch.valign = Gtk.Align.CENTER;

        var due_label = new Gtk.Label (_("Schedule") + ":");
        due_datepicker = new Granite.Widgets.DatePicker ();
        due_timepicker = new Granite.Widgets.TimePicker ();

        var due_datetimepicker = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        due_datetimepicker.add (due_label);
        due_datetimepicker.add (due_switch);
        due_datetimepicker.add (due_datepicker);
        due_datetimepicker.add (due_timepicker);

        var description_textview = new Gtk.TextView ();
        description_textview.left_margin = description_textview.right_margin = 12;
        description_textview.top_margin = description_textview.bottom_margin = 12;
        description_textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
        description_textview.accepts_tab = false;

        description_textbuffer = new Gtk.TextBuffer (null);
        description_textview.set_buffer (description_textbuffer);

        var description_scrolled_window = new Gtk.ScrolledWindow (null, null);
        description_scrolled_window.hscrollbar_policy = Gtk.PolicyType.EXTERNAL;
        description_scrolled_window.height_request = 140;
        description_scrolled_window.add (description_textview);

        var description_frame = new Gtk.Frame (null);
        description_frame.margin_bottom = 0;
        description_frame.add (description_scrolled_window);

        var delete_button = new Gtk.Button ();
        delete_button.sensitive = false;
        delete_button.label = _("Delete Task");
        delete_button.halign = Gtk.Align.START;
        delete_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var cancel_button = new Gtk.Button ();
        cancel_button.label = _("Cancel");
        cancel_button.halign = Gtk.Align.START;

        var save_button = new Gtk.Button ();
        save_button.label = _("Save Changes");
        save_button.halign = Gtk.Align.END;
        save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        button_box.baseline_position = Gtk.BaselinePosition.CENTER;
        button_box.set_layout (Gtk.ButtonBoxStyle.END);

        button_box.add (delete_button);
        button_box.set_child_secondary (delete_button, true);
        button_box.set_child_non_homogeneous (delete_button, true);
        button_box.add (cancel_button);
        button_box.set_child_non_homogeneous (cancel_button, true);
        button_box.add (save_button);

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        box.margin_top = box.margin_bottom = 6;
        box.homogeneous = false;
        box.add (due_datetimepicker);
        box.add (description_frame);
        box.add (button_box);

        add (box);
        reveal_child = false;

        notify["task"].connect (update_request);

        delete_button.clicked.connect (() => { delete_clicked(task); });
        cancel_button.clicked.connect (() => { cancel_clicked(); });
        save_button.clicked.connect (() => {
            unowned ICal.Component ical_task = task.get_icalcomponent ();

            if (due_switch.active) {
                ical_task.set_due (Util.date_time_to_ical (due_datepicker.date, due_timepicker.time));
                ical_task.set_due (Util.date_time_to_ical (due_datepicker.date, due_timepicker.time));
            } else {
                ical_task.set_due ( ICal.Time.null_time ());
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
            var description = description_textview.get_buffer ().text;
            if (description != null && description.strip ().length > 0) {
                var property = new ICal.Property (ICal.PropertyKind.DESCRIPTION_PROPERTY);
                property.set_description (description.strip ());
                ical_task.add_property (property);
            }

            save_clicked(task);
        });

        due_switch.bind_property ("active", due_datepicker, "sensitive", GLib.BindingFlags.SYNC_CREATE);
        due_switch.bind_property ("active", due_timepicker, "sensitive", GLib.BindingFlags.SYNC_CREATE);
    }

    private void update_request () {
        unowned ICal.Component ical_task = task.get_icalcomponent ();

        if (ical_task.get_due ().is_null_time ()) {
            due_switch.active = false;
            due_datepicker.date = due_timepicker.time = null;
        } else {
            var due_date_time = Util.ical_to_date_time (ical_task.get_due ());
            due_datepicker.date = due_timepicker.time = due_date_time;

            due_switch.active = true;
        }

        if (ical_task.get_description () != null) {
            description_textbuffer.text = ical_task.get_description ().strip ();
        } else {
            description_textbuffer.text = "";
        }
    }

    public void reveal_child_request (bool value) {
        if (value) {
            update_request ();
        }
        reveal_child = value;
    }
}
