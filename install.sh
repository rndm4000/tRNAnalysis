#!/usr/bin/env bash

# References
# http://kvz.io/blog/2013/11/21/bash-best-practices/
# http://jvns.ca/blog/2017/03/26/bash-quirks/

# exit when a command fails
set -o errexit

# exit if any pipe commands fail
set -o pipefail

# exit when your script tries to use undeclared variables
#set -o nounset

# trace what gets executed
set -o xtrace

# Bash traps
# http://aplawrence.com/Basics/trapping_errors.html
# https://stelfox.net/blog/2013/11/fail-fast-in-bash-scripts/

#set -o errtrace

SCRIPT_NAME="$0"
SCRIPT_PARAMS="$@"

error_handler() {
    echo
    echo " ########################################################## "
    echo
    echo " An error occurred in:"
    echo
    echo " - line number: ${1}"
    shift
    echo " - exit status: ${1}"
    shift
    echo " - command: ${@}"
    echo
    echo " The script will abort now. User input was: "
    echo
    echo " ${SCRIPT_NAME} ${SCRIPT_PARAMS}"
    echo
    echo " Please copy and paste this error and report it via Git Hub: "
    echo " https://github.com/Acribbs/tRNAnalysis/issues "
    print_env_vars
    echo " ########################################################## "
}

trap 'error_handler ${LINENO} $? ${BASH_COMMAND}' ERR INT TERM

# log installation information
log() {
    echo "# install.sh log | `hostname` | `date` | $1 "
}

# report error and exit
report_error() {
    echo
    echo $1
    echo
    echo "Aborting."
    echo
    exit 1
}

# detect trnanalysis installation
detect_trnanalysis_installation() {

    if [[ -z "$INSTALL_HOME" ]] ; then

	if [[ -d "$HOME/trnanalysis-install/conda-install" ]] ; then
	    UNINSTALL_DIR="$HOME/trnanalysis-install"
	fi

    else

	if [[ -d "$INSTALL_HOME/conda-install" ]] ; then
	    UNINSTALL_DIR="$INSTALL_HOME"
	fi

    fi

} # detect_trnanalysis_installation


# configure environment variables 
# set: INSTALL_HOME, CONDA_INSTALL_DIR, CONDA_INSTALL_TYPE
get_trnanalysis_env() {
    INSTALL_HOME=$TRAVIS_BUILD_DIR
    CONDA_INSTALL_TYPE="trnanalysis.yml"
    CONDA_INSTALL_DIR=$INSTALL_HOME/conda-install
    CONDA_INSTALL_ENV="trnanalysis"

} # get_trnanalysis_env


# setup environment variables
setup_env_vars() {

    export CFLAGS=$CFLAGS" -I$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/include -L$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/lib"
    export CPATH=$CPATH" -I$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/include -L$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/lib"
    export C_INCLUDE_PATH=$C_INCLUDE_PATH:$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/include
    export CPLUS_INCLUDE_PATH=$CPLUS_INCLUDE_PATH:$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/include
    export LIBRARY_PATH=$LIBRARY_PATH:$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/lib
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/lib:$CONDA_INSTALL_DIR/envs/$CONDA_INSTALL_ENV/lib/R/lib

} # setup_env_vars

# print related environment variables
print_env_vars() {

    echo
    echo " Debugging: "
    echo " CFLAGS: "$CFLAGS
    echo " CPATH: "$CPATH
    echo " C_INCLUDE_PATH: "$C_INCLUDE_PATH
    echo " CPLUS_INCLUDE_PATH: "$CPLUS_INCLUDE_PATH
    echo " LIBRARY_PATH: "$LIBRARY_PATH
    echo " LD_LIBRARY_PATH: "$LD_LIBRARY_PATH
    echo " INSTALL_HOME: "$INSTALL_HOME
    echo " CONDA_INSTALL_DIR: "$CONDA_INSTALL_DIR
    echo " CONDA_INSTALL_TYPE: "$CONDA_INSTALL_TYPE
    echo " CONDA_INSTALL_ENV: "$CONDA_INSTALL_ENV
    echo " PYTHONPATH: "$PYTHONPATH
    [[ ! $INSTALL_TEST ]] && echo " INSTALL_BRANCH: "$INSTALL_BRANCH
    [[ ! $INSTALL_TEST ]] && echo " RELEASE: "$RELEASE
    [[ ! $INSTALL_TEST ]] && echo " CODE_DOWNLOAD_TYPE: "$CODE_DOWNLOAD_TYPE
    echo

} # print_env_vars

# Travis installations are running out of RAM
# with large conda installations. Issue has been submitted here:
# https://github.com/conda/conda/issues/1197
# While we wait for a response, we'll try to clean up the conda
# installation folder as much as possible
conda_cleanup() {
    conda clean --index-cache
    conda clean --lock
    conda clean --tarballs -y
    conda clean --packages -y
}


# proceed with conda installation
conda_install() {

    log "installing conda"

    detect_trnanalysis_installation

    if [[ -n "$UNINSTALL_DIR" ]] ; then

	echo
	echo " An installation of the trnanalysis code was found in: $UNINSTALL_DIR"
	echo " Please use --location to install trnanalysis code in a different location "
	echo " or uninstall the current version before proceeding."
	echo
	echo " Installation is aborted."
	echo
	exit 1

    fi

    # get environment variables: INSTALL_HOME, CONDA_INSTALL_DIR, CONDA_INSTALL_TYPE
    get_trnanalysis_env

    mkdir -p $INSTALL_HOME
    cd $INSTALL_HOME

    # select Miniconda bootstrap script depending on Operating System
    MINICONDA=

    if [[ `uname` == "Linux" ]] ; then

	# Conda 4.4 breaks everything again!
	# Conda 4.5 looks better
	MINICONDA="Miniconda3-latest-Linux-x86_64.sh"
	#MINICONDA="Miniconda3-4.3.31-Linux-x86_64.sh"

    elif [[ `uname` == "Darwin" ]] ; then

	# Conda 4.4 breaks everything again!
	# Conda 4.5 looks better
	MINICONDA="Miniconda3-latest-MacOSX-x86_64.sh"
	#MINICONDA="Miniconda3-4.3.31-MacOSX-x86_64.sh"

    else
	echo
	echo " Unsupported operating system detected. "
	echo
	echo " Aborting installation... "
	echo
	exit 1

    fi

    log "downloading miniconda"
    # download and install conda
    curl -O https://repo.continuum.io/miniconda/${MINICONDA}

    log "installing miniconda"
    bash ${MINICONDA} -b -p $CONDA_INSTALL_DIR
    source ${CONDA_INSTALL_DIR}/bin/activate
    hash -r

    # install cgat environment
    log "updating conda environment"
    # Conda 4.4 breaks everything again!
    # Conda 4.5 looks better
    # conda install --quiet --yes 'conda=4.3.33'
    conda update --all --yes
    conda info -a

    log "installing tRNAnalysis environment"
    # Now using conda environment files:
    # https://conda.io/docs/using/envs.html#use-environment-from-file

    [[ -z ${TRAVIS_BRANCH} ]] && TRAVIS_BRANCH=${INSTALL_BRANCH}
    curl -o env.yml -O https://raw.githubusercontent.com/Acribbs/tRNAnalysis/${TRAVIS_BRANCH}/conda/environments/${CONDA_INSTALL_TYPE}
    conda env create --quiet --file env.yml
    
    conda env export --name ${CONDA_INSTALL_ENV}

    # activate trnanalysis environment
    log "activating environment"
    source $CONDA_INSTALL_DIR/bin/activate $CONDA_INSTALL_ENV

    log "installing trnanalysis code into conda environment"
    # if installation is 'devel' (outside of travis), checkout latest version from github
    if [[ -z ${TRAVIS_INSTALL} ]] ; then

	DEV_RESULT=0

    fi # if travis install

} # conda install


# test code with conda install
conda_test() {

    log "starting conda_test"

    # get environment variables: INSTALL_HOME, CONDA_INSTALL_DIR, CONDA_INSTALL_TYPE
    get_trnanalysis_env

    setup_env_vars

    # setup environment and run tests
    if [[ $TRAVIS_INSTALL ]]; then

	# enable Conda env
	log "activating trnanalysis conda environment"
	source $CONDA_INSTALL_DIR/bin/activate $CONDA_INSTALL_ENV

	# show conda environment used for testing
	conda env export

	# python preparation
	log "install CGAT code into conda environment"
	cd $INSTALL_HOME
	# remove install_requires (no longer required with conda package)
	sed -i'' -e '/REPO_REQUIREMENT/,/pass/d' setup.py
	sed -i'' -e '/# dependencies/,/dependency_links=dependency_links,/d' setup.py
	python setup.py develop

	# run tests
	log "running tests..."
	if [[ $TEST_ALL ]] ; then
	    pytest tests
	elif [[ $TEST_IMPORT ]] ; then
	    nosetests -v tests/test_import.py ;
	elif [[ $TEST_STYLE ]] ; then
	    nosetests -v tests/test_style.py ;
	fi


    fi # if travis or jenkins

} # conda_test


# update conda installation
conda_update() {

    # get environment variables: INSTALL_HOME, CONDA_INSTALL_DIR, CONDA_INSTALL_TYPE
    get_trnanalysis_env

    source $CONDA_INSTALL_DIR/bin/activate $CONDA_INSTALL_ENV
    conda update --all

    if [[ ! $? -eq 0 ]] ; then

	echo
	echo " There was a problem updating the installation. "
	echo 
	echo " Please submit this issue via Git Hub: "
	echo " https://github.com/Acribbs/tRNAnalysis/issues "
	echo 

    else 

	echo
	echo " All packages were succesfully updated. "
	echo 

    fi 

} # conda_update


# unistall trnanalysis
uninstall() {

    detect_trnanalysis_installation

    if [[ -z "$UNINSTALL_DIR" ]] ; then

	echo
	echo " The location of the CGAT code was not found. "
	echo " Please uninstall manually."
	echo
	exit 1
	
    else

	rm -rf $UNINSTALL_DIR
	if [[ $? -eq 0 ]] ; then
	    echo
	    echo " CGAT code successfully uninstalled."
	    echo 
	    exit 0
	else
	    echo
	    echo " There was a problem uninstalling the CGAT code."
	    echo " Please uninstall manually."
	    echo
	    exit 1
	fi
    fi

}


# test whether --git and --git-ssh download is doable
test_git() {
    git --version >& /dev/null || GIT_AVAIL=$?
    if [[ $GIT_AVAIL -ne 0 ]] ; then
	echo
	echo " Git is not available but --git or --git-ssh option was given."
	echo " Please rerun this script on a computer with git installed "
	echo " or try again without --git or --git-ssh"
	report_error " "
    fi
}


# test whether --git-ssh download is doable
test_git_ssh() {
    ssh-add -L >& /dev/null || SSH_KEYS_LOADED=$?
    if [[ $SSH_KEYS_LOADED -ne 0 ]] ; then
	echo
	echo " Please load your ssh keys for GitHub before proceeding!"
	echo
	echo " Try: "
	echo " 1. eval \$(ssh-agent)"
	echo " 2. ssh-add ~/.ssh/id_rsa # or the file where your private key is"
	report_error " and run this script again. "
    fi
}


# don't mix branch and release options together
test_mix_branch_release() {
    # don't mix branch and release options together
    if [[ $RELEASE ]] ; then
	if [[ "$INSTALL_BRANCH" != "master" ]] ; then
            echo
            echo " You cannot mix git branches and releases for the installation."
            echo
            echo " Your input was: "$SCRIPT_PARAMS
            report_error " Please either use branches or releases but not both."
	fi
    fi
}


# test whether a branch exists in the trnanalysis repository
# https://stackoverflow.com/questions/12199059/how-to-check-if-an-url-exists-with-the-shell-and-probably-curl
test_core_branch() {
    RELEASE_TEST=0
    curl --output /dev/null --silent --head --fail https://raw.githubusercontent.com/Acribbs/tRNAnalysis/${INSTALL_BRANCH}/README.rst || RELEASE_TEST=$?
    if [[ ${RELEASE_TEST} -ne 0 ]] ; then
	echo
	echo " The branch provided for trnanalysis does not exist: ${INSTALL_BRANCH}"
	echo
	echo " Please have a look at valid branches here: "
	echo " https://github.com/Acribbs/tRNAnalysis/branches"
	echo
	report_error " Please use a valid branch and try again."
    fi
}


# test whether a release exists or not
# https://stackoverflow.com/questions/12199059/how-to-check-if-an-url-exists-with-the-shell-and-probably-curl
test_release() {
    RELEASE_TEST=0
    curl --output /dev/null --silent --head --fail https://raw.githubusercontent.com/Acribbs/tRNAnalysis/${RELEASE}/README.rst || RELEASE_TEST=$?
    if [[ ${RELEASE_TEST} -ne 0 ]] ; then
	echo
	echo " The release number provided does not exist: ${RELEASE}"
	echo
	echo " Please have a look at valid releases here: "
	echo " https://github.com/Acribbs/tRNAnalysis/releases"
	echo
	echo " An example of valid release is: --release v0.4.0"
	report_error " Please use a valid release and try again."
    fi
}


# clean up environment
# deliberately use brute force
cleanup_env() {
    set +e
    source deactivate >& /dev/null || true
    source deactivate >& /dev/null || true
    unset -f conda || true
    unset PYTHONPATH || true
    # Next actions disabled. Please see:
    # https://github.com/cgat-developers/cgat-core/issues/44
    #module purge >& /dev/null || true
    #mymodule purge >& /dev/null || true
    set -e
}


# function to display help message
help_message() {
    echo
    echo " This script uses Conda to install trnanalysis. To proceed, please type:"
    echo " ./install.sh [--location </full/path/to/folder/without/trailing/slash>]"
    echo
    echo " The default install folder will be: $HOME/cgat-install"
    echo
    echo " It will create a new Conda environment ready to run the CGAT code."
    echo
    echo " By default the master branch will be installed:"
    echo " https://github.com/Acribbs/tRNAnalysis/"
    echo
    echo " Change that with:"
    echo " ./install.sh  --branch <name-of-branch>"
    echo
    echo " To test the installation:"
    echo " ./install.sh --test [--location </full/path/to/folder/without/trailing/slash>]"
    echo
    echo " To update the Conda packages:"
    echo " ./install.sh --update [--location </full/path/to/folder/without/trailing/slash>]"
    echo 
    echo " To uninstall the CGAT code:"
    echo " ./install.sh --uninstall [--location </full/path/to/folder/without/trailing/slash>]"
    echo
    echo " Please submit any issues via Git Hub:"
    echo " https://github.com/Acribbs/tRNAnalysis/issues"
    echo
    exit 1
} # help_message

# the script starts here
cleanup_env

if [[ $# -eq 0 ]] ; then

    help_message

fi

# travis execution
TRAVIS_INSTALL=
# test current installation
INSTALL_TEST=
# update current installation
INSTALL_UPDATE=
# uninstall code
UNINSTALL=
UNINSTALL_DIR=
# where to install code
INSTALL_HOME=
# how to download code:
# 0 = as zip (default)
# 1 = git clone with https
# 2 = git clone with ssh
CODE_DOWNLOAD_TYPE=0
# which github branch to use (default: master)
INSTALL_BRANCH="master"
# Install a released version?
RELEASE=

# parse input parameters
# https://stackoverflow.com/questions/402377/using-getopts-in-bash-shell-script-to-get-long-and-short-command-line-options
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash

while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in

	--help)
	    help_message
	    ;;

	--install-repo)
	    INSTALL_DEVEL=1
	    shift
	    ;;

	--travis)
	    TRAVIS_INSTALL=1
	    shift # past argument
	    ;;

	--zip)
	    CODE_DOWNLOAD_TYPE=0
	    shift
	    ;;

	--git)
	    CODE_DOWNLOAD_TYPE=1
	    shift
	    test_git
	    ;;

	--git-ssh)
	    CODE_DOWNLOAD_TYPE=2
	    shift
	    test_git
	    test_git_ssh
	    ;;

	--test)
	    INSTALL_TEST=1
	    shift
	    ;;

	--update)
	    INSTALL_UPDATE=1
	    shift
	    ;;

	--uninstall)
	    UNINSTALL=1
	    shift
	    ;;

	--location)
	    INSTALL_HOME="$2"
	    shift 2
	    ;;

	--branch)
	    INSTALL_BRANCH="$2"
	    test_mix_branch_release
	    shift 2
	    ;;

	--release)
	    RELEASE="$2"
	    test_mix_branch_release
	    test_release
	    INSTALL_BRANCH="$2"
	    shift 2
	    ;;

	*)
	    help_message
	    ;;

    esac
done

# sanity check 2: make sure one installation option is selected
if [[ -z $INSTALL_TEST ]] && \
       [[ -z $INSTALL_DEVEL ]] && \
       [[ -z $TRAVIS_INSTALL ]] ; then

    report_error " You need to select either --devel or --production. "

fi

# sanity check 3: make sure there is space available in the destination folder (10 GB) in 512-byte blocks
[[ -z ${TRAVIS_INSTALL} ]] && \
    mkdir -p ${INSTALL_HOME} && \
    [[ `df -P ${INSTALL_HOME} | awk '/\// {print $4}'` -lt 20971520  ]] && \
    report_error " Not enough disk space available on the installation folder: "$INSTALL_HOME

# perform actions according to the input parameters processed
if [[ $TRAVIS_INSTALL ]]; then

    conda_install
    conda_test

else 

    if [[ $INSTALL_DEVEL ]] ; then
	conda_install
    fi

    if [[ $INSTALL_TEST ]] ; then
	conda_test
    fi

    if [[ $INSTALL_UPDATE ]] ; then
	conda_update
    fi

    if [[ $UNINSTALL ]] ; then
	uninstall
    fi

fi # if-variables
