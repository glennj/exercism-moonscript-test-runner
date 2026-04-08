tz = require 'tz'

utc_time = ->
  timespec = year: 2014, month: 11, day: 1, hour: 20
  zone = 'UTC'
  tz.time timespec, zone

utc_time
