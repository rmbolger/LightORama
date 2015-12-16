<#
.SYNOPSIS
Create Light-O-Rama S3 compatible timing grids from Audacity exported label files.

.DESCRIPTION
This is a Powershell port of John Storms' audacity2lor.pl script. All credit for the idea and original implementation should go to him. A friend of mine asked me to write this because he didn't want to hassle with Perl on Windows. For tons of info and help on Light-O-Rama hardware and sequencing, visit John's site:
http://listentoourlights.com

The script takes a file with a single label/timing track exported from Audacity and generates XML snippets for the timing grid in an LOR sequence. Optionally, it can also generate channel and track XML snippets to map MIDI notes to LOR channels based on the polyphonic transition from the Queen Mary Vamp plugin.

The expected use case is that the user will use Audacity to export label tracks, use this script to convert them to LOR snippets, capture the script's output to a file, and copy/paste the XML snippets into the appropriate locations in the LOR generated LMS files.

.PARAMETER LabelFile
File path for the exported label/timing file.

.PARAMETER SaveID
Number used to uniquely identify the timing grid. Defaults to 0.

.PARAMETER SplitByLabel
If True, attempt to map label information to Midi notes and give each a LOR channel. For use with Polyphonic translation from Audacity.

.EXAMPLE
.\Audacity2Lor.ps1 labels.txt
Process a non-polyphonic label file and output the XML to the console

.EXAMPLE
.\Audacity2Lor.ps1 poly-labels.txt 0 -SplitByLabel
Process a polyphonic label file and output the XML to the console

.EXAMPLE
.\Audacity2Lor.ps1 poly-labels.txt 0 -SplitByLabel | Out-File out.xml
Process a polyphonic label file and output the XML to a file

.LINK
https://github.com/rmbolger/LightORama
.LINK
http://www1.lightorama.com/sequencing-software-download/
.LINK
http://audacityteam.org/
.LINK
http://nutcracker123.com/nutcracker/releases/Vamp_Plugin.exe
#>

#Requires -version 3.0

Param (
    [Parameter(Mandatory=$True,Position=1)]
    [string]$LabelFile,
    [Parameter(Position=2)]
    [int]$SaveID = 0,
    [Parameter(Position=3)]
    [switch]$SplitByLabel = $false
)

# The source file should be a single tab delimited file with 3 columns.
# Columns 1 and 2 are fractional second values for the start and end time of the label
# Column 3 is the label name which for Polyphonic exports should be an integer that maps to a corresponding MIDI note
# When we import the file, we'll convert the timing columns to the integer centiseconds that LOR uses
$labels = Import-Csv -Delimiter "`t" $LabelFile -Header "Start","End","Label" |
    %{ New-Object PSObject -Property @{
        Start = [int][Math]::Round([double]::Parse($_.Start) * 100);
        End = [int][Math]::Round([double]::Parse($_.End) * 100);
        Label = $_.Label; }
    }

# add all unique values to an array (including a 0 value) and sort it
$timings = @([int]0)
foreach ($row in $labels)
{
    if ($timings -notcontains $row.Start) {
        $timings += $row.Start
    }
    if ($timings -notcontains $row.End) {
        $timings += $row.End
    }
}
[array]::sort($timings)

# start building the XML
$sw = New-Object System.IO.StringWriter
$xml = New-Object System.Xml.XmlTextWriter $sw
$xml.Formatting = "indented"
$xml.Indentation = 1
$xml.IndentChar = "`t"

# start the timing grid section
$xml.WriteComment("TIMING ELEMENT")
$xml.WriteStartElement("timingGrid")
$xml.WriteAttributeString("saveID", $SaveID)
$xml.WriteAttributeString("name", [io.path]::GetFileNameWithoutExtension($LabelFile))
$xml.WriteAttributeString("type", "freeform")

# write the timing elements
$timings | %{
    $xml.WriteStartElement("timing")
    $xml.WriteAttributeString("centisecond", $_)
    $xml.WriteEndElement()
}

# end the timing grid section
$xml.WriteEndElement()

# Add the sections for polyphonic mapping if necessary
if ($SplitByLabel)
{
    # create a hashtable of midi numbers to note names
    # http://www.electronics.dit.ie/staff/tscarff/Music_technology/midi/midi_note_numbers_for_octaves.htm
    $midi = @{
		  0 = "C0";   1 = "C#0";   2 = "D0";   3 = "D#0";   4 = "E0";   5 = "F0";   6 = "F#0";   7 = "G0";   8 = "G#0";   9 = "A0";  10 = "A#0";  11 = "B0";
		 12 = "C1";  13 = "C#1";  14 = "D1";  15 = "D#1";  16 = "E1";  17 = "F1";  18 = "F#1";  19 = "G1";  20 = "G#1";  21 = "A1";  22 = "A#1";  23 = "B1";
		 24 = "C2";  25 = "C#2";  26 = "D2";  27 = "D#2";  28 = "E2";  29 = "F2";  30 = "F#2";  31 = "G2";  32 = "G#2";  33 = "A2";  34 = "A#2";  35 = "B2";
		 36 = "C3";  37 = "C#3";  38 = "D3";  39 = "D#3";  40 = "E3";  41 = "F3";  42 = "F#3";  43 = "G3";  44 = "G#3";  45 = "A3";  46 = "A#3";  47 = "B3";
		 48 = "C4";  49 = "C#4";  50 = "D4";  51 = "D#4";  52 = "E4";  53 = "F4";  54 = "F#4";  55 = "G4";  56 = "G#4";  57 = "A4";  58 = "A#4";  59 = "B4";
		 60 = "C5";  61 = "C#5";  62 = "D5";  63 = "D#5";  64 = "E5";  65 = "F5";  66 = "F#5";  67 = "G5";  68 = "G#5";  69 = "A5";  70 = "A#5";  71 = "B5";
		 72 = "C6";  73 = "C#6";  74 = "D6";  75 = "D#6";  76 = "E6";  77 = "F6";  78 = "F#6";  79 = "G6";  80 = "G#6";  81 = "A6";  82 = "A#6";  83 = "B6";
		 84 = "C7";  85 = "C#7";  86 = "D7";  87 = "D#7";  88 = "E7";  89 = "F7";  90 = "F#7";  91 = "G7";  92 = "G#7";  93 = "A7";  94 = "A#7";  95 = "B7";
		 96 = "C8";  97 = "C#8";  98 = "D8";  99 = "D#8"; 100 = "E8"; 101 = "F8"; 102 = "F#8"; 103 = "G8"; 104 = "G#8"; 105 = "A8"; 106 = "A#8"; 107 = "B8";
		108 = "C9"; 109 = "C#9"; 110 = "D9"; 111 = "D#9"; 112 = "E9"; 113 = "F9"; 114 = "F#9"; 115 = "G9"; 116 = "G#9"; 117 = "A9"; 118 = "A#9"; 119 = "B9";
		120 = "C10";121 = "C#10";122 = "D10";123 = "D#10";124 = "E10";125 = "F10";126 = "F#10";127 = "G10";
    }

    # sort the original labels into groups of MIDI notes
    $noteLabels = $labels | select Start,End,
        @{L="NoteName";E={

            $num = [int][Math]::Round([double]::Parse($_.Label));

            # use the note name if it has a match in the table
            if ($midi.ContainsKey($num)) { $midi[$num] }
            else { $num }

        } } | group NoteName | sort Name

    # start the channels section
    $xml.WriteComment("CHANNEL ELEMENT")
    $xml.WriteStartElement("channels")

    # add a channel for each note
    $chanIndex = 0
    $noteLabels | %{
        $xml.WriteStartElement("channel")
        $xml.WriteAttributeString("name", $_.Name)
        $xml.WriteAttributeString("color", 202)
        $xml.WriteAttributeString("centiseconds", $timings[-1])
        $xml.WriteAttributeString("savedIndex", $chanIndex)

        # add an effect for each label using that note
        $_.Group | sort Start | %{
            $xml.WriteStartElement("effect")
            $xml.WriteAttributeString("type", "intensity")
            $xml.WriteAttributeString("startCentisecond", $_.Start)
            $xml.WriteAttributeString("endCentisecond", $_.End)
            $xml.WriteAttributeString("startIntensity", 100)
            $xml.WriteAttributeString("endIntensity", 0)
            $xml.WriteEndElement()
        }

        # end the channel
        $xml.WriteEndElement()
        $chanIndex++
    }

    # end the channels section
    $xml.WriteEndElement()

    # start the tracks/track/channels section
    $xml.WriteComment("TRACKS ELEMENT")
    $xml.WriteStartElement("tracks")
    $xml.WriteStartElement("track")
    $xml.WriteAttributeString("totalCentiseconds", $timings[-1])
    $xml.WriteAttributeString("timingGrid", $SaveID)
    $xml.WriteStartElement("channels")

    # add a channel for each one we wrote in the channels section
    0..($chanIndex-1) | %{
        $xml.WriteStartElement("channel")
        $xml.WriteAttributeString("savedIndex", $_)
        $xml.WriteEndElement()
    }

    # end the channels section
    $xml.WriteEndElement()

    # add an empty loopLevels element (because that was in the original script)
    $xml.WriteStartElement("loopLevels")
    $xml.WriteEndElement()

    # end the tracks/track section
    $xml.WriteEndElement()
    $xml.WriteEndElement()
}

# close out the XML and write it to output
$xml.Flush()
$xml.Close()
$sw.Flush()
write-output $sw.ToString()
$sw.Close()
