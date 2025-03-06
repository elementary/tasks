/*
 * Copyright 2021-2023 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

public class Tasks.Widgets.EntryPopover.DateTime : Generic<GLib.DateTime?> {
    private Gtk.Calendar calendar;
    private Granite.TimePicker timepicker;
    private Gtk.Revealer timepicker_revealer;

    public DateTime () {
        Object (
            icon_name: "office-calendar-symbolic",
            placeholder: _("Set Due")
        );
    }

    construct {
        calendar = new Gtk.Calendar () {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6
        };

        timepicker = new Granite.TimePicker () {
            margin_top = 12,
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12
        };

        timepicker_revealer = new Gtk.Revealer () {
            reveal_child = true,
            child = timepicker
        };

        var today_separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_bottom = 3,
            margin_top = 3
        };

        var today_button = new PopoverMenuitem () {
            text = _("Today")
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_top = 3
        };
        box.append (today_button);
        box.append (today_separator);
        box.append (calendar);
        box.append (timepicker_revealer);

        popover.child = box;

        popover.show.connect (on_popover_show);

        today_button.clicked.connect (on_today_button_clicked);
        calendar.day_selected.connect (on_calendar_day_selected);
        timepicker.time_changed.connect (on_timepicker_time_changed);
    }

    public void hide_timepicker () {
        timepicker_revealer.reveal_child = false;
    }

    private void on_popover_show () {
        var selected_datetime = value;
        if (selected_datetime == null) {
            selected_datetime = get_next_full_hour (
                new GLib.DateTime.now_local ()
            );
            value = selected_datetime;
        }

        calendar.select_day (selected_datetime);
        timepicker.time = selected_datetime;
    }

    private void on_today_button_clicked () {
        calendar.select_day (new GLib.DateTime.now_local ());
    }

    private void on_calendar_day_selected () {
        var selected_datetime = new GLib.DateTime.local (
            calendar.year,
            calendar.month + 1,
            calendar.day,
            value.get_hour (),
            value.get_minute (),
            0
        );
        timepicker.time = selected_datetime;
        value = selected_datetime;
    }

    private void on_timepicker_time_changed () {
        value = timepicker.time;
    }

    private GLib.DateTime get_next_full_hour (GLib.DateTime datetime) {
        var next_full_hour = datetime.add_minutes (60 - datetime.get_minute ());
        next_full_hour = next_full_hour.add_seconds (-next_full_hour.get_seconds ());
        return next_full_hour;
    }
}
