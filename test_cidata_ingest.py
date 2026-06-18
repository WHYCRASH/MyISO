import pytest
from unittest.mock import patch, MagicMock
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

@patch('cidata_ingest.getpass.getpass')
@patch('cidata_ingest.os.open')
@patch('cidata_ingest.os.fdopen')
@patch('cidata_ingest.os.path.exists')
def test_prompt_passphrase_getpass_fallback_tty(mock_exists, mock_fdopen, mock_open, mock_getpass):
    """
    Test the fallback behavior when getpass fails (e.g. not a terminal) and
    the application successfully opens a TTY.
    """
    mock_exists.return_value = True
    mock_getpass.side_effect = Exception("Not a terminal")

    mock_tty_in = MagicMock()
    mock_tty_out = MagicMock()

    def fdopen_side_effect(fd, mode):
        if mode == 'r':
            return mock_tty_in
        elif mode == 'w':
            return mock_tty_out
        return MagicMock()

    mock_fdopen.side_effect = fdopen_side_effect
    mock_tty_in.readline.return_value = "my_fallback_secret\n"

    result = cidata_ingest.prompt_passphrase()

    mock_getpass.assert_called_once()
    mock_tty_out.write.assert_any_call("Enter passphrase: ")
    mock_tty_out.flush.assert_called()
    mock_tty_in.readline.assert_called_once()
    assert result == "my_fallback_secret"

@patch('cidata_ingest.getpass.getpass')
@patch('cidata_ingest.os.open', side_effect=Exception('Mocked tty failure'))
@patch('sys.stdin', new_callable=io.StringIO)
@patch('sys.stdout', new_callable=io.StringIO)
def test_prompt_passphrase_getpass_fallback_sys_io(mock_stdout, mock_stdin, mock_os_open, mock_getpass):
    """
    Test the fallback behavior when getpass fails and the application
    falls back to sys.stdin/stdout (e.g., when a TTY could not be opened).
    """
    mock_stdin.write("fallback_passphrase_sys\n")
    mock_stdin.seek(0)
    mock_getpass.side_effect = Exception("Not a terminal")

    result = cidata_ingest.prompt_passphrase()

    mock_getpass.assert_called_once()
    assert result == "fallback_passphrase_sys"

    output = mock_stdout.getvalue()
    assert "Enter passphrase: " in output
