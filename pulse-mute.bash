#!/bin/bash
# vim:set ts=4 sw=4 tw=80 et ai si cindent cino=L0,b1,(1s,U1,m1,j1,J1,)50,*90,#0 cinkeys=0{,0},0),0],\:,0#,!^F,o,O,e,0=break:
#
#/**********************************************************************
#    Pulse Mute
#    Copyright (C)2022 Krayon (Todd Harbour)
#
#    This program is free software; you can redistribute it and/or
#    modify it under the terms of the GNU General Public License
#    version 2 ONLY, as published by the Free Software Foundation.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program, in the file COPYING or COPYING.txt; if
#    not, see http://www.gnu.org/licenses/ , or write to:
#      The Free Software Foundation, Inc.,
#      51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# **********************************************************************/

# pulse-mute
# ----------
# pulse-mute is a small tool to mute anything (for example Zoom) via PulseAudio.
#
# Required:
#     pactl
#     sed
# Recommended:
#     -

# Config paths
_APP_NAME="pulse-mute"
_CONF_FILENAME="${_APP_NAME}.conf"
_ETC_CONF="/etc/${_CONF_FILENAME}"



############### STOP ###############
#
# Do NOT edit the CONFIGURATION below. Instead generate the default
# configuration file in your XDG_CONFIG directory thusly:
#
#     ./pulse-mute.bash -C >"$XDG_CONFIG_HOME/pulse-mute.conf"
#
# or perhaps:
#     ./pulse-mute.bash -C >~/.config/pulse-mute.conf
#
# Consult --help for more complete information.
#
####################################

# [ CONFIG_START

# Pulse Mute - Default Configuration
# ==================================

# DEBUG
#   This defines debug mode which will output verbose info to stderr or, if
#   configured, the debug file ( ERROR_LOG ).
DEBUG=0

# ERROR_LOG
#   The file to output errors and debug statements (when DEBUG != 0) instead of
#   stderr.
#ERROR_LOG="${HOME}/pulse-mute.log"

# PATH_SED
#   The path to the sed binary. If set to "*", $PATH is used (ie.
#   "sed" called without a path).
PATH_SED="*"

# PATH_PACTL
#   The path to the pactl binary. If set to "*", $PATH is used (ie.
#   "pactl" called without a path).
PATH_PACTL="*"

# SOURCES
#   An array of sources you want to mute, in the format:
#       SOURCES=(
#            '<id>'
#            'N:<name>'
#       )
#   Sources can be IDs (<id>) or names (<name>) however when names are used,
#   they must be prefixed with "N:". When names are used and they are not
#   unique, ALL matching names will be muted.
#
#   These can also be provided on the command line.
SOURCES=()

# ] CONFIG_END



####################################{
###
# Config loading
###

# A list of configs - user provided prioritised over system
# (built backwards to save fiddling with CONFIG_DIRS order)
_CONFS=""

# XDG Base (v0.8) - User level
# ( https://specifications.freedesktop.org/basedir-spec/0.8/ )
# ( xdg_base_spec.0.8.txt )
_XDG_CONF_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"
# As per spec, non-absolute paths are invalid and must be ignored
[ "${_XDG_CONF_DIR:0:1}" == "/" ] && {
        for conf in\
            "${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}"\
            "${_XDG_CONF_DIR}/${_CONF_FILENAME}"\
        ; do #{
            [ -r "${conf}" ] && _CONFS="${conf}:${_CONFS}"
        done #}
}

# XDG Base (v0.8) - System level
# ( https://specifications.freedesktop.org/basedir-spec/0.8/ )
# ( xdg_base_spec.0.8.txt )
_XDG_CONF_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
# NOTE: Appending colon as read's '-d' sets the TERMINATOR (not delimiter)
[ "${_XDG_CONF_DIRS: -1:1}" != ":" ] && _XDG_CONF_DIRS="${_XDG_CONF_DIRS}:"
while read -r -d: _XDG_CONF_DIR; do #{
    # As per spec, non-absolute paths are invalid and must be ignored
    [ "${_XDG_CONF_DIR:0:1}" == "/" ] && {
        for conf in\
            "${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}"\
            "${_XDG_CONF_DIR}/${_CONF_FILENAME}"\
        ; do #{
            [ -r "${conf}" ] && _CONFS="${conf}:${_CONFS}"
        done #}
    }
done <<<"${_XDG_CONF_DIRS}" #}

# _CONFS now contains a list of config files, in reverse importance order. We
# can therefore source each in turn, allowing the more important to override the
# earlier ones.

# NOTE: Appending colon as read's '-d' sets the TERMINATOR (not delimiter)
[ "${_CONF: -1:1}" != ":" ] && _CONF="${_CONF}:"
while read -r -d: conf; do #{
    . "${conf}"
done <<<"${_CONFS}" #}
####################################}



# Version
APP_NAME="Pulse Mute"
APP_VER="0.0.1"
APP_COPY="(C)2022 Krayon (Todd Harbour)"
APP_URL="https://www.github.com/krayon/pulse-mute/"

# Program name
_binname="${_APP_NAME}"
_binname="${0##*/}"
_binnam_="${_binname//?/ }"

# exit condition constants
ERR_NONE=0
ERR_UNKNOWN=1
# START /usr/include/sysexits.h {
ERR_USAGE=64       # command line usage error
ERR_DATAERR=65     # data format error
ERR_NOINPUT=66     # cannot open input
ERR_NOUSER=67      # addressee unknown
ERR_NOHOST=68      # host name unknown
ERR_UNAVAILABLE=69 # service unavailable
ERR_SOFTWARE=70    # internal software error
ERR_OSERR=71       # system error (e.g., can't fork)
ERR_OSFILE=72      # critical OS file missing
ERR_CANTCREAT=73   # can't create (user) output file
ERR_IOERR=74       # input/output error
ERR_TEMPFAIL=75    # temp failure; user is invited to retry
ERR_PROTOCOL=76    # remote error in protocol
ERR_NOPERM=77      # permission denied
ERR_CONFIG=78      # configuration error
# END   /usr/include/sysexits.h }
ERR_MISSINGDEP=90

# Defaults not in config

tmpdir=""
pwd="$(pwd)"

# Ensure 'action' isn't set
unset action
declare -a s_actions=('Unmute' 'Mute' 'Toggle')



# Params:
#   $1 =  (s) command to look for
#   $2 =  (s) complete path to binary
#   $3 =  (i) print error (1 = yes, 0 = no)
#   $4 = [(s) suspected package name]
# Outputs:
#   Path to command, if found
# Returns:
#   $ERR_NONE
#   -or-
#   $ERR_MISSINGDEP
check_for_cmd() {
    # Check for ${1} command
    local ret=${ERR_NONE}
    local path=""
    local cmd="${1}"; shift 1
    local bin="${1}"; shift 1
    local msg="${1}"; shift 1
    local pkg="${1}"; shift 1
    [ -z "${pkg}" ] && pkg="${cmd}"

    path="$(type -P "${bin}" 2>&1)" || {
        # Not found
        ret=${ERR_MISSINGDEP}

        [ "${msg}" -eq 1 ] &>/dev/null && {

cat <<EOF >&2
ERROR: Cannot find ${cmd}${bin:+ (as }${bin}${bin:+)}.  This is required.
Ensure you have ${pkg} installed or search for ${cmd}
in your distribution's packages.
EOF

            return ${ret}
        }
    }

    [ ! -z "${path}" ] && echo "${path}"

    return ${ret}
} # check_for_cmd()

# Params:
#   NONE
show_version() {
    echo -e "\
${APP_NAME} v${APP_VER}\n\
${APP_COPY}\n\
${APP_URL}${APP_URL:+\n}\
"
} # show_version()

# Params:
#   NONE
show_usage() {
    show_version

cat <<EOF

${APP_NAME} is a small tool to mute anything (for example Zoom) via PulseAudio.

Usage: ${_binname} [-v|--verbose] -h|--help
       ${_binname} [-v|--verbose] -V|--version
       ${_binname} [-v|--verbose] -C|--configuration

       ${_binname} [-v|--verbose] [-t|--toggle] [<SOURCES> [...]]
       ${_binname} [-v|--verbose] -m|--mute     [<SOURCES> [...]]
       ${_binname} [-v|--verbose] -u|--unmute   [<SOURCES> [...]]

-h|--help           - Displays this help
-V|--version        - Displays the program version
-C|--configuration  - Outputs the default configuration that can be placed in a
                      config file in XDG_CONFIG or one of the XDG_CONFIG_DIRS
                      (in order of decreasing precedence):
                          ${XDG_CONFIG_HOME:-${HOME}/.config}/${_APP_NAME}/${_CONF_FILENAME}
                          ${XDG_CONFIG_HOME:-${HOME}/.config}/${_CONF_FILENAME}
EOF
    while read -r -d: _XDG_CONF_DIR; do #{
        # As per spec, non-absolute paths are invalid and must be ignored
        [ "${_XDG_CONF_DIR:0:1}" != "/" ] && continue
cat <<EOF
                          ${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}
                          ${_XDG_CONF_DIR}/${_CONF_FILENAME}
EOF
    done <<<"${_XDG_CONF_DIRS:-/etc/xdg}:" #}
cat <<EOF
                      for editing.
-v|--verbose        - Displays extra debugging information.  This is the same
                      as setting DEBUG=1 in your config.
-t|--toggle         - Toggle mute status of the source(s). If no state provided,
                      this is the DEFAULT.
-m|--mute           - Mute the source(s).
-u|--unmute         - Unmute the source(s).

<SOURCES> [...]     - List of one or more sources to mute (
EOF
        [ -z "${SOURCES[*]}" ] && {
cat <<EOF
                        SOURCES[] in config - currently empty
EOF
        } || {
cat <<EOF
                        SOURCES[] in config, currently:
EOF
            for s in "${SOURCES[@]}"; do #{
cat <<EOF
                          ${s}
EOF
            done #}
        }
cat <<EOF
                      )

ERRORS

Possible errors that may be returned include:

    ERR_MISSINGDEP(${ERR_MISSINGDEP}):
        A dependency is missing
    ERR_USAGE(${ERR_USAGE}):
        Error in your command line parameters (or possibly config)
    ERR_SOFTWARE(${ERR_SOFTWARE}):
        pactl called returned an error
    ERR_NOUSER(${ERR_NOUSER}):
        Unable to find requested source

Example: ${_binname}
EOF

} # show_usage()

# Clean up
cleanup() {
    decho "Clean Up"

    [ ! -z "${tmpdir}" ] && rm -Rf "${tmpdir}" &>/dev/null
    [ ! -z "${pwd}"    ] && cd "${pwd}"        &>/dev/null
} # cleanup()

trapint() {
    >&2 echo "WARNING: Signal received: ${1}"

    cleanup

    exit ${1}
} # trapint()

# Output configuration file
output_config() {
    "${PATH_SED}" -n '/^# \[ CONFIG_START/,/^# \] CONFIG_END/p' <"${0}"
} # output_config()

# Debug echo
decho() {
    # global $DEBUG
    local line

    # Not debugging, get out of here then
    [ -z "${DEBUG}" ] || [ "${DEBUG}" -le 0 ] && return

    # If message is "-" or isn't specified, use stdin ("" is valid input)
    msg="${@}"
    [ ${#} -lt 1 ] || [ "${msg}" == "-" ] && msg="$(</dev/stdin)"

    while IFS="" read -r line; do #{
        >&2 echo "[$(date +'%Y-%m-%d %H:%M')] DEBUG: ${line}"
    done< <(echo "${msg}") #}
} # decho()



#----------------------------------------------------------
# START #

# Clear DEBUG if it's 0
[ -n "${DEBUG}" ] && [ "${DEBUG}" == "0" ] && DEBUG=

ret=${ERR_NONE}

# If debug file, redirect stderr out to it
[ -n "${ERROR_LOG}" ] && exec 2>>"${ERROR_LOG}"

decho "START"

# SIGINT  =  2 # (CTRL-c etc)
# SIGKILL =  9
# SIGUSR1 = 10
# SIGUSR2 = 12
for sig in 2 9 10 12; do #{
    trap "trapint ${sig}" ${sig}
done #}

# Check for required commands

# sed (REQUIRED)
decho "Path for sed set to: '${PATH_SED}'..."
[ "${PATH_SED}" == "*" ] && PATH_SED="sed"
PATH_SED="$(check_for_cmd "sed" "${PATH_SED}" 1)" || exit $?

[ -z "${PATH_SED}" ] && {
    >&2 echo "ERROR: sed is required (set PATH_SED in config?)"
    exit ${ERR_MISSINGDEP}
}
decho "sed path: ${PATH_SED}"

# pactl (REQUIRED)
decho "Path for pactl set to: '${PATH_PACTL}'..."
[ "${PATH_PACTL}" == "*" ] && PATH_PACTL="pactl"
PATH_PACTL="$(check_for_cmd "pactl" "${PATH_PACTL}" 1)" || exit $?

[ -z "${PATH_PACTL}" ] && {
    >&2 echo "ERROR: pactl is required (set PATH_PACTL in config?)"
    exit ${ERR_MISSINGDEP}
}
decho "pactl path: ${PATH_PACTL}"

# Process command line parameters
opts=$(\
    getopt\
        --options v,h,V,C,t,m,u\
        --long verbose,help,version,configuration,toggle,mute,unmute\
        --name "${_binname}"\
        --\
        "$@"\
) || {
    >&2 echo "ERROR: Syntax error"
    >&2 show_usage
    exit ${ERR_USAGE}
}

eval set -- "${opts}"
unset opts

while :; do #{
    case "${1}" in #{
        # Verbose mode # [-v|--verbose]
        -v|--verbose)
            decho "Verbose mode specified"
            DEBUG=1
        ;;

        # Help # -h|--help
        -h|--help)
            decho "Help"

            show_usage
            exit ${ERR_NONE}
        ;;

        # Version # -V|--version
        -V|--version)
            decho "Version"

            show_version
            exit ${ERR_NONE}
        ;;

        # Configuration output # -C|--configuration
        -C|--configuration)
            decho "Configuration"

            output_config
            exit ${ERR_NONE}
        ;;

        # Toggle # -t|--toggle
        -t|--toggle)
            decho "Toggle"

            if [ -n "${action}" ]; then
                # Action is already set so error
                >&2 echo "ERROR: Contradicting action specified: ${1}"
                show_usage
                exit 2
            else
                action=2
            fi
        ;;

        # Mute # -m|--mute
        -m|--mute)
            decho "Mute"

            if [ -n "${action}" ]; then
                # Action is already set so error
                >&2 echo "ERROR: Contradicting action specified: ${1}"
                show_usage
                exit 2
            else
                action=1
            fi
        ;;

        # Unmute # -u|--unmute
        -u|--unmute)
            decho "Unmute"

            if [ -n "${action}" ]; then
                # Action is already set so error
                >&2 echo "ERROR: Contradicting action specified: ${1}"
                show_usage
                exit 2
            else
                action=0
            fi
        ;;

        --)
            shift
            break
        ;;

        -)
            # Read stdin
            #set -- "/dev/stdin"
            # FALL THROUGH TO FILE HANDLER BELOW
        ;;

        *)
            >&2 echo "ERROR: Unrecognised parameter ${1}..."
            exit ${ERR_USAGE}
        ;;
    esac #}

    shift

done #}

# TODO: Check for non-optional parameters

# No mode specified - default to toggle
[ -z "${action}" ] && action=2
decho "Action to take: ${s_actions[${action}]}"

# Injest command line supplied sources
while [ ! -z "${1}" ]; do #{
    SOURCES+=("${1}")
    shift 1
done #}

[ "${#SOURCES[@]}" -lt 1 ] && {
    >&2 echo "ERROR: SOURCES not set, and none specified on command line"
    exit ${ERR_USAGE}
}

# Validate numeric sources
for s in "${SOURCES[@]}"; do #{
    decho "Validating: ${s}"
    if [ "${s:0:2}" != 'N:' ]; then #{
        decho "    Expect numeric: ${s}"
        [ "${s}" -eq "${s}" ] &>/dev/null || {
            >&2 echo "ERROR: SOURCES must be numeric IDs or names prefixed with 'N:': ${s}"
            exit ${ERR_USAGE}
        }
    fi #}
done #}
unset s

[ ! -z "${DEBUG}" ] && [ "${DEBUG}" -gt 0 ] && {
    _exploded=""
    for s in "${SOURCES[@]}"; do #{
        # Backslash and double-quote gets "escaped" with a backslash for
        # printing, allowing us to accurately output the strings, no matter how
        # many backslashes and double-quotes they contain :D
        s="${s//\\/\\\\}"
        s="${s//\"/\\\"}"
        _exploded+=", "'"'"${s}"'"'
    done #}
    _exploded="${_exploded:2}"
    decho "SOURCES: ${_exploded}"
    unset _exploded s
}



declare -a pa_source_outputs
declare -a pa_source_output_names

#Source Output #347
#<TAB>Driver: protocol-native.c
#<TAB>Owner Module: 16
#<TAB>Client: 130
#<TAB>Source: 4
#<TAB>Sample Specification: s16le 2ch 44100Hz
#<TAB>Channel Map: front-left,front-right
#<TAB>Format: pcm, format.sample_format = "\"s16le\""  format.rate = "44100"  format.channels = "2"  format.channel_map = "\"front-left,front-right\""
#<TAB>Corked: no
#<TAB>Mute: no
#<TAB>Volume: front-left: 65536 / 100% / 0.00 dB,   front-right: 65536 / 100% / 0.00 dB
#<TAB>        balance 0.00
#<TAB>Buffer Latency: 0 usec
#<TAB>Source Latency: 271 usec
#<TAB>Resample method: n/a
#<TAB>Properties:
#<TAB><TAB>media.name = "recStream"
#<TAB><TAB>application.name = "ZOOM VoiceEngine"
#<TAB><TAB>native-protocol.peer = "TCP/IP client from 127.0.0.1:56710"
#<TAB><TAB>native-protocol.version = "34"
#<TAB><TAB>application.process.id = "28808"
#<TAB><TAB>application.process.user = "krayon"
#<TAB><TAB>application.process.host = "lister"
#<TAB><TAB>application.process.binary = "zoom"
#<TAB><TAB>application.language = "en_AU.UTF-8"
#<TAB><TAB>window.x11.display = ":0.0"
#<TAB><TAB>application.process.machine_id = "c23ee5e579e1ca1fc9d680bb6295ba7b"
#<TAB><TAB>application.process.session_id = "1"
#<TAB><TAB>module-stream-restore.id = "source-output-by-application-name:ZOOM VoiceEngine"

get_pa_app_name() {
    echo "${@}"|"${PATH_SED}" -n '/^\tProperties:/,${s/^\t\tapplication.name *= *"\(.*\)"$/\1/p}'
}

get_pa_source_input_id_by_name() {
    local k

    decho "Looking up ID by name: ${@}"
    for k in "${!pa_source_outputs[@]}"; do #{
        [ "${pa_source_output_names[${k}]}" == "${@}" ] && {
            decho "    Found: ${k}"
            echo "${k}"
            return 0
        }
    done #}

    decho "    Not found"
    return 1
}

get_pa_source_outputs() {
    declare -a keys
    local k
    local data="$("${PATH_PACTL}" list source-outputs)" || {
        >&2 echo "ERROR: Failed to enumerate source-outputs (errno:$?)"
        exit ${ERR_SOFTWARE}
    }

    keys=(
        $("${PATH_SED}" -n 's/^Source Output #\([0-9]\+\).*$/\1/p' <<<"${data}")
    )

    decho "Retrieved keys(${#keys[@]}): ${keys[@]}"
    decho ""

    for k in "${keys[@]}"; do #{
        pa_source_outputs[${k}]="$(
            "${PATH_SED}" -n '/^Source Output #'"${k}"'$/,/^Source Output/{/^Source Output/!p}' <<<"${data}"
        )"

        pa_source_output_names[${k}]="$(get_pa_app_name "${pa_source_outputs[${k}]}")"

        decho "    ${k}: ${pa_source_output_names[${k}]}"
    done #}
    decho ""
}

decho "Getting PA source-outputs..."
get_pa_source_outputs

for s in "${SOURCES[@]}"; do #{
    id="${s}"
    [ "${id:0:2}" == 'N:' ] && {
        id="$(get_pa_source_input_id_by_name "${id:2}")" || {
            >&2 echo "WARNING: Source not found: ${s}"
            ret=${ERR_NOUSER}
            continue
        }
    }

    decho "Checking for presence of source: ${s}"
    [ -z "${pa_source_outputs[${id}]}" ] && {
        >&2 echo "WARNING: Source not found: ${s}"
        ret=${ERR_NOUSER}
        continue
    }

    decho "Calling: ${PATH_PACTL} set-source-output-mute "'"'"${id}"'"'" "'"'"${action/2/toggle}"'"...'
    "${PATH_PACTL}" set-source-output-mute "${id}" "${action/2/toggle}" || {
        >&2 echo "WARNING: Failed to ${s_actions[${action}]} source-output: ${s} (errno:$?)"
        ret=${ERR_SOFTWARE}
    }
done #}
unset s id

decho "DONE"

cleanup

exit ${ret}
