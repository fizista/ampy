#!/bin/bash
# run_tests.sh <ampy connection args>
#set -x
dir_old='./t_old'
dir_new='./t_new'
base_dir=$(pwd)

if [ -n "$1" ]
then
    ampy_args="$1"
else
    ampy_args="--port /dev/ttyUSB0"
fi

function create_old() {
    ampy $ampy_args mkdir /x/
    ampy $ampy_args put "${dir_old}/x/x.txt"
    ampy $ampy_args mkdir /x/y/
    ampy $ampy_args put "${dir_old}/x/y/y.txt"
}

function clean() {
    ampy $ampy_args rmdir --missing-okay /x
    ampy $ampy_args rmdir --missing-okay /test
    ampy $ampy_args rmdir --missing-okay /t_old
    ampy $ampy_args rmdir --missing-okay /t_new
}

function assert_equal() {
    STEP_NAME="$1"
    DATA1="$2"
    DATA2="$3"

    if [ "$DATA1" = "$DATA2" ]
    then
        echo "${STEP_NAME} - ok"
    else
        echo "${STEP_NAME} - NOT EQUAL"
    fi
}

function assert_equal_file() {
    LOCAL_FILE_PATH="$1"
    REMOTE_FILE_PATH="$2"
    data_remote=$(ampy $ampy_args get "$REMOTE_FILE_PATH" 2>/dev/null | xargs | sed 's/ *//g')

    if [ ! $? -eq 0 ]
    then
        echo "File: $REMOTE_FILE_PATH - NOT EXISTS"
        return
    fi

    data_local=$(cat "$LOCAL_FILE_PATH" | xargs | sed 's/ *//g')
    if [ "$data_local" = "$data_remote" ]
    then
        echo "File: $REMOTE_FILE_PATH - ok"
    else
        echo "File: $REMOTE_FILE_PATH - NOT EQUAL"
        echo "Local  data: /$data_local/"
        echo "Remote data: /$data_remote/"
        echo
    fi

}

function assert_dir_exists() {
    DIR="$1"
    ampy $ampy_args ls "$DIR" &> /dev/null
    assert_equal "Exists dir: $DIR" "$?" "0"
}

function test_equal() {
    cd $base_dir
    echo "####################################################"
    echo "###### $1"
    echo "####################################################"
    echo "Remote files:"
    ampy $ampy_args ls -l -r
    echo
    assert_dir_exists $2/x
    assert_dir_exists $2/x/y
    assert_dir_exists $2/x/z1
    assert_dir_exists $2/x/y/z2
    assert_equal_file "${dir_new}/x/x.txt" "$2/x/x.txt"
    assert_equal_file "${dir_new}/x/y/y.txt" "$2/x/y/y.txt"
}

clean

cd $dir_new
ampy $ampy_args rsync ./
test_equal "Only local"

cd $base_dir
clean
ampy $ampy_args rsync ./t_new/ /
test_equal "Local and remote"

cd $base_dir
clean
ampy $ampy_args mkdir /test
ampy $ampy_args rsync ./t_new/ /test/
test_equal "Local and remote non root" "/test"

clean

# Testy z plikiem timestamp
# .lastsync obok