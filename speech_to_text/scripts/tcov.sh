# Ensure test errors fail the script
set -e
flutter test --coverage
coverPct=$(genhtml coverage/lcov.info -o coverage | tail -n 2 | head -n 1 | cut -d ' ' -f 4 | sed 's/%//')
scc lib | sed -n '4p' | tr -s ' ' | cut  -d ' ' -f 2-7 | sed "s/^/$coverPct,/" | sed 's/ /,/g' | sed "s/^/`date '+%Y\/%m\/%d %H:%M:%S'`,/" >> codestats.csv