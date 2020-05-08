#!/bin/bash

#aws efs describe-file-systems|jq '.FileSystems[] | .Name, .FileSystemId, .ThroughputMode'
filesystems=$(aws efs describe-file-systems|jq '.FileSystems[] | .Name')


echo "ID, NOMBRE, TIPO, CREDITOS(GB), ESTADO" > listfs.csv


for i  in $filesystems; do

	filesystemname=$(echo $i |sed 's/\"//g')
	filesystemid=$(echo "aws efs describe-file-systems|jq '.FileSystems[] | select (.Name | contains($i)) | .FileSystemId'" |sh )
	filesystemid=$(echo $filesystemid | sed 's/\"//g')
	throughmode=$(echo "aws efs describe-file-systems|jq '.FileSystems[] | select (.Name | contains ($i)) | .ThroughputMode'" | sh)
	throughmode=$(echo $throughmode |sed 's/\"//g')

        bursting=$(aws cloudwatch get-metric-statistics --metric-name BurstCreditBalance --start-time 2020-05-07T11:00:00 --end-time 2020-05-07T12:00:00 --period 3600 --namespace AWS/EFS --statistics Average --dimensions Name=FileSystemId,Value=$filesystemid  |jq '.Datapoints[] | .Average' )
	burstingK=$( echo $bursting/1024 | bc )
	burstingM=$(echo $burstingK/1024 | bc )
        burstingG=$(echo $burstingM/1024 | bc )

	warning=160
	critical=80
	
	if [[ $burstingG -lt $critical ]]
	then
		alarm="CRITICAL"
	else
		if [[ $burstingG -lt $warning ]] 
	 	then
			alarm="WARNING"
		else
			alarm="OK"
		fi
	fi
	

	echo $filesystemid, $filesystemname, $throughmode, $burstingG, $alarm >> listfs.csv
done

unoconv -f odt listfs.csv
