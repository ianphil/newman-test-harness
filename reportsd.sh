#!/bin/bash

reportshtml=/var/www/html/reports.html

generateReports() {
  DATE=`date '+%Y-%m-%d %H:%M:%S'`
  html="<h1>Reports (as of $DATE)</h1><ul>"

  echo "Generating reports..."
  for collectionfile in /mnt/data/collections/*.json; do
    collection=$(basename $collectionfile .json)

    for envfile in /mnt/data/environments/*.json; do
      env=$(basename $envfile .json)
      report=report-$collection-$env

      echo "Creating $report.html..."
      newman run $collectionfile \
        -n 10 \
        -e $envfile \
        -r html \
        --timeout-request 10000 \
        --reporter-html-export /var/www/html/$report.html
      chmod 644 /var/www/html/$report.html
      echo "$report.html successfully generated!"
      html="$html<li><a href=\"/$report.html\">$report.html</a></li>"
    done
  done

  rm $reportshtml
  html="$html</ul>"
  echo $html >> $reportshtml
}

watchFiles() {
    chsumprev=""

    while [ true ]
    do
        chsumnext=`find /mnt/data/ -type f -exec md5sum {} \;`
        if [ "$chsumprev" != "$chsumnext" ] ; then
            generateReports
            chsumprev=$chsumnext
        fi
        sleep 2
    done
}

echo "Watching files for changes..."
watchFiles
