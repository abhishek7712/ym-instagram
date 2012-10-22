#= require "plugins"
#= require "libs/jquery.masonry.min"
#= require "libs/jquery.gomap-1.3.2"

client_id = "49d9e4f5efa14fec989223b14ebefd1f"
redirect_uri = "http://172.16.1.139:4567/"
monthArray = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

address = ""
nextFilename = ""
dataContainer = []
marker = {}
singleViewActive = false
nextPageJSON = ""
currentPhotoIndex = 0
currentPage = 1

String::toProperCase = ->
	@replace /\w\S*/g, (txt) ->
		txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase()

$(window).load ->
	$('#smallView').masonry
		itemSelector: ".feedParent"
		columnWidth: 150
		gutterWidth: 1
		isAnimated: true
		isFitWidth: true

	unless "ontouchstart" of document.documentElement
		$('body').addClass 'backgroundActive'

	setEventListeners()
	loadPhotos('first')

setEventListeners = ->
	$('.viewOptions a').on 'click', switchView
	$(window).on 'scroll', infiniteScroll
	$('.ui-arrow#arrowRight').on 'click', nextSinglePhoto
	$('.ui-arrow#arrowLeft').on 'click', prevSinglePhoto
	$('.ui-back_arrowContainer, .clickbg').on 'click', closeBigImageView
	$('body').on 'keyup', singlePhotoKeyEvent

switchView = ->
	switch $(this).data('view')
		when 'largeView'
			imgSize = 303
			$('#smallView').addClass 'large'
		when 'smallView'
			imgSize = 150
			$('#smallView').removeClass 'large'

	$('.feedParent img').animate
		width: imgSize
		height: imgSize
	,
		duration: 500
		complete: ->
			if imgSize is 303
				$(this).attr
					src: $(this).parent().data().photos.low_resolution.url
			else
				$(this).attr
					src: $(this).parent().data().photos.thumbnail.url

	$('#smallView').masonry
		columnWidth: imgSize


loadPhotos = (jsonURL)->

	if jsonURL == 'done'
		return

	if jsonURL is 'first'
		jsonURL = '/api?page='+currentPage

	$.ajax
		type: 'GET'
		cache: 'false'
		contentType: 'application/json'
		dataType: 'json'
		processData: false
		headers: {'X-Requested-With': 'XMLHttpRequest'}
		url: jsonURL
		success: (data) ->
			$('#smallView').fadeIn()
			$(data).each (i, p) ->
				createNewPhoto(i, p)

				if data.length == 50
					currentPage++
					jsonURL = '/api?page='+currentPage
				else
					jsonURL = 'done'

		error: ->
			alert "An error occured while connecting to the instagram API"


createNewPhoto = (i, photo) ->
	newPhoto = $('<div class="feedParent"></div>')
	if $('#smallView').hasClass 'large'
		newPhoto.append '<img src="'+photo.images.low_resolution.url+'" />'
	else
		newPhoto.append '<img src="'+photo.images.thumbnail.url+'" />'

	newPhoto.data
		'user': photo.full_name
		'printdate': setPrintDate(photo.created_time)
		'captionText': photo.caption
		'photos': photo.images

	if photo.location
		if photo.location.latitude
			newPhoto.data
				'lat': photo.location.latitude
				'long': photo.location.longitude

	$('#smallView').append(newPhoto).masonry 'appended', newPhoto, true

	newPhoto.on 'mouseenter', ->
		$('#smallView').css 'overflow':'visible'

	newPhoto.on 'click', smallPhotoClick


smallPhotoClick = (e) ->
	$(window).scrollTop(0)

	index = $(this).index()
	photo = $(this)
	setImageInfo(photo)
	$('#instagramFeed').fadeOut 100, ->
		loadBigImage(index)
	fadeInSingleView()
	singleViewActive = true


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


loadBigImage = (index) ->
	if index > $('.feedParent').length
		return

	currentPhotoIndex = index
	photo = $('.feedParent').eq(index).data()
	big_url = photo.photos.standard_resolution.url

	img = $('<img id="singleImage" />').attr('src', big_url).load ->
			if not @complete or typeof @naturalWidth is 'undefined' or @naturalWidth is 0
				console.log 'Could not load image.'
			else
				if $('.bigImageContainer').children().size() == 2
					$(".bigImageContainer").prepend img
					touchEvents()
					fadeInSingleView()


loadSingleImage = (index) ->
	$('#singleImage').fadeOut 200, ->
		$('#singleImage').remove()
		loadBigImage(index)
		$newobj = $('.feedParent').eq(index)
		setImageInfo($newobj)

nextSinglePhoto = ->
	totalPhotos = $('.feedParent').length
	currentPhotoIndex++
	if currentPhotoIndex == totalPhotos
		currentPhotoIndex = 0
	loadSingleImage(currentPhotoIndex)


prevSinglePhoto = ->
	totalPhotos = $('.feedParent').length
	unless currentPhotoIndex == 0
		currentPhotoIndex--
	else
		currentPhotoIndex = totalPhotos - 1
	loadSingleImage(currentPhotoIndex)

fadeInSingleView = ->
	$('#singleImage, .bigImageView').fadeIn()
	$('.ui-back_arrowContainer').show()
	$('.ui-view_smallContainer, .ui-view_largeContainer').hide()

infiniteScroll = (e) ->
	unless singleViewActive
		st = $(window).scrollTop()
		bottom = $(document).height() - $(window).height()
		if st is bottom
			unless nextPageJSON is ''
				loadPhotos(nextPageJSON)

setPrintDate = (data) ->
	date = new Date(data*1000)
	d = date.getDate()
	m = date.getMonth()
	y = date.getFullYear()
	month = monthArray[m]
	dateJoin = [d,month,y]
	printdate = dateJoin.join(" ")

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

singlePhotoKeyEvent = (e) ->
	if singleViewActive
		if e.keyCode is 37
			nextSinglePhoto()
		else if e.keyCode is 39
			prevSinglePhoto()

closeBigImageView = ->
	$('.bigImageView').fadeOut 200, ->
		$('.ui-back_arrowContainer').hide()
		$('.ui-view_smallContainer, .ui-view_largeContainer').show()
		$("#singleImage").remove()
		$('#smallView, #instagramFeed, #filterSection').fadeIn()
		singleViewActive = false

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