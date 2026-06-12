
open2jam
========
open source emulator of [O2Jam](http://o2jam.wikia.com/wiki/O2Jam).

It is written in Java with LWJGL 3/OpenGL for rendering and LWJGL 3 OpenAL/STB for audio, with the objective of being able to play on current JDKs and macOS arm64.

We don't have an official roadmap, but we aim to:

*   Have it working on major platforms (Windows, Linux, Mac OS X).
*   Being able to play any OJN/OJM and BMS files.
*   Skinnable game interface
*   Multiplayer similar to o2jam.

Current Features
----------------

* Supports OJN/OJM files and BMS files.
    * Partially supports BGA for BMS files. (Image backgrounds and movie files using VLC)
* Works on current JDKs with Maven-managed LWJGL 3 natives.
    * Migrated for macOS arm64 with JDK 17.
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

Run from source with:

```
mvn -s .mvn/settings.xml exec:exec
```
