Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Form = require 'form'
Loglist = require 'loglist'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
Plugin = require 'plugin'
Server = require 'server'
Time = require 'time'
Ui = require 'ui'
Geoloc = require 'geoloc'
Icon = require 'icon'
{tr} = require 'i18n'

exports.render = !->

	myLoc = Db.shared.get('dist', Plugin.userId())
	base = Db.shared.get('base')

	Dom.style textAlign: 'center'

	if !Geoloc.isSubscribed()
		Dom.div !->
			Dom.style position: 'relative', margin: '10px 10px 20px 10px', padding: '10px', border: '1px solid #aaa', borderRadius: '10px'
			Dom.div !->
				Dom.style
					position: 'absolute'
					content: '""'
					bottom: '-20px'
					left: '50%'
					marginLeft: '-10px'
					border: '10px solid transparent'
					borderTop: '10px solid #aaa'

			Ui.bigButton tr("Allow location updates"), !->
				Geoloc.subscribe()
			Dom.div !->
				Dom.style padding: '8px 0', fontSize: '85%'
				Dom.richText tr("Members can then see whether you are at the specified location.")+' '
				Dom.span !->
					Dom.style fontWeight: 'bold'
					Dom.text tr("They can not track you.")

	if !base
		Dom.div !->
			Dom.style fontWeight: 'bold', margin: '40px', fontSize: '120%', color: '#999', textShadow: '0 1px 0 #fff'
			if Plugin.userIsAdmin() or Plugin.ownerId() is Plugin.userId()
				Dom.text tr("Configure the base location in the plugin settings")
			else
				Dom.text tr("The base location for this plugin hasn't been configured yet")

		return

	Server.send 'update'

	renderUsers = (type) !->
		userCount = Obs.create(0)
		if Geoloc.isSubscribed()
			Plugin.users.observeEach (user) !->
				userCount.incr()
				Obs.onClean !->
					userCount.incr(-1)
				Dom.div !->
					ew = type is 'elsewhere'
					time = Db.shared.get('nearby', user.key(), 'time') * 0.001
					age = Plugin.time()-time
					Dom.style
						Box: 'center middle'
						display: 'inline-block'
						opacity: if !time or age > 30*60 then '0.35' else (if age > 15*60 then '0.6' else '1')
						margin: '6px 2px'
						width: if ew then '50px' else '70px'
					Ui.avatar Plugin.userAvatar(user.key()),
						style: display: 'inline-block', margin: '0 0 1px 0'
						size: (if ew then 40 else 60)
						onTap: (!-> Plugin.userInfo(user.key()))

					Dom.div !->
						Dom.style overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'
						if ew
							Dom.style fontSize: '75%'
						Dom.text Plugin.userName(user.key())
					if time
						Dom.div !->
							Dom.style fontSize: (if ew then '60%' else '75%'), marginTop: '-1px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'
							if Db.shared.get('nearby', user.key(), 'loading')
								Ui.spinner (if ew then 5 else 9), !->
									Dom.style display: 'inline-block', marginRight: '4px'
							Time.deltaText time, 'short'
			, (user) ->
				nearby = Db.shared.get('nearby', user.key(), 'nearby')
				time = Db.shared.get('nearby', user.key(), 'time') * 0.001
				age = Plugin.time()-time
				if age > 24*60*60 or !nearby?
					if type is 'unknown'
						-time
				else
					if type is 'nearby' and nearby > 0.5
						-time
					else if type is 'elsewhere' and nearby < 0.5
						-time

		Dom.div !->
			if !userCount.get()
				Dom.style display: 'block', margin: '10px 0', color: '#aaa', fontSize: '75%'
				if Geoloc.isSubscribed()
					Dom.text tr("No-one")
				else if type is 'nearby'
					Dom.text tr("(allow updates to see members at this location)")
				else if type is 'elsewhere'
					Dom.text tr("(allow updates to see members who are elsewhere)")
			else
				Dom.style display: 'none'

	Dom.section !->
		name = Db.shared.get('locationName')||tr("On location")
		Dom.div !->
			Dom.style fontWeight: 'bold', fontSize: '120%', color: '#999', marginBottom: '4px'
			Dom.text name
			
		renderUsers 'nearby'

	Dom.div !->
		Dom.style fontWeight: 'bold', margin: '10px 6px 4px 6px', fontSize: '120%', color: '#999', textShadow: '0 1px 0 #fff'
		Dom.text tr("Elsewhere")

	renderUsers 'elsewhere'

	###
	Dom.div !->
		Dom.style fontWeight: 'bold', margin: '10px 6px 4px 6px', color: '#999', textShadow: '0 1px 0 #fff'
		Dom.text tr("Unknown")
	renderUsers 'unknown'
	###

	return


exports.renderSettings = !->
	Dom.div !->
		Dom.style margin: '0 -6px 6px -6px'
		
		Form.box !->
			Dom.style padding: '0 8px 8px 8px'
			Form.input
				name: 'locationName'
				text: tr 'Location name'
				value: Db.shared.func('locationName') if Db.shared

		Form.condition (val) ->
			tr("A location name is required") if !val.locationName

		Form.sep()
		Form.box !->

			if base = Db.shared?.get('base')
				value = base.latitude + ',' + base.longitude

			Dom.text tr("Base location")
			[handleChange] = Form.makeInput
				name: 'base'
				value: value
				content: (value) !->
					Dom.div !->
						if !value
							Dom.text tr("Not set")
							return
						#Geoloc.resolve value
						valueF = value.split(',').map((x)->Math.round(x*10000)/10000).join(', ')
						Dom.text tr("Near %1", valueF)

			Dom.onTap !->
				Geoloc.auth !->
					state = Geoloc.track()
				
					Modal.show tr("Base location"), !->
						Dom.div tr("Set base location to your current location?")
						Dom.div !->
							#Dom.text JSON.stringify(state.get())
							Dom.style marginTop: '8px', color: '#999', fontSize: '85%'
							ac = state.get('accuracy')
							Dom.text tr("Current location accuracy: %1m", if ac? then Math.round(ac) else '?')
					, (choice) !->
						if choice is 'ok' and state.get('ok')
							handleChange state.get('latlong')
						else if choice is 'ok'
							Modal.show tr("No accurate location.")

					, ['cancel', tr("Cancel"), 'ok', !->
						Dom.div !->
							if state.get('ok')
								Dom.style color: ''
								Dom.text tr("Set location")
							else
								Dom.style color: '#aaa'
								Dom.text tr("No location")
					]

			Icon.render
				data: 'map3'
				color: '#ba1a6e'
				style:
					position: 'absolute'
					right: '10px'
					top: '50%'
					marginTop: '-14px'

		Form.sep()
		Form.box !->

			radius = Db.shared?.get('radius')||150

			Dom.text tr("Radius")
			[handleChange] = Form.makeInput
				name: 'radius'
				value: radius
				content: (value) !->
					Dom.div !->
						Dom.text tr("%1 meters", value)

			Dom.onTap !->
				Modal.show tr("Select radius"), !->
					Dom.style width: '60%'
					opts = [150, 250, 500, 1000, 2500, 5000]
					Dom.div !->
						Dom.style
							maxHeight: '45.5%'
							backgroundColor: '#eee'
							margin: '-12px'
						Dom.overflow()
						for rad in opts then do (rad) !->
							Ui.item !->
								Dom.text tr("%1 meters", rad)
								if radius is rad
									Dom.style fontWeight: 'bold'

									Dom.div !->
										Dom.style
											Flex: 1
											padding: '0 10px'
											textAlign: 'right'
											fontSize: '150%'
											color: Plugin.colors().highlight
										Dom.text "✓"
								Dom.onTap !->
									handleChange rad
									radius = rad
									Modal.remove()

		Form.sep()

		Form.condition (val) ->
			tr("A base location is required") if !val.base
