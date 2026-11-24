"""Intentional insecure sample for the demo gate.

Nothing in the service imports this module, and the image build does not copy it.
"""

import subprocess


def run_user_command(command: str) -> str:
    completed = subprocess.run(
        command,
        shell=True,
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout
