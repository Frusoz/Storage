#!/bin/bash

function gpt () {
    file=$(echo $disk_name | sed -s 's/\/dev\///g')
    part_count=$(ls -l /dev/${file}* | wc -l)
    part_avail=$(expr 128 - $(( $part_count-1 )))
    space_left=$(parted $disk_name unit MB print free | grep 'Free Space' | tail -n1 | awk '{print $3}' | tr -d "MB")

    if [ $part_count -gt 1 ]; then
            start=$(parted $disk_name unit MB print | tail -n 2 | awk '{printf $3}' | tr -d "MB")
    else
            start="1"
    fi

    echo -e "\nPartition type: GPT\nSize left on the device: ${space_left}MB\nThere are already $(( $part_count-1 )) partitions\nYou can create $part_avail partitions.\n"
    echo -e "Choose partition size (in MB, MAX: $space_left):"
    read size
    end=$(expr $start + $size)
    [ $end -gt $space_left ] && { echo -e "Not enough space left on the device!" && exit 1; }
    parted "$disk_name" -s mkpart -a optimal primary "${start}MB" "${end}MB"

}

declare -A disks
echo -e "\nAvailable disk to create new partition:\n"
while read -r device; do
    disk_id=$(echo "$device" | awk '{printf $1}')
    disk_size=$(echo "$device" | awk '{printf $2}')
    disk_partlabel=$(blkid "$disk_id" | egrep -io '(dos|gpt)')
    if [ ! -z "$disk_partlabel" ]; then
        disks[$disk_id]=$disk_partlabel
        echo -e "\e[32mDisk: $disk_id ; Size: $disk_size ; Type: $disk_partlabel\033[0m\n"
    fi

done < <(lsblk -dplno NAME,SIZE,TYPE | grep -v 'disk');

echo -e "\nSelect disk to partition:"

read disk_name


if [ ! -v "disks[$disk_name]" ]; then
        echo -e "\nDisk $disk_name is not available for partitioning!"
        exit 1
fi

case "$(echo "${disks[$disk_name]}" | tr [:upper:] [:lower:])" in

        "gpt")
                gpt
                ;;

        "dos")
                echo "dos!"
                ;;

        *)
                echo "Cannot regognize PTTYPE!"
                ;;

esac
