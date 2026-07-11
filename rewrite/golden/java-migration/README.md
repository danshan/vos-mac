# Java Migration Golden Corpus

This corpus preserves Java behavior from source commit `05257da` plus determinism overlay `62ece7083ea473f02ecc9a83ee7d3e151905bf0e`, which pins Liberation Sans font bytes and provenance.

Normal tests treat this directory as read-only. Regenerate it only from the pinned Java source and toolchain with:

```bash
mise exec -- bash -lc 'mvn -s "$MAVEN_SETTINGS" test-compile org.codehaus.mojo:exec-maven-plugin:3.5.0:exec -Dexec.args="--add-exports java.desktop/com.sun.media.sound=ALL-UNNAMED -classpath target/test-classes:lib/*:%classpath org.open2jam.export.MigrationGoldenCorpusGenerator --output rewrite/golden/java-migration --work-root /tmp/open2jam-java-golden-v1"'
```

On macOS, the CLI spelling `/tmp/open2jam-java-golden-v1` resolves canonically to `/private/tmp/open2jam-java-golden-v1`; the manifest and normalized expected JSON pin the canonical spelling.

Do not regenerate this corpus after the Java implementation is deleted. It is immutable migration provenance.
