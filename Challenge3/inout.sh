#!/bin/bash

file=$(cat test.json)

for line in $file
do
    echo -e "$line"
    value=`echo $line | head -1 | awk -F '”:{“' '{print $3}' | awk -F ':' '{print $2}' | cut -c2`
    echo "Value : $value"
done
