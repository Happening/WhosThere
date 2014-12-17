Db = require 'db'
Dom = require 'dom'
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

	Dom.h2 !->
		Dom.style margin: '6px 2px'
		Dom.text Plugin.title() || tr("Nearby %1", Plugin.groupName())

	if !Geoloc.isSubscribed()
		Dom.div !->
			Dom.style margin: '25px'

			Dom.div !->
				Dom.style padding: '8px 0', textAlign: 'center', fontSize: '85%'
				Dom.text tr("To get started, we need to access your geolocation updates.")
			Ui.bigButton tr("Allow geolocation updates"), !->
				Geoloc.subscribe()

	else
		Dom.table !->
			Db.shared.iterate 'distances', (dist) !->
				Dom.tr !->
					Dom.th !->
						Dom.text Plugin.userName(dist.key())
					Dom.td !->
						Dom.div !->
							d = dist.get('distance')
							if d > 2500
								Dom.text tr("more than 2500m")
							else
								Dom.text tr("less than %1m", d)
							Dom.div !->
								Dom.style color: '#aaa', fontSize: '85%'
								Time.deltaText dist.get('time')*.001

exports.renderSettings = !->

	Dom.div tr("This plugin will show the coarse distance between a set base geolocation and the geolocation of members.")

	Dom.div !->
		Dom.style margin: '12px -12px -12px'

		Form.sep()
		Form.box !->

			if base = Db.shared?.get('base')
				value = base.latitude + ',' + base.longitude

			Dom.text tr("Base geolocation")
			[handleChange] = Form.makeInput
				name: 'base'
				value: value
				content: (value) !->
					Dom.div !->
						if !value
							Dom.text tr("Not set")
							return
						#Geoloc.resolve value
						Dom.text tr("Near %1", value)

			Dom.onTap !->
				Geoloc.auth (ok) !->
					return if !ok
					state = Geoloc.track()
				
					Modal = require('modal')
					Modal.show tr("Update location"), !->
						Dom.div tr("Update location to your current location?")
						Dom.div !->
							Dom.style padding: '8px'
							Dom.text JSON.stringify(state.get())
					, (choice) !->
						if choice is 'ok' and state.get('ok')
							handleChange state.get('latlong')
						else if choice is 'ok'
							Modal.show tr("No accurate geolocation.")
						else if choice is 'clear'
							handleChange false

					, ['cancel', tr("Cancel"), 'clear', tr("Clear"), 'ok', !->
						if state.get('ok')
							Dom.style color: ''
							Dom.text tr("Set")
						else
							Dom.style color: '#aaa'
							Dom.text tr("No accurate fix")
					]

			Icon.render
				data: 'map3'
				color: '#ba1a6e'
				style:
					position: 'absolute'
					right: '10px'
					top: '50%'
					marginTop: '-14px'



