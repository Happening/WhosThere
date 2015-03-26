Db = require 'db'
Event = require 'event'
Plugin = require 'plugin'
Geoloc = require 'geoloc'
Timer = require 'timer'

exports.getTitle = ->
	Db.shared.get 'locationName'

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

	if name = config.locationName
		Db.shared.set 'locationName', name

	oldRadius = Db.shared?.get('radius')
	if radius = config.radius
		Db.shared.set 'radius', radius

	if !oldBase || oldRadius != radius || oldBase.latitude != base.latitude || oldBase.longitude != base.longitude
		Db.shared.remove 'nearby'
		for userId,geoloc of Db.backend.get('last')
			onGeoloc userId, geoloc

	# maybe also notify when distance of previous base location is far away
	if !oldBase and base.latitude and base.longitude and name
		Event.create
			unit: 'other'
			text: "#{Plugin.userName()} set the base location for '#{name}'"

exports.client_update = !->
	userIds = Geoloc.request('all')
	log 'updating', userIds
	for userId in userIds
		Timer.cancel 'cancelLoad', userId
		Timer.set 10000, 'cancelLoad', userId
		log 'setting timer', 10000, 'cancelLoad', userId
		Db.shared.set 'nearby', userId, 'loading', true

exports.cancelLoad = (userId) !->
	log 'cancelLoad', userId
	Db.shared.remove 'nearby', userId, 'loading'
	
exports.onGeoloc = onGeoloc = (userId, geoloc) !->
	log 'onGeoloc', userId, JSON.stringify(geoloc)
	return if typeof geoloc isnt 'object'

	Db.backend.set 'last', userId, geoloc

	base = Db.shared.get('base')
	threshold = Db.shared.get('radius')||150

	return if !base || !geoloc.latitude? || !geoloc.longitude?
	distance = calcDist(base.latitude, base.longitude, geoloc.latitude, geoloc.longitude)*1000
	log 'userId, distance', userId, distance

	nearby = if distance < threshold && (geoloc.accuracy||0) < threshold then 1 else 0
	Db.shared.set 'nearby', userId,
		nearby: nearby
		time: geoloc.time*1000

deg2rad = (deg) -> deg * (3.1415/180)

calcDist = (lat1,lon1,lat2,lon2) ->
	dlat = deg2rad(lat2-lat1)
	dlon = deg2rad(lon2-lon1)
	a = Math.sin(dlat/2) * Math.sin(dlat/2) +
		Math.cos(deg2rad(lat1)) * Math.cos(deg2rad(lat2)) * Math.sin(dlon/2) * Math.sin(dlon/2)
	6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
