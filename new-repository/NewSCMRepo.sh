#! /bin/bash

# Configuration section. Change it to point to the right directories, according
# to your infrastructure layout.
SCM_ROOT="/var/www/repos";
TRAC_ROOT="${SCM_ROOT}/trac-repos";
TRAC_BASE_CONFIG="${TRAC_ROOT}/base-config.ini";
SVN_ROOT="${SCM_ROOT}/svn-repos";
GIT_ROOT="${SCM_ROOT}/git-repos";

# Exit status:
# - 0: success
EXIT_SUCCESS=0
# - 1: unknown parameters were supplied or required parameters were not supplied
EXIT_PARAMETER_ERROR=1
# - 2: validation error. The supplied parameres did not pass some validation rule
EXIT_INVALID_DATA_ERROR=2
# - 3: one or more of the repository creation steps failed
EXIT_PROCESS_ERROR=3

# Global variables which store the parsed arguments the user supplied
REPO_NAME=""
REPO_DESCRIPTION=""
CREATE_TRAC_REPO=0
CREATE_GIT_REPO=0
CREATE_SVN_REPO=0
DEBUG_INFO=0

# Shows usage information
usage() {
    output_error "${EXIT_PARAMETER_ERROR}" "Usage: ${0} --name \"repository_name\" [--create-trac-repository] [--create-git-repository] [--create-svn-repository] [--description \"Repository description\"]"
}

# Outputs an error message and terminates script execution
# Parameters:
# 1 - error code: this script's exit code will be set to this value
# 2 - error message
output_error() {
    ERROR_CODE="$1"
    ERROR_MESSAGE="$2"

    echo "${ERROR_MESSAGE}";
    exit "${ERROR_CODE}";
}

# Shows a message as an error message if the first argument is zero
# Expected parameters:
# 1: the value which will be checked
# 2: the exit code that this message should generate
# 3: the error message to be shown if value is zero
error_if_zero() {
  VALUE="$1";
  ERROR_CODE="$2"
  ERROR_MESSAGE="$3";

    if [[ "${VALUE}" == "0" ]]; then
        output_error "${ERROR_CODE}" "${ERROR_MESSAGE}";
    fi
}

# Shows a message as an error message if the first argument is not zero
# Expected parameters:
# 1: the value which will be checked
# 2: the exit code that this message should generate
# 3: the error message to be shown if value is not zero
error_if_not_zero() {
    VALUE="$1";
    ERROR_CODE="$2"
    ERROR_MESSAGE="$3";

    if [[ "${VALUE}" != "0" ]]; then
        output_error "${ERROR_CODE}" "${ERROR_MESSAGE}";
    fi
}

# Create a directory. In case of error, shows the error message
create_directory_or_error() {
    DIRECTORY="$1";

    MSG=$(mkdir "${DIRECTORY}" 2>&1);
    error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error creating directory at ${DIRECTORY}. Error: ${MSG}";
}

# Validates the parameters supplied by the client. Show an error message if they are not valid.
validate() {
    if [[ "${REPO_NAME}" == "" ]]; then
        output_error $EXIT_INVALID_DATA_ERROR "The name of the repository cannot be empty.";
    fi

    # Validates that the repositories do not exist yet
    if [[ "${CREATE_TRAC_REPO}" == "1" && -d "${TRAC_ROOT}/${REPO_NAME}" ]]; then
        output_error $EXIT_INVALID_DATA_ERROR "There is already a TRAC repository with the requested name. Please, choose another name.";
    fi
    if [[ "${CREATE_SVN_REPO}" == "1" && -d "${SVN_ROOT}/${REPO_NAME}" ]]; then
        output_error $EXIT_INVALID_DATA_ERROR "There is already a SVN repository with the requested name. Please, choose another name.";
    fi
    if [[ "${CREATE_GIT_REPO}" == "1" && -d "${GIT_ROOT}/${REPO_NAME}.git" ]]; then
        output_error $EXIT_INVALID_DATA_ERROR "There is already a GIT repository with the requested name. Please, choose another name.";
    fi
}

# Fixes the permisions on the filesystem. It ensures that all the processes have
# the necessary permissions to access/write to the correct files.
fix_permissions() {
    # Add RW permission for the group on trac.ini and trac.db
    if [[ "${CREATE_TRAC_REPO}" == "1" ]]; then
        MSG=$(chmod "g+rw" "${TRAC_ROOT}/${REPO_NAME}/conf/trac.ini" 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error fixing permissions of file trac.ini. Error: ${MSG}";
        MSG=$(chmod "g+rw" "${TRAC_ROOT}/${REPO_NAME}/db/trac.db" 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error fixing permissions of file trac.ini. Error: ${MSG}";
    fi
}

# Creates the repositories.
create_repositories() {
    # Create the directories for the repositories (do not initialise them yet)
    if [[ "${CREATE_TRAC_REPO}" == "1" ]]; then
        create_directory_or_error "${TRAC_ROOT}/${REPO_NAME}";
    fi
    if [[ "${CREATE_SVN_REPO}" == "1" ]]; then
        create_directory_or_error "${SVN_ROOT}/${REPO_NAME}";
    fi
    if [[ "${CREATE_GIT_REPO}" == "1" ]]; then
        create_directory_or_error "${GIT_ROOT}/${REPO_NAME}.git";
    fi

    # Initialise the repositories (first GIT and SVN repositories, as TRAC needs the SVN and/or GIT repositories to already
    # exist in order to link to them; after that, initialise the TRAC repository)
    if [[ "${CREATE_SVN_REPO}" == "1" ]]; then
        pushd "${SVN_ROOT}/${REPO_NAME}" > /dev/null;
        MSG=$(svnadmin create . 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error creating SVN repository directory at $(pwd). Error: ${MSG}";
        # Create the TTB folder structure
        TMP_CHECKOUT=$(mktemp -d);
        pushd "${TMP_CHECKOUT}" > /dev/null;
        MSG=$(svn checkout "file://${SVN_ROOT}/${REPO_NAME}" . 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error checking out the recently created SVN repository directory at $(pwd). Error: ${MSG}";
        MSG=$(svn mkdir trunk tags branches 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error creating the TTB folder structure on the recently created SVN repository. Error: ${MSG}";
        MSG=$(svn commit --username "root" --message "TTB directories." 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error committing the TTB folder structure on the recently created SVN repository. Error: ${MSG}";
        popd > /dev/null;
        rm -rf "${TMP_CHECKOUT}" > /dev/null;
        popd > /dev/null;
    fi

    if [[ "${CREATE_GIT_REPO}" == "1" ]]; then
        pushd "${GIT_ROOT}/${REPO_NAME}.git" > /dev/null;
        MSG=$(git init --quiet --bare . 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error creating GIT repository directory at $(pwd). Error: ${MSG}";
        # Enable the post-update hook, which updates the necessary files so that dumb HTTP clients are capable of accessing the repository.
        # Not in use now, but may be used in the future to easily give someone read only access to the repository.
        MSG=$(mv hooks/post-update.sample hooks/post-update 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error creating GIT repository directory at $(pwd). Error: ${MSG}";
        popd > /dev/null;
    fi

    if [[ "${CREATE_TRAC_REPO}" == "1" ]]; then
        TRAC_CMD="trac-admin"
        pushd "${TRAC_ROOT}/${REPO_NAME}" > /dev/null;
        MSG=$(${TRAC_CMD} . initenv "${REPO_NAME}" "sqlite:db/trac.db" --inherit="${TRAC_ROOT}/.shared/conf/trac.ini" 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error creating TRAC repository directory at $(pwd). Error: ${MSG}";
        if [[ "${REPO_DESCRIPTION}" != "" ]]; then
            MSG=$(${TRAC_CMD} . config set project descr "${REPO_DESCRIPTION}" 2>&1);
            error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error setting TRAC repository description. Error: ${MSG}";
        fi
        # Set trac internal permissions
        MSG=$(${TRAC_CMD} . permission remove anonymous "*" 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error removing permissions for user group \"anonymous\" inside trac env. Error: ${MSG}";
        MSG=$(${TRAC_CMD} . permission remove authenticated "*" 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error removing permissions for user group \"authenticated\" inside trac env. Error: ${MSG}";
        MSG=$(${TRAC_CMD} . permission add authenticated TRAC_ADMIN 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error adding permissions for user group \"authenticated\" inside trac env. Error: ${MSG}";
        # Remove unneeded wiki pages (this will take some time...)
        NUMBER_OF_CPUS=$(getconf _NPROCESSORS_ONLN);
        MSG=$(${TRAC_CMD} . wiki list | cut --delim=" " -f 1 | egrep -v "(^Wiki)|(^$)" | tail -n +3 | xargs -n 1 -P ${NUMBER_OF_CPUS} ${TRAC_CMD} . wiki remove 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error removing unneeded wiki pages from the trac environment. Error: ${MSG}";
        # Link SVN and/or GIT repositories to this TRAC instance
        SVN_INSTANCE_NAME=""
        GIT_INSTANCE_NAME=""
        # Only set a name if creating both SVN and GIT repositories
        if [[ "${CREATE_SVN_REPO}" == "1" && "${CREATE_GIT_REPO}" == "1" ]]; then
            SVN_INSTANCE_NAME="${REPO_NAME}"
            GIT_INSTANCE_NAME="${REPO_NAME}.git"
        fi
        if [[ "${CREATE_SVN_REPO}" == "1" ]]; then
            MSG=$(${TRAC_CMD} . repository add "${SVN_INSTANCE_NAME}" "${SVN_ROOT}/${REPO_NAME}" svn 2>&1);
            error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error linking TRAC instance to SVN repository. Error: ${MSG}";
        fi
        if [[ "${CREATE_GIT_REPO}" == "1" ]]; then
            MSG=$(${TRAC_CMD} . repository add "${GIT_INSTANCE_NAME}" "${GIT_ROOT}/${REPO_NAME}.git" git 2>&1);
            error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error linking TRAC instance to GIT repository. Error: ${MSG}";
        fi
        # Remove trac.ini.sample
        MSG=$(rm -rf "conf/trac.ini.sample" 2>&1);
        error_if_not_zero "$?" "${EXIT_PROCESS_ERROR}" "Error removing sample configuration file trac.ini.sample. Error: ${MSG}";
        popd > /dev/null;
    fi

    fix_permissions;
}

do_work() {
    validate;
    create_repositories;
}

# Parse commandline arguments
if [[ $# -eq 0 ]]; then
    usage;
fi

while [ "${1}" != "" ]; do
    case "${1}" in
        --create-trac-repository )
            CREATE_TRAC_REPO=1
            ;;
        --create-git-repository )
            CREATE_GIT_REPO=1
            ;;
        --create-svn-repository )
            CREATE_SVN_REPO=1
            ;;
        --name )
            shift;
            REPO_NAME="${1}";
            ;;
        --description )
            shift;
            REPO_DESCRIPTION="${1}";
            ;;
        --debug-info )
            DEBUG_INFO=1;
            ;;
        * )
            usage;
            ;;
    esac
    shift;
done

if [[ $DEBUG_INFO -eq 1 ]]; then
    cat << EOF
REPO_NAME="${REPO_NAME}"
REPO_DESCRIPTION="${REPO_DESCRIPTION}"
CREATE_TRAC_REPO="${CREATE_TRAC_REPO}"
CREATE_GIT_REPO="${CREATE_GIT_REPO}"
CREATE_SVN_REPO="${CREATE_SVN_REPO}"
EOF
fi

# Let the magic begin
do_work;
