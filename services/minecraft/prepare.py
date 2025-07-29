#!/bin/python3

from os import listdir
from os.path import isdir
from zipfile import ZipFile

def pack_datapack(datapack: str):
    with ZipFile(f"{datapack}.zip", "w") as zip:
        zip.write(f"{datapack}/pack.mcmeta", "pack.mcmeta")
        zip.write(f"{datapack}/data", "data")


def main():
    for datapack in listdir("datapacks"):
        if isdir(f"datapacks/{datapack}"):
            print(f"Zipping {datapack}")
            pack_datapack(f"datapacks/{datapack}")

if __name__ == "__main__":
    main()
