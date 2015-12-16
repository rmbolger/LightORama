# LightORama
Scripts and code relating to Light-O-Rama based light shows

## Audacity2Lor.ps1 ([source](Audacity2Lor.ps1))

This is a Powershell port of John Storms' [audacity2lor.pl](https://sites.google.com/site/listentoourlights/home/how-to/timing-grids) script. All credit for the idea and original implementation should go to him. A friend of mine asked me to write this because he didn't want to hassle with Perl on Windows. For tons of info and help on Light-O-Rama hardware and sequencing, visit 
John's site:
http://listentoourlights.com

This script takes a file with a single label/timing track exported from Audacity and generates XML snippets for the timing grid in an LOR sequence. Optionally, it can also generate channel and track XML snippets to map MIDI notes to LOR channels based on the polyphonic transition from the Queen Mary
Vamp plugin.

The expected use case is that the user will use Audacity to export label tracks, use this script to convert them to LOR snippets, capture the script's output to a file, and copy/paste the XML snippets into the appropriate locations in the LOR generated LMS files.

I would recommend created a very basic LOR LMS file to paste into. Specifically, Start a new musical sequence, add 1 channel and no timings, save, then paste in the XML snippets.

### Software You'll Need

* Windows and Powershell v3 or later *(Installed by default on Windows 8 and later, downloadable for Windows 7 SP1 [here](http://www.microsoft.com/en-us/download/details.aspx?id=34595))*
* [Audacity](http://audacityteam.org/)
* [Queen Mary Vamp plugins for Audacity](http://nutcracker123.com/nutcracker/releases/Vamp_Plugin.exe)
* [Light-O-Rama ShowTime Sequencing Suite](http://www1.lightorama.com/sequencing-software-download/)

### Usage

```Powershell
.\Audacity2Lor.ps1 [-LabelFile] <String> [[-SaveID] <Int32>] [[-SplitByLabel]]
```

### Examples

```
# Process a non-polyphonic label file and output the XML to the console
.\Audacity2Lor.ps1 labels.txt

# Process a polyphonic label file and output the XML to the console
.\Audacity2Lor.ps1 poly-labels.txt 0 -SplitByLabel

# Process a polyphonic label file and output the XML to a file
.\Audacity2Lor.ps1 poly-labels.txt 0 -SplitByLabel | Out-File out.xml

```