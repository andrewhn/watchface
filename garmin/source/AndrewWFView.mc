using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;
using Toybox.Time.Gregorian;
using Toybox.Math;

class AndrewWFView extends WatchUi.WatchFace {

    var last_draw_minute = -1;
    var last_ts = -1;

    function initialize() {
        WatchFace.initialize();
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
        //checkBackgroundRequest();
    }

    // Update the view
    function onUpdate(dc) {
        var clockTime = System.getClockTime();
        if (last_draw_minute == clockTime.min) {
            return;
        }
        last_draw_minute = clockTime.min;
        checkBackgroundRequest();
        System.println("Update - minor cycle");
        // minor update - time and weather timeago

        // Get the current time and format it correctly
        var timeFormat = "$1$:$2$";
        var hours = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
            if (hours > 12) {
                hours = hours - 12;
            }
        }
        var timeString = Lang.format(timeFormat, [hours.format("%02d"), clockTime.min.format("%02d")]);
        var timeView = View.findDrawableById("TimeLabel");
        timeView.setColor(0xFFFFFF);
        timeView.setText(timeString);

        var dateView = View.findDrawableById("DateLabel");
        var info = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = Lang.format("$1$ $2$ $3$", [info.day_of_week, info.month, info.day]);
        dateView.setText(dateStr);

        // update the timeagos
        var owmCurrent = Application.getApp().getProperty("OpenWeatherMapCurrent");
        if (owmCurrent) {
            // of the most recent obs
            var tsnow = Time.now().value();
            var timeagoView = View.findDrawableById("TimeagoLabel");
            var ts = tsnow - owmCurrent["closest"]["ts"];
            timeagoView.setText((ts / 60).format("%d") + "m");

            // update the timeago
            var sunr = owmCurrent["srss"][0];
            var suns = owmCurrent["srss"][1];
            var secTo = 0;
            var nxt;
            if (sunr > suns) {
                secTo = suns - tsnow;
                nxt = "Sunset";
            } else {
                secTo = sunr - tsnow;
                nxt = "Sunrise";
            }
            var srssView = View.findDrawableById("SunriseSunsetLabel");
            srssView.setText(Lang.format("$1$ in $2$", [nxt, getHM(secTo)]));

            // if we have no new data, exit here - don't need to render anything here because nothing
            // else changes
            if (owmCurrent["closest"]["ts"] == last_ts) {
                // draw the changes we've made
                View.onUpdate(dc);
                return;
            } else {
                last_ts = owmCurrent["closest"]["ts"];
            }

            var latLngView = View.findDrawableById("LatLngLabel");
            latLngView.setText(Lang.format("$1$,$2$",
                [Application.getApp().getProperty("LastLocationLat").format("%.3f"), Application.getApp().getProperty("LastLocationLng").format("%.3f")]));

            // https://coolors.co/084c61-db504a-e3b505-4f6d7a-56a3a6

            // render everything else
            //System.print(owmCurrent["forecast"]);
            var stnView = View.findDrawableById("StationLabel");
            stnView.setText(owmCurrent["closest"]["stn"]);
            for (var i = 0; i < 5; i++) {
                var forecastMaxView = View.findDrawableById("ForecastLabelMax" + Lang.format("$1$", [i + 1]));
                forecastMaxView.setText(Lang.format("$1$", [owmCurrent["forecast"][i][0]]));
                forecastMaxView.setColor(0xDB504A);

                var forecastMinView = View.findDrawableById("ForecastLabelMin" + Lang.format("$1$", [i + 1]));
                forecastMinView.setText(Lang.format("$1$", [owmCurrent["forecast"][i][1]]));
                forecastMinView.setColor(0x56A3A6);

                var forecastRFView = View.findDrawableById("ForecastLabelRF" + Lang.format("$1$", [i + 1]));
                forecastRFView.setText(Lang.format("$1$", [owmCurrent["forecast"][i][2]]));
                forecastRFView.setColor(0xE3B505);
            }

            var battView = View.findDrawableById("BattPctLabel");
            battView.setText(System.getSystemStats().battery.format("%d") + "%");

            var currentView = View.findDrawableById("CurrentLabel");
            var cvText = Lang.format("$1$° $2$ $3$", [owmCurrent["closest"]["app_tmp"],
                owmCurrent["closest"]["wind_spd_kt"], owmCurrent["closest"]["wind_dir"]]);
            currentView.setText(cvText);

            var stKView = View.findDrawableById("StKLabel");
            stKView.setText(Lang.format("$1$ $2$", [owmCurrent["stk"]["wind_spd_kt"], owmCurrent["stk"]["wind_dir"]]));
        }

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    function getHM(sec) {
        var min = sec / 60;
        var hr;
        var hrMin;
        if (min >= 60) {
            hr = Math.floor(min / 60);
            hrMin = min - hr * 60;
            if (hrMin == 0) {
                return Lang.format("$1$h", [hr]);
            } else {
                return Lang.format("$1$h$2$m", [hr, hrMin]);
            }
        } else {
            return Lang.format("$1$m", [min]);
        }
        return Lang.format("$1$m2", [sec / 60]);
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        checkBackgroundRequest();
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }

    function checkBackgroundRequest() {
        if (AndrewWFApp has :checkPendingWebRequests) { // checkPendingWebRequests() can be excluded to save memory.
            Application.getApp().checkPendingWebRequests(); // Depends on mDataFields.hasField().
        }
    }

}
