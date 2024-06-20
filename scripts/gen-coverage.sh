forge coverage --report lcov
lcov --rc lcov_branch_coverage=1 --remove lcov.info 'test/*' -o forge-pruned-lcov.info
genhtml ./forge-pruned-lcov.info -o report --rc lcov_branch_coverage=1