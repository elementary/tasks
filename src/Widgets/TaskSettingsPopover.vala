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

    public Tasks.TaskModel model { get; construct; }

    public TaskSettingsPopover (Tasks.TaskModel model) {
        Object (model: model);
    }

    construct {
        var summary_entry = new Gtk.Entry ();
        summary_entry.margin_start = summary_entry.margin_end = 12;
        summary_entry.margin_top = summary_entry.margin_bottom = 12;
        summary_entry.text = model.summary;

        var due_label = new Gtk.Label (_("Schedule"));
        due_label.hexpand = true;
        due_label.xalign = 0;

        var due_switch = new Gtk.Switch ();
        due_switch.active = model.due != null;

        var due_grid = new Gtk.Grid ();
        due_grid.column_spacing = 6;
        due_grid.add (due_label);
        due_grid.add (due_switch);

        var due_button = new Gtk.ModelButton ();
        due_button.margin_top = due_button.margin_bottom = 3;
        due_button.get_child ().destroy ();
        due_button.add (due_grid);

        var due_datetimepicker = new Tasks.DateTimePicker ();
        due_datetimepicker.halign = Gtk.Align.END;
        due_datetimepicker.margin_start = due_datetimepicker.margin_end = 12;
        due_datetimepicker.margin_bottom = 12;
        if (model.due != null) {
            due_datetimepicker.date_picker.date = model.due;
            due_datetimepicker.time_picker.time = model.due;
        }

        var description_textview = new Gtk.TextView ();
        description_textview.left_margin = description_textview.right_margin = 12;
        description_textview.top_margin = description_textview.bottom_margin = 12;
        description_textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
        description_textview.accepts_tab = false;

        if (model.description != null) {
            Gtk.TextBuffer buffer = new Gtk.TextBuffer (null);
            buffer.text = model.description;
            description_textview.set_buffer (buffer);
        }

        var description_scrolled_window = new Gtk.ScrolledWindow (null, null);
        description_scrolled_window.hscrollbar_policy = Gtk.PolicyType.EXTERNAL;
        description_scrolled_window.height_request = 140;
        description_scrolled_window.add (description_textview);

        var done_button = new Gtk.Button ();
        done_button.label = _("Done");
        done_button.halign = Gtk.Align.END;
        done_button.margin_right = 6;
        done_button.margin_top = 6;
        done_button.margin_bottom = 3;

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.margin_top = grid.margin_bottom = 3;
        grid.add (summary_entry);
        grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.add (due_button);
        grid.add (due_datetimepicker);
        grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.add (description_scrolled_window);
        grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.add (done_button);
        grid.show_all ();

        width_request = 379;
        add (grid);

        if (model.due == null) {
            due_datetimepicker.hide ();
        }

        due_button.button_release_event.connect (() => {
            var previous_active = due_switch.active;
            due_switch.activate ();

            if (previous_active) {
                due_datetimepicker.hide ();
            } else {
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
