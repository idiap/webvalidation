#!/usr/bin/perl -w

# Copyright (c) 2014 Idiap Research Institute, http://www.idiap.ch/
# Written by Alexandre Nanchen <alexandre.nanchen@idiap.ch>,
# Christine Marcel <christine.marcel@idiap.ch>,
# Renato S. Martins

# This file is part of Webvalidation.

# Web validation is free software: you can redistribute it and/or modify
# it under the terms of the BSD 3-Clause License as published by
# the Open Source Initiative.

# Web validation is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# BSD 3-Clause License for more details.

# You should have received a copy of the BSD 3-Clause License
# along with Web validation. If not, see <http://opensource.org/licenses/>.

package Webvalidation;

#Library
require Exporter; 
use strict;

# use strict "subs";
# use strict "vars";
# not use strict "refs" because of how packaged functions are tracked
use UNIVERSAL qw(isa);
use FileHandle;
use POSIX;  # used for debugging right now
use CGI::Pretty;
use File::Copy;
use Encode;
use AppConfig qw(:expand :argcount);
use Fcntl qw(:flock);
use File::Copy::Recursive qw(dirmove);
use File::Path 'make_path';


BEGIN {
	
  our @ISA = qw(Exporter);
  our $VERSION = 0.1;
  our @EXPORT = qw();
  our %EXPORT_TAGS = ();
  
  our @EXPORT_OK = qw(get_next_wav_file get_text_name $website_url_domain $webapp_salt $cookie_name $db_config $data_directory_url $data_directory $media_url $cgi_web_directory $sentence_folder_name 
  					  @projects @groups
                      print_javascript_document_ready_header 
  					  print_javascript_document_ready_footer print_javascript_jplayer_sound_setup 
  					  print_jplayer_graphics get_text_from_file_path $wav_extension $text_extension print_information print_title
  					  write_text_to_file_path make_directory move_directory move_sentence clean_accepted dircontent $accepted_folder_name $refused_folder_name copy_sentence
  					  print_help $initial_volume print_navigation print_loading_layer print_messages array_has);
}

#Read the data in conf file
my $config = AppConfig->new("website_url_domain"  => {ARGCOUNT => ARGCOUNT_ONE},
                            "webapp_salt"		  => {ARGCOUNT => ARGCOUNT_ONE},
                            "cookie_name"		  => {ARGCOUNT => ARGCOUNT_ONE},
                            "projects"			  => {ARGCOUNT => ARGCOUNT_LIST},
                            "groups"			  => {ARGCOUNT => ARGCOUNT_LIST},
                            "db_config"			  => {ARGCOUNT => ARGCOUNT_HASH},
                            "data_directory_url"  => {ARGCOUNT => ARGCOUNT_ONE},
                            "data_directory"  	  => {ARGCOUNT => ARGCOUNT_ONE},
                            "media_url"  	  => {ARGCOUNT => ARGCOUNT_ONE},
                            "asrf_web_directory"  => {ARGCOUNT => ARGCOUNT_ONE},
                            "cgi_web_directory"   => {ARGCOUNT => ARGCOUNT_ONE},
                            "sentence_folder_name"=> {ARGCOUNT => ARGCOUNT_ONE},
                            "accepted_folder_name"=> {ARGCOUNT => ARGCOUNT_ONE},
                            "refused_folder_name" => {ARGCOUNT => ARGCOUNT_ONE},
                            "wav_extension"	  => {ARGCOUNT => ARGCOUNT_ONE},
                            "text_extension"	  => {ARGCOUNT => ARGCOUNT_ONE},
                            "initial_volume" 	  => {ARGCOUNT => ARGCOUNT_ONE});

$config->file('/etc/webvalidation/webvalidation.conf');

#Initialisation des paramètres du daemon
our $website_url_domain = $config->website_url_domain();
our $webapp_salt = $config->webapp_salt();
our $cookie_name = $config->cookie_name();
our @projects = @{$config->projects()};
our @groups = @{$config->groups()};
our $db_config = $config->db_config();
our $data_directory_url = $config->data_directory_url();
our $data_directory = $config->data_directory();
our $media_url = $config->media_url();
our $asrf_web_directory = $config->asrf_web_directory();
our $cgi_web_directory = $config->cgi_web_directory();
our $sentence_folder_name = $config->sentence_folder_name();
our $accepted_folder_name = $config->accepted_folder_name();
our $refused_folder_name = $config->refused_folder_name();
our $wav_extension = $config->wav_extension();
our $text_extension = $config->text_extension();
our $initial_volume = $config->initial_volume();


#Find a wav file matching the pattern section_subtest.wav and
#return prefix if any (speaker id) with file name
#
#param input_folder		: folder containing the wav files
#return the name of the next wav file

sub get_next_wav_file {
	
	my ($input_folder) = @_;
	
	opendir(DIR, $input_folder) or return '';
	
	my @files = sort(grep(/\.wav$/,readdir(DIR)));
	
	#Context dependent
	my $fileNumber = @files;
	
	closedir(DIR);
	
	if ($fileNumber == 0) {
		
		return "";		
	}
	
	#First in the list
	return $files[0];	
}


#Get the annotation name from wav file name
#
#param wavFileName: the name of the wav file
#return the name of the annotated text file

sub get_text_name {
	
	my ($wavFileName) = @_;
	
	my $baseName = substr($wavFileName, 0, length($wavFileName) - length($wav_extension));
	my $textName = $baseName . $text_extension;
	
	return ($textName, $baseName);	
}

#Get the content of a text file as a list.
#
#param filePath: the path of the file to extract text from
#return a list of lines

sub get_text_from_file_path {
	
	my ($filePath) = @_;		
	
	if (!open(MYFILE, $filePath)) {
		
		#Return an anonymous array
		return ("Unknown file.");	
	}
	
	my @content = <MYFILE>;
	
	close(MYFILE);
	
	return @content;
}

#Write the given content to the file.
#This override the file content.
#
#param $filePath: the file to write to
#param $strContent: the content to write

sub write_text_to_file_path {
	
	my ($filePath, $strContent) = @_;
	
	#Output uft-8 with checking
	#Don't do the actual decoding
	open(MYFILE, ">:encoding(UTF-8)", "$filePath") or die "$!";

	print STDERR "opened file: $filePath \n";
	
	#Received string is not in utf-8
	#Make sure it is now (no harm done if
	#already in utf-8)
	$strContent = decode_utf8($strContent);
		
	print MYFILE $strContent;
	
	close(MYFILE);		
}

#Check existence of dirname in path.
#
#param path: the place for creating the directory
#param dirName: the name of the directory to create 

sub make_directory {
	
	my ($path, $dirName) = @_;
	
	my $fullPath = $path . "/" . $dirName;
	
	if (-e $fullPath) {
		
		return;
	}
	
	mkdir $fullPath;		
}


###
# Move a directory content into a second directory (the latter will be created
# if it doesn't exist). This function locks the source folder while moving it.
# Returns the number of files and folders moved (if an error occurs returns -1).
#
# $source (string): source folder path
# $destination (string): destination folder path
#
# Example:
# $result = move_directory('/source/folder', '/destination/folder');
###
sub move_directory {
	my ($source, $destination) = @_;
	return 0 if ( ! -e $source);

	my $result = 0;
	eval {
		open(SRC, $source) or return 0;
		flock(SRC, LOCK_EX) or return 0;
		print STDERR "moving dir: $source => $destination \n";
		$result = dirmove($source, $destination);
		close(SRC);
		print STDERR "move dir ok \n" if (!$result);
	};
	$result;
}


###
# Move a sentence (ie. the wav and txt files) with given name from source folder
# to a destination folder.
#
# $source (string): source folder path
# $file_basename (string): sentence filename without the extension
# $destination (string): destination folder path
###
sub move_sentence {
	my ($source, $file_basename, $destination) = @_;
	# select the files to move
	my $wav_file = "${source}/${file_basename}.wav";
	my $txt_file = "${source}/${file_basename}.txt";
	my $result;
	eval {
		print STDERR "moving sentence: $source/$file_basename => $destination \n";
		# make sure there is a destination folder
		make_path($destination);
		# move wav and txt files
		$result = move($wav_file, $destination);
		$result *= move($txt_file, $destination);
		print STDERR "move sentence ok \n" if (!$result);
	};
	$result;
}


###
# Move all files from `accepted` folder into main folder.
#
# $data_path (string): main folder path
###
sub clean_accepted {
	my $data_path = shift(@_);
	my @files = glob("$data_path/$accepted_folder_name/*");
	print STDERR "move from accepted: $data_path \n";
	move($_, $data_path) for (@files);
	print STDERR "move accepted ok \n";
}


###
# Returns a hash reference with the content of a given directory.
# Files and directories that begin with dot (.) are ignored, and also `accepted`
# and `refused` folders (except if `$no_ignore` is set to true).
# It is structured as the following example:
#
# {
#     'a.txt' => 'a.txt',
#     'b.txt' => 'b.txt',
#     'c' => {
#         'c_1' => {
#             'c_1_1.txt' => 'c_1_1.txt',
#             'c_1_2.txt' => 'c_1_2.txt'
#         },
#         'c2.txt' => 'c2.txt'
#     },
#     'd' => {}
# }
#
# Note that:
# - values of files are the same as their keys;
# - values of directories are hash references too;
# - empty directories are empty hashes references.
# 
# $path (string): directory path
# $depth (integer): maximum depth to go into the directory tree - depth=0 would
#   only display the content of given directory, depth=1 would display also the
#   content of directory `c` and depth=2 would display content of `c_1`, etc.
# $no_ignore (bool): don't ignore any folder, shows even `accepted` and
#   `refused` folders
#
# Example:
# $content = dircontent('/root/folder/path');
###
sub dircontent {
	my ($path, $depth, $no_ignore) = @_;
	$depth = -1 if (!defined($depth));
	my $content = {};
	# if directory cannot be opened return an empty hash reference
	opendir(DIR, $path) or return $content;
	# we don't want any entries that begin with a dot
	# or folders named `accepted` and `refused`
	my @entries = grep {
		$no_ignore ? !/^\./ : !/(^\.)|(accepted)|(refused)/;
	} readdir(DIR);
	closedir(DIR);

	foreach my $entry (@entries) {
		my $filename = $entry;
		$entry = "$path/$entry";
		if (-f $entry) {
			$content->{$filename} = $filename;
		}
		elsif (-d $entry) {
			if ($depth != 0) {
				$content->{$filename} = dircontent($entry, $depth-1, $no_ignore);
			}
			else {
				$content->{$filename} = {};
			}
		}
	}
	$content;
}


###
# Test if a string exists in a list
#
# $string (string)
# @list (array)
#
# Returns: boolean
###
sub array_has {
	my ($string, @list) = @_;
	scalar(grep({$_ eq $string} @list));
}


#Copy text file and wav file into appropriate folder.
#
#param currentSentenceFolder: the working sentence folder
#param baseName				: the name of the sentence
#param accepted				: the result of the validation

sub copy_sentence {
	
	my ($currentSentenceFolder, $baseName, $submitValue) = @_;
	
	#Check directory existence
	make_directory($currentSentenceFolder, $submitValue);
	
	#The files to copy
	my $wavToMove = $currentSentenceFolder . "/" . $baseName . $wav_extension;
	my $textToMove = $currentSentenceFolder . "/" . $baseName . $text_extension;
	
	#The location where to copy
	my $resultLocation = $accepted_folder_name;
					
	if ($submitValue eq $refused_folder_name) {
		
		$resultLocation = $refused_folder_name;		
	}
	
	#The validated - refused location
	my $destination = $currentSentenceFolder . "/" . $resultLocation;
	
	move($wavToMove, $destination);
	move($textToMove, $destination);	
}


###
# Print a navigation menu (div#navigation).
#
# $cgi (CGI): a CGI object
# $current (string): current script
# $user (hasref): the logged in user
###
sub print_navigation {
	my ($cgi, $current, $user) = @_;

	my $get_anchor = sub {
		my ($page, $name) = @_;
		my $attrs = {-href => $page};
		$attrs->{-class} = 'current' if ($page eq $current);
		$cgi->a($attrs, $name);
	};

	print $cgi->start_div({-id => 'navigation', -class => 'whitebox'});
	if ($user) {
		print $cgi->start_ul({-id => 'links'});
		print $cgi->li(&$get_anchor('annotation_space.pl', 'Annotation Space'));
		print $cgi->li(&$get_anchor('user_space.pl', 'User Space'));
		if ($user->{groupname} eq 'admin') {
			print $cgi->li(&$get_anchor('completed.pl', 'Completed'));
			print $cgi->li(&$get_anchor('new_user.pl', 'New User'));
			print $cgi->li(&$get_anchor('stats_user.pl', 'Statistics'));
		}
		print $cgi->end_ul();
	}

	print $cgi->start_div({-id => 'user'});
	if ($user) {
		print $cgi->div({-id => 'login'},
			$user->{login} . $cgi->span({-class => 'arrow'}, '▼') .
			$cgi->start_ul() .
			$cgi->li(&$get_anchor('edit_user.pl', 'Edit User')) .
			$cgi->li(&$get_anchor('logout.pl', 'Logout')) .
			$cgi->end_ul()
		);
	}
	print $cgi->end_div();

	print $cgi->end_div();
}


###
# Print an overlay box with a loading GIF.
#
# $cgi (CGI): a CGI object
###
sub print_loading_layer {
	my $cgi = shift(@_);
	print $cgi->div({-id => 'loading'},
		$cgi->div({-id => 'content'},
			$cgi->img({-src => $media_url . 'images/loader.gif'}) .
			'Processing...'
		)
	);
}


###
# Print a list of messages in a popup.
#
# $cgi (CGI): a CGI object
# @msgs (array): messages (strings) to render in the page
###
sub print_messages {
	my ($cgi, @msgs) = @_;
	if (scalar(@msgs)) {
		print $cgi->div({-id => 'messages'}, join($cgi->br(), @msgs));
	}
}


#Print the formatted title of the page and
#exit

sub print_information {
	
	my ($cgi, $title) = @_;
	
	print $cgi->header(-type => 'text/html; charset=UTF-8'),
          $cgi->start_html(-title=>"Sentences validation", 
                           -style => [{ -src => "$media_url/css/style.css",
                             		    -type => 'text/css',
                             		    -media => 'all' }]);
    
	print_title($title);
		
	print $cgi->end_html;                             		    
		  	
}

#The formatted title

sub print_title {
	
	my ($title) = @_;
	
	print qq{<div id="title">};

	print qq{<h2>Check: $title</h2>};

	print qq{</div>};		
}

#User help

sub print_help {

	print qq{<h5>Shortcut keys</h2>};
	print qq{<p class='help'><b>alt+p:</b> start-pause</p>};
	print qq{<p class='help'><b>alt+i:</b> select text area</p>};
	print qq{<p class='help'><b>alt+a:</b> accept</p>};
	print qq{<p class='help'><b>alt+r:</b> refuse</p>};	
	print qq{<p class='help'><b>6:</b> 3 secs backward</p>};
	print qq{<p class='help'><b>7:</b> 3 secs forward</p>};
	
}

#Java script header for document ready event

sub print_javascript_document_ready_header {
	
	print qq{<script language="JavaScript">};   	
   	print "\$(document).ready(function() {\n";      	
	
}

#Java script footer for document ready event

sub print_javascript_document_ready_footer {	
	
	#Force setting for google chrome?
	#print "document.getElementById('idAutoPlay').value='12';\n";
	
	#End of document.ready event
	print "}); //end document ready event\n\n"; 		
	
	#Function to handle auto submit of text	
	print_auto_submit();
	
	#The document respond to key strokes	
	print_keystroke_event();
  	
  	#Keystroke handler for document
  	print_key_stroke_handler();
  	
  	#Keystroke handler for text area
  	print_click_handler();
  	
  	#Key shortcuts
  	print_play_pause();
  	print_go_backward();
  	print_go_forward();
	  	         	
	#Check that it is listened
	print_check_listen();
	  	         	
   	print qq{</script>\n};
   		
}

#Auto submit javascript function
sub print_auto_submit {
	
	print "function AutoSubmit() {\n";
	
	print "var auto = document.getElementById('idAutoPlay');\n".  					   
	  					       				   
    	  "if (auto.value == 'true') { \n".                       
          "  //document.getElementById('accepted').click();\n".
          "}\n".
          "else {\n".          
          "  auto.value='true';\n" .
          "  \$('#jpId').jPlayer('play')" .                                 
          "}\n";
                       	
	print "}\n";
}

#Register keystroke listener

sub print_keystroke_event {
			
	print qq{document.onkeypress = KeyPressHappened;\n};
	print qq{document.onkeyup = KeyUpHappened;\n};
}

#Handle key strokes for document
sub print_key_stroke_handler {

	print "function getKeyCode(e) {\n";  
	print qq{	if (!e) e=window.event;\n};  	
    	  	 	  	
  	print qq{	var code;\n};   
  
  	print qq{	if ((e.charCode) && (e.keyCode==0))\n};
    print qq{		code = e.charCode;\n};
  	print qq{	else\n};
    print qq{		code = e.keyCode;\n};
    print qq{	return code;\n};
    print "}\n";

		
	print "function KeyUpHappened(e) {\n"; 

	print qq{	var code = getKeyCode();\n};  
  
  	print qq{	if (e.altKey && code == 80)\n};  	
  	print "		{";  	
  	print qq{		playPauseAudio();\n};
  	print "		}";
  	
  	#Do not include shift key (cf. when opening a new window with holding shift)
  	print qq{   if (code != 16) \n};
  	print "		{";
  	
  	print_disable_auto_submit();
  	
  	print "		}";
  			  
	print "}\n";	


	print "function KeyPressHappened(e) {\n"; 

	print qq{	var code = getKeyCode();\n};  

  	print qq{	if (code == 54)\n};  	
  	print "		{";  	
  	print qq{		goBackward();\n};
  	print qq{		return false;\n};
  	print "		}";

  	print qq{	else if (code == 55)\n};  	
  	print "		{";  	
  	print qq{		goForward();\n};
  	print qq{		return false;\n};
  	print "		}";
  			  
	print "}\n";	
}

#Handle key strokes for document
sub print_click_handler {
	
	print "function ClickedHappened(e) {\n";	
	
	print_disable_auto_submit();
	
	print "}\n";  
}



#Disable auto submit
sub print_disable_auto_submit {
	
	print qq{   var auto = document.getElementById('idAutoPlay');\n};
    print qq{   auto.value = 'false' ;\n};
  	
}

#Enable auto submit
sub print_enable_auto_submit {
	
	print qq{   var auto = document.getElementById('idAutoPlay');\n};
    print qq{   auto.value = 'true' ;\n};
  	
}

#Play - pause shortcut

sub print_play_pause {
	
	print "function playPauseAudio() {\n";
	
	print qq{if(\$("#jpId").data("jPlayer").status.paused)\n};
  	print qq{ \$("#jpId").jPlayer("play");\n};
  	print qq{ else\n};
  	print qq{ \$("#jpId").jPlayer("pause");\n};  	
	print "};\n";	
}

# Go backward shortcut

sub print_go_backward {
	print <<'JS';
	function goBackward() {
		var $jp = $("#jpId");
		var curtime = $jp.data('jPlayer').status.currentTime;
		$jp.jPlayer('play', curtime - 3);
	}
JS
}

# Go forward shortcut

sub print_go_forward {
	print <<'JS';
	function goForward() {
		var $jp = $("#jpId");
		var curtime = $jp.data('jPlayer').status.currentTime;
		$jp.jPlayer('play', curtime + 3);
	}
JS
}

#Check that the user has listen

sub print_check_listen {
	
	print "function checkform() {\n";
	print "  var volume = document.getElementById('idEnded');\n";
	print "  if (volume.value != 'true') { \n";
	print "        alert('Please listen to the sample first.');\n";
	print "        return false;\n";
	print "   }\n";
	print "  var spent = document.getElementById('spent');\n";
	print "  spent.value = getCurrentSeconds() - start_seconds;\n";
	print "  return true;\n";
	print "}\n";	
}


#With event checking that the user has listen
#
#param divId    : the id of the player
#param wav_path : the path to the sound file
#param suffix   : the suffix for the css classes (i.e. small)

sub print_javascript_jplayer_sound_setup {
	
	my ($divId, $wav_path, $volume_level) = @_;
	
	#Volume change event
    my $eventSound = "\$('#jpId').bind(\$.jPlayer.event.volumechange, function(event) {\n" .    				    
   	                   "var volume = document.getElementById('idVolume');\n" .
   	                   #"alert(volume.value);\n" .
                       "volume.value = event.jPlayer.status.volume ;\n" . 
    				   "});";

	#Ended event
    my $eventEnded = "\$('#${divId}').bind(\$.jPlayer.event.ended, function(event) {\n" .
    				   
   	                   "var ended = document.getElementById('idEnded');\n" .
                       "ended.value = 'true' ;\n" .
                       
                       "var auto = document.getElementById('idAutoPlay');\n".                       
                       
                       "if (auto.value == 'true') { \n".                       
          			   "  setTimeout('AutoSubmit()', 3000);\n".
          			   "}\n".
          			   "else {\n".          
          			   "  auto.value='true';\n" .             
          			   "  \$(this).jPlayer('play');\n".
          			   "}\n".
          			                                 					   	
    				   "});\n";    				   
    				 
    				   	
	print_javascript_jplayer($divId, $wav_path, "", $volume_level, $eventSound, $eventEnded);
}


#Print the javascript event that setup jplayer
#
#param divId    : the id of the player
#param wav_path : the path to the sound file
#param suffix   : the suffix for the css classes (i.e. small)
#param events   : the events to setup

sub print_javascript_jplayer {
	
	my ($divId, $wav_path, $suffix, $volume_level, $eventSound, $eventEnded) = @_;
	
	unless (defined($eventSound)) {
		$eventSound="";
	}
	
	unless (defined($eventEnded)) {
		$eventEnded="";
	}
	
	$suffix = get_full_css_suffix($suffix);
	
	print "  \$('#${divId}').jPlayer( {\n";
    print "      ready: function () {\$(this).jPlayer('setMedia', { wav: '$wav_path'}).jPlayer('play');},\n";                   
    print "      preload: 'auto',\n";
    print "      volume: $volume_level,\n";
    print "      solution: 'html',\n";
    print "      supplied: 'wav',\n";
    print "      swfPath: '$media_url/js',\n";
    #print "      errorAlerts:true ,\n";
    #print "      warningAlerts:true ,\n";
    print "      swfPath: '$media_url/js',\n";
    print "      cssSelectorAncestor: '#jp_interface_${divId}',\n";
    print qq(    cssSelector:{videoPlay:"", play:".jp-play${suffix}", pause:".jp-pause${suffix}", stop:".jp-stop${suffix}",\n);
    print qq(                  seekBar:".jp-seek-bar${suffix}", playBar:".jp-play-bar${suffix}",mute:".jp-mute${suffix}",unmute:".jp-unmute${suffix}",\n);
    print qq(                  volumeBar:".jp-volume-bar${suffix}",volumeBarValue:".jp-volume-bar-value${suffix}",\n);
    print qq(                  currentTime:".jp-current-time${suffix}",duration:".jp-duration${suffix}"}\n);
    print "});\n";
    
    print qq();        
    
    print "$eventSound\n";
    print "$eventEnded\n";
    
}

sub get_full_css_suffix {
	
	my ($suffix) = @_;
	
	if (defined($suffix) and (length($suffix) != 0)) {
		
		$suffix = "-" . $suffix;		
	} 
	else {
		
		$suffix = "";		
	}
	
	return $suffix;	
}

#Print the html for rendering jplayer.
#
#param divId  : the id of the player
#param suffix : the suffix for all css classes

sub print_jplayer_graphics {
	
	my ($divId, $suffix) = @_;
		
	$suffix = get_full_css_suffix($suffix);
	
	print qq{<div id="$divId" class="jp-jplayer${suffix}"></div>};
	print qq{		<div class="jp-audio${suffix}">};
	print qq{			<div class="jp-type-single">};
	print qq{				<div id="jp_interface_${divId}" class="jp-interface${suffix}">};
	print qq{					<ul class="jp-controls">};
	print qq{						<li><a href="#" class="jp-play${suffix}" tabindex="1">play</a></li>};
	print qq{						<li><a href="#" class="jp-pause${suffix}" tabindex="1">pause</a></li>};
	print qq{						<li><a href="#" class="jp-stop${suffix}" tabindex="1">stop</a></li>};
	print qq{						<li><a href="#" class="jp-mute${suffix}" tabindex="1">mute</a></li>};
	print qq{						<li><a href="#" class="jp-unmute${suffix}" tabindex="1">unmute</a></li>};
	print qq{					</ul>};
	print qq{					<div class="jp-progress${suffix}">};
	print qq{						<div class="jp-seek-bar${suffix}">};
	print qq{							<div class="jp-play-bar${suffix}"></div>};
	print qq{						</div>};
	print qq{					</div>};
	print qq{					<div class="jp-volume-bar${suffix}">};
	print qq{						<div class="jp-volume-bar-value${suffix}"></div>};
	print qq{					</div>};
	print qq{					<div class="jp-current-time${suffix}"></div>};
	print qq{					<div class="jp-duration${suffix}"></div>};
	print qq{				</div>};
	print qq{				<div class="jp-playlist${suffix}">};
	print qq{				</div>};
	print qq{			</div>};
	print qq{		</div>};
	print qq{<br/>};
	#print qq{</p>};
		
}

