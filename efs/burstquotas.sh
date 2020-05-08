#!/bin/bash
###############################################################################
#                                                                             #
# Script creado por Manrique García                                           #
# Fecha: 07-05-2020                                                           #
# Version: 0.1                                                                #
#                                                                             #
# Descripción: este script es para listar los EFS de una cuenta de AWS        #
#              y mostrar los créditos disponibles                             #
#                                                                             #
# Requerimientos: Necesita AWS CLI y una cuenta de acceso programatico        #
###############################################################################

#Cabecera para el archivo csv
echo "ID, NOMBRE, TIPO, CREDITOS(GB), ESTADO" > listfs.csv

#Declaracion de variables

#Variable de contador
i=0

#Esta variable mirará el número de filesystems que hay activos
longitud=$(aws efs describe-file-systems | jq '.FileSystems[] |length'|wc -l)

#Mientras que no lleguemos al número de elmentos obtenemos la informacion de nombre, id y tipo de Throughput
while [ $i -lt $longitud ]
do
	declare -A filesystem=$(aws efs describe-file-systems |jq -r '.FileSystems['$i'] | .Name + "," + .FileSystemId + "," + .ThroughputMode')
	filesystemname=$(echo $filesystem | cut -d"," -f1 )
	filesystemid=$(echo $filesystem | cut -d"," -f2)
	throughmode=$(echo $filesystem | cut -d"," -f3)
	i=$(($i+1))

#Llamamos a Cloud Watch para mirar la métrica, ponemos un periodo de una hora para que nos de un solo dato, más fácil de manejar

        bursting=$(aws cloudwatch get-metric-statistics --metric-name BurstCreditBalance --start-time 2020-05-07T11:00:00 --end-time 2020-05-07T12:00:00 --period 3600 --namespace AWS/EFS --statistics Average --dimensions Name=FileSystemId,Value=$filesystemid  |jq '.Datapoints[] | .Average' )
	burstingK=$( echo $bursting/1024 | bc )
	burstingM=$(echo $burstingK/1024 | bc )
        burstingG=$(echo $burstingM/1024 | bc )

#Establecemos los parámetro de Warning y Critical
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

#Finalmente convertivos el csv de salida a hoja de cálculo
unoconv -f odt listfs.csv
