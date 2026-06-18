import unittest
from unittest.mock import patch, mock_open, call
import os
import yaml
from cidata_ingest import ingest_cleartext_yaml

class TestCidataIngest(unittest.TestCase):

    @patch('builtins.open', new_callable=mock_open, read_data="invalid: yaml: content: [")
    def test_ingest_cleartext_yaml_parsing_failure(self, mock_file):
        """Test that invalid YAML causes ingest_cleartext_yaml to return False."""
        result = ingest_cleartext_yaml("dummy_path.yaml")

        self.assertFalse(result)
        mock_file.assert_called_once_with("dummy_path.yaml", 'r')

    @patch('builtins.open', new_callable=mock_open, read_data="")
    def test_ingest_cleartext_yaml_empty(self, mock_file):
        """Test that empty YAML causes ingest_cleartext_yaml to return False."""
        result = ingest_cleartext_yaml("dummy_path.yaml")
        self.assertFalse(result)

    @patch('builtins.open', new_callable=mock_open, read_data="key: value")
    def test_ingest_cleartext_yaml_no_write_files(self, mock_file):
        """Test that missing write_files causes ingest_cleartext_yaml to return False."""
        result = ingest_cleartext_yaml("dummy_path.yaml")
        self.assertFalse(result)

    @patch('os.chown')
    @patch('os.chmod')
    @patch('os.makedirs')
    @patch('builtins.open', new_callable=mock_open, read_data="write_files:\n  - path: /etc/test.conf\n    content: test_content\n    owner: root:root\n    permissions: '0644'")
    def test_ingest_cleartext_yaml_success(self, mock_file, mock_makedirs, mock_chmod, mock_chown):
        """Test successful parsing and writing of files."""
        result = ingest_cleartext_yaml("dummy_path.yaml")
        self.assertTrue(result)

        # We need to verify that it attempted to write the file properly.
        # The first call to open is reading the YAML, the second is writing the file.
        calls = mock_file.call_args_list
        self.assertEqual(len(calls), 2)

        # The second call is to open the target file for writing
        target_path = "/target/etc/test.conf"
        self.assertEqual(calls[1], call(target_path, 'w'))

        # Get the file handle from the mock to check what was written
        handle = mock_file.return_value
        handle.write.assert_called_with('test_content')

if __name__ == '__main__':
    unittest.main()
