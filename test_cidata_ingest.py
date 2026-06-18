import pytest
import os
import sys
import yaml
from unittest.mock import patch, mock_open, MagicMock, call

# Add current directory to path so we can import cidata_ingest
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import cidata_ingest

@pytest.fixture
def mock_tty():
    with patch('os.path.exists', return_value=True), \
         patch('os.open', return_value=3), \
         patch('os.fdopen') as mock_fdopen:
        mock_in = MagicMock()
        mock_out = MagicMock()
        mock_fdopen.side_effect = lambda fd, mode: mock_in if mode == 'r' else mock_out
        yield mock_in, mock_out

class TestPromptPassphrase:
    @patch('getpass.getpass', return_value="my_secret")
    def test_prompt_passphrase_success_getpass(self, mock_getpass, mock_tty):
        mock_in, mock_out = mock_tty
        passphrase = cidata_ingest.prompt_passphrase()
        assert passphrase == "my_secret"
        mock_out.write.assert_called()

    @patch('getpass.getpass', side_effect=Exception("No getpass"))
    def test_prompt_passphrase_fallback_stdin(self, mock_getpass, mock_tty):
        mock_in, mock_out = mock_tty
        mock_in.readline.return_value = "fallback_secret\n"
        passphrase = cidata_ingest.prompt_passphrase()
        assert passphrase == "fallback_secret"
        mock_out.write.assert_called()


class TestDecryptSecretsArchive:
    @patch('cidata_ingest.prompt_passphrase', return_value="secret")
    @patch('subprocess.run')
    @patch('os.remove')
    @patch('os.system')
    @patch('os.path.exists', return_value=True)
    def test_decrypt_secrets_archive_success(self, mock_exists, mock_system, mock_remove, mock_run, mock_prompt):
        # Setup mock subprocess.run to return success (0)
        mock_res = MagicMock()
        mock_res.returncode = 0
        mock_run.return_value = mock_res

        success = cidata_ingest.decrypt_secrets_archive("dummy.enc")

        assert success is True
        assert mock_run.call_count == 2
        mock_system.assert_called()
        mock_remove.assert_called_once_with('/tmp/secrets.tar.gz')

    @patch('cidata_ingest.prompt_passphrase', return_value="secret")
    @patch('subprocess.run')
    def test_decrypt_secrets_archive_decryption_fail(self, mock_run, mock_prompt):
        mock_res = MagicMock()
        mock_res.returncode = 1
        mock_res.stderr = "bad password"
        mock_run.return_value = mock_res

        success = cidata_ingest.decrypt_secrets_archive("dummy.enc")

        assert success is False
        assert mock_run.call_count == 1

    @patch('cidata_ingest.prompt_passphrase', return_value="secret")
    @patch('subprocess.run')
    @patch('os.path.exists', return_value=False)
    def test_decrypt_secrets_archive_extraction_fail(self, mock_exists, mock_run, mock_prompt):
        mock_res_dec = MagicMock()
        mock_res_dec.returncode = 0

        mock_res_ext = MagicMock()
        mock_res_ext.returncode = 1
        mock_res_ext.stderr = "tar failed"

        mock_run.side_effect = [mock_res_dec, mock_res_ext]

        success = cidata_ingest.decrypt_secrets_archive("dummy.enc")

        assert success is False
        assert mock_run.call_count == 2


class TestIngestCleartextYaml:
    @patch('builtins.open', new_callable=mock_open)
    @patch('yaml.safe_load')
    @patch('os.makedirs')
    @patch('os.chmod')
    @patch('os.chown')
    def test_ingest_cleartext_yaml_success(self, mock_chown, mock_chmod, mock_makedirs, mock_yaml_load, mock_file):
        mock_yaml_load.return_value = {
            'write_files': [
                {'path': '/etc/test.conf', 'content': 'test', 'owner': 'root:root', 'permissions': '0644'},
                {'path': 'local.conf', 'content': 'local', 'owner': 'shane:shane'}
            ]
        }

        success = cidata_ingest.ingest_cleartext_yaml("dummy.yaml")

        assert success is True
        assert mock_makedirs.call_count == 2
        assert mock_file().write.call_count == 2
        mock_chmod.assert_has_calls([call('/target/etc/test.conf', 0o644), call('/target/home/shane/local.conf', 0o600)])
        mock_chown.assert_any_call('/target/etc/test.conf', 0, 0)
        mock_chown.assert_any_call('/target/home/shane/local.conf', 1000, 1000)

    @patch('builtins.open', side_effect=Exception("File not found"))
    def test_ingest_cleartext_yaml_file_error(self, mock_file):
        success = cidata_ingest.ingest_cleartext_yaml("dummy.yaml")
        assert success is False

    @patch('builtins.open', new_callable=mock_open, read_data="invalid yaml")
    def test_ingest_cleartext_yaml_empty(self, mock_file):
        # yaml.safe_load returns None for empty file
        with patch('yaml.safe_load', return_value=None):
            success = cidata_ingest.ingest_cleartext_yaml("dummy.yaml")
            assert success is False

    @patch('builtins.open', new_callable=mock_open)
    @patch('yaml.safe_load', return_value={'other_key': 'value'})
    def test_ingest_cleartext_yaml_no_write_files(self, mock_yaml_load, mock_file):
        success = cidata_ingest.ingest_cleartext_yaml("dummy.yaml")
        assert success is False


class TestMain:
    @patch('os.path.exists')
    @patch('cidata_ingest.decrypt_secrets_archive', return_value=True)
    def test_main_enc_archive_success(self, mock_decrypt, mock_exists):
        mock_exists.side_effect = lambda path: path == '/tmp/cidata/secrets.tar.gz.enc'

        # Should not exit
        cidata_ingest.main()
        mock_decrypt.assert_called_once()

    @patch('os.path.exists')
    @patch('cidata_ingest.decrypt_secrets_archive', return_value=False)
    @patch('sys.exit')
    def test_main_enc_archive_fail(self, mock_exit, mock_decrypt, mock_exists):
        mock_exists.side_effect = lambda path: path == '/tmp/cidata/secrets.tar.gz.enc'

        cidata_ingest.main()
        mock_decrypt.assert_called_once()
        mock_exit.assert_called_once_with(1)

    @patch('os.path.exists')
    @patch('cidata_ingest.ingest_cleartext_yaml', return_value=True)
    def test_main_cleartext_yaml_success(self, mock_ingest, mock_exists):
        mock_exists.side_effect = lambda path: path == '/tmp/cidata/user-data'

        cidata_ingest.main()
        mock_ingest.assert_called_once()

    @patch('os.path.exists')
    @patch('cidata_ingest.ingest_cleartext_yaml', return_value=False)
    @patch('sys.exit')
    def test_main_cleartext_yaml_fail(self, mock_exit, mock_ingest, mock_exists):
        mock_exists.side_effect = lambda path: path == '/tmp/cidata/user-data'

        cidata_ingest.main()
        mock_ingest.assert_called_once()
        mock_exit.assert_called_once_with(1)

    @patch('os.path.exists', return_value=False)
    @patch('sys.exit')
    def test_main_no_files(self, mock_exit, mock_exists):
        cidata_ingest.main()
        mock_exit.assert_called_once_with(1)
