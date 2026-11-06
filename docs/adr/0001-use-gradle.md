# ADR 0001: Use Gradle as the build tool

- Status: Accepted
- Date: 2026-11-06

## Decision
Build with Gradle (Groovy DSL) using the Gradle wrapper.

## Why
- The project brief names Gradle.
- The wrapper pins the Gradle version, so Jenkins and laptops build the same way.
- `build.gradle` sets a fixed jar name (`shopease.jar`) and the version from Jenkins' `BUILD_NUMBER`.

## Rejected
- Maven: equally valid, but not what the brief asks for.
