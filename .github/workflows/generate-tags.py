#!/usr/bin/env python3

import argparse
from datetime import datetime


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image-name", dest="image_name", required=True)
    parser.add_argument("--nginx-version", dest="version", required=True)
    parser.add_argument("--env-name", dest="env_name", required=True)
    args = parser.parse_args()

    tags = ["latest", args.version, datetime.today().strftime("%Y%m%d")]

    final_tags = [f"{args.image_name}:{tag}" for tag in tags]
    print("{}={}".format(args.env_name, ",".join(final_tags)))


if __name__ == "__main__":
    main()
