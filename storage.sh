#!/bin/bash

function gpt () {
    file=$(echo $device | sed -s 's/\/dev\///g')
    part_count=$(printf "$(ls /dev/ | sed -n -e "s/^$file\(.*\)/\1/p")" | wc -l)
    part_avail=$(expr 128 - $part_count)
    total_space=$(parted $device unit MB print free | grep 'Free Space' | tail -n1 | awk '{print $2}' | tr -d "MB")
    space_left=$(parted $device unit MB print free | grep 'Free Space' | tail -n1 | awk '{print $3}' | tr -d "MB")

    if [ $part_count -gt 0 ]; then
            start=$(parted $device unit MB print | tail -n 2 | awk '{printf $3}' | tr -d "MB")
    else
            start="1"
    fi

    echo -e "\nPartition type: GPT\nSize left on the device: ${space_left}MB\nThere are already $part_count partitions\nYou can create $part_avail partitions.\n"
    echo -e "Choose partition size (in MB, MAX: $space_left):"
    read size
    end=$(expr $start + $size)
    [ $end -gt $total_space ] && { echo -e "Not enough space left on the device!" && exit 1; }
    parted "$device" -s mkpart -a optimal primary "${start}MiB" "${end}MiB"
    if [ $? -gt 0 ]; then
        echo -e "\nCannot create partition!"
        exit 1
    else
        new_part=$(fdisk -l $device | tail -n 1 | awk '{printf $1}')
        echo -e "\nPartition $new_part created correctly!"
    fi

    filesystem $new_part

}

function filesystem () {

        filesystems=("xfs" "ext2" "ext3" "ext4" "fat" "vfat")
        echo -e "\nDo you want to create filesystem on the new partition? (y/n)"
        read resp

        if [ "$resp" = "y" ]; then
                echo -e "Select the filesystem\n"

                for fs in "${!filesystems[@]}"
                do
                        echo -e "${fs}) \e[32m${filesystems[$fs]}\033[0m\n"
                done
        else
                echo -e "Bye!"
                exit 0
        fi

        read fs

        if [ ! -v "filesystems[$fs]" ]; then
                echo -e "\nFilesystem $filesystems[$fs] is not available!"
                exit 1
        else
                fs_disk=${filesystems[$fs]}
        fi

        mkfs.${fs_disk} $new_part

}       


disks=()
echo -e "\nAvailable disk to create new partition:\n"
while read -r device; do
    disk_id=$(echo "$device" | awk '{printf $1}')
    disk_size=$(echo "$device" | awk '{printf $2}')
    disk_partlabel=$(blkid "$disk_id" | egrep -io '(dos|gpt)')
    if [ ! -z "$disk_partlabel" ]; then
        disks+=($disk_id)
    fi

done < <(lsblk -dplno NAME,SIZE,TYPE);

for avail_disk in "${!disks[@]}"
do
        echo -e "${avail_disk}) \e[32m${disks[$avail_disk]}\033[0m\n"
done

echo -e "Now choose the disk using the number:\n"

read disk_index

if [ ! -v "disks[$disk_index]" ]; then
        echo -e "\nDisk $disks[$disk_index] is not available for partitioning!"
        exit 1
else
        device=${disks[$disk_index]}
fi

case "$(blkid $device | egrep -io '(gpt|dos)' | tr [:upper:] [:lower:])" in

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
