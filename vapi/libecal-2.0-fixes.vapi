namespace E {
    [CCode (cname = "e_webdav_discover_sources_finish")]
    bool webdav_discover_sources_finish (E.Source source, GLib.AsyncResult result, out string out_certificate_pem, out GLib.TlsCertificateFlags out_certificate_errors, out GLib.SList<E.WebDAVDiscoveredSource?> out_discovered_sources, out GLib.SList<string> out_calendar_user_addresses) throws GLib.Error;
}