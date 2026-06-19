import pytest
from unittest.mock import patch
import os
import sys
import io

import cidata_ingest

@patch('sys.stdout', new_callable=io.StringIO)
@patch('sys.stdin', new_callable=io.StringIO)
@patch('os.open')
@patch('getpass.getpass')
@patch('os.path.exists')
def test_prompt_passphrase_tty_open_failure(mock_exists, mock_getpass, mock_os_open, mock_stdin, mock_stdout):
    """
    Test that prompt_passphrase falls back to sys.stdin and sys.stdout
    when os.open fails to open the TTY path.
    """
    mock_exists.return_value = True
    mock_os_open.side_effect = Exception("Permission denied")
    mock_getpass.return_value = "my_secret_passphrase"

    result = cidata_ingest.prompt_passphrase()

    mock_os_open.assert_called_once()
    assert result == "my_secret_passphrase"

    output = mock_stdout.getvalue()
    assert "Warning: could not open /dev/tty1, falling back to stdin/stdout: Permission denied" in output
    assert "ENTER CIDATA SECRETS DECRYPTION KEY" in output
