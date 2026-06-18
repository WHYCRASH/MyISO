import os
import tempfile
import unittest
import shutil

from desktop_rename import rename_in_dirs

class TestDesktopRename(unittest.TestCase):

    def setUp(self):
        # Create a temporary directory
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        # Remove the directory after the test
        shutil.rmtree(self.test_dir)

    def test_missing_directory(self):
        # Should not raise an error
        rename_in_dirs('/path/that/definitely/does/not/exist/12345')

    def test_renames_correct_fields(self):
        # Setup mock desktop file
        desktop_content = """[Desktop Entry]
Type=Application
Name=Trojita Email
Exec=trojita
Icon=trojita

[Desktop Action NewMessage]
Name=New Message
Exec=trojita --compose
"""
        filepath = os.path.join(self.test_dir, 'trojita.desktop')
        with open(filepath, 'w') as f:
            f.write(desktop_content)

        # Run function
        rename_in_dirs(self.test_dir)

        # Verify
        with open(filepath, 'r') as f:
            new_content = f.read()

        expected_content = """[Desktop Entry]
Type=Application
Name=Email
Exec=trojita
Icon=trojita

[Desktop Action NewMessage]
Name=New Message
Exec=trojita --compose
"""
        self.assertEqual(new_content, expected_content)

    def test_does_not_rename_wrong_file(self):
        desktop_content = """[Desktop Entry]
Type=Application
Name=Other App
"""
        filepath = os.path.join(self.test_dir, 'other.desktop')
        with open(filepath, 'w') as f:
            f.write(desktop_content)

        rename_in_dirs(self.test_dir)

        with open(filepath, 'r') as f:
            new_content = f.read()

        self.assertEqual(new_content, desktop_content)

if __name__ == '__main__':
    unittest.main()
