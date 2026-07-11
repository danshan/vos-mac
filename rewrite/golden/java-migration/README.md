# Java Migration Golden Corpus

Normal tests treat this directory as read-only. Regenerate it only from the pinned Java source and toolchain with:

```bash
mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" test-compile org.codehaus.mojo:exec-maven-plugin:3.5.0:exec -Dexec.args="--add-exports java.desktop/com.sun.media.sound=ALL-UNNAMED -classpath target/test-classes:lib/*:%classpath org.open2jam.export.MigrationGoldenCorpusGenerator --output rewrite/golden/java-migration --work-root /tmp/open2jam-java-golden-v1"'
```

Do not regenerate this corpus after the Java implementation is deleted. It is immutable migration provenance.
