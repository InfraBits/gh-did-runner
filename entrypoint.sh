#!/usr/bin/env bash
set -eo pipefail

# Start the docker daemon (as root)
if [ "$(id -un)" == "root" ];
then
  dockerd &
fi

# Re-execute the script to launch the worker as the github-runner user
if [ "$(id -un)" != "github-runner" ];
then
  exec /usr/bin/sudo --preserve-env=GITHUB_TOKEN,GITHUB_ORG,RUNNER_NAME -u github-runner $0
fi

# Move to the runtime directory
cd /home/github-runner

# Use a random runner name if one is not provided
if [ -z "${RUNNER_NAME}" ];
then
  export RUNNER_NAME=$(uuidgen)
fi

# Get a runner token from the API (using the app access token)
RUNNER_TOKEN=$(curl \
                -s \
                -X POST \
                -H "Authorization: token ${GITHUB_TOKEN}" \
                -H "Accept: application/vnd.github.v3+json" \
                "https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token" \
                | jq -r .token)

# Remove the runner on exit (ephemeral)
hook_exit() {
  cd /home/github-runner && ./config.sh remove --token "${RUNNER_TOKEN}"
  exit
}
trap hook_exit SIGINT SIGQUIT SIGTERM INT TERM QUIT

# Register the runner (using the runner token we just generated)
./config.sh \
    --url "https://github.com/${GITHUB_ORG}" \
    --token "${RUNNER_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --unattended \
    --replace \
    --disableupdate \
    --labels self-hosted,ubuntu-20.04 \
    --ephemeral

# Start the runner (will terminate after 1 job)
exec ./run.sh
