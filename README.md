# Pulse Mute

## Summary

Pulse Mute is a small tool to mute anything (for example Zoom) via PulseAudio.

## Introduction

As Zoom currently only offers a mute toggle ( :sob: ) alternatives are needed to
manage the mute option. Thankfully we can always do this at the system level. I
use Linux so this solution utilises PulseAudio.

## Dependencies

This script only depends on `bash`, `sed` and `pactl`.

## Help

```
Pulse Mute v0.0.1
(C)2022 Krayon (Todd Harbour)
https://www.github.com/krayon/pulse-mute/


Pulse Mute is a small tool to mute anything (for example Zoom) via PulseAudio.

Usage: pulse-mute.bash [-v|--verbose] -h|--help
       pulse-mute.bash [-v|--verbose] -V|--version
       pulse-mute.bash [-v|--verbose] -C|--configuration

       pulse-mute.bash [-v|--verbose] [-t|--toggle] [<SOURCES> [...]]
       pulse-mute.bash [-v|--verbose] -m|--mute     [<SOURCES> [...]]
       pulse-mute.bash [-v|--verbose] -u|--unmute   [<SOURCES> [...]]

-h|--help           - Displays this help
-V|--version        - Displays the program version
-C|--configuration  - Outputs the default configuration that can be placed in a
                      config file in XDG_CONFIG or one of the XDG_CONFIG_DIRS
                      (in order of decreasing precedence):
                          /home/krayon//.config/pulse-mute/pulse-mute.conf
                          /home/krayon//.config/pulse-mute.conf
                          /etc/xdg/pulse-mute/pulse-mute.conf
                          /etc/xdg/pulse-mute.conf
                      for editing.
-v|--verbose        - Displays extra debugging information.  This is the same
                      as setting DEBUG=1 in your config.
-t|--toggle         - Toggle mute status of the source(s). If no state provided,
                      this is the DEFAULT.
-m|--mute           - Mute the source(s).
-u|--unmute         - Unmute the source(s).

<SOURCES> [...]     - List of one or more sources to mute (
                        SOURCES[] in config - currently empty
                      )

ERRORS

Possible errors that may be returned include:

    ERR_MISSINGDEP(90):
        A dependency is missing
    ERR_USAGE(64):
        Error in your command line parameters (or possibly config)
    ERR_SOFTWARE(70):
        pactl called returned an error (at least once)
    ERR_NOUSER(67):
        Unable to find (at least one of the) requested source(s)

NOTE: In the event of an error during processing of multiple sources, it is
possible that some commands work, but an error is still returned. This is only
valid for the error codes ERR_SOFTWARE and ERR_NOUSER.

Example: pulse-mute.bash 'N:ZOOM VoiceEngine'
```

----
[//]: # ( vim: set ts=4 sw=4 et cindent tw=80 ai si syn=markdown ft=markdown: )
