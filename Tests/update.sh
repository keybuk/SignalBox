#!/bin/sh -e
[ -d Tests/ ]

rm -f Tests/LinuxMain.swift Tests/*/XCTestManifests.swift
swift test --generate-linuxmain
