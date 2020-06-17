/*
 * Copyright 2011-2020 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 */

namespace Calendar.Util {

    //--- GLib.DateTime Helpers ---//

    public GLib.DateTime date_time_get_start_of_month (owned GLib.DateTime? date = null) {
        if (date == null) {
            date = new GLib.DateTime.now_local ();
        }

        return new GLib.DateTime.local (date.get_year (), date.get_month (), 1, 0, 0, 0);
    }

    public GLib.DateTime date_time_strip_time (GLib.DateTime datetime) {
        return datetime.add_full (0, 0, 0, -datetime.get_hour (), -datetime.get_minute (), -datetime.get_second ());
    }

    /**
     * Say if an event lasts all day.
     */
    public bool date_time_is_all_day (GLib.DateTime dtstart, GLib.DateTime dtend) {
        var utc_start = dtstart.to_timezone (new TimeZone.utc ());
        var timespan = dtend.difference (dtstart);

        if (timespan % GLib.TimeSpan.DAY == 0 && utc_start.get_hour () == 0) {
            return true;
        } else {
            return false;
        }
    }

    //--- ICal.Time Helpers ---//

    /**
     * Converts the given ICal.Time to a DateTime.
     */
    public TimeZone ical_time_get_timezone (ICal.Time date) {
        int is_daylight;
        var interval = date.get_timezone ().get_utc_offset (null, out is_daylight);
        bool is_positive = interval >= 0;
        interval = interval.abs ();
        var hours = (interval / 3600);
        var minutes = (interval % 3600) / 60;
        var hour_string = "%s%02d:%02d".printf (is_positive ? "+" : "-", hours, minutes);

        return new TimeZone (hour_string);
    }

    /**
     * Converts the given ICal.Time to a DateTime.
     * XXX : Track next versions of evolution in order to convert ICal.Timezone to GLib.TimeZone with a dedicated function…
     */
    public GLib.DateTime ical_time_to_date_time (ICal.Time date) {
#if E_CAL_2_0
        int year, month, day, hour, minute, second;
        date.get_date (out year, out month, out day);
        date.get_time (out hour, out minute, out second);
        return new GLib.DateTime (ical_time_get_timezone (date), year, month,
            day, hour, minute, second);
#else
        return new GLib.DateTime (ical_time_get_timezone (date), date.year, date.month,
            date.day, date.hour, date.minute, date.second);
#endif
    }

    //--- ECal.Component Helpers ---//

    /* Returns true if 'a' and 'b' are the same ECal.Component */
    public bool ecalcomponent_equal_func (ECal.Component a, ECal.Component b) {
        return a.get_id ().equal (b.get_id ());
    }

    public int ecalcomponent_compare_func (ECal.Component? a, ECal.Component? b) {
        if (a == null && b != null) {
            return 1;
        } else if (b == null && a != null) {
            return -1;
        } else if (b == null && a == null) {
            return 0;
        }

        var a_id = a.get_id ();
        var b_id = b.get_id ();
        int res = GLib.strcmp (a_id.get_uid (), b_id.get_uid ());
        if (res == 0) {
            return GLib.strcmp (a_id.get_rid (), b_id.get_rid ());
        }

        return res;
    }

    public bool ecalcomponent_is_on_day (ECal.Component component, GLib.DateTime day) {
#if E_CAL_2_0
        unowned ICal.Timezone system_timezone = ECal.util_get_system_timezone ();
#else
        unowned ICal.Timezone system_timezone = ECal.Util.get_system_timezone ();
#endif
        var stripped_time = new GLib.DateTime.local (day.get_year (), day.get_month (), day.get_day_of_month (), 0, 0, 0);

        var selected_date_unix = stripped_time.to_unix ();
        var selected_date_unix_next = stripped_time.add_days (1).to_unix ();

        /* We want to be relative to the local timezone */
        unowned ICal.Component? ical_component = component.get_icalcomponent ();
        ICal.Time? start_time;
        ICal.Time? end_time;
        switch (component.get_vtype ()) {
            case ECal.ComponentVType.EVENT:
                start_time = ical_component.get_dtstart ();
                end_time = ical_component.get_dtend ();
                break;

            case ECal.ComponentVType.TODO:
                start_time = ical_component.get_due ();
                end_time = ical_component.get_due ();
                break;

            default:
                return false;
        }

        time_t start_unix = start_time.as_timet_with_zone (system_timezone);
        time_t end_unix = end_time.as_timet_with_zone (system_timezone);

        /* If the selected date is inside the event */
        if (start_unix < selected_date_unix && selected_date_unix_next < end_unix) {
            return true;
        }

        /* If the event start before the selected date but finished in the selected date */
        if (start_unix < selected_date_unix && selected_date_unix < end_unix) {
            return true;
        }

        /* If the event start after the selected date but finished after the selected date */
        if (start_unix < selected_date_unix_next && selected_date_unix_next < end_unix) {
            return true;
        }

        /* If the event is inside the selected date */
        if (start_unix < selected_date_unix_next && selected_date_unix < end_unix) {
            return true;
        }

        return false;
    }
}
