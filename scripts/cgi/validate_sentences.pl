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


use strict;

use CGI::Pretty;

use Webvalidation qw(get_next_wav_file get_text_name $data_directory_url $data_directory $media_url $sentence_folder_name $cgi_web_directory print_javascript_document_ready_header 
  		    print_javascript_document_ready_footer print_javascript_jplayer_sound_setup 
  			print_jplayer_graphics get_text_from_file_path $wav_extension $text_extension print_information print_title
  			write_text_to_file_path make_directory $accepted_folder_name $refused_folder_name copy_sentence print_help 
  			$initial_volume $website_url_domain move_directory move_sentence dircontent clean_accepted
			print_navigation print_messages
);
use Time::Piece;
use User;
use Stats;
  					
  				   					
my $cgi = new CGI;
# check if user is logged in
my $user = User::authenticate($cgi);
unless ($user) {
	print $cgi->redirect($website_url_domain . $cgi_web_directory . 'login.pl');
}

my $username = $user->{login};
my $project = $user->{project};

#Get or Post
my $dataPath = $cgi->param('dataPath');
# the level should be 'first' or 'second'
my $level = $cgi->param('level');
my $volumeLevel = $cgi->param('volumeLevel');
my $spent = $cgi->param('spent');

my $time = gmtime();

#Result of the user
my $submitValue = $cgi->param('choice');
my $newText = $cgi->param('newText');
my $currentBaseName = $cgi->param('currentBaseName');

#Parameter checking
unless (defined($dataPath)) {
	
	print_information($cgi, "Incorrect data path!");
				
	exit();	
}

# check if user is accessing his/her own user_space
my $expected_path = "${project}/user_space/${username}/${level}/";
if (index($dataPath, $expected_path) != 0) {
	print_information($cgi, "Your access is restricted to your own user_space");
	exit();
}

unless (defined($volumeLevel)) {
	
	$volumeLevel = $initial_volume;	
}

#Some data pathes
my $urlDataPath = $data_directory_url . "/" . $dataPath;
my $fullDataPath = $data_directory . "/" . $dataPath;


#---------Result processing --------------------
# Process the values before going to the next
# wave file
#-----------------------------------------------

my $currentTextFileName = undef;
my $result;
my $result_msg = '';

if (defined($submitValue)) {
	
	my $currentWavFileName = $fullDataPath . "/" . $currentBaseName . $wav_extension;
	$currentTextFileName = $fullDataPath . "/" . $currentBaseName . $text_extension;  

	my $destination = "${fullDataPath}/${submitValue}/";
	my $acceptance;
	
	if($submitValue eq $accepted_folder_name) {
		$acceptance = 1;
		#Copy the new Text
		write_text_to_file_path($currentTextFileName, $newText);
		# move to accepted
		$result = move_sentence($fullDataPath, $currentBaseName, $destination);
		$result_msg = $! if (!$result);
		print STDERR "error move sentence: $result_msg\n" if (length($result_msg));
	}
	elsif ($submitValue eq $refused_folder_name) {
		$acceptance = 0;
		# move to refused
		$result = move_sentence($fullDataPath, $currentBaseName, $destination);
		$result_msg = $! if (!$result);
		print STDERR "error move sentence: $result_msg\n" if (length($result_msg));
	}

	# create a new statistics entry on this validation
	Stats::create({
		user		=> $user,
		path		=> $destination,
		filename	=> $currentBaseName,
		level		=> $level,
		time		=> $time,
		spent		=> $spent,
		acceptance	=> $acceptance
	});

	# if this is the last sentence in the folder
	my $content = dircontent($fullDataPath, 0);
	if (scalar(keys(%$content)) == 0) {
		# the relative name of the data folder (the last piece in $dataPath)
		my @split_data_folder = split(/\//, $dataPath);
		my $relative_data_folder = pop(@split_data_folder);

		$destination = "${data_directory}/${project}/";
		# if level is 'first'
		if ($level eq 'first') {
			# move accepted content to data folder
			clean_accepted($fullDataPath);
			# move to annotation_space/second
			$destination .= "annotation_space/second/${relative_data_folder}/";
		}
		# otherwise ('second')
		else {
			# get today's date
			my $today = gmtime()->ymd('');
			# move to completed folder
			$destination .= "completed/${today}/${relative_data_folder}/";
		}

		# move data folder to annotation_space/second or to completed/[today]
		$result = move_directory($fullDataPath, $destination);
		$result_msg = $! if (!$result);
		print STDERR "error move dir: ${result_msg}\n" if (length($result_msg));

		# and redirect to user_space
		if ($result) {
			print $cgi->redirect(
				$website_url_domain . $cgi_web_directory . 'user_space.pl'
			);
		}
	}
}

#---------Process next wav file ----------------
# Process the values before going to the next
# wave file
#-----------------------------------------------

#Fetch the next wav file
my $wavFileName = get_next_wav_file($fullDataPath);

#No more wav files
if (length($wavFileName) == 0) {
		                         		   
	print_information($cgi, "Finished for the given folder: $urlDataPath!");
				
	exit();
}

#We have a wav file, get the associated text file
my @textNames = get_text_name($wavFileName);

#Get the text content
my @fileContent = get_text_from_file_path($fullDataPath . "/" . $textNames[0]);
my $strFileContent = "@fileContent";

#Utf8 support: headers and web page
#Html content
print $cgi->header(-type => 'text/html; charset=UTF-8');
print $cgi->start_html(
	-title => "Sentences validation",
	-encoding => "utf-8",
	-style => [{
		-src	=> $media_url . 'css/mystyle.css',
		-type	=> 'text/css',
		-media	=> 'all'
	}, {
		-src	=> $media_url . 'css/jplayer.blue.monday.css',
		-type	=> 'text/css',
		-media	=> 'all'
	}, {
		-src	=> $media_url . 'css/style.css',
		-type	=> 'text/css',
		-media	=> 'all'
	}],
	-script => [{
		-type	=> 'text/javascript',
		-src	=> $media_url . 'js/jquery.min.js'
	}, {
		-type	=> 'text/javascript',
		-src	=> $media_url . 'js/jquery.jplayer.min.js'
	}, {
		-type	=> 'text/javascript',
		-src	=> $media_url . 'js/app.js'
	}]
);

print_navigation($cgi, 'validate_sentences.pl', $user);

if (length($result_msg)) {
	print_messages($cgi, "Error: $result_msg");
}

#Setup player
print_javascript_document_ready_header();   	   	
print_javascript_jplayer_sound_setup("jpId", "$urlDataPath/$wavFileName", $volumeLevel);    	
print_javascript_document_ready_footer();

print qq{<div id="wrap">\n};
print qq{<div id="left">\n};

#The css formatted title
print_title($textNames[1]);

   	
#print_html($cgi, template_login_header_name);

print_jplayer_graphics("jpId");

#print_html($cgi, template_login_footer_name);

   	  	
print qq{</br></br></br></br></br>};

print qq{<div id="sentence">};
   	
print $cgi->start_form(-action=> $cgi_web_directory . '/validate_sentences.pl', -method=>'POST', -onSubmit=>'return checkform()'),
				qq{<textarea id="annotatedText" name="newText" onClick="ClickedHappened()" accesskey='i' cols="180" rows="20">},
				qq{$strFileContent}, 
				qq{</textarea>},
				qq{<p align="center">},
				"<input name='choice' id='accepted' class='button' type='submit' accesskey='a' value='" . $accepted_folder_name . "' />",
				'<span style="display:inline-block;width:30px"></span>',
				"<input name='choice' id='refused' class='button red' type='submit' accesskey='r' value='" . $refused_folder_name . "' />", 
				qq{</p>},				 
	  			qq{<input name= "dataPath" type="hidden" value="$dataPath" />},
	  			qq{<input name="level" type="hidden" value="$level" />},
	  			qq{<input name="spent" id="spent" type="hidden" />},
	  			qq{<input name= "currentBaseName" type="hidden" value="$textNames[1]" />},
	  			qq{<input id = "idVolume" name = "volumeLevel" type="hidden" value="$volumeLevel" />},
	  			qq{<input id = "idEnded" type="hidden" value="false" />},
	  			qq{<input id = "idAutoPlay"  type="hidden" value="true" />},
				$cgi->end_form();
				
print qq{</div>\n};
print qq{</div>\n}; #End left

print qq{<div id="right" style="display:inline">\n};
print_help();
print qq{</div>\n}; #End right

print qq{</div>\n}; #End wrap
	
print $cgi->end_html;
   	
   	
   	
   	
   
