# audacity2lor.pl <filename> [<savedIndex> <splitbylabel>]
# Written by John Storms 
# listentoourlights@gmail.com
# http://listentoourlights.com
# 
# This is known crappy code. Very limited testing done.
#
# This script takes a file with a single (*1*) label/timing track and genertes
# XML snippets for the timing grid. Optionally, it can also generate channel
# and track XML snippets to map midi notes to LOR channels based on the
# polyphonic translation from the Queen Mary Vamp plugin. 
# The expect use case is that the user will use Audacity to export label tracks,
# then use this script to convert them to LOR snippets, capture this script's output 
# to a file, then using a file editor (like Notepad.exe) copy and paste the XML 
# snippets into the appropriate locations in their LOR generated .LMS files.
# I would recommend creating a very basic LOR .LMS file to past into. Specifically, 
# I would Start a new musical sequence, add 1 channel, and do no timings, then save. 
# Then paste in the XML snippets.
#
# <filename> - contains the file with the one (*1*) audacity track with timing/label info
# <savedIndex> - The number used to uniquely identify the timing grid.
#                Defaults to 0.
# <splitbylabel> - For use with Polyphonic translation from Audacity. Here the script
#                Will map the label information to midi notes and give each a LOR
#                channel.
#
# Software You'll Need: (Assuming MS-Windows ENV)
# * LOR S3
#   http://www1.lightorama.com/sequencing-software-download/
# * Audacity
#   http://audacity.sourceforge.net/
# * Queen Mary Vamp plugins for Audacity
#   http://nutcracker123.com/nutcracker/releases/Vamp_Plugin.exe
# * PERL (many others too)
#   http://www.activestate.com/activeperl
#
# Potential improvements:
# * Use an XML library. Apologies in advance, there are better ways to manipulate XML
# * Modify to do multiple timing grids from one input file.
# * Modify to modularize label mapping so other mappings other than midi can be done
# * Instead of just doing snippets take a LMS file as input and then modify it.
# * Use pointers to the arrays.
# * Better command line argument handling
# * Check for non-existent file
# * Use something other than PERL
# * Replace color constant with some color options
# * Figure out better way to get total number of centiseconds in a song

my($filename) = $ARGV[0];     # Audacity label/timing file
my($savedindex) = $ARGV[1];   # savedIndex number to use for TimingGrid (they start at 0)
my($splitbylabel) = $ARGV[2]; # 1 means split each midi channel to its own LOR channel

# Some crude error checking
if($filename eq "") {die;} # Should check that file exists
if($savedindex eq "") {$savedindex = "0";}
if($splitbylabel eq "") { $splitbylabel = "0"; }

# Convert timings/labels into LOR XML snippets
my(@output) = create_LOR_XML_snips($filename,$savedindex,$splitbylabel);

# print output that can be copy/pasted into LOR .lms files
foreach my $i (@output) { print "\t\t".$i; }

# INPUTS
# filename = tab deliminated text file containing "1" audacity label/timing information
#            <starting seconds>\t<ending seconds>\t<label>
# savedindex = Used to number the timing grid
# splitbylabel = if 1, this will create channels for each label. Labels are assumed
#                to be integers representing MIDI notes.
# OUTPUTS
# Array of XML snippets
sub create_LOR_XML_snips {
	my($filename) = shift(@_);
	my($savedindex) = shift(@_);
	my($splitbylabel) = shift(@_);

	my($name); # Timing Grid name
	($name) = split(/\./,$filename);

	if( $savedindex eq "") { $savedindex = "0"; }

	my($totcenti) = 0; # best shot at getting the total time

	##### Prep for Timing Grids
	my(@timing); # Holds XML timing grid
	my(%timing); # Used to avoid duplicating times
	# Start Timing Grid
	push(@timing,"\<timingGrid saveID=\"".$savedindex."\" name=\"".$name."\" type=\"freeform\"\>\n");
	push(@timing,"\t\<timing centisecond=\"0\"\/\>\n");

	# Open Audacity label file and go through line by line
	open(READ,$filename);
	my($line);
	$line = <READ>;
	while($line ne "") {
		chop($line);
		my($start,$stop,$label); ($start,$stop,$label) = split(/\t/,$line);

		# convert seconds to centiseconds the way LOR likes it
		$start = second_to_whole_centisecond($start);
		$stop = second_to_whole_centisecond($stop);
		$label = int($label);

		#### Update Timing Grid
		if( $timing{$start} eq "") { # Making sure timing doesn't already exist
			$timing{$start} = 1; # Note that it exists now
			# Add timing data to XML timing grid
			push(@timing,"\t\<timing centisecond=\"".$start."\"\/\>\n");
		} #ENDIF
		if( $timing{$stop} eq "") { # Making sure timing doesn't already exist
			$timing{$stop} = 1; # Note that it exists now
			# Add timing data to XML timing grid
			push(@timing,"\t\<timing centisecond=\"".$stop."\"\/\>\n");
		} #ENDIF

		if($splitbylabel) {
			# CHANNEL DATA: Save for a 2nd pass (optimization opportunity here)
			push(@chdata,"$label,$start,$stop");
			# Watch for highest value stop time
			if( $stop > $totcenti) { $totcenti = $stop; }
		} #endif

		$line = <READ>;
	} #endwhile
	close(READ);

	# Finish off timing grid XML
	push(@timing,"\<\/timingGrid\>\n");

	my(@channelsNtracks); # Holds channel and track XML elements
	if($splitbylabel) {
		(@channelsNtracks) = do_channels_and_tracks($totcenti,$savedindex,@chdata);
	} #endif

	return("\#TIMING ELEMENT\n",@timing,@channelsNtracks);
} # create_LOR_XML_snips


# @channelsNtracks = do_channels_and_tracks($totcenti,$savedindex,@chdata);
sub do_channels_and_tracks {
	my($totcenti) = shift(@_);
	my($savedindex) = shift(@_);
	my(@chdata) = @_;

	my($color) = 202; # Color to use for channels. OMG he used a constant

	# Sort channel data by channel number then start time.
	my(@channeldata) = sort(@chdata); 
	@chdata = (); # Free up some memory

	my(@ch); # Holds the Channel element
	my(@tracks); # Holds the Track element

	my($lastch) = 0; # Used to detect new channel
	my($count) = 0; # Used to increment savedIndex

	# Prep tracks and channels elements
	push(@tracks,"\<tracks\>\n\t\t\t\<track totalCentiseconds=\"".$totcenti."\" timingGrid=\"".$savedindex."\"\>\n\t\t\t\t\<channels\>\n");
	push(@ch,"\<channels\>\n");

	foreach my $i (@channeldata) {  ## midi,start time, stop time ##
		my($midi,$start,$stop); ($midi,$start,$stop) = split(/,/,$i);
		if( $midi ne $lastch ) { #### NEW CHANNEL DETECTED
			$lastch = $midi;
			my($chname) = getmidi($midi); # Map midi number to note name
			if( $count) { # Do this on every channel except on the first hit
				push(@ch,"\t\<\/channel>\n");
			} #endif

			# Add to channel XML
			push(@ch,"\t\<channel name=\"$chname\" color=\"".$color."\" centiseconds=\"$totcenti\" savedIndex=\"$count\"\>\n");

			# Add channel to track XML (how LOR knows what channels are in the track)
			push(@tracks,"\t\t\t\<channel savedIndex=\"".$count."\"\/\>\n");
			$count++; # Increment for savedIndex
		} #endif
		push(@ch,"\t\t\<effect type=\"intensity\" startCentisecond=\"".$start."\" endCentisecond=\"".$stop."\" startIntensity=\"100\" endIntensity=\"0\"/>\n");
	} #foreach

	# End Channel and Tracks elements
	push(@ch,"\t\<\/channel>\n");
	push(@ch,"\<\/channels>\n");

	push(@tracks,"\t\t\<\/channels\>\n\t\t\t\<loopLevels\/\>\n\t\t\t\<\/track\>\n\t\t\<\/tracks\>\n");

	return("\#CHANNEL ELEMENT\n",@ch,"\#TRACKS ELEMENT\n",@tracks);
} # do_channels_and_tracks

# maps an integer to a midi note name
# pulled a table off the Internet and massaged it into a hash table.
sub getmidi {
	my($note) = shift(@_);
	my(%midi);
	$midi{'0'}="C";
	$midi{'1'}="C#-Db";
	$midi{'2'}="D";
	$midi{'3'}="D#-Eb";
	$midi{'4'}="E";
	$midi{'5'}="F";
	$midi{'6'}="F#-Gb";
	$midi{'7'}="G";
	$midi{'8'}="G#-Ab";
	$midi{'9'}="A";
	$midi{'10'}="A#-Bb";
	$midi{'11'}="B";
	$midi{'12'}="C";
	$midi{'13'}="C#-Db";
	$midi{'14'}="D";
	$midi{'15'}="D#-Eb";
	$midi{'16'}="E";
	$midi{'17'}="F";
	$midi{'18'}="F#-Gb";
	$midi{'19'}="G";
	$midi{'20'}="G#-Ab";
	$midi{'21'}="A";
	$midi{'22'}="A#-Bb";
	$midi{'23'}="B";
	$midi{'24'}="C";
	$midi{'25'}="C#-Db";
	$midi{'26'}="D";
	$midi{'27'}="D#-Eb";
	$midi{'28'}="E";
	$midi{'29'}="F";
	$midi{'30'}="F#-Gb";
	$midi{'31'}="Low_G";
	$midi{'32'}="Low_G#-Ab";
	$midi{'33'}="Low_A";
	$midi{'34'}="Low_A#-Bb";
	$midi{'35'}="Low_B";
	$midi{'36'}="Low_C";
	$midi{'37'}="Low_C#-Db";
	$midi{'38'}="Low_D";
	$midi{'39'}="Low_D#-Eb";
	$midi{'40'}="Low_E";
	$midi{'41'}="Low_F";
	$midi{'42'}="Low_F#-Gb";
	$midi{'43'}="Bass_G";
	$midi{'44'}="Bass_G#-Ab";
	$midi{'45'}="Bass_A";
	$midi{'46'}="Bass_A#-Bb";
	$midi{'47'}="Bass_B";
	$midi{'48'}="Bass_C";
	$midi{'49'}="Bass_C#-Db";
	$midi{'50'}="Bass_D";
	$midi{'51'}="Bass_D#-Eb";
	$midi{'52'}="Bass_E";
	$midi{'53'}="Bass_F";
	$midi{'54'}="Bass_F#-Gb";
	$midi{'55'}="Middle_G";
	$midi{'56'}="Middle_G#-Ab";
	$midi{'57'}="Middle_A";
	$midi{'58'}="Middle_A#-Bb";
	$midi{'59'}="Middle_B";
	$midi{'60'}="Middle_C";
	$midi{'61'}="Middle_C#-Db";
	$midi{'62'}="Middle_D";
	$midi{'63'}="Middle_D#-Eb";
	$midi{'64'}="Middle_E";
	$midi{'65'}="Middle_F";
	$midi{'66'}="Treble_F#-Gb";
	$midi{'67'}="Treble_G";
	$midi{'68'}="Treble_G#-Ab";
	$midi{'69'}="Treble_A";
	$midi{'70'}="Treble_A#-Bb";
	$midi{'71'}="Treble_B";
	$midi{'72'}="Treble_C";
	$midi{'73'}="Treble_C#-Db";
	$midi{'74'}="Treble_D";
	$midi{'75'}="Treble_D#-Eb";
	$midi{'76'}="Treble_E";
	$midi{'77'}="Treble_F";
	$midi{'78'}="High_F#-Gb";
	$midi{'79'}="High_G";
	$midi{'80'}="High_G#-Ab";
	$midi{'81'}="High_A";
	$midi{'82'}="High_A#-Bb";
	$midi{'83'}="High_B";
	$midi{'84'}="High_C";
	$midi{'85'}="High_C#-Db";
	$midi{'86'}="High_D";
	$midi{'87'}="High_D#-Eb";
	$midi{'88'}="High_E";
	$midi{'89'}="High_F";
	$midi{'90'}="F#-Gb";
	$midi{'91'}="G";
	$midi{'92'}="G#-Ab";
	$midi{'93'}="A";
	$midi{'94'}="A#-Bb";
	$midi{'95'}="B";
	$midi{'96'}="C";
	$midi{'97'}="C#-Db";
	$midi{'98'}="D";
	$midi{'99'}="D#-Eb";
	$midi{'100'}="E";
	$midi{'101'}="F";
	$midi{'102'}="F#-Gb";
	$midi{'103'}="G";
	$midi{'104'}="G#-Ab";
	$midi{'105'}="A";
	$midi{'106'}="A#-Bb";
	$midi{'107'}="B";
	$midi{'108'}="C";
	$midi{'109'}="C#-Db";
	$midi{'110'}="D";
	$midi{'111'}="D#-Eb";
	$midi{'112'}="E";
	$midi{'113'}="F";
	$midi{'114'}="F#-Gb";
	$midi{'115'}="G";
	$midi{'116'}="G#-Ab";
	$midi{'117'}="A";
	$midi{'118'}="A#-Bb";
	$midi{'119'}="B";
	$midi{'120'}="C";
	$midi{'121'}="C#-Db";
	$midi{'122'}="D";
	$midi{'123'}="D#-Eb";
	$midi{'124'}="E";
	$midi{'125'}="F";
	$midi{'126'}="F#-Gb";
	$midi{'127'}="G";
	return($midi{$note});
} #getmidi

# Converts seconds to centisecond
sub second_to_whole_centisecond { return(round($_[0]*100,0)); }

# Just rounds a number to the nearest $places
# Grabbed this sub of Internet vs. including a perl lib or writing yet another round function
sub round { 
    my ($number, $places) = @_;
    my $sign = ($number < 0) ? '-' : '';
    my $abs = abs($number);

    if($places < 0) {
        $places *= -1;
        return $sign . substr($abs+("0." . "0" x $places . "5"), 0, $places+length(int($abs))+1);
    } else {
        my $p10 = 10**$places;
        return $sign . int($abs/$p10 + 0.5)*$p10;
    } #endif
} # round
