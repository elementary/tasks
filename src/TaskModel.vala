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

public struct Tasks.TaskModel {
    string uid;
    string summary;
    string description;
    ICal.PropertyStatus status;
    GLib.DateTime? due;

    public bool is_completed (){
        return status == ICal.PropertyStatus.COMPLETED;
    }

    public static GLib.DateTime? ical_time_to_glib_datetime (ICal.Time ical_time){
        if (ical_time.is_null_time()) {
            return null;
        }

        GLib.TimeZone glib_timezone = null;
        if (ical_time.get_tzid () != null) {
            glib_timezone = new GLib.TimeZone (ical_time.get_tzid ());
        } else {
            glib_timezone = new GLib.TimeZone.local ();
        }

        return new GLib.DateTime (
            glib_timezone,
            ical_time.year,
            ical_time.month,
            ical_time.day,
            ical_time.hour,
            ical_time.minute,
            ical_time.second
        );
    }
}
