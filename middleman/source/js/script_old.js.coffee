#= require "plugins"
#= require "libs/jquery.masonry.min"
#= require "libs/jquery.gomap-1.3.2"

client_id = "49d9e4f5efa14fec989223b14ebefd1f"
redirect_uri = "http://172.16.1.139:4567/"
monthArray = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

address = ""
dataContainer = []
marker = {}
nextFilename = ""
singleViewActive = false

String::toProperCase = ->
	@replace /\w\S*/g, (txt) ->
		txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()

$(window).load ->

	$(".viewOptions").on "click", "a", (e) ->
		e.preventDefault()
		whatView($(this).data('view'))
	$('#smallView').masonry
		itemSelector: ".feedParent"
		columnWidth: 150
		gutterWidth: 1
		isAnimated: true
		isFitWidth: true
	getFeed()

getFeed = ->
	$.ajax
		type: "GET"
		cache: "false"
		datatype: "json"
		url: "feed.json"
		success: (data) ->
			i = 0
			dataContainer = data

			while i < data.length
				createNewInstaPic(data[i].images.thumbnail.url,i,"smallView")
				$currObj = $('#smallView').children().last()
				$currObj.data('user':data[i].caption.from.full_name)

				#set date
				printdate = setprintDate(data[i].caption.created_time)
				$currObj.data('printdate':printdate)

				#set caption
				$currObj.data('captionText':data[i].caption.text)

				#set lat and long values
				if data[i].location
					if data[i].location.latitude
						$currObj.data('lat':data[i].location.latitude)
						$currObj.data('long':data[i].location.longitude)
				i++
				console.log $currObj.data()

		error: (data) ->
			alert "An error occured while connecting to the instagram API"
		complete: (data) ->
			# $('#smallView').masonry('reload')

			fadeInFeed()

unless "ontouchstart" of document.documentElement
	$('body').addClass('backgroundActive')
	#$('.ui-arrow').hide()


#infinite scroll stuff
$(window).on 'scroll', (e) ->
	st = $(window).scrollTop()
	bottom = $(document).height() - $(window).height()
	if st is bottom
		getFeed()


touchEvents = ->
	originX = 0
	movingX = 0
	touchelem = document.getElementById('singleImage')
	touchelem.ontouchstart = (e) ->
		originX = e.targetTouches[0].pageX

	touchelem.ontouchmove = (e) ->
		movingX = e.targetTouches[0].pageX

	touchelem.ontouchend = (e) ->
		diff = movingX - originX
		if diff > 200
			changeImage("arrowRight")

		else if diff < -200
			changeImage("arrowLeft")


changeImage = (direction) ->
	newFeednum = 0
	currFeedNum = $('.bigImageContainer').data('currFeedNum')
	containerLength = $('#smallView').children().size()
	if direction == "arrowLeft"
		if currFeedNum - 1 >= 0
			newFeednum = currFeedNum - 1
#				console.log newFeednum
		else
			newFeednum = containerLength - 1
	else if direction == "arrowRight"
		if currFeedNum + 1 < containerLength
			newFeednum = currFeedNum + 1
		else
			newFeednum = 0

		console.log newFeednum
	$('#singleImage').fadeOut 200, ->
		$('#singleImage').remove()
		#load new image
		loadBigImage(newFeednum)
		$newobj = $('.feedParent:eq('+newFeednum+')')
		#set the new image info
		setImageInfo($newobj)

#attach keyevents to singleview

$('body').keyup (e) ->
	if singleViewActive
		console.log "keypress"
		if e.keyCode is 37
			changeImage("arrowLeft")
		else if e.keyCode is 39
			changeImage("arrowRight")


#set clickhandlers on navarrows in singleview
$('.ui-arrow').click (e) ->
	e.preventDefault()
	changeImage($(this).attr('id'))

#set closebutton click
$('.ui-back_arrowContainer, .clickbg').click (e) ->
	e.preventDefault()
	closeBigImageView()

closeBigImageView = ->
	currentView = $('body').attr "class"
	currViewObj = $('#'+currentView)
	newImg = $('.bigImageView')
	newImg.fadeOut 200, ->
		$('.ui-back_arrowContainer').hide()
		$('.ui-view_smallContainer').show()
		$('.ui-view_largeContainer').show()
		# $('#map_canvas').empty()
		$("#singleImage").remove()
		fadeInFeed()
		currViewObj.masonry('reload')
		currViewObj.css('overflow-x':'visible')
		currViewObj.css('overflow-y':'visible')
		# $('#map_canvas').remove()
		singleViewActive = false


setprintDate = (data) ->
	#set date
	date = new Date(data*1000)
	d = date.getDate()
	m = date.getMonth()
	y = date.getFullYear()
	month = monthArray[m]
	dateJoin = [d,month,y]
	printdate = dateJoin.join(" ")


whatView = (viewType) ->
	body = $('body')
	#currentView = body.attr "class"
	currentView = body.data('class')
	console.log currentView
	switch viewType
		when "smallView"
			unless body.hasClass(viewType)
				$("#"+currentView).fadeOut(20)
				changeView(viewType)
		when "largeView"
			unless body.hasClass(viewType)
				$("#"+currentView).fadeOut(20)
				changeView(viewType)
		when "listView"
			unless body.hasClass(viewType)
				changeView(viewType)

changeView = (viewtype) ->
	#$('body').attr('class':viewtype)
	console.log viewtype
	$('body').data('class':viewtype)
	$viewObj = $("#"+viewtype)
	i = 0
	if $viewObj.children().length  > 0
		console.log "has children"
		$viewObj.delay(30).fadeIn()
		#$viewObj.masonry('reload')
		#$viewObj.css('overflow-x':'visible')
		#$viewObj.css('overflow-y':'visible')

	else
		while i < dataContainer.length
			createNewInstaPic(dataContainer[i].images.low_resolution.url,i,viewtype)
			$currObj = $viewObj.children().last()
			$currObj.data('user':dataContainer[i].caption.from.full_name)

			#set caption
			$currObj.data('captionText':dataContainer[i].caption.text)

			#set date
			printdate = setprintDate(dataContainer[i].caption.created_time)
			$currObj.data('printdate':printdate)

			#set lat and long values
			if dataContainer[i].location
				if dataContainer[i].location.latitude
					$currObj.data('lat':dataContainer[i].location.latitude)
					$currObj.data('long':dataContainer[i].location.longitude)
			i++
			if viewtype is "largeView"
				if i is dataContainer.length
					$('#largeView').masonry
						itemSelector: ".feedParent"
						columnWidth: 303
						isAnimated: true
						isFitWidth: true
						gutterWidth: 1

					$('#largeView').masonry('reload')
					$('#largeView').css('overflow-x':'visible')
					$('#largeView').css('overflow-y':'visible')

createNewInstaPic = (url,nr,viewtype) ->
	$newElement =$("<div class=feedParent></>")
	$newElement.append "<img src="+url+" />"
	parent = $('#'+viewtype)
	parent.append($newElement).masonry 'appended', $newElement, true
	setDataElement = $('#instagramFeed').children(':last')

	$newElement.click (e) ->
		e.preventDefault()
		$(window).scrollTop(0)
		fadeOutFeed(nr)
		setImageInfo($(this))
		fadeInSingleView()
		$('.bigImageView').fadeIn()
		singleViewActive = true

fadeInFeed = ->
	delayVal = 0
	$('#instagramFeed, #filterSection').show()

	currentView = $('body').attr "class"
	currViewObj = $('#'+currentView)

	currViewObj.children().each ->
		$(this).css('display','block')
		$(this).delay(delayVal).animate({'opacity':1})
		delayVal += 50


fadeOutFeed = (num) ->
	$('#instagramFeed').fadeOut 100, ->
		loadBigImage(num)
		$("#filterSection").fadeOut(50)


loadBigImage = (num) ->

	data = dataContainer[num]
	big_url = dataContainer[num].images.standard_resolution.url

	img = $('<img id="singleImage" />').attr('src', big_url).load( ->
			if not @complete or typeof @naturalWidth is 'undefined' or @naturalWidth is 0
				console.log 'Could not load image.'
			else
				if $('.bigImageContainer').children().size() == 2
					$(".bigImageContainer").prepend img
					$(".bigImageContainer").data("currFeedNum":num)
					#activate swiping gestures
					touchEvents()

					fadeInSingleView()
			)


fadeInSingleView = ->
	$('#singleImage').fadeIn()
	$('.ui-back_arrowContainer').show()
	$('.ui-view_smallContainer').hide()
	$('.ui-view_largeContainer').hide()


setImageInfo = ($obj) ->
	captionTxt = $obj.data('captionText')
	user = $obj.data('user').toProperCase()
	printdate = $obj.data('printdate')
	lat = $obj.data('lat') or ""
	long = $obj.data('long') or ""
	if long
		initgooglemaps(lat, long)
	else
		$('#map_canvas').hide()
	$('.caption .picdata .userdate').html "Taken by " + user + " on " + printdate
	$('.caption .picdata .location').html ""
	$('.captionText').html captionTxt


initgooglemaps = (lat, long) ->

	$("#map_canvas").goMap
		markers: [
			latitude: 40.738334655
			longitude: -73.989166259
			id: "swordMarker"
		 ]
		icon: "images/map-marker.png"
		addMarker: true

	stylez = [
		stylers: [ saturation: -100 ]
	]

	latlng = new google.maps.LatLng(lat, long)
	geocoder = new google.maps.Geocoder();

	geocoder.geocode
		latLng: latlng
	,(results, status) ->
		if status is google.maps.GeocoderStatus.OK
			if results[1]
				address = results[0].formatted_address
				if address is '29 E 19th St, New York, NY 10003, USA' or address is '35 E 19th St, New York, NY 10003, USA'
					address = "Your Majesty's New York office (29 E 19th St, New York, NY 10003, USA)"
				$('.caption .picdata .location').append " @ " + address

				$.goMap.setMap
					latitude: lat
					longitude: long
					zoom: 16
					mapTypeControlOptions:
						mapTypeIds: [ google.maps.MapTypeId.HYBRID, "ym" ]

				$.goMap.setMarker "swordMarker",
					latitude: lat
					longitude: long

				styledMapOptions = name: "YM"
				bwMap = new google.maps.StyledMapType(stylez, styledMapOptions)
				$.goMap.map.mapTypes.set "ym", bwMap
				$.goMap.map.setMapTypeId "ym"

				$('#map_canvas').show()

			else
				console.log "No results found"
		else
			console.log status