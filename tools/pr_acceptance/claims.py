"""Exact reviewed scope/claim/inspect logic copied from f374e9c workflow."""
import json
import re

def scope(value):
    if not isinstance(value, str) or not value:
        raise ValueError("Invalid path scope")
    directory = value.endswith("/**")
    base = value[:-3] if directory else value
    if not re.fullmatch(r"[A-Za-z0-9_. /-]+", base):
        raise ValueError("Use an exact path or directory/**")
    if any(part in ("", ".", "..") for part in base.split("/")):
        raise ValueError("Use a normalized repository path")
    return base, directory


def overlaps(left, right):
    a, ad = scope(left)
    b, bd = scope(right)
    return a == b or (ad and b.startswith(a + "/")) or (bd and a.startswith(b + "/"))


def covers(claim, filename):
    base, directory = scope(claim)
    return filename.startswith(base + "/") if directory else filename == base


def claim(pr):
    matches = re.findall(r"<!--\s*work-claim\s+(.*?)\s*-->", pr.get("body") or "", re.S)
    if len(matches) != 1:
        raise ValueError("Keep exactly one work-claim JSON line in the PR body")
    data = json.loads(matches[0])
    if not isinstance(data, dict):
        raise ValueError("Claim must be an object")
    if not isinstance(data.get("owner"), str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]{0,38}", data["owner"]):
        raise ValueError("Set one GitHub owner")
    if data["owner"] == "YOUR_LOGIN":
        raise ValueError("Replace the owner placeholder")
    if not isinstance(data.get("task"), str) or not data["task"].strip() or data["task"] == "REPLACE":
        raise ValueError("Set the task")
    paths = data.get("paths")
    if not isinstance(paths, list) or not paths:
        raise ValueError("Set one or more file scopes")
    for item in paths:
        scope(item)
        if "REPLACE" in item:
            raise ValueError("Replace the path placeholder")
    return data


def inspect(prs, details, files):
    errors = []
    claims = {}
    for pr in prs:
        number = pr["number"]
        try:
            data = claim(pr)
            claims[number] = data
            detail = details(number)
            changed = files(number)
            if detail["changed_files"] != len(changed):
                raise ValueError("Incomplete changed-file inventory; split this PR")
            for item in changed:
                for name in {item["filename"], item.get("previous_filename", item["filename"])}:
                    if not any(covers(path, name) for path in data["paths"]):
                        errors.append(f"PR #{number}: changed file outside declared scope: {name}")
        except (ValueError, TypeError, KeyError) as error:
            errors.append(f"PR #{number}: {error}")
    numbers = sorted(claims)
    for index, left in enumerate(numbers):
        for right in numbers[index + 1:]:
            for a in claims[left]["paths"]:
                for b in claims[right]["paths"]:
                    if overlaps(a, b):
                        errors.append(f"PR #{left} and PR #{right}: overlapping scopes {a} / {b}")
    return claims, errors


