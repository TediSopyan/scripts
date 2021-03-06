#!/bin/bash

# psxc-unpack.sh v2.12 (c) psxc//2009
#####################################
#
# This simple little thingy extracts files in a dir and removes the
# archive files afterwards. You can use this two ways - either extract
# files right after a release is complete, or crontab it. The latter
# is the best way imho.
# the 'nice' command should be used to keep unrar from hogging too much cpu -
# see UNRAR (below)
#
# NOTICE: This script does not scan recursively - to make that possible, use
#         psxc-unpack_all.sh
#
######################################
#
# installation:
# 1. copy psxc-unpack.sh to /glftpd/bin
# 2. make sure the /glftpd/tmp dir exists, and is world read/writable:
#      mkdir -p -m777 /glftpd/tmp
# 3. make your zipscript run this script after release is complete.
#    with pzs-ng, add
#      #define complete_script "/bin/psxc-unpack.sh"
#    to zsconfig.h
# 4. add a crontab entry to execute /glftpd/bin/psxc-unpack.sh at certain intervals
#      */5 * * * * /glftpd/bin/psxc-unpack.sh >/dev/null 2>&1
#
# you can also use this as a site command - fyi
#   site_cmd UNPACK EXEC /bin/psxc-unpack.sh
#   custom-unpack 1

# needed bins:
# unrar unzip sort ps grep cat awk head ls echo mv tr chmod wc basename tr (nice)

#####################################################
# CONFIGURATION
#####################################################

# PATH variable - should be fine as is.
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/libexec:/usr/libexec

# glftpd's root dir
GLROOT=/glftpd

# path to external conf - will override the settings below if found
# this path is within chroot, so don't add /glftpd in front.
UNPACK_CONF=/etc/psxc-unpack.conf

# glftpd's site dir
SITEDIR=/site

# where our logfile is located - path is within chroot so don't
# put /glftpd in front of this.
LOGFILE=/tmp/psxc-unpack.log

# glftpd's logfile (within chroot) - used for announces.
GLLOG=/ftp-data/logs/glftpd.log

# a logfile which list all successfully unpacked dirs.
COMPLETELOG=/tmp/psxc-unpack-complete.log

# How much time (in seconds) should the script wait before
# unpacking a release? The default value is 3600 (1 hour)
WAITSECONDS=3600

# in what dirs should this script be executed?
DIRS="/site/XVID /site/DVDR"

# the unrar command. remove the 'echo' in front to activate
# also check the man page for unrar.
UNRAR="echo nice -n 20 unrar e -p- -c- -cfg- -o- --"

# rm/delete command. remove the 'echo' in front to activate
RM="echo rm"

# rmdir command - used to delete empty subdirs. remove the 'echo' in front
# to activate. WARNING! Be careful!
RMDIR="echo rm -fR"

# rar filetypes. should be fine as is.
FILETYPES="\.[Rr][Aa][Rr]$ \.001$"

# subdirs. should be fine as is.
SUBDIRS="^[CcDdSs][DdVvIiUu][DdSsBb]?[CcKkSs]?[0-9A-Za-z]?[0-9A-Za-z]?$"

# how your completedirs look like. (This is regexp style, so keep the .*)
COMPLETEDIR=".*\[.*\].*[-].*[Cc][Oo][Mm][Pp][Ll][Ee][Tt][Ee].*\[.*\].*"

# this variable holds a list of files/dirs to remove if extraction was complete.
# (not regexp style, so slightly different.) separate with a space.
# default setting removes the complete bar, sample dir, sfv-files and dot-files (like .message)
RMFILES="*\[*\]*[Cc][Oo][Mm][Pp][Ll][Ee][Tt][Ee]*\[*\]* [Ss][Aa][Mm][Pp][Ll][Ee] \.[a-zA-Z0-9]* *.[Ss][Ff][Vv]"

# The following variable allows you to list dirs that are excluded from
# the DIRS list - if the dir match this, it will be skipped.
IGNOREDIRS="_subs$ /site/XVID/SUBS"

# The script supports unpacking of zipfiles as well. If the following variable
# is set, the script will try to unpack zipfiles as well. To disable it, set
# it to "".
ZIPUNPACK="YES"

# the unzip command. remove the 'echo' in front to activate.
# IMPORTANT! Do not add switches behind unzip!"
UNZIP="echo nice -n 20 unzip"

# set this to '1' to make the script run immediatly after release is complete
RUN_NOW=0

# put here a word to use to make the script unpack immediatly - only
# handy if you add this script as a site command. Not case sensitive.
# The site command will then be 'site unpack now' to extract immediatly.
MAGICWORD="now"

# If you wish to remove write-rights of the dirs after extraction, set this
# variable to 1.
CHMOD_DIRS=1

# Touch a file if extraction of the archive fails? Set to "" to disable.
# The file will be placed in the 'main' dir - ie, not in the subdir.
# Forbidden chars include / & \ $ [:space:] (they will be replaced with _)
# The first ''%%'' encountered will be replaced with the name of the archive.
UNPACKERROR="  PSXC-UNPACK - FAILED TO UNPACK ARCHIVE (%%)  "

# Script to execute after sucessful unpack - use "" to disable.
# One script only.
COMPLETESCRIPT="/bin/psxc-trailer.sh"

################################################################
# CODE BELOW - PLEASE IGNORE
################################################################

# remove the # on the line below for debug purposes only.
#set -x -v

RDIR=""
[[ -d $GLROOT/bin ]] && RDIR=$GLROOT
[[ -e $RDIR/$UNPACK_CONF ]] && source $RDIR/$UNPACK_CONF
[[ -e $RDIR/$UNPACK_CONF ]] && source $RDIR/$UNPACK_CONF
[[ ! -e $RDIR/$LOGFILE ]] && :>$RDIR/$LOGFILE && chmod 666 $RDIR/$LOGFILE
[[ ! -w $RDIR/$LOGFILE ]] && echo "HELP! UNABLE TO LOG DIRS! CHECK PERMS" && exit 1
[[ "$(echo "$MAGICWORD" | tr 'A-Z' 'a-z')" == "$(echo "$1" | tr 'A-Z' 'a-z')" ]] && RUN_NOW=1
[[ -e $SITEDIR ]] && {
  for DNAME in $DIRS; do
    [[ ! -z "$(echo $PWD | grep $DNAME)" ]] && {
      found=1
       break
    }
  done
  [[ $found -eq 1 || RUN_NOW -eq 1 ]] && echo "$PWD" >>$RDIR/$LOGFILE
}
[[ $RUN_NOW -ne 1 && -z "$(cat $RDIR/$LOGFILE)" ]] && exit 0
[[ -z "$(cat $RDIR/$LOGFILE)" ]] && exit 0
[[ $RUN_NOW -ne 1 && $found -eq 1 ]] && exit 0
[[ -e "$RDIR/$LOGFILE.pid" ]] && {
  oldpid=$(cat "$RDIR/$LOGFILE.pid")
  for pid in $(ps ax | awk '{print $1}'); do
    [[ $pid -eq $oldpid ]] && exit 0
  done
}
echo $$ >"$RDIR/$LOGFILE.pid" && chmod 666 "$RDIR/$LOGFILE.pid"
:>"$RDIR/$LOGFILE.complete" && chmod 666 "$RDIR/$LOGFILE.complete"
while [ 1 ]; do
  :>"$RDIR/$LOGFILE.tmp" && chmod 666 "$RDIR/$LOGFILE.tmp"
  [[ -z "$(cat "$RDIR/$LOGFILE")" ]] && break
  DNAME="$(head -n 1 $RDIR/$LOGFILE)"
  [[ ! -d "$RDIR/$DNAME" ]] && {
    grep -v -F "$DNAME" "$RDIR/$LOGFILE" > "$RDIR/$LOGFILE.tmp"
    mv "$RDIR/$LOGFILE.tmp" "$RDIR/$LOGFILE"
    continue
  }
  IGNORED=""
  for IGNORE in $IGNOREDIRS; do
    [[ ! -z "$(echo "$DNAME" | grep $IGNORE)" ]] && {
      IGNORED="YES"
      break
    }
  done
  [[ ! -z "$IGNORED" ]] && {
    grep -v -F "$DNAME" "$RDIR/$LOGFILE" > "$RDIR/$LOGFILE.tmp"
    mv "$RDIR/$LOGFILE.tmp" "$RDIR/$LOGFILE"
    continue
  }
  ZRETVAL=0
  while [ 2 ]; do
    :>"$RDIR/$LOGFILE.tmp" && chmod 666 "$RDIR/$LOGFILE.tmp"
    EXTRACTNAME=""
    [[ ! -e "$RDIR/$DNAME" ]] && break
    [[ ! -z "ZIPUNPACK" && ! -z "$(ls -1 | grep "\.[Zz][Ii][Pp]$")" && $ZRETVAL -eq 0 ]] && {
      mkdir ./.psxctmp
      OFS=$IFS
      IFS=${IFS# }
      for zipfile in $(ls -1 | grep "\.[Zz][Ii][Pp]$" | sort); do
        unset IFS
        $UNZIP -oCjd ./.psxctmp "$zipfile"
        let ZRETVAL=ZRETVAL+$?
      done
      unset IFS
      IFS=$OFS
      [[ $ZRETVAL -eq 0 ]] && {
        IFS=${IFS# }
        for zipfile in $(ls -1 | grep "\.[Zz][Ii][Pp]$" | sort); do
          unset IFS
          IFS=$OFS
          $RM "$zipfile"
        done
        unset IFS
        mv ./.psxctmp/* ./
      }
      rm -fR ./.psxctmp
    }
    ls -1 "$RDIR/$DNAME" | sort >"$RDIR/$LOGFILE.tmp"
    cd "$RDIR/$DNAME"
    while read FNAME; do
      for FTYPE in $FILETYPES; do
        [[ ! -z "$(echo "$FNAME" | grep -E $FTYPE)" ]] && {
          EXTRACTNAME="$FNAME"
          BASETYPE=$FTYPE
          break
        }
      done
      [[ ! -z "$EXTRACTNAME" ]] && break
    done < "$RDIR/$LOGFILE.tmp"
    rm "$RDIR/$LOGFILE.tmp"
    :>"$RDIR/$LOGFILE.tmp" && chmod 666 "$RDIR/$LOGFILE.tmp"
    grep -v -F "$DNAME" "$RDIR/$LOGFILE" > "$RDIR/$LOGFILE.tmp"
    mv "$RDIR/$LOGFILE.tmp" "$RDIR/$LOGFILE"
    [[ -z "$EXTRACTNAME" ]] && break
    SMATCH=0
    for SUBDIR in $SUBDIRS; do
      [[ ! -z "$(basename "$DNAME" | grep -E "$SUBDIR")" ]] && SMATCH=1 && break
    done
    [[ $SMATCH -eq 1 ]] && PARENT="../" || PARENT=""
    BASENAME="$(echo "$EXTRACTNAME" | sed "s/\.[Pp][Aa][Rr][Tt][0-9]*\.[rRaA0-9][rRaA0-9][rRaA0-9]$/./" | sed "s/$BASETYPE//")"
    unrar vt -v -- "$EXTRACTNAME" | grep -- "$BASENAME" | grep -v "^ " | grep -o -- "$BASENAME.*" >$RDIR/$LOGFILE.lst
    mkdir ./.psxctmp
    $UNRAR "$EXTRACTNAME" ./.psxctmp/
    RET=$?
    UNPACKERR="$(echo "$UNPACKERROR" | tr '/\$\\\&\ ' '_' | sed "s|%%|$EXTRACTNAME|")"
    [[ $RET -eq 0 ]] && {
      echo "$RDIR/$DNAME" >>"$RDIR/$LOGFILE.complete"
      while read FNAME; do
        $RM "$FNAME"
      done <$RDIR/$LOGFILE.lst
      rm "$RDIR/$LOGFILE.lst"
      mv -f ./.psxctmp/* ./ && rm -fR ./.psxctmp
      [[ ! -z "$RMFILES" ]] && {
        for DELME in $RMFILES; do
          $RMDIR "$DELME"
        done
      }
      [[ ! -z "$PARENT" ]] && {
        ls -1 | sort >"$RDIR/$LOGFILE.tmp"
        EXTRACTNAME=""
        while read FNAME; do
          for FTYPE in $FILETYPES; do
            [[ ! -z "$(echo "$FNAME" | grep -E $FTYPE)" ]] && {
              EXTRACTNAME="$FNAME"
              BASETYPE=$FTYPE
              break
            }
          done
        done < "$RDIR/$LOGFILE.tmp"
        rm "$RDIR/$LOGFILE.tmp"
        [[ -z "$EXTRACTNAME" ]] && mv ./* ../ && $RMDIR "$PWD"
      }
      [[ ! -e "$RDIR/$DNAME" ]] && break
      [[ $(ls -1 "$RDIR/$DNAME" | sort | grep -v "^\ " | grep -v "^\." | grep -v "$COMPLETEDIR" | grep -v "$UNPACKERR" | wc -l) -eq 0 ]] && $RMDIR "$RDIR/$DNAME"
    } || {
      [[ -e ./.psxctmp ]] && rm -fR ./.psxctmp
      [[ -e "$RDIR/$LOGFILE.lst" ]] && rm "$RDIR/$LOGFILE.lst"
    }
    RETMODE=$RET
    [[ $RET -ne 0 ]] && {
      echo "Error in archive $RDIR/$DNAME/$EXTRACTNAME - skipping this dir."
      [[ "$UNPACKERR" != "" ]] && :>"$RDIR/$DNAME/$UNPACKERR" && chmod 666 "$RDIR/$DNAME/$UNPACKERR"
      break
    }
    [[ ! -z "$(echo $RM | grep "echo")" ]] && echo "running in testmode - unable to test for more than one release in the dir w/o going into endless loop. breaking." && break
  done
  [[ ! -z "$GLLOG" && $RETMODE -eq 0 ]] && { 
    echo "$(date "+%a %b %e %T %Y") PSXCUNPACK: {$DNAME}" >>$RDIR/$GLLOG
    curpath="$PWD"
    [[ "$PARENT" != "" ]]&& {
      cd $(dirname "$RDIR/$DNAME")
#    cd "$RDIR/$DNAME/$PARENT"
    }
    destpath="$PWD"
#    cd "$curpath"
    [[ -z "$(echo "$destpath" | grep -- "^$GLROOT")" ]] && destpath="$(echo "$GLROOT/$destpath" | tr -s "/")"
    let LOGDATEFORMAT=$(date +%s)+${WAITSECONDS:-3600}
    [[ ! -z "$COMPLETELOG" ]] &&  echo "$LOGDATEFORMAT $destpath" >>$RDIR/$COMPLETELOG
    [[ ! -z "$COMPLETESCRIPT" && -x $COMPLETESCRIPT ]] && {
      echo "psxc-unpack: Executing script... please wait."
      $COMPLETESCRIPT
      [[ $? -eq 0 ]] && {
        echo "psxc-unpack: Executing script done."
      } || {
        echo "psxc-unpack: Script returned with an error."
      }
    }
  }
  [[ ! -z "$GLLOG" && $RETMODE -ne 0 ]] && echo "$(date "+%a %b %e %T %Y") PSXCUNPACKERROR: {$DNAME}" >>$RDIR/$GLLOG
done
[[ $CHMOD_DIRS -eq 1 && $RET -eq 0 ]] && {
  while read CDIR; do
    [[ -d "$CDIR" ]] && chmod 555 "$CDIR"
  done < "$RDIR/$LOGFILE.complete"
}
[[ -e "$RDIR/$LOGFILE" ]] && rm "$RDIR/$LOGFILE"
[[ -e "$RDIR/$LOGFILE.tmp" ]] && rm "$RDIR/$LOGFILE.tmp"
[[ -e "$RDIR/$LOGFILE.complete" ]] && rm "$RDIR/$LOGFILE.complete"
[[ -e "$RDIR/$LOGFILE.pid" ]] && rm "$RDIR/$LOGFILE.pid"

