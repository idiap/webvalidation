function getCurrentSeconds() {
	return Math.round(new Date().getTime() / 1000);
}
var start_seconds = getCurrentSeconds();

$(document).ready(function(){

	// show loading layer when moving folders from annotation space
	$('#annotationpage #validation').on('click', 'a', function(){
		$('#loading').show();
	});

	// handle clicks to show directory tree on the completed page
	$('#completedpage #completed').on('click', '.folder > .name', function(e){
		e.stopImmediatePropagation();
		$(this).parent().toggleClass('opened');
	});

	// hide messages with a click
	$('#messages').click(function(){
		$(this).addClass('close');
	});
});
