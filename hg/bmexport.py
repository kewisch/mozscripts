#!/usr/bin/env python
import argparse
import re
import os
import subprocess


def long_substr(data):
    def substrs(x):
        return {x[i:i+j] for i in range(len(x)) for j in range(len(x) - i + 1)}

    s = substrs(data[0])
    for val in data[1:]:
        s.intersection_update(substrs(val))
    return max(s, key=len)


def slugify(data):
    data = re.sub(r'[ar]=.*$', '', data).strip(" .")
    data = re.sub(r'[^\w\s-]', '', data).strip().lower()
    data = re.sub(r'[-\s]+', '-', data)
    return data


def bug(data):
    found = re.search(r'bug-\d+', data)
    return found.group(0) if found else ''


def tofilenames(data):
    msgs = [[cset, message, slugify(message)] for cset, message in data]
    commonpart = None
    if len(data) > 1:
        commonpart = long_substr([message for _, _, message in msgs])
        commonpart = commonpart.replace(bug(commonpart) + "-", '')
        if len(commonpart) < 15:
            commonpart = None

    outdata = []
    for idx, [cset, message, slug] in enumerate(msgs):
        filename = ""
        if len(data) > 1:
            filename += str(idx+1).rjust(2, '0') + "-"

        if commonpart:
            filename += slug.replace(commonpart, "")
        else:
            filename += slug

        filename += ".diff"

        outdata.append([cset, message, filename])

    return outdata


def execute(hg, rev, outpath):
    output = subprocess.check_output([
        hg, "log", "-r", rev, "--template", "{node} {desc|firstline}\\n"
    ]).strip()
    data = [line.split(" ", 1) for line in output.split("\n")]
    data = tofilenames(data)
    outpath = os.path.expanduser(outpath)
    maxlen = max([len(filename) for _, _, filename in data]) + len(outpath) + 1

    for cset, message, filename in data:
        path = os.path.join(outpath, filename)
        subprocess.call([hg, "export", "-r", cset, "-o", path])
        print path.ljust(maxlen), "<-", message


parser = argparse.ArgumentParser()
parser.add_argument("-r", "--rev", dest='argrev',
                    help="Revisions to export")
parser.add_argument("--hg", default="hg",
                    help="Path to mercurial")
parser.add_argument("-o", "--output", default="~/Desktop/",
                    help="Output directory")
parser.add_argument("rev", nargs="?", help="Output directory")
args = parser.parse_args()

rev = args.argrev or args.rev or "."

execute(hg=args.hg, rev=rev, outpath=args.output)
