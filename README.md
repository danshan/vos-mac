
# vos-mac

vos-mac is a macOS-focused fork of [open2jam](https://github.com/open2jamorg/open2jam), an open source emulator of [O2Jam](http://o2jam.wikia.com/wiki/O2Jam).

This fork keeps the original open2jam gameplay and file-format work, while updating the runtime so the application can build and run on current JDKs and Apple Silicon macOS.

Credits and upstream
--------------------

This project is derived from the original open2jam project:

* Upstream repository: <https://github.com/open2jamorg/open2jam>
* Original project: open2jam, an open source O2Jam emulator.
* License: Artistic License 2.0, preserved in [LICENSE](LICENSE).

Many thanks to the open2jam authors and contributors for the parser, gameplay, skinning, latency, local matching, and UI foundations that this fork builds on.

What changed in this fork
-------------------------

The main changes in vos-mac are runtime and platform support changes:

* Replaced the legacy Ant/NetBeans build with a Maven/JDK 17 build.
* Migrated rendering from LWJGL 2 Display APIs to LWJGL 3 OpenGL.
* Replaced the GLFW gameplay window with an AWT-hosted LWJGL 3 canvas for compatibility with the existing Swing UI on macOS.
* Fixed Retina/HiDPI rendering so the gameplay scene fills the window instead of rendering into the lower-left quadrant.
* Replaced FMOD Ex native audio with LWJGL 3 OpenAL plus STB Vorbis based decoding.
* Updated JNA from the bundled legacy x86-era jar to Maven-managed JNA 5.x.
* Added an executable shaded jar build with a proper `Main-Class` manifest.
* Added keyboard handling that supports current key mapping flows, including Space and semicolon.
* Removed the need for Rosetta or an x86_64 JDK on Apple Silicon.

Platform support
----------------

Current verified target:

* macOS arm64 on Apple Silicon.
* JDK 17.
* Maven build using LWJGL 3 macOS arm64 natives.

Expected but not currently verified:

* macOS x86_64 may work after changing the LWJGL native classifier in `pom.xml` from `natives-macos-arm64` to the x86_64 macOS classifier.
* Linux and Windows are not currently validated by this fork. The original open2jam project targeted multiple desktop platforms, but this fork's current build configuration and native dependency selection are macOS arm64 focused.

Known limitations:

* MP3 sample decoding is not implemented in the new OpenAL backend.
* BGA video still depends on the existing VLC/VLCJ path and has not been revalidated on every platform.
* The old bundled LWJGL 2 and FMOD native libraries are no longer the gameplay path for macOS arm64.

Current Features
----------------

* Supports OJN/OJM files, VOS files, and BMS files.
    * Partially supports BGA for BMS files. (Image backgrounds and movie files using VLC)
* Works on current JDKs with Maven-managed LWJGL 3 natives.
    * Verified for macOS arm64 with JDK 17.
* Music directory selection
    * You can put songs in multiple directories. open2jam keeps track of each of them separately.
* Adjustable KEY/BGM volume.
* Auto-play mode.
* Display and audio latency compensation. [Howto](https://github.com/open2jamorg/open2jam/blob/master/docs/autosync.md)
    * Related discussions:
        * [Audio Latency and Autosyncing](https://github.com/open2jamorg/open2jam/pull/20)
        * [Display lag and audio latency - Some information and problems](https://github.com/open2jamorg/open2jam/issues/8)
* Optional, configurable alternative judgment method: "Timed Judgment," which judges notes by milliseconds rather than beats.
* Local matching - play with friends (powered by [partytime](https://github.com/dtinth/partytime)). [Demo Video](http://www.youtube.com/watch?v=UaZu2jVOdS8)
* Speed type: Hi-Speed, xR-Speed, W-Speed, Regul-Speed


License
-------

All the code here is distributed under the terms of the Artistic License 2.0.  
For more details, see the full text of the license in the file LICENSE.


Running from source
-------------------

You need JDK 17 or later and Maven.

Build the project with:

```
mvn -s .mvn/settings.xml -DskipTests package
```

Run the packaged jar on macOS with:

```
java -jar target/open2jam-0.1.0-SNAPSHOT.jar
```

Do not use `-XstartOnFirstThread` with this fork. The gameplay window is hosted through AWT/Swing rather than GLFW.

Run from source with:

```
mvn -s .mvn/settings.xml exec:exec
```
