//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Tasks.Util {

    /*
     * ECal Utility Functions
     */

    /* Computes hash value for E.Source */
    private uint source_hash_func (E.Source key) {
        return key.dup_uid (). hash ();
    }

    /* Returns true if 'a' and 'b' are the same E.Source */
    private bool source_equal_func (E.Source a, E.Source b) {
        return a.get_uid () == b.get_uid ();
    }

    /* Returns true if 'a' and 'b' are the same ECal.Component */
    public bool calcomponent_equal_func (ECal.Component a, ECal.Component b) {
        return false;
        //return a.get_id ().equal (b.get_id ());
    }

    public int calcomponent_compare_func (ECal.Component? a, ECal.Component? b) {
        if (a == null && b != null) {
            return 1;
        } else if (b == null && a != null) {
            return -1;
        } else if (b == null && a == null) {
            return 0;
        }

        return 0;

        //var a_id = a.get_id ();
        //var b_id = b.get_id ();
        //int res = GLib.strcmp (a_id.get_uid (), b_id.get_uid ());
        //if (res == 0) {
            //return GLib.strcmp (a_id.get_rid (), b_id.get_rid ());
        //}

        //return res;
    }
}

