vos-mac macOS arm64 migration
=============================

This fork is derived from the original open2jam project at https://github.com/open2jamorg/open2jam.

The migration focuses on making the application build and run on current macOS arm64 systems:

* Replaced the Ant/NetBeans build with a Maven/JDK 17 build.
* Migrated the rendering backend from LWJGL 2 Display APIs to LWJGL 3 OpenGL.
* Hosted the gameplay OpenGL context in an AWT canvas so it can coexist with the existing Swing UI on macOS.
* Fixed Retina/HiDPI viewport sizing for gameplay rendering.
* Replaced FMOD Ex native audio with LWJGL 3 OpenAL and STB Vorbis.
* Replaced the legacy bundled JNA jar with Maven-managed JNA 5.x.
* Added an executable shaded jar manifest.
* Updated keyboard capture and mapping support for current JDKs.

Current verified platform support:

* macOS arm64.
* JDK 17.

Other platforms are not currently validated by this fork.

Alpha 7
=======

After more than a year, this release brings in a lot of new features:

* Sound system changed from OpenAL to FMOD Ex. There should be less audio issue in this release.
* Better support for BMS, OJM and OJN, and SM file formats.
* Partial support for background animations in BMS files.
* [Audio and display latency settings and syncing.](autosync.md)
* More accurate calculation of health points, based on the selected difficulty.
* Regul-Speed modifier.
* Local matching — play open2jam with your friends.
* BMS exporter.
* Lot of bug fixes.

Regul-Speed
-----------
This speed modifier is borrowed from beatmaniaIIDX and makes the notes scroll at 150BPM * speed multiplier,
regardless of actual BPM changes present in the chart. This is equivalent to the C-mod in StepMania.

BMS Exporter
------------
You can convert any playable files to BMS, by right-clicking at the song you want to export in the selection list,
and choose __Convert to BMS.__

The song file, along with keysounds and background music will be exported with the converted BMS file.

The converted files will appear in the "converted" directory inside your open2jam folder.
