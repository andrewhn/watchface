"""

"""

import urllib.request as request
import xml.etree.ElementTree as ET
import json
import datetime
from bottle import route, run
from math import sin, cos, sqrt, atan2, radians
from suntime import Sun

products = [
    ("IDD60920", "NT"),
    ("IDN60920", "NSW"),
    ("IDQ60920", "QLD"),
    ("IDS60920", "SA"),
    ("IDT60920", "TAS"),
    ("IDV60920", "VIC"),
    ("IDW60920", "WA"),
]

station_attrs = [
    "wmo-id",
    "bom-id",
    "tz",
    "stn-name",
    "stn-height",
    "type",
    "lat",
    "lon",
    "forecast-district-id",
    "description",
]

obs_attrs = [
    "wind_dir",
    "wind_dir_deg",
    "wind_spd",
    "wind_spd_kmh",
    "wind_gust_spd",
    "gust_kmh",
    "qnh_pres",
    "msl_pres",
    "pres",
    "vis_km",
    "cloud",
    "weather",
    "swell_period",
    "swell_height",
    "swell_dir",
    "sea_height",
    "apparent_temp",
    "air_temperature",
    "dew_point",
    "delta_t",
    "rel_humidity",
    "rainfall",
    "rainfall_24hr",
]

target = "ftp://ftp.bom.gov.au/anon/gen/fwo/{product}.xml"

# approximate radius of earth in km for `calc_distance`
R = 6373.0

def _process_station(elt):
    clean = {k.replace("-", "_"): elt.get(k, None) for k in station_attrs}
    return clean

def _process_obs(elt):
    wmo_id = elt.get("wmo-id")
    period = elt.find("period")
    datetime = period.get("time-utc")
    clean = {k: None for k in obs_attrs}
    ## fill in actual values
    for element in period.find("level").findall("element"):
        datatype = element.get("type").replace("-", "_")
        if datatype in obs_attrs:
            clean[datatype] = element.text
    clean["wmo_id"] = wmo_id
    clean["datetime"] = datetime
    return clean

def get_obs():
    all_obs = []
    for product, state in products:
        uri = target.format(product=product)
        req = request.Request(uri)
        with request.urlopen(req) as response:
            data = response.read().decode()
        tree = ET.fromstring(data)
        observations = tree.find("observations")
        for station_element in observations.findall("station"):
            station = _process_station(station_element)
            obs = _process_obs(station_element)
            all_obs.append((station, obs))
    return all_obs

def calc_distance(lat1, lon1, lat2, lon2):
    ## implements haversine distance, an approximation of earth distance
    ## that assumes it is a perfect sphere
    dlon = radians(lon2) - radians(lon1)
    dlat = radians(lat2) - radians(lat1)
    a = sin(dlat / 2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2)**2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    distance = R * c
    return distance

def get_forecast():
    forecast = []
    uri = "ftp://ftp.bom.gov.au/anon/gen/fwo/IDV10753.xml"
    req = request.Request(uri)
    with request.urlopen(req) as response:
        data = response.read().decode()
    tree = ET.fromstring(data)
    area = [a for a in tree.find("forecast")
            if a.get("description") == "Watsonia"] #Phillip Island"]
    if area:
        for i, elt in enumerate(area[0].findall("forecast-period")):
            if i > 4: break
            mx = elt.find('.//element[@type="air_temperature_maximum"]')
            mn = elt.find('.//element[@type="air_temperature_minimum"]')
            rp = elt.find('.//text[@type="probability_of_precipitation"]')
            day = []
            for x in [mx, mn, rp]:
                if x is None:
                    res = ""
                else:
                    res = x.text
                    try:
                        res = int(res)
                    except:
                        pass
                #forecast.append(res)
                day.append(res)
            forecast.append(day)
    return forecast

@route('/<lat:float>/<lng:float>')
def index(lat, lng):
    obs = get_obs()
    closest = sorted(obs, key=lambda o: calc_distance(float(o[0]['lat']), float(o[0]['lon']), lat, lng))[0]
    stk = [x for x in obs if x[0]["stn_name"] == "ST KILDA HARBOUR - RMYS"]
    if len(stk):
        stk = {"wind_spd_kt": stk[0][1]["wind_spd"], "wind_dir": stk[0][1]["wind_dir"]}
    else:
        stk = {"wind_spd_kt": "", "wind_dir": ""}
    forecast = get_forecast()
    sun = Sun(lat, lng)
    sunr = sun.get_sunrise_time().timestamp()
    sund = sun.get_sunset_time().timestamp()
    return json.dumps({
        "closest": {
            "stn": closest[0]["description"],
            "wind_dir": closest[1]["wind_dir"],
            "wind_spd_kt": closest[1]["wind_spd"],
            "app_tmp": closest[1]["apparent_temp"],
            "rel_humidity": closest[1]["rel_humidity"],
            "ts": round(datetime.datetime.strptime(closest[1]["datetime"], "%Y-%m-%dT%H:%M:%S%z").timestamp()),
        },
        "srss": [round(sunr), round(sund)],
        "stk": stk,
        "forecast": forecast,
    })

run(host='localhost', port=8081)
