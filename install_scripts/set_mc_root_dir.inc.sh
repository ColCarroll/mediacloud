#
# Sets MC_ROOT_DIR (independently from the current path)
#

PWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CANDIDATE_MC_ROOT_DIR="$PWD/../"
if [ ! -f "$CANDIDATE_MC_ROOT_DIR/install.sh" ]; then
	echo "Unable to determine Media Cloud root directory; tried $CANDIDATE_MC_ROOT_DIR"
	exit 1
fi

MC_ROOT_DIR="$CANDIDATE_MC_ROOT_DIR"
