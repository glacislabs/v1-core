LINE_COVERAGE=$1
FUNCTION_COVERAGE=$2
BRANCH_COVERAGE=$3

genhtml --branch-coverage lcov.info -output lcov.html | grep "\.:" > lcov.txt

sed -i 's/\.*:\ /=/g' lcov.txt
sed -i 's/\..*//g' lcov.txt

. lcov.txt
echo "Checking PR coverage "`date`
echo
echo "Requested coverage"
echo "------------------"
echo "Line coverage: $LINE_COVERAGE%"
echo "Function coverage: $FUNCTION_COVERAGE%"
echo "Branch coverage: $BRANCH_COVERAGE%"
echo
echo "Current coverage"
echo "------------------"
echo "Line coverage: $lines%"
echo "Function coverage: $functions%"
echo "Branch coverage: $branches%"
echo
echo "Coverage report"
echo "------------------"

if [ $lines -lt $LINE_COVERAGE ] ; then
    echo "Line test coverage is below $LINE_COVERAGE% - PR Coverage check failed"
    exit 1
fi

if [ $functions -lt $FUNCTION_COVERAGE ] ; then
    echo "Function test coverage is below $FUNCTION_COVERAGE% - PR Coverage check failed"
    exit 1
fi

if [ $branches -lt $BRANCH_COVERAGE ]; then
    echo "Branch test coverage is below $BRANCH_COVERAGE% - PR Coverage check failed"
    exit 1
fi

echo "PR Coverage check passed"