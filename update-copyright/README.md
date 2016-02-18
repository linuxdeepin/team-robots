**Description**: A simple tool to add or update copyright information in
source files.

It support python/bash/perl/golang/c/cpp now, enjoy!

## Dependencies

- bash
- awk
- sed

## Usage

Show all the source files that missing copyright information under git
repository and will exit with error code 1 if the list is not empty
```sh
update-copyright
```

Add the missing copyright for source files automatically
```sh
update-copyright -a
```

Update the copyright with special year
```sh
update-copyright -u -y 2013
update-copyright -u -y 2013 test.c test.go test.py
```
