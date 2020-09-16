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

    /**
     * Converts two datetimes to one TimeType. The first contains the date,
     * its time settings are ignored. The second one contains the time itself.
     */
    public ICal.Time datetimes_to_icaltime (GLib.DateTime date, GLib.DateTime? time_local, string? timezone = null) {
        var result = new ICal.Time.from_day_of_year (date.get_day_of_year (), date.get_year ());
        if (time_local != null) {
            if (timezone != null) {
                result.set_timezone (ICal.Timezone.get_builtin_timezone (timezone));
            } else {
                result.set_timezone (ECal.util_get_system_timezone ());
            }

            result.set_is_date (false);
            result.set_time (time_local.get_hour (), time_local.get_minute (), time_local.get_second ());
        } else {
            result.set_is_date (true);
            result.set_time (0, 0, 0);
        }

        return result;
    }
}
