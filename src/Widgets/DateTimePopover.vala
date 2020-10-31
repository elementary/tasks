/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
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
*/

public class Tasks.DateTimePopover : Tasks.EntryPopover<GLib.DateTime?> {
    private Gtk.Calendar calendar;
    private Granite.Widgets.TimePicker timepicker;

    construct {
        calendar = new Gtk.Calendar () {
            sensitive = false
        };
        calendar.get_style_context ().add_class (Gtk.STYLE_CLASS_BACKGROUND);

        timepicker = new Granite.Widgets.TimePicker () {
            sensitive = false
        };

        var today_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
        var today_button = new Gtk.ModelButton () {
            text = _("Today")
        };

        var grid = new Gtk.Grid () {
            margin = 6,
            row_spacing = 6,
            column_spacing = 6
        };
        grid.attach (calendar, 0, 0);
        grid.attach (timepicker, 0, 1);
        grid.attach (today_separator, 0, 2);
        grid.attach (today_button, 0, 3);
        
        grid.show_all ();

        popover.add (grid);

        popover.show.connect (on_popover_show);
        popover.closed.connect (on_popover_closed);

        today_button.button_release_event.connect (on_today_button_release_event);
        calendar.day_selected.connect (on_calendar_day_selected);
        timepicker.time_changed.connect (on_timepicker_time_changed);
    }

    private void on_popover_show () {
        var selected_datetime = value;
        if (selected_datetime == null) {
            selected_datetime = get_next_full_hour (
                new GLib.DateTime.now_local ()
            );
        }

        calendar.select_month (selected_datetime.get_month () - 1, selected_datetime.get_year ());
        calendar.select_day (selected_datetime.get_day_of_month ());
        timepicker.time = selected_datetime;

        calendar.sensitive = timepicker.sensitive = true;
    }

    private void on_popover_closed () {
        calendar.sensitive = timepicker.sensitive = false;
    }

    private bool on_today_button_release_event () {
        var now_local = new GLib.DateTime.now_local ();

        calendar.select_month (now_local.get_month () - 1, now_local.get_year ());
        calendar.select_day (now_local.get_day_of_month ());

        return Gdk.EVENT_STOP;
    }

    private void on_calendar_day_selected () {
        if (!calendar.sensitive) {
            return;
        }
        var selected_datetime = new GLib.DateTime.local (
            calendar.year,
            calendar.month + 1,
            calendar.day,
            timepicker.time.get_hour (),
            timepicker.time.get_minute (),
            0
        );
        timepicker.time = selected_datetime;
        value = selected_datetime;
    }

    private void on_timepicker_time_changed () {
        if (!timepicker.sensitive) {
            return;
        }
        value = timepicker.time;
    }

    private GLib.DateTime get_next_full_hour (GLib.DateTime datetime) {
        var next_full_hour = datetime.add_minutes (60 - datetime.get_minute ());
        next_full_hour = next_full_hour.add_seconds (-next_full_hour.get_seconds ());
        return next_full_hour;
    }
}
