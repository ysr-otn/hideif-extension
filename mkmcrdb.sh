#! /bin/sh

## Copyright (C) 2020 Yoshihiro Ohtani

# Author: Yoshihiro Ohtani
# Version: 0.1.1

## License:

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with GNU Emacs; see the file COPYING.  If not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.


## Code:

# Usage of this command
usage() {
  echo "Make macro database *.mdb for C/C++ source code.

Usage: $(basename $0) [-I include paths] [-D define options] [-t type] [-c compile command] [-m show macro option] directories.

    -I: Include paths. This option can be set multiple separate with ':'.
        ex. Set include paths like -I/usr/include -I/usr/local/include.
                -I /usr/include:/usr/local/include
    -D: Define options. This option can be set multiple separate with ':'.
        ex. Set define options like -DHOGE -DFUGA=1.
                -D HOGE:FUGA=1
    -t: Type of source code. 
        - c: C
        - c++: C++
        Default value is c.
    -c: Compile command.
        Default value is below.
        - if option -t is c: gcc
        - if option -t is c++: g++
    -m: Options for compile command to show macro definition.
        Default value is \"-dM -E\"
    directories: Directories path that make macro database.
                 Macro database directories .mcrdb that include
                 macro database files *.mdb, are made in each directories
                 these are specified this option."
  exit 1
}


# Default value of Type of source file.
TYPE_OPT=c

# Default value of Compile command
CC_OPT=NONE

# The options of preprocess.
MCR_OPT="-dM -E"

# Analyse options
while getopts I:D:t:c:p:h OPT
do
    case $OPT in
        # -I options at build.
        "I" ) INC_OPT="$OPTARG";;
        # -D options at build.
        "D" ) DEF_OPT="$OPTARG";;
        # Type of source file.
        "t" ) TYPE_OPT="$OPTARG";;
        # Compile command
        "c" ) CC_OPT="$OPTARG";;
        # Preprocess option
        "p" ) MCR_OPT="$OPTARG";;
        h) usage;;
        *) usage;;
    esac
done

# Delete the options already analysed.
shift  $(($OPTIND - 1)) 


# The directories to analyse
DIR=$*

# The directory to be stored the macro database files. 
MCRDB_DIR=.mcrdb

# The extension of macro database file.
MCRDB_EXT=.mdb

# C/C++ compiler.
if [ $TYPE_OPT = c ]; then
    if [ $CC_OPT = NONE ]; then
        CC=gcc
    else
        CC=$CC_OPT
    fi
elif [ $TYPE_OPT = c++ ]; then
    if [ $CC_OPT = NONE ]; then
        CC=g++
    else
        CC=$CC_OPT
    fi
else
    echo \'$TYPE_OPT\' is a invalid argument for option -t.
    exit;
fi


# Save the current directory path.
cur_dir=`pwd`


# Execute the process to each directories.
for dir in $DIR
do
    # Move the directory.
    cd $cur_dir/$dir
    
    # C/C++ source directories.
    src_dir=`find ./ -type d | sed 's/^\.\/*//' | grep -v \.ccls-cache | grep -v build | grep -v ${MCRDB_DIR}`
    # C source files.
    if [ $TYPE_OPT == c ]; then
        src_file=`find ./ -name "*.[CcHh]" | grep -v \.ccls-cache | grep -v build | sed 's/^\.\/*//' | sort`
    else
        # C++ source files.
        src_file=`find -E ./ -type f -iregex ".*\.(cc|cpp|c\+\+|cxx|h|hh)" | grep -v \.ccls-cache | grep -v build | sed 's/^\.\/*//' | sort`
    fi


    # Setting of the include paths.
    INCLUDES="-I./"
    inc_opt=`echo ${INC_OPT} | awk -F ':' '{for(i = 0; i < NF; i++){printf("%s ", $(NF - i))}}'`
    for i in ${inc_opt}
    do
        INCLUDES="-I"$i" "${INCLUDES}
    done

    # Setting of the defines.
    DEFINES=""
    def_opt=`echo ${DEF_OPT} | awk -F ':' '{for(i = 0; i < NF; i++){printf("%s ", $(NF - i))}}'`
    for d in ${def_opt}
    do
        DEFINES="-D"$d" "${DEFINES}
    done

    # Make macro database directory, if it is not exist.
    if [ ! -d ${MCRDB_DIR} ]; then
        mkdir ${MCRDB_DIR}
    fi
    
    # Make macro database subdirectories, if these are not exist.
    for i in $src_dir
    do
        if [ ! -d ${MCRDB_DIR}/$i ]; then
            mkdir ${MCRDB_DIR}/$i
        fi
    done

    # Make database files for each source codes.
    for i in $src_file
    do
        # The database file.
        ofile=`echo ${MCRDB_DIR}/${i}${MCRDB_EXT}`
        # Write preprocess command after comment out character '#', at the head of line of database file.
        echo \# $CC $MCR_OPT $DEFINES $INCLUDES $i > $ofile
        # If the macro does not have a value, write 'MacroName' to the macro database file.
        # If the macro have a value, write 'MacroName MacroValue' to the macro database file.
		# The detail of each pipe line sequences described below.
		# 1. tr: Convert line feed code CR + LF to LF.
        # 2. grep: Grep macro definition.
        # 3. awk: Print 'MacroName' and 'MacroValue'.
		# 4. python: If 'MacroValue' is a formula then calculate 'MacroValue' to a number, otherwise print 'MacroValue' as it is.
		# 5. tr: Convert line feed code CR + LF to LF.
		$CC $MCR_OPT $DEFINES $INCLUDES $i \
			| tr -d \\r \
			| grep -e "^[ \t]*#define[ \t][ \t]*[A-z0-9_][A-z0-9_]*[ \t$]" \
			| awk '{printf("%s", $2); if(NF > 2) printf(" ");  for(i = 3; i <= NF; i++){printf("%s", $i)} printf("\n")}' \
			| python -c "import sys, re; [(lambda x: print(x[0], eval(x[1])) if len(x) > 1 and re.match(r'([+-]?[Xx][0-9A-Fa-f]+|[+-]?[0-9]+|[+\-*/%<>()])+$', x[1]) else print(' '.join(x)))(i) for i in [l.split() for l in sys.stdin]]" \
			| tr -d \\r \
    				  >> $ofile
    done    
done

# Return to the saved directory path. 
cd $cur_dir
