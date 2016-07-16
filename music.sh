#!/bin/sh
#
# Copyright 2016 Sylvia van Os <iamsylvie@openmailbox.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

unset config_music_directory
unset config_state_directory

. "$SCRIPTPATH/config.sh"

if [ ! -d "$config_music_directory" ]; then
    echo "config_music_directory is not a valid directory" 1>&2
    exit 1
fi

if [ ! -d "$config_state_directory" ]; then
    echo "config_state_directory is not a valid directory" 1>&2
    exit 1
fi

main() {
    trap cleanUp INT

    cleanUp() {
        kill "$(cat "$config_state_directory/mplayer_pid")"

        rm "$config_state_directory/mplayer_input"
        rm "$config_state_directory/mplayer_output"
        rm "$config_state_directory/mplayer_pid"

        exit
    }

    if [ ! -p "$config_state_directory/mplayer_input" ]; then
        mkfifo "$config_state_directory/mplayer_input"
    fi

    playSong() {
        getRandomSong() {
            find "$config_music_directory" -type f | shuf -n1
        }

        if [ -f "$config_state_directory/mplayer_pid" ]; then
            if ps -p "$(cat "$config_state_directory/mplayer_pid")" >/dev/null; then
                # Already playing a song
                return 1
            fi
        fi

        song="$(getRandomSong)"
        if [ ! "$?" ]; then
            echo "No songs in $config_music_directory" 1>&2
            return 2
        fi

        mplayer "$song" -vo null -quiet -slave -input file="$config_state_directory/mplayer_input" >"$config_state_directory/mplayer_output" 2>/dev/null &
        echo "$!" > "$config_state_directory/mplayer_pid"
    }

    while true; do
        playSong
        sleep 1
    done
}

info() {
    if [ ! -f "$config_state_directory/mplayer_pid" ]; then
        echo "Mplayer does not appear to be running. Did you forget to start the daemon?" >&2
        return 1
    fi

    echo "get_file_name" >"$config_state_directory/mplayer_input"
    echo "get_meta_artist" >"$config_state_directory/mplayer_input"
    echo "get_meta_title" >"$config_state_directory/mplayer_input"
    echo "get_meta_album" >"$config_state_directory/mplayer_input"
    echo "get_time_pos" >"$config_state_directory/mplayer_input"
    echo "get_time_length" >"$config_state_directory/mplayer_input"
    echo "get_percent_pos" >"$config_state_directory/mplayer_input"
    sleep 1 # Hack to make sure the data is populated
    tail -n7 "$config_state_directory/mplayer_output"
}

next() {
    if kill "$(cat "$config_state_directory/mplayer_pid")" 2>/dev/null; then
        exit 0
    fi

    echo "Not currently playing anything. Is the daemon running?" >&2
    exit 1
}

action="info"

while getopts ":dn" opt; do
    case $opt in
        d)
            action="main"
            ;;
        n)
            action="next"
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

$action
