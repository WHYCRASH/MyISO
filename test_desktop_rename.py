import os
import unittest
from unittest.mock import patch
import io

import desktop_rename

class TestDesktopRename(unittest.TestCase):
    @patch('sys.stdout', new_callable=io.StringIO)
    def test_rename_in_dirs_non_existent(self, mock_stdout):
        # Using a directory that definitely doesn't exist
        directory = '/non_existent_dir_12345'

        # We need to make sure the directory doesn't exist just in case
        self.assertFalse(os.path.exists(directory))

        # Call the function
        desktop_rename.rename_in_dirs(directory)

        # Verify the output
        expected_output = f"Directory {directory} does not exist. Skipping.\n"
        self.assertEqual(mock_stdout.getvalue(), expected_output)

if __name__ == '__main__':
    unittest.main()
