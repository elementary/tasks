namespace E {
    [CCode (cname = "e_webdav_session_update_properties_sync")]
    bool webdav_session_update_properties_sync (E.WebDAVSession webdav, string? uri, [CCode (type = "const GSList *")] GLib.SList<E.WebDAVPropertyChange> changes, GLib.Cancellable? cancellable = null) throws GLib.Error;
}
