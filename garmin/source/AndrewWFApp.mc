using Toybox.Application;
using Toybox.WatchUi;
using Toybox.System as Sys;
using Toybox.Background as Bg;
using Toybox.WatchUi as Ui;
using Toybox.Time;
using Toybox.Position;

var gLocationLat = null;
var gLocationLng = null;

class AndrewWFApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    // Return the initial view of your application here
    function getInitialView() {
        return [ new AndrewWFView() ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        if (AndrewWFApp has :checkPendingWebRequests) { // checkPendingWebRequests() can be excluded to save memory.
            checkPendingWebRequests();
        }
        WatchUi.requestUpdate();
    }

    (:background_method)
    function checkPendingWebRequests() {
        Sys.println("checkPendingWebRequests (checking for stale data)");

        // Attempt to update current location, to be used by Sunrise/Sunset, and Weather.
        // If current location available from current activity, save it in case it goes "stale" and can not longer be retrieved.
        // n.b. in development, need to swap the Activity API for the Position API - for some reason, Activity works on the watch
        // but not in development, and vice versa
        var location = Activity.getActivityInfo().currentLocation;
        //var location = Position.getInfo();
        if (location) {
            // Sys.println("Saving location");
            location = location.toDegrees();
            //location = location.position.toDegrees();
            gLocationLat = location[0].toFloat();
            gLocationLng = location[1].toFloat();

            Application.getApp().setProperty("LastLocationLat", gLocationLat);
            Application.getApp().setProperty("LastLocationLng", gLocationLng);
        // If current location is not available, read stored value from Object Store, being careful not to overwrite a valid
        // in-memory value with an invalid stored one.
        } else {
            var lat = Application.getApp().getProperty("LastLocationLat");
            if (lat != null) {
                gLocationLat = lat;
            }

            var lng = Application.getApp().getProperty("LastLocationLng");
            if (lng != null) {
                gLocationLng = lng;
            }
        }

        Sys.println("Got lat/lng: " + gLocationLat + ", " + gLocationLng);
        if (!(Sys has :ServiceDelegate)) {
            return;
        }

        var pendingWebRequests = getProperty("PendingWebRequests");
        if (pendingWebRequests == null) {
            pendingWebRequests = {};
        }

        // 2. Weather:
        // Location must be available, weather or humidity (#113) data field must be shown.
        if (gLocationLat != null) {

            var owmCurrent = getProperty("OpenWeatherMapCurrent");

            // No existing data.
            if (owmCurrent == null) {
                Sys.println("No data detected, requesting");
                pendingWebRequests["OpenWeatherMapCurrent"] = true;
            // Successfully received weather data.
            } else if (Time.now().value() > (owmCurrent["closest"]["ts"] + 10 * 60)) {
                Sys.println("Stale data detected, reqesting new");
                pendingWebRequests["OpenWeatherMapCurrent"] = true;
            }
        }


        // If there are any pending requests:
        if (pendingWebRequests.keys().size() > 0) {
            // Register for background temporal event as soon as possible.
            var lastTime = Bg.getLastTemporalEventTime();

            if (lastTime) {
                Sys.println("Scheduling new temporal event for 5m from the last");
                // Events scheduled for a time in the past trigger immediately.
                var nextTime = lastTime.add(new Time.Duration(5 * 60));  // 5 * 60
                Bg.registerForTemporalEvent(nextTime);
            } else {
                Bg.registerForTemporalEvent(Time.now());
            }
        }

        setProperty("PendingWebRequests", pendingWebRequests);
    }

    (:background_method)
    function getServiceDelegate() {
        return [new BackgroundService()];
    }

    // Handle data received from BackgroundService.
    // On success, clear appropriate pendingWebRequests flag.
    // data is Dictionary with single key that indicates the data type received. This corresponds with Object Store and
    // pendingWebRequests keys.
    (:background_method)
    function onBackgroundData(data) {
        Sys.println("onBackgroundData() called");

        var pendingWebRequests = getProperty("PendingWebRequests");
        if (pendingWebRequests == null) {
            //Sys.println("onBackgroundData() called with no pending web requests!");
            pendingWebRequests = {};
        }

        var type = data.keys()[0]; // Type of received data.
        Sys.println("Type received");
        Sys.println(type);
        var storedData = getProperty(type);
        var receivedData = data[type]; // The actual data received: strip away type key.

        // No value in showing any HTTP error to the user, so no need to modify stored data.
        // Leave pendingWebRequests flag set, and simply return early.
        if (receivedData["httpError"]) {
            return;
        }

        // New data received: clear pendingWebRequests flag and overwrite stored data.
        storedData = receivedData;
        pendingWebRequests.remove(type);
        setProperty("PendingWebRequests", pendingWebRequests);
        setProperty(type, storedData);
        Sys.println("Pending web requests now looks like");
        Sys.println(pendingWebRequests);

        Ui.requestUpdate();
    }

}