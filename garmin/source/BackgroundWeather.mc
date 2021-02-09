using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;

(:background)
class BackgroundService extends Sys.ServiceDelegate {

    (:background_method)
    function initialize() {
        Sys.ServiceDelegate.initialize();
    }

    // Read pending web requests, and call appropriate web request function.
    // This function determines priority of web requests, if multiple are pending.
    // Pending web request flag will be cleared only once the background data has been successfully received.
    (:background_method)
    function onTemporalEvent() {
        Sys.println("onTemporalEvent");
        var pendingWebRequests = App.getApp().getProperty("PendingWebRequests");
        Sys.println(pendingWebRequests);
        if (pendingWebRequests != null) {
            if (pendingWebRequests["OpenWeatherMapCurrent"] != null) {
                var uri = Lang.format("https://<my.weather.api>/$1$/$2$",
                    [App.getApp().getProperty("LastLocationLat"), App.getApp().getProperty("LastLocationLng")]);
                Sys.println(uri);
                makeWebRequest(uri, {}, method(:onReceiveOpenWeatherMapCurrent));
            }
        } /* else {
            Sys.println("onTemporalEvent() called with no pending web requests!");
        } */
    }

    (:background_method)
    function onReceiveOpenWeatherMapCurrent(responseCode, data) {
        var result;

        // Useful data only available if result was successful.
        // Filter and flatten data response for data that we actually need.
        // Reduces runtime memory spike in main app.
        if (responseCode == 200) {
            result = data;
        // HTTP error: do not save.
        } else {
            Sys.println("HTTP ERROR");
            Sys.println(responseCode);
            result = {
                "httpError" => responseCode
            };
        }

        Bg.exit({
            "OpenWeatherMapCurrent" => result
        });
    }

    (:background_method)
    function makeWebRequest(url, params, callback) {
        var options = {
            :method => Comms.HTTP_REQUEST_METHOD_GET,
            :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED},
            :responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        Comms.makeWebRequest(url, params, options, callback);
    }
}