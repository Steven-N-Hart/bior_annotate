# Pass in the path to tool_info.txt file as first arg
tool_info=$1
# then shift it off so we can pass the other args to the merge.groovy cmd
shift

source "$tool_info"
BIOR_LITE_HOME=`dirname $BIOR`

CLASSPATH=$BIOR_LITE_HOME/lib/htsjdk*.jar

echo "tool_info: $tool_info"
echo "BIOR_LITE_HOME:  $BIOR_LITE_HOME"
echo "BIOR_ANNOTATE_DIR: $BIOR_ANNOTATE_DIR"

$GROOVY_HOME/bin/groovy -cp $CLASSPATH $BIOR_ANNOTATE_DIR/scripts/merge.groovy $*

