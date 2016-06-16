# CTest

## what this is

This is a testing utility for you chocolatey package.

When you run `ctest`, you need to give it a path.
Then ctest script will index all the file in that folder recursively.

Then it will match all the `*.nuspec` file and do `choco pack` on the `*.nuspec` file respectively.

Then try to install and uninstall all the packed chocolatey package.
