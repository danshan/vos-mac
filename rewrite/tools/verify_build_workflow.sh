#!/usr/bin/env bash
set -euo pipefail

WORKFLOW_PATH="${1:-.github/workflows/build.yml}"

if [[ ! -f "$WORKFLOW_PATH" ]]; then
	printf 'Missing build workflow: %s\n' "$WORKFLOW_PATH" >&2
	exit 1
fi

step_name=""
step_uses=""
step_run=""
step_if=""
step_continue=""
step_body=""
step_body_line_count=0
step_index=0
runtime_count=0
runtime_index=0
golden_count=0
golden_index=0
build_count=0
build_index=0
package_count=0
package_index=0
inside_maven=false
inside_steps=false
maven_job_count=0
job_if=""
job_unexpected=""

reject_conditionals() {
	local name="$1"
	local condition="$2"
	local continue_on_error="$3"
	if [[ -n "$condition" ]]; then
		printf 'Required workflow step must be unconditional: %s\n' "$name" >&2
		exit 1
	fi
	if [[ -n "$continue_on_error" ]]; then
		printf 'Required workflow step cannot set continue-on-error: %s\n' "$name" >&2
		exit 1
	fi
}

require_exact_step_body() {
	local name="$1"
	local expected_line="$2"
	if [[ "$step_body_line_count" -ne 1 || "$step_body" != "$expected_line" ]]; then
		printf 'Required workflow step contains unexpected configuration: %s\n' \
			"$name" >&2
		exit 1
	fi
}

finish_step() {
	if [[ -z "$step_name" ]]; then
		return
	fi
	step_index=$((step_index + 1))
	case "$step_name" in
		"Install project runtime")
			runtime_count=$((runtime_count + 1))
			runtime_index="$step_index"
			reject_conditionals "$step_name" "$step_if" "$step_continue"
			require_exact_step_body "$step_name" \
				'        uses: jdx/mise-action@v4'
			if [[ "$step_uses" != "jdx/mise-action@v4" || -n "$step_run" ]]; then
				printf 'Project runtime step is not wired to jdx/mise-action@v4.\n' >&2
				exit 1
			fi
			;;
		"Verify migration goldens")
			golden_count=$((golden_count + 1))
			golden_index="$step_index"
			reject_conditionals "$step_name" "$step_if" "$step_continue"
			require_exact_step_body "$step_name" \
				'        run: mise run verify-goldens'
			if [[ "$step_run" != "mise run verify-goldens" || -n "$step_uses" ]]; then
				printf 'Build workflow does not run the golden verifier.\n' >&2
				exit 1
			fi
			;;
		"Build and test")
			build_count=$((build_count + 1))
			build_index="$step_index"
			reject_conditionals "$step_name" "$step_if" "$step_continue"
			require_exact_step_body "$step_name" \
				'        run: mise exec -- bash -lc '\''mvn --batch-mode -s "$MAVEN_SETTINGS" clean verify'\'''
			if [[ "$step_run" != "mise exec -- bash -lc 'mvn --batch-mode -s \"\$MAVEN_SETTINGS\" clean verify'" || -n "$step_uses" ]]; then
				printf 'Build workflow does not run clean Maven verification through mise.\n' >&2
				exit 1
			fi
			;;
		"Verify packaged migration resources")
			package_count=$((package_count + 1))
			package_index="$step_index"
			reject_conditionals "$step_name" "$step_if" "$step_continue"
			require_exact_step_body "$step_name" \
				'        run: bash rewrite/tools/verify_java_migration_package.sh'
			if [[ "$step_run" != "bash rewrite/tools/verify_java_migration_package.sh" \
				|| -n "$step_uses" ]]; then
				printf 'Build workflow does not verify the final packaged JAR.\n' >&2
				exit 1
			fi
			;;
	esac
	step_name=""
	step_uses=""
	step_run=""
	step_if=""
	step_continue=""
	step_body=""
	step_body_line_count=0
}

while IFS= read -r line || [[ -n "$line" ]]; do
	if [[ "$line" == "  maven:" ]]; then
		finish_step
		inside_maven=true
		inside_steps=false
		maven_job_count=$((maven_job_count + 1))
		continue
	fi
	if [[ "$inside_maven" == true && "$line" == "  "*":" \
		&& "$line" != "   "* && "$line" != "  maven:" ]]; then
		finish_step
		inside_maven=false
		inside_steps=false
		continue
	fi
	if [[ "$inside_maven" != true ]]; then
		continue
	fi
	if [[ "$line" == "    if: "* ]]; then
		job_if="${line#    if: }"
		continue
	fi
	if [[ "$line" == "    "* && "$line" != "     "* \
		&& "$line" != "    name: Maven build" \
		&& "$line" != "    runs-on: macos-latest" \
		&& "$line" != "    steps:" ]]; then
		job_unexpected="$line"
	fi
	if [[ "$line" == "    steps:" ]]; then
		inside_steps=true
		continue
	fi
	if [[ "$inside_steps" != true ]]; then
		continue
	fi
	if [[ "$line" == "      - name: "* ]]; then
		finish_step
		step_name="${line#      - name: }"
		continue
	fi
	if [[ "$line" == "      - "* ]]; then
		finish_step
		continue
	fi
	if [[ -z "$step_name" ]]; then
		continue
	fi
	if [[ -n "$line" && "$line" == "        "* ]]; then
		step_body_line_count=$((step_body_line_count + 1))
		if [[ -z "$step_body" ]]; then
			step_body="$line"
		else
			step_body="$step_body"$'\n'"$line"
		fi
	fi
	case "$line" in
		"        uses: "*) step_uses="${line#        uses: }" ;;
		"        run: "*) step_run="${line#        run: }" ;;
		"        if: "*) step_if="${line#        if: }" ;;
		"        continue-on-error: "*)
			step_continue="${line#        continue-on-error: }"
			;;
	esac
done <"$WORKFLOW_PATH"

finish_step

if [[ "$maven_job_count" -ne 1 ]]; then
	printf 'Build workflow must contain exactly one maven job.\n' >&2
	exit 1
fi
if [[ -n "$job_if" ]]; then
	printf 'Maven build job must be unconditional.\n' >&2
	exit 1
fi
if [[ -n "$job_unexpected" ]]; then
	printf 'Maven build job contains unexpected configuration: %s\n' \
		"$job_unexpected" >&2
	exit 1
fi

for required_name in \
	"Install project runtime" \
	"Verify migration goldens" \
	"Build and test" \
	"Verify packaged migration resources"; do
	name_occurrences="$(awk -v needle="$required_name" \
		'index($0, needle) { count++ } END { print count + 0 }' "$WORKFLOW_PATH")"
	if [[ "$name_occurrences" -ne 1 ]]; then
		printf 'Build workflow required step name is missing or duplicated: %s\n' \
			"$required_name" >&2
		exit 1
	fi
done
if [[ "$runtime_count" -ne 1 || "$golden_count" -ne 1 || "$build_count" -ne 1 \
	|| "$package_count" -ne 1 ]]; then
	printf 'Build workflow is missing or duplicates a required enabled step.\n' >&2
	exit 1
fi
if (( runtime_index >= golden_index || golden_index >= build_index \
	|| build_index >= package_index )); then
	printf 'Build workflow steps must run runtime, goldens, clean build, then package verification in order.\n' >&2
	exit 1
fi

if forbidden="$(grep -En \
	'^[[:space:]]*(uses:[[:space:]]+actions/setup-java|run:[[:space:]]+mvn[[:space:]])' \
	"$WORKFLOW_PATH" 2>&1)"; then
	printf 'Build workflow bypasses the project mise runtime:\n%s\n' "$forbidden" >&2
	exit 1
else
	grep_status=$?
	if [[ "$grep_status" -ne 1 ]]; then
		printf 'Unable to inspect build workflow:\n%s\n' "$forbidden" >&2
		exit 1
	fi
fi

printf 'Build workflow contract passed.\n'
