Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Form = require 'form'
Loglist = require 'loglist'
Obs = require 'obs'
Page = require 'page'
Photo = require 'photo'
App = require 'app'
Server = require 'server'
Time = require 'time'
Ui = require 'ui'
Geoloc = require 'geoloc'
Icon = require 'icon'
{tr} = require 'i18n'

exports.render = !->

	myLoc = Db.shared.get('dist', App.userId())
	base = Db.shared.get('base')

	Dom.style textAlign: 'center'

	if !Geoloc.isSubscribed()
		Dom.div !->
			Dom.style position: 'relative', margin: '10px 10px 20px 10px', padding: '10px', border: '1px solid #aaa', borderRadius: '10px', backgroundColor: '#EEE'
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
			if App.userIsAdmin() or App.ownerId() is App.userId()
				Dom.text tr("Configure the base location in the plugin settings")
			else
				Dom.text tr("The base location for this plugin hasn't been configured yet")

		return

	Server.send 'update'

	renderUsers = (type) !->
		userCount = Obs.create(0)
		if Geoloc.isSubscribed()
			App.users.observeEach (user) !->
				userCount.incr()
				Obs.onClean !->
					userCount.incr(-1)
				Dom.div !->
					ew = type is 'elsewhere'
					time = Db.shared.get('nearby', user.key(), 'time') * 0.001
					age = App.time()-time
					Dom.style
						Box: 'center middle'
						display: 'inline-block'
						opacity: if !time or age > 30*60 then '0.35' else (if age > 15*60 then '0.6' else '1')
						margin: '6px 2px'
						width: if ew then '50px' else '70px'
					Ui.avatar App.userAvatar(user.key()),
						style: display: 'inline-block', margin: '0 0 1px 0'
						size: (if ew then 40 else 60)
						onTap: (!-> App.showMemberInfo(user.key()))

					Dom.div !->
						Dom.style overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'
						if ew
							Dom.style fontSize: '75%'
						else
							Dom.style fontSize: '85%'
						Dom.text App.userName(user.key())
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
				age = App.time()-time
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

	Page.setCardBackground()

	Dom.section !->
		Dom.style padding: 12
		name = App.title()||tr("On location")
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

	Obs.observe !->
		if Geoloc.isSubscribed()
			tracker = Geoloc.track(0, 1)
	return


exports.renderSettings = !->
	Form.input
		name: '_title'
		text: tr 'Location name'
		value: App.title()

	Form.condition (val) ->
		tr("A location name is required") if !val._title


	[baseHandle] = Form.makeInput
		name: 'base'
		value: null
		content: (value) !->
			Form.box
				content: tr("Base location")
				sub: !->
					if !value
						Dom.text tr("Not set")
						return
					#Geoloc.resolve value
					valueF = value.split(',').map((x)->Math.round(x*10000)/10000).join(', ')
					Dom.text tr("Near %1", valueF)
				onTap: !->
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
								baseHandle state.get('latlong')
							else if choice is 'ok'
								Modal.show tr("No accurate location.")

						, ['cancel', tr("Cancel"), 'ok', !->
							if state.get('ok')
								Dom.style color: ''
								Dom.text tr("Set location")
							else
								Dom.style color: '#aaa'
								Dom.text tr("No location")
						]
				icon: 'map3'

	Obs.observe !->
		radius = Db.shared?.get('radius')||150
		[radiusHandle] = Form.makeInput
			name: 'radius'
			value: radius
			content: (value) !->
				Form.box
					content: !-> Dom.text tr("%1 meters", value)
					onTap: !->
						Modal.show tr("Select radius"), !->
							opts = [150, 250, 500, 1000, 2500, 5000]
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
												color: App.colors().highlight
											Dom.text "✓"
									Dom.onTap !->
										radiusHandle rad
										radius = rad
										Modal.remove()

	Form.condition (val) ->
		tr("A base location is required") if !val.base