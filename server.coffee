Db = require 'db'
Plugin = require 'plugin'
Geoloc = require 'geoloc'

exports.onInstall = exports.onConfig = (config) !->
	return if !config?
	oldBase = Db.shared?.get('base')
	if base = config.base
		base = base.split(',')
		base = {latitude: base[0], longitude: base[1]}
		Db.shared.set 'base', base
	else
		base = {}
		Db.shared.remove 'base'

	if !oldBase || oldBase.latitude != base.latitude || oldBase.longitude != base.longitude
		# remove current distances
		Db.shared.remove 'distances'

exports.onGeoloc = (userId, geoloc) !->
	base = Db.shared.get('base')
	return if !base || !geoloc.latitude? || !geoloc.longitude?
	dist = distance(base.latitude, base.longitude, geoloc.latitude, geoloc.longitude)*1000
	if dist < 50
		dist = 50
	else if dist < 250
		dist = 250
	else if dist < 2500
		dist = 2500
	else
		dist = 10000
	Db.shared.set 'distances', userId,
		distance: dist
		time: Date.now()

deg2rad = (deg) -> deg * (3.1415/180)

distance = (lat1,lon1,lat2,lon2) ->
	dlat = deg2rad(lat2-lat1)
	dlon = deg2rad(lon2-lon1)
	a = Math.sin(dlat/2) * Math.sin(dlat/2) +
		Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * Math.sin(dlon/2) * Math.sin(dlon/2)
	6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
